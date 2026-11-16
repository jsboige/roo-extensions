# Stagnation — une situation qui n'avance plus se relance, elle ne s'accepte pas

**Version :** 1.0.0 · **Demande :** user 2026-11-16 (« ne pas accepter par indécision une situation dégradée ou une issue qui n'avance plus… tâcher à chaque session de cycle d'identifier les points de relâchement qui mériteraient au contraire une relance »)
**Règle globale** — déployée dans `~/.claude/rules/` par
`.claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target rules`. Corps canonique ici.

---

## Pourquoi

Sur tous les workspaces, le même symptôme : une issue dormante reste dormante,
un arbitrage attendu reste attendu, une situation dégradée dure par habitude.
Chaque cycle la constate, aucun ne la relance. Le silence n'est jamais une
décision : c'est la dérive elle-même. Les organes existants couvrent des
fragments — environnement dégradé, questions user, silence inter-agent,
mandats à métrique — mais aucun ne charge la lane de **reprendre
l'initiative** sur ce qui stagne. C'est le trou que cette règle ferme,
coordinateurs en premier.

## Les cinq règles

1. **Deux états, jamais aucun.** Une stagnation porte soit une **relance
   active**, soit une **pause explicite** (datée, motivée, avec condition de
   reprise). Issue sans mouvement, arbitrage en attente, escalade d'une autre
   lane non suivie, question user ouverte depuis plusieurs cycles : ce qui
   n'est ni relancé ni mis en pause est **accepté par indécision** — interdit.
2. **Sweep de relance à chaque session de cycle.** La lane identifie ses
   points de relâchement : ses claims/fiches sans progrès depuis >48 h, les
   arbitrages qu'elle attend sans avoir relancé, les `[DEGRADED]`/`[ASK]`
   d'autres lanes qu'elle peut faire avancer, les questions user représentées
   au registre mais jamais relancées. Trois sorties valides par point, aucune
   quatrième : **relancer** (communication d'initiative — dashboard, `[ASK]`,
   mention), **planifier une session deep** (règle 4), **consigner la pause
   explicite**. Le rapport de fin de cycle dit quels points ont été balayés.
3. **Une relance porte du neuf.** Recopier la question précédente n'est pas
   une relance, c'est du spam. Une relance apporte un fait nouveau, une
   échéance passée, ou une demande de décision en forme fermée (oui/non, ou
   choix a/b/c). Format d'écriture : celui du registre des questions user
   (5 champs ; jamais un mot plus fort que ce qui a été mesuré).
4. **Session deep quand la veille ne suffit plus.** Un point re-scanné en
   surface à chaque cycle sans progrès habite une problématique plus large
   que la tournée de veille : il demande une **session dédiée planifiée**
   (scope écrit, livrable attendu, créée comme tâche), pas un re-scan de
   boucle.
5. **Le coordinateur balaye en premier.** La revue de stagnation entre dans
   chaque cycle de coordination : issues dormantes du Project, arbitrages
   ouverts, lanes en `[IDLE]` répété, escalades sans suite. Un coordinateur
   qui constate sans relancer porte la dérive.

## Ce qui n'est PAS une relance

- Recopier le message précédent à l'identique (règle 3).
- Attendre le prochain cycle « pour voir » — c'est le relâchement même.
- Clore ou marquer `[DONE]` un dossier non résolu pour arrêter de le voir.
- Re-scanner en surface au lieu de planifier la session deep (règle 4).

## Articulation avec les organes existants

| Situation | Organe existant | Ce que cette règle ajoute |
|---|---|---|
| Mon environnement est cassé | `degraded-escalation.md` (`[DEGRADED]`/`[REPAIRED]`) | la relance des escalades **d'autres lanes** que je peux débloquer |
| Question user ouverte | registre per-machine + entrée `ASK-USER` globale | la **relance au-delà de la représentation** (représenter ≠ relancer) |
| Lane voisine silencieuse | anti-silence 2×`[IDLE]` (intercom) | la relance des **dossiers** de la voisine, pas seulement son signal de vie |
| Métrique dégradée | mandats-résultat (`outcome-mandates.md`) | couvre ce qui n'a **pas** de métrique (issue, arbitrage, dossier) |

**Plafond :** le sweep est l'acte de la lane elle-même — une lane qui ne
balaye pas reste invisible de l'extérieur. La règle 2 rend le sweep
obligatoire précisément pour que ce qui stagne ait au moins une trace par
cycle : relancé, planifié, ou mis en pause.
