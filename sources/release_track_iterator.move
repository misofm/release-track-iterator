// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

module release_track_iterator::release_track_iterator;

// === Imports ===

use miso_music::release::{Release, Track};

// === Errors ===

const ENoTracksRemaining: u64 = 0;
const ETracksRemaining: u64 = 1;

// === Structs ===

public struct ReleaseTrackIterator<phantom Witness> {
    release_id: ID,
    tracks: vector<Track>,
    position: u64,
}

// === Public Functions ===

public fun new<Witness: drop>(release: &Release, _: Witness): ReleaseTrackIterator<Witness> {
    ReleaseTrackIterator {
        release_id: object::id(release),
        tracks: *release.tracks(),
        position: 0,
    }
}

public fun next<Witness: drop>(self: &mut ReleaseTrackIterator<Witness>, _: Witness): ID {
    assert!(self.position < self.tracks.length(), ENoTracksRemaining);
    let recording_id = self.tracks[self.position].recording_id();
    self.position = self.position + 1;
    recording_id
}

public fun finish<Witness: drop>(self: ReleaseTrackIterator<Witness>, _: Witness) {
    let ReleaseTrackIterator { tracks, position, .. } = self;
    assert!(position == tracks.length(), ETracksRemaining);
}

// === View Functions ===

public fun release_id<Witness>(self: &ReleaseTrackIterator<Witness>): ID {
    self.release_id
}

public fun position<Witness>(self: &ReleaseTrackIterator<Witness>): u64 {
    self.position
}

public fun remaining<Witness>(self: &ReleaseTrackIterator<Witness>): u64 {
    self.tracks.length() - self.position
}
