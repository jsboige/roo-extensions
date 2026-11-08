# Archive — instruments one-shot de la campagne A2 (audit doc 2026-07-21)

> ## ARCHIVED - one-shot campaign instruments (2026-11-08)
>
> **Status:** Verbatim snapshots, kept for traceability. One-shot scripts of the 2026-07-21 doc-audit follow-up (#2639 WS3 / #2878 era).
> **Moved from:** `scripts/docs/` (git mv, history preserved).
> **Why:** These scripts reference `mcps/{INSTALLATION,OPTIMIZATIONS,TROUBLESHOOTING}.md` as repair targets / verified files; the three docs were archived by #4593 (WS3 option (a)). No caller anywhere: zero CI/workflow references, zero live consumers (only frozen audit records and `_archive` READMEs mention them).
> **Decision:** #2639 follow-up to #4593 — option (a) move (coordinator ai-01, file `ai01-queue-20261108a-po2024`, 2026-11-08). `scripts/_archive/` follows the `cleanup-3323-2026-08-31` precedent; the scanner's `(^|/)_?archive/` exclusion covers it.
> **Contexte:** `fix-broken-links.ps1` = correcteur one-shot (oct. 2025, patterns codés en dur pour une réorg antérieure) ; `verify-*-A2.ps1` = vérificateurs one-shot de la phase A2.

| Fichier | Rôle à l'époque |
|---------|------------------|
| `fix-broken-links.ps1` | Correcteur ponctuel de liens (réorg `mcp-servers/` → `internal/`) |
| `verify-corrections-A2.ps1` | Vérification post-correction des fichiers cibles |
| `verify-target-files-A2.ps1` | Vérification d'existence des fichiers cibles A2 |

**Ne pas exécuter :** les cibles qu'ils vérifient n'existent plus à ces chemins (archivées sous `docs/archive/`). Les snapshots d'inventaire machine (`scripts/inventory/*.json`, baselines `roo-config/baselines/*`) qui enregistrent leurs anciens chemins absolus sont des données figées, laissées telles quelles.
