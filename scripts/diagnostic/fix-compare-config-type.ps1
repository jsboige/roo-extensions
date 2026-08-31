#!/usr/bin/env pwsh
# ARCHIVED — one-shot fix #3323 (2026-08-31)
#
# This script attempted to add `DetectedDifference` type annotation to
# a `.map(diff => ...)` pattern at line 127 of compare-config.ts.
#
# VERIFIED OBSOLETE:
# - Current compare-config.ts does NOT import `DetectedDifference` from DiffDetector.js
# - Current compare-config.ts uses bare `.map(diff => ...)` in 5 locations
#   (lines 624, 630, 636, 1010, 1057)
# - The targeted "line 127" no longer exists in the current file (file was restructured)
# - The script's regex `\.map\(diff =>` would actually match lines that
#   weren't the original target — running it would corrupt other call sites
#
# Original archived at:
#   scripts/_archive/cleanup-3323-2026-08-31/fix-compare-config-type.ps1
#
# DO NOT RUN. See scripts/_archive/cleanup-3323-2026-08-31/README.md.

Write-Host "[ARCHIVED] fix-compare-config-type.ps1 — obsolete. Target file structure changed since script was authored." -ForegroundColor Red
Write-Host "[ARCHIVED] Running this script would corrupt 5 unrelated .map(diff => ...) call sites." -ForegroundColor Red
Write-Host "[ARCHIVED] See scripts/_archive/cleanup-3323-2026-08-31/README.md (#3323)." -ForegroundColor Yellow
exit 0