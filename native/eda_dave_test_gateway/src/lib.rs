//! The MLS side of Discord's voice gateway, for tests.
//!
//! A DAVE group cannot form without the gateway: it is the group's external sender, the only
//! party allowed to propose who joins and who leaves. This crate plays that part, so that tests
//! can run real groups of several sessions without Discord: it signs the proposals, and it takes
//! apart the commit and welcome a member answers with, as the gateway does before relaying them.
//!
//! The external sender follows the one in the test suites of libdave and davey.

use openmls::prelude::{
    tls_codec::{Deserialize, Serialize},
    *,
};
use openmls_basic_credential::SignatureKeyPair;
use openmls_rust_crypto::OpenMlsRustCrypto;
use rustler::{Binary, Env, NewBinary, ResourceArc};
use std::sync::Mutex;

struct Gateway {
    provider: OpenMlsRustCrypto,
    group_id: GroupId,
    signer: SignatureKeyPair,
    external_sender: ExternalSender,
}

struct GatewayResource(Mutex<Gateway>);

#[rustler::resource_impl]
impl rustler::Resource for GatewayResource {}

fn to_binary<'a>(env: Env<'a>, data: &[u8]) -> Binary<'a> {
    let mut bin = NewBinary::new(env, data.len());
    bin.as_mut_slice().copy_from_slice(data);
    bin.into()
}

fn failed<E: std::fmt::Debug>(error: E) -> String {
    format!("{error:?}")
}

/// A gateway for the group of one channel: a DAVE group's id is its channel's.
#[rustler::nif]
fn new(channel_id: u64) -> Result<ResourceArc<GatewayResource>, String> {
    let ciphersuite = Ciphersuite::MLS_128_DHKEMP256_AES128GCM_SHA256_P256;
    let signer = SignatureKeyPair::new(ciphersuite.signature_algorithm()).map_err(failed)?;
    let external_sender = ExternalSender::new(
        signer.public().into(),
        BasicCredential::new(vec![0x00, 0x01, 0x01, 0x00]).into(),
    );

    Ok(ResourceArc::new(GatewayResource(Mutex::new(Gateway {
        provider: OpenMlsRustCrypto::default(),
        group_id: GroupId::from_slice(&channel_id.to_be_bytes()),
        signer,
        external_sender,
    }))))
}

/// The payload of opcode 25, DAVE_MLS_EXTERNAL_SENDER.
#[rustler::nif]
fn external_sender<'a>(
    env: Env<'a>,
    resource: ResourceArc<GatewayResource>,
) -> Result<Binary<'a>, String> {
    let gateway = resource.0.lock().map_err(failed)?;
    let bytes = gateway
        .external_sender
        .tls_serialize_detached()
        .map_err(failed)?;
    Ok(to_binary(env, &bytes))
}

/// The proposals of an appending opcode 27, DAVE_MLS_PROPOSALS, for a group at `epoch`: one to add
/// the owner of each key package, one to remove the member at each leaf.
#[rustler::nif]
fn proposals<'a>(
    env: Env<'a>,
    resource: ResourceArc<GatewayResource>,
    epoch: u64,
    key_packages: Vec<Binary>,
    removed_leaves: Vec<u32>,
) -> Result<Binary<'a>, String> {
    let gateway = resource.0.lock().map_err(failed)?;
    let mut messages: Vec<u8> = Vec::new();

    for key_package in key_packages {
        let key_package = KeyPackageIn::tls_deserialize_exact_bytes(key_package.as_slice())
            .map_err(failed)?
            .validate(gateway.provider.crypto(), ProtocolVersion::Mls10)
            .map_err(failed)?;

        let message = ExternalProposal::new_add::<OpenMlsRustCrypto>(
            key_package,
            gateway.group_id.clone(),
            GroupEpoch::from(epoch),
            &gateway.signer,
            SenderExtensionIndex::new(0),
        )
        .map_err(failed)?;

        messages.extend(message.tls_serialize_detached().map_err(failed)?);
    }

    for leaf in removed_leaves {
        let message = ExternalProposal::new_remove::<OpenMlsRustCrypto>(
            LeafNodeIndex::new(leaf),
            gateway.group_id.clone(),
            GroupEpoch::from(epoch),
            &gateway.signer,
            SenderExtensionIndex::new(0),
        )
        .map_err(failed)?;

        messages.extend(message.tls_serialize_detached().map_err(failed)?);
    }

    let bytes = VLBytes::new(messages)
        .tls_serialize_detached()
        .map_err(failed)?;
    Ok(to_binary(env, &bytes))
}

/// Splits the payload of opcode 28, DAVE_MLS_COMMIT_WELCOME, into the commit and the welcome that
/// may follow it: the gateway announces the first to the members and sends the second to those
/// being added.
#[rustler::nif]
fn split_commit_welcome<'a>(
    env: Env<'a>,
    payload: Binary,
) -> Result<(Binary<'a>, Option<Binary<'a>>), String> {
    let bytes = payload.as_slice();
    let mut rest = bytes;
    MlsMessageIn::tls_deserialize(&mut rest).map_err(failed)?;

    let commit = &bytes[..bytes.len() - rest.len()];
    let welcome = if rest.is_empty() {
        None
    } else {
        Some(to_binary(env, rest))
    };

    Ok((to_binary(env, commit), welcome))
}

rustler::init!("Elixir.EDA.Test.DaveGateway.Native");
