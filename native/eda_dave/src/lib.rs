use davey::{errors::EncryptError, DaveSession, ProposalsOperationType};
use rustler::{Atom, Binary, Env, NewBinary, ResourceArc};
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

#[rustler::nif]
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

#[rustler::nif]
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

#[rustler::nif]
fn process_proposals<'a>(
    env: Env<'a>,
    resource: ResourceArc<DaveSessionResource>,
    operation_type: Atom,
    proposals: Binary,
) -> Result<(Atom, Binary<'a>, Option<Binary<'a>>), Atom> {
    let mut session = resource.0.lock().map_err(|_| atoms::error())?;

    let op_type = if operation_type == atoms::revoke() {
        ProposalsOperationType::REVOKE
    } else {
        ProposalsOperationType::APPEND
    };

    match session.process_proposals(op_type, proposals.as_slice(), None) {
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

#[rustler::nif]
fn process_commit(
    resource: ResourceArc<DaveSessionResource>,
    commit: Binary,
) -> Atom {
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error(),
    };
    match session.process_commit(commit.as_slice()) {
        Ok(()) => atoms::ok(),
        Err(_) => atoms::error(),
    }
}

#[rustler::nif]
fn process_welcome(
    resource: ResourceArc<DaveSessionResource>,
    welcome: Binary,
) -> Atom {
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error(),
    };
    match session.process_welcome(welcome.as_slice()) {
        Ok(()) => atoms::ok(),
        Err(_) => atoms::error(),
    }
}

#[rustler::nif]
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

#[rustler::nif]
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
) -> Atom {
    let mut session = match resource.0.lock() {
        Ok(s) => s,
        Err(_) => return atoms::error(),
    };
    session.set_passthrough_mode(passthrough, None);
    atoms::ok()
}

rustler::init!("Elixir.EDA.Voice.Dave.Native");
