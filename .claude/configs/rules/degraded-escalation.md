# Environnement dégradé — escalade immédiate, échéance à 2 cycles

**Version :** 1.2.0 · **Issue :** #4517 · #4746 · #4729 · **MAJ :** 2026-11-20
**Règle globale** — déployée dans `~/.claude/rules/` par
`.claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target rules`. Corps canonique ici.

---

## Pourquoi

Du 01 au 03/11/2026, une lane a contourné pendant deux jours un MCP qu'elle
croyait mort. La sonde de siège a rendu **6 LIVE, 0 DEAD** : le serveur répondait
en 1,18 s, la lane ne l'avait simplement jamais vérifié. La règle « réparer,
jamais contourner » existait déjà et n'a pas mordu, parce que **rien ne bornait le
temps** qu'une lane pouvait passer dans un environnement dégradé en silence.

Verbatim user (2026-11-03) : « Vous ne devez pas travailler avec des
environnements dégradés, tu aurais dû escalader immédiatement et réclamer
réparation en instruisant les autres agents de me prévenir si je n'arrivais pas
dans les temps entre 2 cycles. Pas de workaround consacré. »

---

## Les cinq règles

1. **Escalade immédiate.** MCP absent ou muet, kernel manquant, service
   indisponible, sonde incapable de mesurer → on escalade **avant** toute
   tentative de contournement. « Le temps de voir » n'est pas un état : c'est
   déjà le contournement.
2. **L'échéance est dérivée, pas déclarée.** Un post `[DEGRADED]` sur le
   dashboard `workspace` suffit ; le mécanisme calcule `posté + 2 cycles`. Rien à
   calculer, rien à se rappeler pour l'agent sous pression.
3. **Les autres agents sont instruits explicitement.** Toute lane qui exécute
   l'organe pendant son cycle voit l'échéance dépassée et **alerte le user**.
   L'instruction vit dans le mécanisme, pas dans la mémoire de la lane tombée.
4. **Aucun workaround ne se consacre.** Une sortie produite pendant la panne ne
   se rapporte pas comme un résultat normal : elle se rapporte **dégradée, avec
   la panne**. Sortie dégradée commitée comme résultat = l'échec que cette règle
   existe pour empêcher.
5. **Seul `[REPAIRED]` ferme**, et seulement depuis la **même lane**. Un `[DONE]`
   ne ferme jamais une escalade — sinon chaque cycle normal consacrerait la
   sortie dégradée qu'il vient de produire.
   **Nommer l'escalade quand la lane en a plusieurs** (#4746) : un `[REPAIRED]`
   **sans** ligne de portée est une déclaration de lane — il ferme **toutes**
   ses escalades antérieures. Pour n'en fermer qu'une, ajouter au post une
   ligne dédiée `scope: <messageId | #NNNN | HH:MMZ>` (ou `portée:`) — **la
   prose ne compte jamais** (review ai-01 15/11 : y lire heure/issue
   re-scopait 27 réparations déjà fermées). L'organe imprime ce qu'un
   `[REPAIRED]` sans portée a fermé dès qu'il en ferme plus d'une.

`[DEGRADED]` ≠ `[BLOCKED]` : bloqué = j'attends quelqu'un d'autre ; dégradé =
**mon** environnement est cassé et je ne produis plus de résultat normal.

---

## L'organe

**`<roo-extensions>/scripts/diagnostic/check-degraded-escalations.py`**

```bash
python scripts/diagnostic/check-degraded-escalations.py            # exit 0/3/2/1
python scripts/diagnostic/check-degraded-escalations.py --ring     # sonnerie ASK-USER sur le global
python scripts/diagnostic/check-degraded-escalations.py --env-file <fichier>  # remede exit 1 : bearer du siege (#4729)
```

| Exit | Sens | Action |
|---|---|---|
| `0` | aucune escalade `[DEGRADED]` | rien |
| `3` | escalade(s) ouverte(s), dans les délais | rien — ce n'est **pas** « tout va bien » |
| `2` | échéance dépassée sans `[REPAIRED]` | **sonner le user** (`--ring`) |
| `1` | instrument incomplet, ou sonnerie non partie | réparer l'instrument, ne pas conclure |

Sortie `1` : la panne du **lecteur** de l'organe (bearer absent, `store-absent`)
se range à part du compteur de service (#4729) — remède siège `--env-file`
vers le fichier qui porte le bearer ; si l'exit `1` persiste, la panne est
celle du proxy/hôte (jamais un contournement de siège) : [détail](../../../docs/harness/reference/degraded-escalation.md).

Défauts : `2 cycles × 4 h` (cadence des crons flotte `41 */4`), surchargeables par
`--cycles` / `--cycle-hours`. Chaque lane l'exécute **dans son cycle** ; un `2`
se traite comme un `2`, pas comme un log.

**Plafond :** l'organe ne voit que les escalades **postées** — une lane qui
n'escalade pas reste invisible. C'est pourquoi la règle 1 n'est pas négociable,
et pourquoi la sonde de siège (`check-mcp-seats.py`, #4518) mesure la présence
réelle des MCP sans attendre la bonne volonté de la lane.

**Détail, mesures, incident :** `roo-extensions/docs/harness/reference/degraded-escalation.md`.
