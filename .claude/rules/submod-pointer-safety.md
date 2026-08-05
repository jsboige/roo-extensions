# Submodule Pointer Safety

**Version:** 2.0.0 (slim — procédure et incident déportés 2026-08-05)
**Issue :** #2089 follow-up (incident 2026-05-11, commit `67514ec1`)

---

## Règle Absolue

**Avant tout commit modifiant un pointeur submodule** (`mcps/internal`,
`mcps/external/win-cli/server`, `roo-code`) : **`git fetch` le submodule, puis vérifier que la SHA
cible est atteignable depuis son upstream.**

```bash
git -C <submod> fetch origin main
git -C <submod> merge-base --is-ancestor $(git -C <submod> rev-parse HEAD) origin/main \
  && echo OK || echo "ORPHAN — STOP"
```

**Si la SHA n'est pas atteignable → STOP.** Pousser d'abord le commit submodule sur son upstream,
ou `reset --hard origin/main`. Un pointeur orphelin casse `git pull` **sur toute la flotte**
(`upload-pack: not our ref`), pas seulement chez soi.

## Pourquoi cette règle existe pour les sessions **interactives**

Le worker schedulé a son propre garde (`Reset-PhantomSubmodulePointers`), et la CI bloque les PRs.
Ni l'un ni l'autre ne couvre une session Claude Code interactive qui pousse sur `main` avec un token
OWNER — c'est exactement ce qui a produit l'incident du 2026-05-11.

## Les trois pièges

- `git submodule update --init --recursive` puis `git add` → checkout arbitraire = pointeur arbitraire.
- « Résoudre le conflit submod » par `checkout --theirs` / `checkout HEAD --` sans regarder la cible.
- Bumper le pointeur parent **avant** que la PR submod soit mergée (voir `pr-mandatory.md`).

---

**Procédure complète, incident fondateur, cas légitimes, post-mortem :**
[`docs/harness/reference/submod-pointer-safety-procedure.md`](../../docs/harness/reference/submod-pointer-safety-procedure.md)
