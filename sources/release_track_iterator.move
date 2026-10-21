// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// A hot potato that walks a release's tracklist in order, one track at a
/// time. Each step is a separate PTB command, so a consumer can make a typed
/// call per track (e.g. into each recording's pool). Only `W`'s defining module
/// can start, advance or finish an iterator, and `finish` requires every track
/// to have been visited.
module release_track_iterator::release_track_iterator;

// === Imports ===

use miso_music::release::Release;

// === Errors ===

const ENoTracksRemaining: u64 = 0;
const ETracksRemaining: u64 = 1;

// === Structs ===

public struct ReleaseTrackIterator<phantom W> {
    release_id: ID,
    recording_ids: vector<ID>,
    /// Index of the next track; also the number of tracks visited.
    position: u64,
}

// === Public Functions ===

public fun new<W: drop>(_: W, release: &Release): ReleaseTrackIterator<W> {
    ReleaseTrackIterator {
        release_id: object::id(release),
        recording_ids: *release.recording_ids(),
        position: 0,
    }
}

public fun next<W: drop>(self: &mut ReleaseTrackIterator<W>, _: W): ID {
    assert!(self.position < self.recording_ids.length(), ENoTracksRemaining);
    let recording_id = self.recording_ids[self.position];
    self.position = self.position + 1;
    recording_id
}

public fun finish<W: drop>(self: ReleaseTrackIterator<W>, _: W) {
    let ReleaseTrackIterator { recording_ids, position, .. } = self;
    assert!(position == recording_ids.length(), ETracksRemaining);
}

// === View Functions ===

public fun release_id<W>(self: &ReleaseTrackIterator<W>): ID {
    self.release_id
}

/// Also the number of tracks visited.
public fun position<W>(self: &ReleaseTrackIterator<W>): u64 {
    self.position
}

public fun remaining<W>(self: &ReleaseTrackIterator<W>): u64 {
    self.recording_ids.length() - self.position
}
