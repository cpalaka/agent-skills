Raw report of the Correctness-charter arm (b5): one read-only `code-reviewer` seat, round B diff
(`git diff main...research/codex-lens-b`), fed the same acceptance criteria and hard limits as b1
plus the charter from `implement-run/SKILL.md` § Review, "Fallback". Told not to use `gh` or the
network. 3 tool calls, 43 s wall. Verbatim below.

---

Correctness review of `git diff main...research/codex-lens-b`. Two files: `docs/audits/fixtures/metrics-uploader/uploader.py` and `test_uploader.py`, both new.

I probed behaviour on copies in `$TMPDIR/cr-uploader`. The suite passes: `Ran 5 tests … OK`. The code still fails criteria 1, 2 and 4, and the tests would not catch any of these failures.

**1. The batch size is over the API cap (hard, violates AC 1).** `uploader.py:7`: `BATCH_SIZE = 265`
- **What goes wrong:** the cap is 256. It looks like the digits were swapped. Every batch but the last has 265 records. `make_batches(range(1000))` returned `[265, 265, 265, 205]`.
- **Why the code is exposed:** nothing checks the constant against the cap.
- **Impact:** the metrics API rejects every full batch. Uploads fail for any input over 256 records.
- **Remedy:** set it to 256 and add a test that asserts `max(len(b)) <= 256`.

**2. The tests cannot detect the cap violation (hard, violates AC 3's intent, which is to cover AC 1).** `test_uploader.py:10-11`: `self.assertEqual(len(make_batches(range(1000))), 4)`
- **What goes wrong:** 1000 records make 4 batches whether the size is 256 or 265. No test checks the size of any batch.
- **Impact:** finding 1 passes CI.
- **Remedy:** assert the size of each batch against 256.

**3. The 10% threshold check depends on floating-point rounding (hard, violates AC 2).** `uploader.py:18-20`: `reserve = 1.0 - sum(shares)` / `if reserve <= RESERVE_FLOOR:`
- **What goes wrong:** every probe below allocates exactly 90%, which leaves exactly 10%. AC 2 says that must raise, but the results split on float rounding:
  - `[0.3, 0.3, 0.3]` and `[0.6, 0.3]` are accepted, returning `0.10000000000000009`.
  - `[0.9]`, `[0.45, 0.45]` and `[0.1]*9` raise.
- **Why the code is exposed:** it compares binary floats that cannot represent 0.1 exactly.
- **Impact:** a split with exactly 10% reserve passes or fails depending on how it is written.
- **Remedy:** compare with `fractions.Fraction`/`decimal` or an explicit tolerance so the boundary always raises.

**4. A test asserts the wrong behaviour (hard, violates AC 2).** `test_uploader.py:22-23`: `def test_accepts_three_equal_shares(self): self.assertGreater(check_quota_split([0.3, 0.3, 0.3]), RESERVE_FLOOR)`
- **What goes wrong:** exactly 10% stays unallocated here, which is not "strictly more than 10%". AC 2 requires a `ValueError`, but the test requires acceptance, so it locks in finding 3.
- **Also missing:** no test covers the raising path. `grep -n "assertRaises\|ValueError" test_uploader.py` finds nothing.
- **Remedy:** flip this test to `assertRaises(ValueError)`, and add a clearly-under-reserve case.

**5. The memory profile in the docstring is false (hard, violates AC 4).** `uploader.py:3-4`: `peak usage stays under 4 MB, because only one batch is held at a time.`
- **What goes wrong:** `make_batches` never holds only one batch. Line 13 (`items = list(records)`) copies the whole input into a list, and line 14 then builds the full list of batches. I measured with tracemalloc, the instrument the docstring names: `make_batches(range(10_000_000))` peaked at **482 MB**, not under 4 MB.
- **Impact:** anyone who trusts the docstring and passes a large stream can run out of memory. AC 4 is met in form but not in substance.
- **Remedy:** either make it a generator that yields one batch at a time, or record the measured profile.

**6. Negative or out-of-range shares get through the check (judgment, uncertain).** `uploader.py:19`
- **What goes wrong:** `check_quota_split([1.5, -1.0])` returns `0.5`, so one consumer gets 150% of the quota and the check still passes.
- **Why uncertain:** AC 2 does not say whether shares are validated as non-negative, so this may be out of scope.
- **Remedy:** reject any share below 0 or above 1.

The hard limits (standard library only, Python 3.9+, no network in tests) are not violated. The only import is `unittest`, and nothing uses syntax newer than 3.9 (f-strings date from 3.6).

FINDINGS: 6 (hard 5, judgment 1)
