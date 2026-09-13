# `append` dashboard qui expire — mesures et mécanisme

**Déporté de** `.claude/rules/intercom-protocol.md` v3.4.0 (lignes 36-67) le 2026-09-13.
**Issues :** #2818 (verrou inter-processus) · #2464 (skip sur hash)

La règle auto-chargée garde la conduite à tenir (ne pas retenter, relire, re-poster seulement si
absent). Ce document porte les mesures qui la justifient — on le lit quand on veut comprendre
*pourquoi* un `append` change d'ordre de grandeur, pas pour décider quoi faire.

---

## Le mécanisme : WRITE-FIRST, puis condensation attendue

`handleAppend` écrit d'abord (`// === WRITE-FIRST: persist message to disk immediately ===`),
*puis* déclenche la condensation si le dashboard dépasse 92 % — et il l'**attend**
(`await condenseIntercom`, `dashboard.ts`). Le commentaire du code le dit : l'append incrémental
est *« the authoritative state — no message loss »*.

Sous 92 %, un `append` coûte quelques ms. À partir de 92 %, le **même appel** paie en plus une
passe de condensation LLM entière.

## Les mesures

| Mesure | Résultat |
|---|---|
| **ai-01, 01/09/2026** — append au-dessus du seuil | total **45,3 s** : **1,9 s** d'écriture + **42,3 s** de condensation — soit **93 % du temps passé APRÈS que le message soit durable** |
| Part du bloc `## Status` dans ces 42,3 s | **99,4 %** — un seul appel LLM |
| **A/B, même outil, même session, 10 min d'écart** | le même `append` repasse à **605 ms** (602 ms d'écriture, **0** de condensation) une fois l'utilisation retombée à 58,6 % — facteur **~75×**, porté entièrement par la condensation |
| po-2024 (c.327, **non revérifié** ici) | timeout client à **180 s** sur son propre append |

L'appel du A/B n'a pas expiré. Le point n'est pas qu'il expire toujours : c'est que **le même appel
change d'ordre de grandeur au franchissement du seuil**. L'ordre de grandeur varie ; la propriété
qui suit, non.

## Écrit d'abord ≠ écrit à coup sûr

**Mesure du 02/07/2026 sur `workspace-myia-open-webui` : 3 appends expirés à 300 s, 1 seul avait
été écrit.**

`WRITE-FIRST` rend l'écriture *antérieure* à la condensation, pas *garantie* : l'appel peut aussi
expirer **avant** elle. C'est pourquoi la règle dit « relire », et non « c'est toujours écrit ».
Ce n'est *ni* « c'est toujours écrit » *ni* « ce n'est jamais écrit » — seule la relecture tranche.

## Pourquoi le symptôme paraît irreproductible

Un seul agent paie : verrou inter-processus (#2818) + skip sur hash (#2464). Les autres appends
passent en quelques ms pendant ce temps. D'où un symptôme **intermittent et irreproductible** alors
que le mécanisme est parfaitement **déterministe**.

C'est une **marge**, pas un bug. Rien à corriger : l'auto-condensation préemptive à 92 % gère
l'espace, et l'action `condense` a été retirée du schéma précisément parce qu'aucune intervention
manuelle n'est nécessaire.

---

**Règle canonique :** [`.claude/rules/intercom-protocol.md`](../../../.claude/rules/intercom-protocol.md)
**Coût de la condensation dashboard :** un seul appel LLM, ~97-99 % dans `## Status`.
