// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

#[test_only]
module release_track_iterator::release_track_iterator_tests;

use std::unit_test::destroy;
use sui::address;
use musicos::release::{Self, Release};
use release_track_iterator::release_track_iterator;

public struct Witness() has drop;

fun release(n: u64, ctx: &mut TxContext): (Release, vector<ID>) {
    let release_id = object::id_from_address(@0xbeef);
    let recording_ids = vector::tabulate!(n, |i| object::id_from_address(address::from_u256((i + 1) as u256)));
    let consents = recording_ids.map_ref!(|id| release::consent_for_testing(*id, release_id));
    let (release, cap) = release::new_for_testing(consents, ctx);
    destroy(cap);
    (release, recording_ids)
}

#[test]
fun visits_every_track_in_order() {
    let mut ctx = tx_context::dummy();
    let (release, recording_ids) = release(3, &mut ctx);
    let mut tracks = release_track_iterator::new(Witness(), &release);
    assert!(tracks.release_id() == object::id(&release));

    recording_ids.length().do!(|i| {
        assert!(tracks.position() == i);
        assert!(tracks.remaining() == 3 - i);
        assert!(tracks.next(Witness()) == recording_ids[i]);
    });
    assert!(tracks.remaining() == 0);
    tracks.finish(Witness());
    destroy(release);
}

#[test, expected_failure(abort_code = release_track_iterator::ETracksRemaining)]
fun finish_with_tracks_remaining_aborts() {
    let mut ctx = tx_context::dummy();
    let (release, _) = release(2, &mut ctx);
    let mut tracks = release_track_iterator::new(Witness(), &release);
    tracks.next(Witness());
    tracks.finish(Witness());
    destroy(release);
}

#[test, expected_failure(abort_code = release_track_iterator::ENoTracksRemaining)]
fun next_past_last_track_aborts() {
    let mut ctx = tx_context::dummy();
    let (release, _) = release(1, &mut ctx);
    let mut tracks = release_track_iterator::new(Witness(), &release);
    tracks.next(Witness());
    tracks.next(Witness());
    tracks.finish(Witness());
    destroy(release);
}
