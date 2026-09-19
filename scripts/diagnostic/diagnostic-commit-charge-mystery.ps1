#!/usr/bin/env pwsh
# ARCHIVED — one-shot diagnostic #3323 (2026-08-31)
#
# This script was created for issue #2992 investigation
# ([CLAUDE-ai-01] Demarrer vLLM épuise la mémoire validée).
#
# VERIFIED ZERO-REFERENCE:
# - Not referenced by any skill (.claude/skills/)
# - Not referenced by any rule (.claude/rules/)
# - Not referenced by any workflow (.github/workflows/)
# - Not referenced by any documentation (docs/)
# - Not referenced by any other script
#
# STATUS CORRECTION (2026-09-19, #2992): the original archival note above
# claimed "#2992 has been resolved (memory validation is now handled by other
# tooling)" — that claim is FALSE. Issue #2992 is still OPEN: the ~500 Go gap
# between system commit charge and the sum of process commits has never been
# attributed, and this script has never been run on ai-01 (no run report in
# the issue thread). There is no other tooling in this repo covering commit
# accounting (grep: zero live references to CommitLimit/CommittedBytes).
#
# KNOWN DEFECT in the archived original: capture class 3 reads perf counters
# by English name and silently skips localized counters (empty catch) — on
# ai-01 (FR locale, per the issue) the counters that feed the "MissingCommit"
# computation (classes 3/9) never populate. Locale-independent alternative:
# Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory (CommittedBytes,
# CommitLimit, PoolPagedBytes, PoolNonpagedBytes). See issue #2992 thread
# for the corrected runbook.
#
# The script is preserved here as a no-op marker so any historical path
# resolution still works.
#
# Original archived at:
#   scripts/_archive/cleanup-3323-2026-08-31/diagnostic-commit-charge-mystery.ps1

Write-Host "[ARCHIVED] diagnostic-commit-charge-mystery.ps1 — zero-reference, one-shot campaign from 2026." -ForegroundColor Yellow
Write-Host "[ARCHIVED] See scripts/_archive/cleanup-3323-2026-08-31/README.md (#3323)." -ForegroundColor Yellow
exit 0