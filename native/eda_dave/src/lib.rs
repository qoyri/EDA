use davey::{
    errors::{EncryptError, ProcessCommitError, ProcessWelcomeError},
    DaveSession, ProposalsOperationType, SessionStatus, DAVE_PROTOCOL_VERSION,
};
use rustler::{Atom, Binary, Encoder, Env, NewBinary, ResourceArc, Term};
use std::num::NonZeroU16;
use std::sync::Mutex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
        not_ready,
        encryption_failed,
        nil,
        append,
        revoke,
        inactive,
        pending,
        awaiting_response,
        active,
        already_in_group,
        no_external_sender,
        no_group,
        pending_group,
        invalid,
    }
}

struct DaveSessionResource(Mutex<DaveSession>);

#[rustler::resource_impl]
impl rustler::Resource for DaveSessionResource {}

fn to_binary<'a>(env: Env<'a>, data: &[u8]) -> Binary<'a> {
    let mut bin = NewBinary::new(env, data.len());
    bin.as_mut_slice().copy_from_slice(data);
    bin.into()
}

// Session creation and re-initialisation generate a signing key pair, so they run on a dirty
// scheduler like the other MLS operations.
#[rustler::nif(schedule = "DirtyCpu")]
fn new_session(
    protocol_version: u16,
    user_id: u64,
    channel_id: u64,
) -> Result<ResourceArc<DaveSessionResource>, Atom> {
    let pv = NonZeroU16::new(protocol_version).ok_or(atoms::error())?;
    match DaveSession::new(pv, user_id, channel_id, None) {
        Ok(session) => Ok(ResourceArc::new(DaveSessionResource(Mutex::new(session)))),
        Err(_) => Err(atoms::error()),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn create_key_package<'a>(
    env: Env<'a>,
    resource: ResourceArc<DaveSessionResource>,
) -> Result<(Atom, Binary<'a>), Atom> {
    let mut session = resource.0.lock().map_err(|_| atoms::error())?;
    match session.create_key_package() {
        Ok(bytes) => Ok((atoms::ok(), to_binary(env, &bytes))),
        Err(_) => Err(atoms::error()),
    }
}

#[rustler::nif]
fn set_external_sender(
    resource: ResourceArc<DaveSessionResource>,
    credential: Binary,
) -> Atom {
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error(),
    };
    match session.set_external_sender(credential.as_slice()) {
        Ok(()) => atoms::ok(),
        Err(_) => atoms::error(),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn process_proposals<'a>(
    env: Env<'a>,
    resource: ResourceArc<DaveSessionResource>,
    operation_type: Atom,
    proposals: Binary,
    user_ids: Vec<u64>,
) -> Result<(Atom, Binary<'a>, Option<Binary<'a>>), Atom> {
    let mut session = resource.0.lock().map_err(|_| atoms::error())?;

    let op_type = if operation_type == atoms::revoke() {
        ProposalsOperationType::REVOKE
    } else {
        ProposalsOperationType::APPEND
    };

    let expected = if user_ids.is_empty() { None } else { Some(user_ids.as_slice()) };

    match session.process_proposals(op_type, proposals.as_slice(), expected) {
        Ok(Some(commit_welcome)) => {
            let commit_bin = to_binary(env, &commit_welcome.commit);
            let welcome_bin = match commit_welcome.welcome {
                Some(welcome) => Some(to_binary(env, &welcome)),
                None => None,
            };
            Ok((atoms::ok(), commit_bin, welcome_bin))
        }
        Ok(None) => {
            // No commit needed — proposals processed, awaiting external commit
            Ok((atoms::ok(), to_binary(env, &[]), None))
        }
        Err(_) => Err(atoms::error()),
    }
}

// Commit and welcome failures carry a reason, because they call for different handling: a welcome
// refused as `already_in_group` is the expected outcome of a commit race, while a malformed one is not.
#[rustler::nif(schedule = "DirtyCpu")]
fn process_commit<'a>(
    env: Env<'a>,
    resource: ResourceArc<DaveSessionResource>,
    commit: Binary,
) -> Term<'a> {
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error().encode(env),
    };
    match session.process_commit(commit.as_slice()) {
        Ok(()) => atoms::ok().encode(env),
        Err(e) => {
            let reason = match e {
                ProcessCommitError::NoGroup => atoms::no_group(),
                ProcessCommitError::PendingGroup => atoms::pending_group(),
                _ => atoms::invalid(),
            };
            (atoms::error(), reason).encode(env)
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn process_welcome<'a>(
    env: Env<'a>,
    resource: ResourceArc<DaveSessionResource>,
    welcome: Binary,
) -> Term<'a> {
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error().encode(env),
    };
    match session.process_welcome(welcome.as_slice()) {
        Ok(()) => atoms::ok().encode(env),
        Err(e) => {
            let reason = match e {
                ProcessWelcomeError::AlreadyInGroup => atoms::already_in_group(),
                ProcessWelcomeError::NoExternalSender => atoms::no_external_sender(),
                _ => atoms::invalid(),
            };
            (atoms::error(), reason).encode(env)
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn encrypt_opus<'a>(
    env: Env<'a>,
    resource: ResourceArc<DaveSessionResource>,
    packet: Binary,
) -> Result<(Atom, Binary<'a>), Atom> {
    let mut session = resource.0.lock().map_err(|_| atoms::error())?;
    match session.encrypt_opus(packet.as_slice()) {
        Ok(encrypted) => Ok((atoms::ok(), to_binary(env, &encrypted))),
        Err(EncryptError::NotReady) => Err(atoms::not_ready()),
        Err(EncryptError::EncryptionFailed) => Err(atoms::encryption_failed()),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn decrypt_audio<'a>(
    env: Env<'a>,
    resource: ResourceArc<DaveSessionResource>,
    sender_user_id: u64,
    packet: Binary,
) -> Result<(Atom, Binary<'a>), Atom> {
    let mut session = resource.0.lock().map_err(|_| atoms::error())?;
    match session.decrypt(
        sender_user_id,
        davey::MediaType::AUDIO,
        packet.as_slice(),
    ) {
        Ok(decrypted) => Ok((atoms::ok(), to_binary(env, &decrypted))),
        Err(_) => Err(atoms::error()),
    }
}

#[rustler::nif(name = "can_passthrough?")]
fn can_passthrough(
    resource: ResourceArc<DaveSessionResource>,
    user_id: u64,
) -> Result<bool, Atom> {
    let session = resource.0.lock().map_err(|_| atoms::error())?;
    Ok(session.can_passthrough(user_id))
}

#[rustler::nif]
fn get_epoch(resource: ResourceArc<DaveSessionResource>) -> Result<u64, Atom> {
    let session = resource.0.lock().map_err(|_| atoms::error())?;
    match session.epoch() {
        Some(epoch) => Ok(epoch.as_u64()),
        None => Ok(0),
    }
}

#[rustler::nif(name = "ready?")]
fn is_ready(resource: ResourceArc<DaveSessionResource>) -> Result<bool, Atom> {
    let session = resource.0.lock().map_err(|_| atoms::error())?;
    Ok(session.is_ready())
}

#[rustler::nif]
fn set_passthrough_mode(
    resource: ResourceArc<DaveSessionResource>,
    passthrough: bool,
    transition_expiry: u32,
) -> Atom {
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error(),
    };
    session.set_passthrough_mode(passthrough, Some(transition_expiry));
    atoms::ok()
}

#[rustler::nif]
fn reset(resource: ResourceArc<DaveSessionResource>) -> Atom {
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error(),
    };
    match session.reset() {
        Ok(()) => atoms::ok(),
        Err(_) => atoms::error(),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn reinit(
    resource: ResourceArc<DaveSessionResource>,
    protocol_version: u16,
    user_id: u64,
    channel_id: u64,
) -> Atom {
    let pv = match NonZeroU16::new(protocol_version) {
        Some(v) => v,
        None => return atoms::error(),
    };
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error(),
    };
    match session.reinit(pv, user_id, channel_id, None) {
        Ok(()) => atoms::ok(),
        Err(_) => atoms::error(),
    }
}

#[rustler::nif]
fn status(resource: ResourceArc<DaveSessionResource>) -> Result<Atom, Atom> {
    let session = resource.0.lock().map_err(|_| atoms::error())?;
    let atom = match session.status() {
        SessionStatus::INACTIVE => atoms::inactive(),
        SessionStatus::PENDING => atoms::pending(),
        SessionStatus::AWAITING_RESPONSE => atoms::awaiting_response(),
        SessionStatus::ACTIVE => atoms::active(),
    };
    Ok(atom)
}

#[rustler::nif]
fn protocol_version(resource: ResourceArc<DaveSessionResource>) -> Result<u16, Atom> {
    let session = resource.0.lock().map_err(|_| atoms::error())?;
    Ok(session.protocol_version().get())
}

#[rustler::nif]
fn max_protocol_version() -> u16 {
    DAVE_PROTOCOL_VERSION
}

// ── Gateway transport compression ────────────────────────────────────────────
//
// zstd-stream: one decompression context per gateway connection, fed each WebSocket message as
// Discord flushes it. It lives in this NIF because EDA already ships it precompiled; the gateway
// reaches it through EDA.Gateway.Zstd.

// The output buffer is kept between messages, so decompressing one allocates nothing but the
// binary it returns.
struct ZstdState {
    dctx: zstd::zstd_safe::DCtx<'static>,
    out: Vec<u8>,
}

struct ZstdResource(Mutex<ZstdState>);

#[rustler::resource_impl]
impl rustler::Resource for ZstdResource {}

#[rustler::nif]
fn zstd_new() -> Result<ResourceArc<ZstdResource>, Atom> {
    let dctx = zstd::zstd_safe::DCtx::try_create().ok_or(atoms::error())?;
    let state = ZstdState {
        dctx,
        out: Vec::with_capacity(64 * 1024),
    };
    Ok(ResourceArc::new(ZstdResource(Mutex::new(state))))
}

fn zstd_run<'a>(
    env: Env<'a>,
    resource: &ResourceArc<ZstdResource>,
    input: &Binary,
) -> Result<Binary<'a>, Atom> {
    let mut guard = resource.0.lock().map_err(|_| atoms::error())?;
    let ZstdState { dctx, out } = &mut *guard;
    out.clear();
    let mut in_buf = zstd::zstd_safe::InBuffer::around(input.as_slice());

    loop {
        if out.capacity() - out.len() < 1024 {
            out.reserve(out.capacity());
        }
        let pos = out.len();
        let mut out_buf = zstd::zstd_safe::OutBuffer::around_pos(out, pos);
        dctx.decompress_stream(&mut out_buf, &mut in_buf)
            .map_err(|_| atoms::error())?;
        let full = out_buf.pos() == out_buf.capacity();
        // Done once the input is consumed and the output was not the limit.
        if in_buf.pos() == input.len() && !full {
            break;
        }
    }

    let result = to_binary(env, out);
    // A huge READY must not keep its buffer for the life of the connection.
    if out.capacity() > 1024 * 1024 {
        *out = Vec::with_capacity(64 * 1024);
    }
    Ok(result)
}

// Most messages decompress in microseconds, well within a normal scheduler's budget; a large
// GUILD_CREATE or READY goes to the dirty one, chosen by input size on the Elixir side.
#[rustler::nif]
fn zstd_decompress<'a>(
    env: Env<'a>,
    resource: ResourceArc<ZstdResource>,
    input: Binary,
) -> Result<Binary<'a>, Atom> {
    zstd_run(env, &resource, &input)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn zstd_decompress_dirty<'a>(
    env: Env<'a>,
    resource: ResourceArc<ZstdResource>,
    input: Binary,
) -> Result<Binary<'a>, Atom> {
    zstd_run(env, &resource, &input)
}

#[rustler::nif]
fn zstd_reset(resource: ResourceArc<ZstdResource>) -> Atom {
    match resource.0.lock() {
        Ok(mut state) => match state.dctx.reset(zstd::zstd_safe::ResetDirective::SessionOnly) {
            Ok(_) => atoms::ok(),
            Err(_) => atoms::error(),
        },
        Err(_) => atoms::error(),
    }
}

rustler::init!("Elixir.EDA.Voice.Dave.Native");
