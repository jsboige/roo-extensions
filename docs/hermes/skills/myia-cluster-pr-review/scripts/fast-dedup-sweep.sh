#!/usr/bin/env bash
# fast-dedup-sweep.sh — Batch SHA+review-count screen for MyIA cluster PRs
#
# Scans all open PRs in a repo and prints: PR#, short SHA, count of [Hermes]/[NanoClaw] reviews.
# PRs with count 0 = candidates for review. PRs with ≥1 = SKIP (already covered on current SHA).
#
# Usage:
#   scripts/fast-dedup-sweep.sh OWNER/REPO
#
# Example:
#   scripts/fast-dedup-sweep.sh jsboige/CoursIA
#
# When ALL rows show count ≥1, the cycle can exit immediately with 0 reviews to post.
# When a row shows count:0, fetch the full review bodies for THAT pr only (narrow the work).
#
# ⚠️ KNOWN GAP — reviewer coverage:
#   This script counts review BODIES matching [Hermes] or [NanoClaw] only. It does NOT
#   detect reviews from other cluster identities (myia-ai-01, po-2023/2024/2025/2026)
#   that may post authoritative reviews WITHOUT those body markers. For repos where
#   cluster peers post untagged reviews, use scripts/dedup-triage.sh instead (which
#   shows ALL reviewer identities per PR). For CoursIA specifically, NanoClaw reliably
#   tags reviews with [NanoClaw], so this count is a reliable fast triage there.
#
#   Also: this counts review bodies, NOT per-SHA. If a PR has ≥1 Hermes/NC review but
#   on a PREVIOUS SHA (new commits since), it may still need a fresh review. For those
#   edge cases, cross-check the review's commit_id against headRefOid.
#
# Relation to scripts/dedup-triage.sh:
#   dedup-triage.sh = rich per-PR projection (reviewer:SHA(state) per review) — heavier,
#   use when you need to see WHO reviewed and on which SHA.
#   fast-dedup-sweep.sh = count-only screen — lighter, use for quick "is everything
#   covered?" triage across 20+ PRs. Visually scannable in seconds.

set -euo pipefail

REPO="${1:?Usage: $0 OWNER/REPO}"

PR_NUMS=$(gh pr list --repo "$REPO" --state open --json number --jq '.[].number')

if [ -z "$PR_NUMS" ]; then
    echo "No open PRs in $REPO"
    exit 0
fi

printf '%-8s %-14s %s\n' "PR#" "SHA" "Hermes/NC count"
printf '%-8s %-14s %s\n' "----" "---" "---------------"

for pr in $PR_NUMS; do
    sha=$(gh pr view "$pr" --repo "$REPO" --json headRefOid --jq '.headRefOid[0:12]' 2>/dev/null || echo "ERROR")
    count=$(gh api "repos/$REPO/pulls/$pr/reviews" \
        --jq '[.[].body] | map(select(test("\\[Hermes\\]|\\[NanoClaw\\]"))) | length' 2>/dev/null || echo "?")
    printf '#%-7s %-14s %s\n' "$pr" "$sha" "$count"
done
