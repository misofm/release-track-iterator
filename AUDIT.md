# Security Audit — `release_track_iterator`

Audited at `804b348ba2bde8e371ef1c5a27396fb67942fdbd` (2026-10-21). Scope: package `release_track_iterator`, module `release_track_iterator::release_track_iterator` (`sources/release_track_iterator.move`); depends on `miso_music::release` for the tracklist.

## What it does

A hot potato that copies a `Release`'s tracklist and hands out one recording ID per `next` call, in order, aborting on overrun and refusing to `finish` until every track was visited. See [README](./README.md).

## Trust model

- **The witness's defining module:** `new`, `next` and `finish` (`release_track_iterator.move:25-43`) each consume a `Witness` value, so an iterator over a consumer's private witness struct can be created, advanced and ended only by that module.
- **Anyone else:** can only call the views (`:47-57`) on an iterator a consumer hands them a reference to. A PTB cannot construct a struct witness, so it cannot advance or end a consumer's iterator.
- **Nobody** can drop, store, copy or destructure `ReleaseTrackIterator` outside this module (no abilities, `:17-21`); a started iterator must be run to completion and finished in the same transaction or the transaction fails.

## Findings

**I-1 · Info · Accepted — a primitive or public witness type opens the iterator to everyone.** The witness bound is only `drop` (`:25`, `:33`, `:40`), so `new<u64>(release, 7)` works from any module or PTB (probe). This protects nothing because there is nothing to protect: the authorization only matters for the consumer's own witness, which it defines as a private struct. Consumers must use their own struct, never a primitive or a type with a public constructor.

**I-2 · Info · Accepted — completeness means every track was handed out, not acted on.** `finish` checks `position == recording_ids.length()` (`:42`). A consumer's own module can call `next` and discard the ID; the iterator cannot prevent that, and the README does not claim otherwise.

**I-3 · Info · Accepted — the tracklist is copied once.** `new` copies up to 1,000 IDs (32 KB) into the hot potato (`:28`). `Release.recording_ids` has no mutator, so the copy cannot diverge from the Release.

## Checked, no finding

- **Order and completeness:** `next` returns `recording_ids[position]` and increments by one (`:34-37`); there is no API that sets `position` or removes IDs, so no track can be skipped or repeated. Verified for 1, 3 and 1,000 tracks (`visits_every_track_in_order`, `walks_a_max_tracks_release`).
- **Bounds:** `next` asserts `position < length` (`ENoTracksRemaining`, `:34`), so `position <= length` always holds and `remaining` (`:56`) cannot underflow. `finish` on an incomplete or unstarted iterator aborts `ETracksRemaining` (`:42`). Both abort codes are reachable (tests).
- **Empty releases:** `new` on a zero-track Release finishes immediately and `next` aborts (`empty_release_finishes_immediately`, `next_on_empty_release_aborts`). On chain `release::new` rejects empty tracklists, so this path only exists through `new_for_testing`.
- **Witness isolation:** iterators over different witness types on one Release advance independently (`iterators_with_different_witnesses_advance_independently`). Witness identity includes the defining address and module, so a same-named struct elsewhere is a different type.
- **Release binding:** `release_id` (`:47-49`) is recorded for consumers that pair the iterator with per-release state; the iterator itself never reads the Release again.
- **Object lifecycle, derived objects, dynamic fields, events:** none. The package holds no state, no `UID`, emits nothing and touches no shared object; `new` takes `&Release`.
- **Limits:** a PTB-driven walk needs `new`, one `next` plus at least one consumer command per track, and `finish`: at least `2n + 2` commands, so a single PTB can walk about 510 tracks before the 1,024-command limit. The hot potato cannot span transactions, so larger releases must be iterated from Move.

## Operational requirements

- Define the witness as a private struct with only `drop` and never expose a constructor (I-1).
- Releases above about 510 tracks cannot be walked from a PTB within the command limit; drive the iterator from a Move function in that case.

## Verification

- `sui move test --coverage`: 9/9 pass. `sui move coverage summary`: 100.00% (`release_track_iterator`).
- `sui move build -e mainnet --warnings-are-errors` and `-e testnet`: both succeed with no warnings (sui 1.82.1).
- 1 throwaway probe test (iteration with a `u64` witness from a foreign module) passed and was not committed.
