# Archive — données brutes de l'audit doc du 2026-07-21

> ## ARCHIVED - raw audit data (2026-11-08)
>
> **Status:** Verbatim snapshots, kept for traceability. Raw measurement records of the 2026-07-21 doc audit (#2878 / #2639 WS3).
> **Moved from:** `docs/harness/reference/` (git mv, history preserved).
> **Why:** These files carry `mcps/{INSTALLATION,OPTIMIZATIONS,TROUBLESHOOTING}.md` paths as measured data; the three docs themselves were archived by #4593 (WS3 option (a)). Moving the raw data alongside keeps `git grep` for pre-submodule paths clean outside archive dirs.
> **Decision:** #2639 follow-up to #4593 — option (a) move (coordinator ai-01, file `ai01-queue-20261108a-po2024`, 2026-11-08). Option (b) freeze-declare in scanner #4576 was rejected as a no-op: the scanner never flags `.json`/`.ps1` (not `.md` link sources).
> **Reports (live):** `docs/harness/reference/doc-audit-2026-07-21.md` · `docs/harness/reference/doc-broken-links-2026-07-21.md`

| Fichier | Contenu |
|---------|---------|
| `doc-audit-raw-2026-07-21.json` | Données brutes de l'audit de fraîcheur doc (1087 fichiers) |
| `doc-broken-links-raw-2026-07-21.json` | Données brutes de l'audit liens cassés (3050 liens) |

**Fichiers gelés :** on ne répare pas les chemins d'un enregistrement mesuré (consolider != archiver) — les références croisées d'autres données d'audit de la même famille (`superseded-by-closed-issues-*`, `mcps-external-readme-coherence-*`, `demo-roo-code-inventory-raw-*`, inventaires machine) pointent toujours l'ancien emplacement et sont laissées telles quelles, données historiques.
