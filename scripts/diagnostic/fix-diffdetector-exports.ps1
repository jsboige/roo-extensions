#!/usr/bin/env pwsh
# ARCHIVED — one-shot fix #3323 (2026-08-31)
#
# This script previously added 4 missing exports to DiffDetector.ts:
#   - export type DiffCategory                  (line 856 in current file)
#   - export interface DetectedDifference      (line 858 in current file)
#   - export interface ComparisonReport        (line 893 in current file)
#   - public async compareInventories(...)     (line 751 in current file)
#
# All 4 additions were verified present in the current DiffDetector.ts.
# Re-running this script would be a NO-OP (the script checks for
# "export.*ComparisonReport" and exits 0), but the script itself is
# obsolete and should not be invoked.
#
# Original archived at:
#   scripts/_archive/cleanup-3323-2026-08-31/fix-diffdetector-exports.ps1
#
# Evidence: grep -nE "export.*ComparisonReport|export.*DetectedDifference|export.*DiffCategory|compareInventories" \
#   mcps/internal/servers/roo-state-manager/src/services/DiffDetector.ts
#     751:  public async compareInventories(
#     856:export type DiffCategory = 'roo_config' | 'hardware' | 'software' | 'system';
#     858:export interface DetectedDifference {
#     893:export interface ComparisonReport {

Write-Host "[ARCHIVED] fix-diffdetector-exports.ps1 — applied, all 4 exports present in DiffDetector.ts." -ForegroundColor Yellow
Write-Host "[ARCHIVED] See scripts/_archive/cleanup-3323-2026-08-31/README.md for consolidation evidence (#3323)." -ForegroundColor Yellow
exit 0