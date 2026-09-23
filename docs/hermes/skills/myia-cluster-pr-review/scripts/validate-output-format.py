#!/usr/bin/env python3
"""
Output format validator for the MyIA cluster PR review cycle.

Run this as the LAST step before delivering your final response. It validates
the output format line against the three-branch gate contract.

Usage:
    # Branch C (posted >= 1): validate the full format line
    python3 scripts/validate-output-format.py \
        --posted 1 --skipped 14 \
        --prs "#9437 COMMENT (CoursIA)" \
        --presence

    # Branch A (posted == 0, presence mode): validate presence line
    python3 scripts/validate-output-format.py --posted 0 --skipped 14 --presence

    # Branch B (posted == 0, no presence): just confirm [SILENT]
    python3 scripts/validate-output-format.py --posted 0 --skipped 14

Exit code 0 = PASS, 1 = FAIL (prints the violation + corrected version).

WHY THIS SCRIPT EXISTS:
    The output gate has been violated 30+ times (recurrences 1-30, 2026-06-22
    through 2026-08-04) despite extensive documentation. The root cause is
    always the same: the agent hand-types the output from memory instead of
    running a programmatic check. This script is zero-friction — one command,
    pass/fail output — to break the recurrence cycle.
"""

import argparse
import re
import sys


def validate_skip_clause(skip_text: str) -> list[str]:
    """Validate the skip clause matches ^\\d+ SHA-match.$"""
    violations = []
    expected_pattern = r"^\d+ SHA-match\.$"
    if not re.match(expected_pattern, skip_text):
        # Extract the number for the corrected version
        m = re.match(r"^(\d+)", skip_text)
        count = m.group(1) if m else "N"
        violations.append(
            f"SKIP CLAUSE VIOLATION: '{skip_text}'\n"
            f"  Must be exactly: '{count} SHA-match.'\n"
            f"  No PR numbers, no reviewer names, no reasons, no French text after the period."
        )
    return violations


def validate_prs_clause(prs_text: str) -> list[str]:
    """Validate each PR entry is #NNN <RESULT_KEYWORD> (RepoName) with nothing else."""
    violations = []
    # Valid result keywords (GitHub review event types ONLY)
    valid_keywords = {"COMMENT", "APPROVE", "CHANGES_REQUESTED", "COMMENT_WITH_CONCERNS"}

    # Match entries like "#NNN COMMENT (Repo)" or "#NNN COMMENT (Repo),"
    # The whole PRs clause is comma-separated entries
    entries = [e.strip() for e in prs_text.split(",") if e.strip()]

    for entry in entries:
        # Expected pattern: #NNN KEYWORD (RepoName)
        m = re.match(
            r"^#(\d+)\s+(\w+(?:_\w+)?)\s*\(([^)]+)\)$",
            entry,
        )
        if not m:
            violations.append(
                f"PRS CLAUSE VIOLATION: '{entry}'\n"
                f"  Must be: '#NNN RESULT_KEYWORD (RepoName)'\n"
                f"  Example: '#9437 COMMENT (CoursIA)'\n"
                f"  RESULT_KEYWORD = one of: {', '.join(sorted(valid_keywords))}\n"
                f"  No descriptions, no em-dashes, no French prose between keyword and (Repo)."
            )
            continue

        pr_num, keyword, repo = m.groups()
        if keyword not in valid_keywords:
            violations.append(
                f"PRS CLAUSE VIOLATION: '{entry}'\n"
                f"  Keyword '{keyword}' is NOT a valid result keyword.\n"
                f"  Valid: {', '.join(sorted(valid_keywords))}\n"
                f"  '{keyword}' looks like a description of the PR content, not a review event type."
            )

    return violations


def main():
    parser = argparse.ArgumentParser(description="Validate PR review cycle output format")
    parser.add_argument("--posted", type=int, required=True, help="Reviews actually posted")
    parser.add_argument("--skipped", type=int, required=True, help="SHA-match skips")
    parser.add_argument("--prs", default="", help="PRs clause (Branch C only)")
    parser.add_argument("--presence", action="store_true", help="Presence-chat mode active")
    args = parser.parse_args()

    all_violations = []

    if args.posted == 0:
        if args.presence:
            # Branch A: presence line only
            print("BRANCH A: posted==0 + presence mode")
            print("  Correct output: 'Tour HH:MMZ — cluster N/N repos, X/X PRs couvertes. RAS.'")
            print("  NO format line, NO '0/0 reviews posted', NO skip clause, NO [SILENT].")
            print("  PASS (format validated — write only the presence line)")
        else:
            # Branch B: [SILENT] only
            print("BRANCH B: posted==0 + no presence mode")
            print("  Correct output: '[SILENT]'")
            print("  PASS (format validated — write [SILENT] only)")
        sys.exit(0)

    # Branch C: posted >= 1
    print(f"BRANCH C: {args.posted} review(s) posted, {args.skipped} skipped")

    # Validate PRs clause
    if not args.prs:
        all_violations.append("PRS CLAUSE VIOLATION: --prs is required when posted >= 1")
    else:
        all_violations.extend(validate_prs_clause(args.prs))

    # Validate skip clause
    skip_clause = f"{args.skipped} SHA-match."
    all_violations.extend(validate_skip_clause(skip_clause))

    # Build the corrected format line for reference
    total = args.posted + args.skipped
    corrected = f"{args.posted}/{total} reviews posted. PRs: {args.prs}. Skipped: {args.skipped} SHA-match."
    if args.presence:
        corrected += "\n\n<Tour HH:MMZ — French presence note, <=3 lines>"

    if all_violations:
        print(f"\n❌ FAIL — {len(all_violations)} violation(s):\n")
        for v in all_violations:
            print(f"  • {v}\n")
        print(f"CORRECTED FORMAT:\n  {corrected}")
        sys.exit(1)
    else:
        print(f"\n✅ PASS — format line is valid:")
        print(f"  {corrected}")
        sys.exit(0)


if __name__ == "__main__":
    main()
