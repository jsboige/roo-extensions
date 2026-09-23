#!/usr/bin/env bash
# dedup-triage.sh — Compact SHA+reviewer+state projection for all open PRs in a repo.
#
# Returns one line per PR showing: number, head SHA (short), and which reviewers
# posted on which SHA. Designed for the common "everything already covered" case
# where 90%+ of PRs will be skipped — avoids fetching full review bodies (5-10KB
# each) until a PR is confirmed to need a new review.
#
# Usage:   bash dedup-triage.sh OWNER/REPO
# Example: bash dedup-triage.sh jsboige/CoursIA
#
# ⚠️ GRAPHQL EXHAUSTION (2026-07-21): `gh pr list` is GraphQL-backed and fails
# with "rate limit exceeded" on the jsboige account (chronic early-cycle
# condition since 2026-07-20). If this script fails on line 1, replace the
# `gh pr list` call with the REST equivalent:
#   gh api "repos/$REPO/pulls?state=open" --jq '.[] | "\(.number)\t\(.head.sha)"'
# The REST endpoint is NOT subject to the GraphQL rate limit. See
# references/gh-cli-quirks.md §"gh pr list (GraphQL) fails" for full details.
#
# Fast batch variant (one-liner, no script file needed):
#   When you have 20+ PRs and just need the review COUNT per SHA to find
#   candidates, this inline loop is faster than running the full script:
#
#   for pr in $(gh pr list --repo OWNER/REPO --state open --json number --jq '.[].number'); do
#     sha=$(gh pr view $pr --repo OWNER/REPO --json headRefOid --jq '.headRefOid[:8]')
#     reviews=$(gh api repos/OWNER/REPO/pulls/$pr/reviews --jq "[.[] | select(.commit_id[:8]==\"$sha\")] | length")
#     echo "#$pr SHA=$sha reviews_on_sha=$reviews"
#   done
#
#   PRs with reviews_on_sha=0 are candidates. PRs with ≥1 need deeper check
#   (was it [Hermes]/[NanoClaw]?).
#
# See also: scripts/fast-dedup-sweep.sh — lighter count-only screen for 20+ PRs.
# Use fast-dedup-sweep when you just need "is everything covered?" at a glance;
# use dedup-triage when you need to see WHO reviewed and on which SHA.
#
# Output format:
#   PR #5554 sha=270aeb6f | NC:270aeb6f(COMMENTED) po-2024:...(COMMENTED)
#
# If NO reviewer appears on the current head SHA → candidate for new review.
# If [Hermes] or NanoClaw appears on the current SHA → SKIP (anti-spam rule).

set -euo pipefail
REPO="${1:?Usage: dedup-triage.sh OWNER/REPO}"

# Get all open PRs with their current head SHA
gh pr list --repo "$REPO" --state open --json number,headRefOid \
  --jq '.[] | "\(.number)\t\(.headRefOid)"' | \
while IFS=$'\t' read -r num full_sha; do
  short_sha="${full_sha:0:10}"

  # Compact projection: SHA + reviewer + state (avoids fetching full bodies)
  reviews=$(gh api "repos/$REPO/pulls/$num/reviews" \
    --jq '[.[] | "\(.user.login):\(.commit_id[:10])(\(.state))"] | join(" ")' \
    2>/dev/null || echo "(none)")

  # Check issue comments for cluster reviewers (Hermes/NanoClaw/po-* posts)
  cluster_reviewers=$(gh api "repos/$REPO/issues/$num/comments" \
    --jq '[.[] | select(.body | test("\\[Hermes\\]|\\[NanoClaw\\]")) | .user.login] | unique | join(",")' \
    2>/dev/null || echo "")

  printf 'PR #%s sha=%s | reviews: %s' "$num" "$short_sha" "$reviews"
  [ -n "$cluster_reviewers" ] && printf ' | cluster: %s' "$cluster_reviewers"
  printf '\n'
done
