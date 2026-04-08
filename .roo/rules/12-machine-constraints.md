# Contraintes Specifiques par Machine

**Version:** 2.0.0 (condensed from 1.0.0)
**MAJ:** 2026-04-08

## Machines

| Machine | GPU | RAM | Role | Provider |
| ------- | --- | --- | ---- | -------- |
| myia-ai-01 | 3x RTX 4090 | 32GB | Coordinateur | Anthropic |
| myia-po-2023 | A5000 | 16GB | Executeur | z.ai |
| myia-po-2024 | A4000 | 16GB | Executeur | z.ai |
| myia-po-2025 | RTX 3060 | 16GB | Executeur | z.ai |
| myia-po-2026 | RTX 3060 | 16GB | Executeur | z.ai |
| myia-web1 | None | 16GB | Executeur | z.ai |

**Note :** Charge LLM sur le provider (z.ai/Anthropic), PAS local.

## Contraintes web1

1. Compte Google different, path GDrive : `C:\Drive\.shortcut-targets-by-id\{ID}\.shared-state`
2. Tests TOUJOURS `--maxWorkers=1`
3. Seuil condensation : 75%

**Ref complete :** `docs/harness/machine-specific/myia-web1-constraints.md`

---
**Historique versions completes :** Git history avant 2026-04-08
