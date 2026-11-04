# Environnement dégradé — escalade immédiate, sonnerie à 2 cycles

**Version :** 1.0.0 · **Issue :** #4517 · **MAJ :** 2026-11-03
**Source canonique :** ce fichier. Déployé flotte (tous workspaces) par
`.claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target rules`.

---

## Incident fondateur (po-2025 `CoursIA`, 01 → 03/11/2026)

Pendant deux jours, une lane a contourné un MCP qu'elle croyait mort
(`jupyter-papermill`) et a présenté son travail comme normal. Le 03/11, la sonde
de siège rend **6 LIVE, 0 DEAD** ; `jupyter-papermill` répondait en **1,18 s**
avec ses 25 outils. **Le serveur n'était pas cassé : la lane ne l'avait jamais
vérifié.**

Verbatim user (2026-11-03) :

> « Attention c'est un manquement grave au stop&repair obligatoire. Vous ne devez
> pas travailler avec des environnements dégradés, tu aurais dû escalader
> immédiatement et réclamer réparation en instruisant les autres agents de me
> prévenir si je n'arrivais pas dans les temps entre 2 cycles. Pas de workaround
> consacré. »

La règle « réparer, jamais contourner » existait déjà. Elle n'a pas mordu parce
que **rien ne bornait le temps** qu'une lane peut passer dans un environnement
dégradé **en silence** : « escalader » restait une intention portée par la
mémoire de l'agent qui l'avait posée.

---

## La règle

1. **Escalade immédiate.** Un environnement dégradé — MCP absent ou muet, kernel
   manquant, service indisponible, sonde incapable de mesurer — s'escalade
   **avant** toute tentative de contournement. « Le temps de voir » n'est pas un
   état : c'est déjà le contournement.

2. **L'échéance est dérivée, jamais déclarée.** Le post `[DEGRADED]` sur le
   dashboard `workspace` suffit ; le mécanisme calcule l'échéance
   (`posté + 2 cycles`). Un agent sous pression n'a rien à calculer, et rien à
   se rappeler.

3. **Les autres agents sont instruits explicitement.** Toute lane qui exécute
   l'organe (voir ci-dessous) pendant son cycle voit l'échéance et **alerte le
   user** quand elle est dépassée. L'instruction vit dans le mécanisme, pas dans
   le post de la lane défaillante.

4. **Aucun workaround ne se consacre.** Une sortie produite pendant la panne ne
   se rapporte pas comme un résultat normal : elle se rapporte **dégradée, avec
   la panne**. C'est la règle SOTA/Stop&Repair appliquée au cas « mon outil est
   absent », et pas seulement « l'outil a produit moins bien ».

5. **Seul `[REPAIRED]` ferme une escalade.** Un `[DONE]` ne la ferme pas — sinon
   le cycle normal consacre précisément la sortie dégradée que le mandat
   interdit. Le `[REPAIRED]` doit venir de la **même lane** ; le `[REPAIRED]`
   d'une autre lane ne ferme rien.

`[DEGRADED]` ≠ `[BLOCKED]` : bloqué = j'attends quelqu'un d'autre ; dégradé =
**mon** environnement est cassé et je ne produis plus de résultat normal.

---

## L'organe : `scripts/diagnostic/check-degraded-escalations.py`

```bash
python scripts/diagnostic/check-degraded-escalations.py                # lit le store PG (bearer requis)
python scripts/diagnostic/check-degraded-escalations.py --json
python scripts/diagnostic/check-degraded-escalations.py --ring         # sonnerie ASK-USER sur le dashboard global
python scripts/diagnostic/check-degraded-escalations.py --dashboard-file <copie.md>   # rejeu forensic
python scripts/diagnostic/check-degraded-escalations.py --selftest
```

| Exit | Sens | Ce que fait l'automate |
|---|---|---|
| `0` | aucune escalade `[DEGRADED]` dans la fenêtre lue | rien |
| `3` | escalade(s) ouverte(s), échéance non dépassée | rien — mais ce n'est **pas** « tout va bien » |
| `2` | au moins une échéance dépassée sans `[REPAIRED]` | **sonner le user** |
| `1` | erreur d'instrument (illisible, miroir gelé, **mesure dégradée**), ou `--ring` demandé et non parti | réparer l'instrument, ne pas conclure |

