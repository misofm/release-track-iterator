# Security Audit — `release_track_iterator`

Audited at `804b348ba2bde8e371ef1c5a27396fb67942fdbd` (2026-10-21). Scope: package `release_track_iterator`, module `release_track_iterator::release_track_iterator` (`sources/release_track_iterator.move`); depends on `miso_music::release` for the tracklist. Later commits adapt to `miso_music::release` @ `f404d77`, where the iterator copies `release.tracks()` instead of `recording_ids()` and a release holds at most `u8::MAX` = 255 tracks, and make `position` and `remaining` `u8`. Every statement below was re-checked against that code. Line references are to the current code.

## What it does

A hot potato that copies a `Release`'s tracklist and hands out one recording ID per `next` call, in order, aborting on overrun and refusing to `finish` until every track was visited. See [README](./README.md).

## Trust model

- **The witness's defining module:** `new`, `next` and `finish` (`release_track_iterator.move:25-43`) each consume a `Witness` value, so an iterator over a consumer's private witness struct can be created, advanced and ended only by that module.
- **Anyone else:** can only call the views (`:47-57`) on an iterator a consumer hands them a reference to. A PTB cannot construct a struct witness, so it cannot advance or end a consumer's iterator.
- **Nobody** can drop, store, copy or destructure `ReleaseTrackIterator` outside this module (no abilities, `:17-21`); a started iterator must be run to completion and finished in the same transaction or the transaction fails.

## Findings

**I-1 · Info · Accepted — a primitive or public witness type opens the iterator to everyone.** The witness bound is only `drop` (`:25`, `:33`, `:40`), so `new<u64>(release, 7)` works from any module or PTB (probe). This protects nothing because there is nothing to protect: the authorization only matters for the consumer's own witness, which it defines as a private struct. Consumers must use their own struct, never a primitive or a type with a public constructor.

**I-2 · Info · Accepted — completeness means every track was handed out, not acted on.** `finish` checks that `position` equals `tracks.length()` (`:42`). A consumer's own module can call `next` and discard the ID; the iterator cannot prevent that, and the README does not claim otherwise.

**I-3 · Info · Accepted — the tracklist is copied once.** `new` copies up to 255 `Track` values (about 8 KB) into the hot potato (`:28`). `Release.tracks` has no mutator, so the copy cannot diverge from the Release.

## Checked, no finding

- **Order and completeness:** `next` returns the recording ID of `tracks[position]` and increments by one (`:34-37`); there is no API that sets `position` or removes tracks, so no track can be skipped or repeated. Verified for 1, 3 and 255 tracks (`visits_every_track_in_order`, `walks_a_max_tracks_release`).
- **Bounds:** `next` asserts `position < length` (`ENoTracksRemaining`, `:34`), so `position <= length` always holds and `remaining` (`:56`) cannot underflow. `position` is a `u8`: it only increments while below a length of at most 255, so it cannot overflow, and `remaining`'s `as u8` cannot abort. `finish` on an incomplete or unstarted iterator aborts `ETracksRemaining` (`:42`). Both abort codes are reachable (tests).
- **Empty releases:** `new` on a zero-track Release finishes immediately and `next` aborts (`empty_release_finishes_immediately`, `next_on_empty_release_aborts`). On chain `release::new` rejects empty tracklists, so this path only exists through `new_for_testing`.
- **Witness isolation:** iterators over different witness types on one Release advance independently (`iterators_with_different_witnesses_advance_independently`). Witness identity includes the defining address and module, so a same-named struct elsewhere is a different type.
- **Release binding:** `release_id` (`:47-49`) is recorded for consumers that pair the iterator with per-release state; the iterator itself never reads the Release again.
- **Object lifecycle, derived objects, dynamic fields, events:** none. The package holds no state, no `UID`, emits nothing and touches no shared object; `new` takes `&Release`.
- **Limits:** a PTB-driven walk needs `new`, one `next` plus at least one consumer command per track, and `finish`: at least `2n + 2` commands. At the 255-track maximum that is 512, so every release fits within a single PTB's 1,024-command limit when each track takes one consumer command.

## Operational requirements

- Define the witness as a private struct with only `drop` and never expose a constructor (I-1).

## Verification

- `sui move test --coverage`: 9/9 pass. `sui move coverage summary`: 100.00% (`release_track_iterator`).
- `sui move build -e mainnet --warnings-are-errors` and `-e testnet`: both succeed with no warnings (sui 1.82.1).
- 1 throwaway probe test (iteration with a `u64` witness from a foreign module) passed and was not committed.
