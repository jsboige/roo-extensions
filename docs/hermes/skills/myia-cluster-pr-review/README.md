# myia-cluster-pr-review — reduced edition

This is the **reduced, publishable** edition of the `myia-cluster-pr-review` skill used by the Hermes PR-review lane (myia-po-2026:hermes-pr-review).

## Where the full edition lives

The complete skill (full SKILL.md with the complete protocol history, incident references and operational details) lives on the **po-2026** machine at `~/skills/github/myia-cluster-pr-review/` and is not published here. This directory contains everything needed to run review cycles elsewhere: the protocol, the four scripts, and the canonical fingerprints.

## Contents

- `SKILL.md` — reduced protocol (dedup #2505, opener gate #3219, notebook full-read + gates #17040, living-proof rule, output format).
- `scripts/nb_view.py` — structural notebook renderer (byte-exact canonical copy, see fingerprint in SKILL.md).
- `scripts/dedup-triage.sh` — cycle dedup table.
- `scripts/fast-dedup-sweep.sh` — cross-repo coverage sweep.
- `scripts/validate-output-format.py` — cycle output line validator.

## Rebuilding from canon

`nb_view.py` here is a byte-exact copy of the canonical file. To rebuild or verify:

```
sha256sum scripts/nb_view.py
# a52bc37a03133507a7de45e8bec11a82b374ae3225b99abce029c8013162be6f
```

Canonical source: jsboige/CoursIA PR #17167, commit `d2e2035c` (`scripts/notebook_tools/nb_view.py`). Any change must land in the canonical source first, then be re-copied here with updated fingerprints — never fork this copy.