Défauts : **2 cycles × 4 h** = 8 h, la cadence des crons flotte (`41 */4`).
`--cycles` / `--cycle-hours` les remplacent là où la cadence diffère.

**Déclaration ≠ mention** (review #4519) : une escalade est **déclarée** par la
ligne `[tags: … DEGRADED …]` ou par le token en **premier token du corps**.
Un post qui **cite** le tag en pleine prose — la review qui le commente, le
`[DONE]` qui l'explique — n'ouvre rien : les deux posts réels du 03/11 qui
citaient le tag produisaient des escalades fantômes qui sonnaient le user pour
rien. Même discipline pour `[REPAIRED]` : seule une déclaration de la même lane
ferme.

**Sources, dans l'ordre** (review #4519) : `--dashboard-file` = rejeu forensic
(sans plafond) → sinon le **store PG**, via le même transport que la sonnerie
(fenêtre des 200 dernières entrées par dashboard) → sinon repli **miroir G:**,
qui **dégrade** la mesure : si PG était configuré, l'organe agit sur ce que le
miroir a dit (rapport + sonnerie) puis sort **1** — jamais un `0` confiant sur
une source de repli. Plafond de fraîcheur du miroir : la plus récente entrée
doit dater de moins d'un cycle, sinon `1` sans sonnerie (un G: gelé depuis le
cut #4131 répond un faux « rien à signaler » sur des données mortes).

**Le store est lu en JSON, pas en markdown** (review ai-01 04/11, MUST) : le
`read` markdown passe par `buildMarkdownOutput`, qui émet l'en-tête et le corps
mais **aucune ligne `[tags: …]`**. Une lane qui déclarait par l'API canonique —
`append(tags=["DEGRADED"])`, corps en prose — restait donc invisible : `tags=[]`,
exit `0`, silence. Or c'est la forme que le harnais documente. L'organe demande
maintenant `format: json` et lit `data.intercom.messages[].tags` (déjà tronqué à
`intercomLimit` côté serveur), c'est-à-dire **la source, pas son rendu**. Repli
markdown conservé si l'enveloppe n'est pas exploitable (hôte ancien). Cas
symétrique côté miroir : la sérialisation place `[msg: id]` **avant** le corps,
donc une déclaration en premier token n'était jamais vue non plus — les lignes de
métadonnées de tête sont désormais neutralisées avant le test du premier token.

`--ring` poste un `[ASK-USER][DEGRADED-ESCALATION]` sur le dashboard `global`,
avec une clé d'idempotence **quotidienne** : le même lot sonne **une fois par
jour**, jamais une fois par tick, et re-sonne chaque jour tant que rien n'est
réparé. Le texte de la sonnerie ne porte **aucun token de declaration**
(`[DEGRADED]`/`[REPAIRED]` remplacés par leur mot) et son entrée porte le tag
`DEGRADED-ESCALATION` : la sonnerie ne peut ni fermer sa propre alarme ni en
ouvrir une nouvelle. Le transport est celui de `detect-approval-stalls.py`
(`call_dashboard_tool`, importé, pas recopié — le même pour LIRE le store et
POSTER la sonnerie). Un `--ring` qui échoue sort **1** : une sonnerie qui n'est
pas partie ne se présente jamais comme un succès.

---

## Plafond dit explicitement

- **L'organe ne voit que les escalades postées.** Une lane qui n'escalade pas
  reste invisible — c'est pourquoi le point 1 n'est pas négociable, et pourquoi
  la sonde de siège (`check-mcp-seats.py`, PR #4518) existe : elle rend la
  dégradation visible sans attendre la bonne volonté de la lane.
- **La sonnerie ne dépend d'aucune horloge partagée** ; elle dépend de la lane
  qui exécute l'organe pendant son cycle. Câbler l'organe dans le pré-vol
  (`/continue`, `/coordinate`) est une décision du coordinateur, hors du
  périmètre de #4517.
- **« 2 cycles » est une convention**, pas une mesure de la difficulté de
  réparation : elle borne le silence, elle ne juge pas le travail.

---

**Voir aussi :** [`escalation-protocol.md`](escalation-protocol.md) (escalade de
**capacité**, 5 niveaux — axe différent) · [`deny-fallback-probe.md`](deny-fallback-probe.md)
(le repli deny qui n'existe pas) · [`tool-availability.md`](../../.claude/rules/tool-availability.md)
(STOP & REPAIR).
