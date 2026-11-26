# Qualité des statuts condensés — corpus historique et mécanismes identifiés (#4434)

**Date :** 2026-10-29 · **Lane :** myia-po-2024:roo-extensions · **Périmètre :** volets 1-3 de #4434 (corpus, journal des changements, hypothèse auto-feedback — première passe)
**MAJ :** 2026-11-26 — append « G8a — fidélité des résumés publiés » (322 paires de production + 24 relectures aveugles, lane myia-po-2024:roo-extensions) ; 2026-11-18 — append « G4 : essai des petits modèles payants, verdicts et coûts » (volet G5, lane myia-po-2024:roo-extensions) ; 2026-11-15 — append « Suite de campagne 01/11 → 15/11 » (volet G5, lane myia-po-2023:roo-extensions) ; le corps du 29/10 ci-dessous reste celui de po-2024, inchangé.

## Résumé exécutif

La dégradation perçue par l'utilisateur est **réelle, récente et mesurable** sur le corpus des archives de condensation (**2 284** archives `global` + `workspace-roo-extensions`, mai→29/10) :

1. **Structure** : le statut `global` passe de 5-6/8 sections attendues (7-16/10) à 2/8 (24-27/10) puis **0/8 (28-29/10)** ; `workspace-roo-extensions` est à 0/8 de façon soutenue depuis le 25/10.
2. **Trois mécanismes concourent**, aucun n'est le seul coupable :
   - **A — troncature déterministe par le haut** (`truncateToMaxSize` garde la fin) : décapite le statut (en-tête `## [key]` + Résumé + État des systèmes + Décisions actées). Observé directement : snapshot de 15 640 o commençant au milieu d'une liste, sans en-tête, 2 sections sur 8.
   - **B — le modèle de fallback ne suit pas la structure** : des statuts annoncés à 10,3-14,9 Ko (sous le plafond, donc jamais tronqués) n'ont que 0-3/8 sections. Sur 120 passes d'octobre avec frontmatter daté : 114 `ok-with-fallback`, toutes via `deepseek-v4-flash`.
   - **C — effondrement du statut entre deux passes, verrouillage NON démontré (lecture corrigée 29/10 21:05Z et 30/10)** : l'entrée `global` passe de 15 442 o / 3 sections (17:57) à 1 845 o / 0 sections (20:27) **sans archive intermédiaire** — deux writers possibles non départagés par le corpus : la sortie de la passe 17:57 elle-même (fallback, mécanisme B) ou un `update` manuel dans la fenêtre (vecteur documenté : les `update` plats de 157-1 845 o existent dans le corpus). En revanche, le maillon « la passe suivante hérite et rend plate » est **contredit sur la seule passe mesurable** : la passe 20:27, entrée plate 1 845 o, annonce en live 14,3 Ko structurés (mesuré par ai-01, corroboré par l'append 20:41 à 14 880 o structurés) — la structure est **récupérée** depuis la base plate. Le verrouillage auto-feedback n'est donc **pas établi** ; les volets 4-5 devront rejouer la chaîne avant de l'affirmer.
3. **Primaire en panne depuis le 23/10 18:01** : 100 % des passes `global` en fallback cloud pendant 6 jours (le primaire ne produisait déjà plus que des passes lentes, 434-833 s, du 19 au 22/10).
4. **Taille ≠ qualité** : les statuts sont restés à ~15,3-15,8 Ko pendant que la structure s'effondrait ; plusieurs dépassent le plafond de 15 360 o (jusqu'à ~16 012 o mesurés) — les marqueurs #1502/#3803 sont ajoutés APRÈS l'application du plafond.

## 1 — Corpus (volet 1)

- **Source** : `dashboards/archive/*.md` du shared-state GDrive, clés `global` et `workspace-roo-extensions`, 2026-05-01 → 2026-10-29. **2 284 fichiers indexés** (empreintes SHA256, tailles, frontmatter, issue annoncée par le message système CONDENSATION). *Comptage fait autorité : le fichier déposé sur le shared-state (21:41Z), **recompté ligne par ligne le 30/10 → 2 284** ; les « 2 283 » d'une première version de ce rapport ne sont pas réconciliables avec le dépôt (aucune trace conservée du run intermédiaire) — l'écart ±1 est un artefact de brouillon, pas une archive ambigüe.*
- **Instrument** : `scripts/analysis/condensation_corpus_scan.py` (lecture seule, émet du JSONL de métadonnées — aucun transcript copié).
- **Dépôt du corpus** : `.shared-state/condensation-audit-4434/` (stockage autorisé flotte) — `condensation_corpus.jsonl`, agrégats.
- **Couverture** : `workspace-roo-extensions` continu (~350-400 archives/mois, juin→oct.) ; `global` : **0 archive en juin** (trou de conservation, pas de paires fabriquées), 5 en juillet, 14 en août, puis continu.
- **Historique du CONTENU des statuts** : disponible uniquement depuis le **04/10** (section « Statut avant condensation » introduite par #3962/ms#1342) — 279 snapshots extrait pour octobre. Avant : seules les **tailles** sont reconstituables (annoncées dans les messages CONDENSATION). PG ne garde que l'état courant (UPSERT + version, sans historique) ; pas d'accès aux révisions Drive via le MCP google-workspace actuel.

### Trajectoire (médianes par quinzaine)

| Quinzaine | global : taille | workspace : taille | fallback % |
|---|---|---|---|
| 05H1-05H2 | 4,8-8,4 Ko | 5,2-15,0 Ko | 0 % |
| 06H1-07H2 | (0-5 archives) | 13,6-15,3 Ko | 0 % |
| 08H1-09H1 | 12,9-13,9 Ko | 12,6-13,4 Ko | 0 % |
| 09H2 | 12,8 Ko | 13,3 Ko | ~1 % |
| 10H1 | 14,8 Ko | 14,1 Ko | 0 % |
| **10H2** | **15,2 Ko** | **15,1 Ko** | **53 %** |

Sections présentes (médiane journalière, statut AVANT condensation, octobre) :

- `global` : 6/8 (07-16/10) → 1-5/8 (19-23/10) → **2/8 (24-27/10)** → **0/8 (28-29/10)**
- `workspace` : bruité 0-8/8 (04-24/10) → **0/8 soutenu (25-29/10)**
- Sections survivantes sous fallback (24-27/10, global, n=59) : Livrables récents 39/59, En cours 26/59, Blocages structurels 24/59 — **Résumé, État des systèmes, Décisions actées : 0/59** (signature de la coupe par le haut + non-suivi du prompt).

## 2 — Journal des changements de la chaîne (volet 2)

Reconstitué par `git log -S` (submodule `mcps/internal`) :

| Date | SHA submodule | Changement |
|---|---|---|
| 2026-04-07 | `98a4ad66` (#66) | `MAX_STATUS_SIZE_BYTES` = 15 Ko introduit |
| 2026-04-19 | `028d673e` (#1502) | LAST-KNOWN-STATE WINS dans le prompt statut |
| 2026-06-01 | `a55d80e8` (#582/#2463) | troncature déterministe du statut dans le chemin fallback |
| 2026-06-16 | `db8c23d0` (#634/#2598) | plafond appliqué dans `condenseTextIfTooLarge` |
| 2026-07-01 | `d9841491` (#664/#2719) | fallback cloud quand le vLLM est down |
| 2026-09-23 | `802aa8f9` (#1194) | le failover ne saute plus l'étage cloud |
| 2026-09-28 | `568f11b9` (#1251) | clip des tentatives primaires au budget de passe |
| 2026-10-03 | `709f37da` | revert du clip (fallback 29-83 %/jour mesuré) |
| 2026-10-04 | `5b5ddbbe` (#1342/#3962) | garde never-worse-than-input + « Statut avant condensation » archivé |
| 2026-10-08 | `8d128b95` (#1405/#3151) | ids `[msg:]` conservés dans les archives |
| 2026-10-15 | `6d8bff2a` (#1439/#4205) | regen du statut seulement on-change |
| 2026-10-21 | `4bfd3b50` (#1473/#3962) | clamp deadline jambe primaire + réserve cloud + compteur troncature |
| 2026-10-21 | `75bd6bad` (#1470/#4095) | [ERROR] flotte sur troncature fallback |
| 2026-10-24 | `c5d27a63` (#1495) | `CONDENSE_CLOUD_RESERVE_MS` hot-reloadable |
| 2026-10-27 | `2bf2e802` (#1540/#4131) | drapeaux PG cutover ON par défaut |

Corrélation : la vague fallbackcontinue démarre le 23/10 18:01 — entre #1470 (21/10) et #1495 (24/10) ; elle coïncide avec la dégradation du primaire vLLM ai-01 (passes 434-833 s les 19-22/10, puis échecs), pas avec un changement de code local. Date d'effet ≠ date de merge : les statuts dégradés sous fallback le deviennent au moment où l'HÔTE sert la panne primaire, quelle que soit la version du build.

## 3 — Hypothèse auto-feedback (volet 3) : vecteurs documentés, verrouillage NON démontré (lecture corrigée 30/10)

Le statut précédent conditionne le suivant (entrée `previousStatus` du prompt). Trois constats — dont le premier **corrige** une version antérieure de ce rapport :

1. **Cas 29/10 soir — pinné sur les deux archives, lecture corrigée (30/10)** : l'entrée `global` à 17:57 est de **15 442 o / 3 sections** (`global-2026-10-29T17-57-52.md`, snapshot #3962 : Livrables récents, En cours, Métriques de référence) ; à 20:27 elle est de **1 845 o / 0 sections** — une liste plate de puces « décisions » (`global-2026-10-29T20-27-36.md`). L'effondrement s'est produit **sans archive intermédiaire** : le corpus ne départage pas (i) la sortie de la passe 17:57 elle-même (fallback, mécanisme B — ses annonces ne sont pas mesurables depuis l'archive, voir Fragilités) de (ii) un `update` manuel dans la fenêtre 17:57-20:27 (vecteur documenté par ailleurs : `update` plats de 157-1 845 o). **Le maillon « héritage verrouillé » est contredit sur la seule passe mesurable** : la passe 20:27 (entrée plate 1 845 o) annonce en live **14,3 Ko via fallback cloud** (mesuré firsthand par ai-01, corroboré par l'append 20:41 à 14 880 o structurés) — la structure est **récupérée** depuis la base plate. Le mécanisme d'héritage reste documenté (consigne « HÉRITER, ne pas réécrire » + garde never-worse-than-input comparant à l'entrée) ; c'est le **verrouillage** qui n'est pas établi.
2. **Oscillation 28-29/10** (les deux clés) : le corpus alterne listes plates minuscules (157-1 845 o) et régénérations ~15 Ko à chaque passe — chaque régénération repart de la base dégradée précédente.
3. **Coupe par le haut** : la section du haut (en-tête + Résumé + État des systèmes + Décisions actées) est la première sacrifiée par la troncature, et absente de l'héritage sur toute la fenêtre 24-27/10 (0/59) — la récupération observée à 20:27 le 29/10 (item 1) prouve qu'elle n'est pas impossible, mais elle n'a pas été la tendance de la fenêtre.

**Limite** : la propagation multi-générations (amplification vs récupération) exige les replays du volet 5 — non couverts par ce cycle (aucun appel cloud émis, aucun statut de production réécrit).

## Recommandations (volet 4, préliminaires — aucune mise en œuvre)

- **Levier prompt/garde immédiat, sans changement de modèle ni de seuil** : (a) le garde #3962 protège la taille, pas la structure — lui ajouter un critère de structure (présence de l'en-tête `## [key]` et des sections sur les statuts d'entrée structurés) est testable hors ligne sur le corpus existant ; (b) la consigne d'héritage pourrait demander la RESTAURATION des sections manquantes plutôt que le seul héritage — à valider par A/B sur fixtures (volet 5), pas en production.
- **Levier mécanique** : `truncateToMaxSize` pourrait couper par section (retirer les sections entières les moins critiques) plutôt que par ligne depuis la fin — à évaluer avec le même protocole.
- **Levier statut manuel** : les `update` d'agents qui remplacent le statut par des listes plates sont un vecteur majeur (mécanisme C) — envisager une consigne de coordonnateur ou un template de section pour les updates manuels.
- **Modèle** : la question du modèle (deepseek en tête de chaîne) reste ouverte au volet 4 avec les mesures de coût/tokens — hors périmètre de ce cycle.

## Parité du prompt de `dashboard-llm-live.integration.test.ts` (vérifié)

Le prompt statut reconstitué dans le test (ligne 156, 955 caractères) est un **variant raccourci** : ses 13 lignes significatives existent toutes verbatim dans le prompt de production, mais il lui manque les doctrines structurantes — LAST-KNOWN-STATE WINS, SILENCE ≠ OBSOLESCENCE, la structure à 8 sections (dont Patterns appris), la garde #3771 (états GitHub non sourcés), les règles d'HÉRITAGE. **Il ne peut pas servir d'oracle pour les replays du volet 5** : les expériences doivent exporter le prompt de production (ou le tester via les fonctions réelles), pas rejouer cette copie.

## Reproduction

```bash
python scripts/analysis/condensation_corpus_scan.py --out corpus.jsonl
```

Lecture seule sur le shared-state ; aucune écriture dashboard/PG/Qdrant ; aucun appel LLM émis pour cette analyse (corpus passif uniquement).

### Fragilités connues du parseur (bornes de mesure — à connaître avant de réutiliser les chiffres)

- **`COND_MSG_RE` prend le PREMIER match** du message système CONDENSATION dans l'archive. Une archive qui **cite** un message CONDENSATION antérieur (message système conservé dans la fenêtre) fait attribuer à la passe les chiffres de la citation, pas ceux de la passe réelle. **Artefact mesuré (30/10) sur les deux rangées du soir du 29/10** : `global-2026-10-29T20-27-36.md` porte `status_kb=15.0` qui appartient à un message 18:19:54 **cité** (le seul bloc CONDENSATION du fichier), et `global-2026-10-29T17-57-52.md` porte `status_kb=14.9` qui appartient à un message 17:31:20 cité — l'annonce de la passe qui crée l'archive n'est pas dans son propre fichier (le message système est ajouté après l'archivage). **Conséquence : les `status_kb` du corpus sont des annonces de passes PRÉCÉDENTES ; les tailles mesurables sans ambiguïté sont `bytes` (fichier) et `before_bytes` (snapshot #3962).** Non corrigé dans l'instrument ce cycle.
- **`section_metrics` compte les sections par sous-chaîne dans les en-têtes** (`#+ … <nom>`) : un en-tête unique « Décisions actées et En cours » compte **2**. Les `sections_present` sont des **bornes hautes**, pas des comptes exacts — conservateur pour le constat 0/8 (un faux 0 est impossible par ce biais), mais un « n/8 » intermédiaire peut être surestimé.

---

# Suite de campagne — 01/11 → 15/11 (mise à jour G5, lane po-203, 15/11)

Ce rapport décrivait l'état au 29/10. La campagne #4434 qui a suivi a corrigé les mécanismes identifiés et mesuré les résultats. Les chiffres ci-dessous viennent des commentaires de l'issue (ancrés par leur id) ; chaque mesure est lisible dans son intégralité au fil.

## Mécanismes A/B/C — état au 15/11

| Mécanisme (§ ci-dessus) | Correctif mergé | Mesure post-déploiement |
|---|---|---|
| **A** — coupe par le haut (plancher déterministe qui ne gardait que lead + blocages + queue) | **ms#1649** (04/11, ai-01) : plancher section-aware — chaque en-tête de section survit à la coupe | `Section-aware truncation kept every section heading` sur les passes finissant au plancher (recensements multi-sièges 05/11, c.6645596264 → c.6649221161) |
| **B** — le repli ne suit pas la structure ; le primaire trop lent pour son budget (52 appels statut, 0 succès, 38 timeouts mesurés au 04/11) | **ms#1652** (04/11, ai-01) : jambe statut **cloud-first** ; **ms#1712** (09/11, web2) : passe déterministe `enforceStatusBudget` sans LLM entre `generateStatusUpdate` et `condenseTextIfTooLarge` ; **ms#1718** (10/11, web2) ; **ms#1731** (11/11, po-203) : plafond 300 mots sur « Blocages structurels » (résiduel 65 % du statut, c.6778288452) | **C1 tenu : 0/33** passes `LLM did not converge` sur 45 h post-ms#1731 (ai-01, 13/11, c.6844511990) ; po-204 : 6/6 passes sous 15 360 o sous ms#1718 (c.6812463424) ; auto-réparation du mécanisme B observée sur l'instance Argumentum (même commentaire) |
| **C** — effondrement par `update` manuel plat (vecteur documenté, non départagé le 29/10) | pas de correctif code — reste à portée **consigne/template-statut** | non traité au 15/11 |

## Tableau consolidé qualité / latence / succès / tokens (tailles d'échantillon nommées)

| Contexte | n | Qualité | Latence | Succès | Tokens (entrée/sortie par passe) |
|---|---|---|---|---|---|
| **Rejeu isolé primaire** `qwen3.6-35b-a3b`, prompts de production, séquentiel (02/11, po-2025, c.6572874103) | 10 paires réelles | conservation structurelle **94,3 %** (33/35 sections) ; ≥ repli sur 10/10 | min 106 s · p50 **200 s** · p90 318 s · max 431 s (budget 645 s) | **10/10** répondu, 0 timeout | sonde pleine taille : 12 381 / 3 914 ; décode 27,8 tok/s moy (16,7-36,2) |
| **Repli d'époque** `deepseek-v4-flash` (mêmes 10 paires, sorties archivées) | 10 paires | conservation **71,4 %** (25/35) | — (non rejoué : sorties d'archive) | statut d'époque : ok-with-fallback 10/10 | — |
| **Conservation repli flotte** (01/11, baseline, c.6563081595) | 549 paires consécutives | **71,5 %** | — | — | — |
| **Production 24 h, jambe résumé primaire** (14-15/11, ai-01, G2, c.6890386808) | 71 passes | — | — | 71/74 jambes résumé au primaire | **10 530 / 793** |
| **Production 24 h, jambe résumé repli** | 3 passes | — | — | 3/74 | 9 394 / 1 253 |
| **Production 24 h, jambe statut repli** (cloud-first, ms#1652) | 74 passes | — | — (condensation détachée #4527 : l'append ne paie plus la passe) | 74/74, 0 `cloud-first-failed` | **17 967 / 2 523** |
| **Production 24 h, jambe statut primaire** | 0 | — | — | jamais tentée dans la fenêtre (cloud-first) | — |
| **Non-convergence au plancher** (C1, 45 h post-ms#1731, ai-01, c.6844511990) | 33 passes | — | — | **0/33** `did not converge` | — |
| **Densité refs/Ko des statuts produits** (G3, post-ms#1731, po-203, c.6892881266) | 230 statuts | P25 5,36 · P50 9,79 · P90 16,66 refs/Ko ; **17,4 %** sous le seuil WARN 4,0 (vs 22,9 % baseline n=363) ; relecture omissions : global 2/15, roo-ext 1/18, CoursIA 11/14 | — | — | — |

Cases « — » = non mesuré dans la campagne (jamais déduites). La colonne **coût** est tenue dans la section G4 ci-dessous (coûts mesurés et projections, tarifs datés) — remplie par les verdicts du 17/11. Lecture d'ensemble : en **isolation** le primaire vaut le repli ou mieux sur chaque paire (la défaite de production se joue sur l'isolement sous charge et le budget, pas sur la capacité — c.6572874103 §5) ; en **production**, la jambe statut est servie par le repli cloud depuis ms#1652 et **converge** désormais (0/33 au plancher) ; le plafond `max_tokens = 7200` reste contraignant (4/10 appels du rejeu en `finish_reason=length`, les deux sections perdues = `Patterns appris`, dernière du canevas).

## G4 — essai borné des petits modèles payants et verdicts (16-17/11)

Protocole et plafond annoncés **avant tout appel** (c.6924889054) : 15 appels payants au plus, arrêt dur à 20 appels ou 2 USD. Consommé : **15 appels, 0,1596 USD** (+15 rejets 401 à 0 USD et 5 reprises gratuites, divulgés par la lane de mesure). Instrument : `replay-4434.py` (reconstruction #4793), prompts de production extraits de `dashboard.ts`, séquentiel. Siège de mesure : po-203 (départ c.6928168114, résultats c.6928668623).

### Verdict auto-feedback (préfixé avant l'essai)

Réfuté dans sa forme forte (549 paires, 01/11, c.6563081595) ; un mécanisme de propagation trouvé et corrigé (ms#1649) ; omissions de génération passagères, réparées à la passe suivante (10/11 et 13/11), qui ne s'accumulent pas. **L'auto-feedback ne justifie à lui seul ni changement de modèle, ni format imposé** (c.6924889054 §1).

### Essai — jambe statut, 3 candidats × 5 paires (témoin swift au niveau clé : 17/19)

| Modèle (prix liste $/M in/out) | Sections /19 | Mode d'échec | Coût 5 paires | Projection 30 j | Latences |
|---|---|---|---|---|---|
| `qwen3.6-flash` (0,1875 / 1,125) | 11 | hermes 1/5, Maintenance 0/3 — `finish=length` | $0,0531 | $6,11 | 35-52 s |
| `MiniMax-M3.1-Flash` (0,15 / 0,60) | 12 | CoursIA-3 0/4, claudish 0/3 — `finish=length` | $0,0286 | $4,38 | 33-67 s |
| **`glm-4.7` (0,60 / 2,20)** | **19** | aucun — 5/5 `finish=stop` (aucun timeout flotte : 15/15 dans le budget 600 s) | $0,0779 | $17,17 | 29-47 s |
| Témoin swift local (niveau clé) | 17/19 | 2 sections | $0 (local) | $0 | — |

Règles (a)-(d) fixées avant la mesure : seul **`glm-4.7` les passe toutes** — (a) 19/19 ≥ témoin 17/19 ; (b) aucune clé sous le repli d'époque ; (c) 5/5 sans timeout ; (d) projection présentée (verdict c.6933208060). Les deux moins chers échouent (a) et (b) par **troncature** (`finish=length`), pas par dérive de format : le verdict « format imposé écarté » tient, le levier restant est le budget de sortie. Projection = jambe résumé, 71 passes/j, profil de tokens de production ; les trois candidats roulent sur des abonnements déjà payés — **coût marginal réel ≈ 0 $**, la projection sert la comparabilité (règle d).

### Verdict de bascule — jambe résumé (17/11)

Mesure dédiée (les 5 mêmes paires, prompt **résumé** de production, instrument étendu `--leg summary` — PR #4811, mergée `7cec82b9`) : `glm-4.7` 5/5 `finish=stop`, à égalité avec le témoin swift rejoué 5/5 ; `glm-5.3-flash` absent du catalogue du hub au moment de la mesure — bras sauté comme prévu (c.6940185160).

**Bascule décidée** (c.6940185160) — les deux conditions du user (RX149 b, c.6856871734) sont remplies :
- **Libérer swift : oui** — la jambe statut ne passe déjà plus par swift (cloud-first ms#1652, 0 appel principal sur 74 passes en G2) ; la jambe résumé était la dernière charge de condensation sur swift.
- **Faire mieux le travail : jambe statut 19/19 contre 17/19** (mieux que le témoin) ; jambe résumé à égalité 5/5 (la règle demandait « au moins autant » ; les sorties glm-4.7 sont 1,7× plus longues — la mesure ne dit pas si c'est contenu ou remplissage, d'où le garde-fou).

| Poste de coût | Mesuré | Projection 30 j (prix liste) | Source |
|---|---|---|---|
| `glm-4.7` jambe statut (essai) | $0,0779 / 5 paires | $17,17 (jambe résumé, 71 passes/j) | c.6928668623 |
| `glm-4.7` jambe résumé (bascule) | ~$0,0073 / passe | **16-21 USD** (basse : 0,0073 × 74 × 30 ; haute : volume G2, sorties 1,7×) — **marginal ≈ 0** (abonnement déjà payé) | c.6940185160 §2 |
| qwen3.6-flash / MiniMax (rejetés) | $0,0531 / $0,0286 / 5 paires | $6,11 / $4,38 — écartés sur (a)(b) | c.6928668623 |
| swift local (témoin, ex-production jambe résumé) | $0 | $0 | c.6933208060 §3 |
| Jambe statut production (repli cloud `deepseek-v4-flash`) | tokens G2 : 17 967 in / 2 523 out × 74 passes/j | tarif daté non publié dans le fil — case non déduite | c.6890386808 |

- **Chemin** : `CONDENSE_SUMMARY_CLOUD_FIRST` (défaut **ON**, kill-switch `=0`) — même mécanisme que ms#1652, swift devient le **repli** ; ms#1797 (`a7e77522`, mergée `34e783c2`), pointeur parent bumpé par #4822 (`910dd07d`, mergé 17/11 18:30Z), builds par siège en cours de roulement (po-203 observé sur `c4b3be3d` le 18/11 05:46Z).
- **Critère 24 h post-déploiement** (c.6947828962, à compter du déploiement effectif par siège) : `summaryPrimaryTokens` servi par `glm-4.7` sur ≥ 90 % des passes ; 0 résumé rejeté par `validateSummaryCompleteness` ; coût réel sur 24 h publié et comparé à la projection ; compte des passes « cloud-first échoué → primaire échoué → sauvetage cloud » (facture deux fois la même jambe, borné par `passDeadlineMs`).
- **Garde-fou qualité** : une lane autre que l'auteur relit 3 résumés post-bascule contre leurs messages (omissions comptées) ; plus d'omissions que sur 3 résumés swift relus de la même façon → retour arrière par variable d'env, pas de revert de code.

## G8a — fidélité des résumés publiés : 322 paires de production (26/11, po-2024)

**Question.** G7a a livré la 4e section « États transverses » (prompt ms#1840 + garde de forme). Les résumés **publiés en production** conservent-ils mieux les états ? Mesure sur archives réelles, sans rejeu ni appel modèle : chaque `CONDENSATION-SUMMARY` posté est apparié à l'archive des messages qu'il résume.

**Protocole.**
- **Appariement** = la notice système de la passe elle-même (`N messages archivés dans archive/<fichier>`) ; repli = archive de même clé à ≤ 300 s. **322 résumés appariés, 79 non appariés** (ni notice ni voisin — non mesurés). Fenêtre 20-26/11.
- **Bras** : POST = le résumé porte `### États transverses` (n = 247) ; PRE = il ne le porte pas (n = 75). **Modèle lu dans le frontmatter de la passe productrice**, pas du transporteur.
- **Couche 1** (déterministe, 322) : rappel lexical des identifiants, des nombres, des auteurs, et de 12 familles de marqueurs d'états (UAC, registre, ASK-USER, exit 1, URGENT, pause, handoff, DENY, claim, DEGRADED/REPAIRED, identifiants de question `Q`, fenêtre user).
- **Couche 2** (sémantique, aveugle) : 24 résumés, 2 par cellule (clé × modèle, 6 cellules), paires PRE/POST les plus proches en temps — règle fixée sur les horodatages seuls. 12 lecteurs `sonnet` qui ne voient ni les métriques ni le bras ; sorties vérifiées mécaniquement par la lane, puis arbitrées par elle (producteur ≠ vérificateur).
- Instruments versionnés : `scripts/analysis/condensation-g8a/` (§ Instruments).

### Couche 1 — rappel lexical

| Moyenne | PRE (n = 75) | POST (n = 247) |
|---|---|---|
| `st_recall` — familles d'états présentes et retrouvées | 0,486 | **0,684** |
| `st_all_kept` — toutes les familles retrouvées | 0,067 | **0,201** |
| `id_recall` — identifiants d'issues/PR | 0,486 | 0,518 |
| `num_recall` — nombres saillants | 0,432 | 0,436 |
| `author_recall` — auteurs nommés | 0,913 | 0,957 |
| corps du résumé (octets) | 3 923 | 4 829 |
| messages par lot | 20,6 | 18,4 |

Sur les 17 cellules (clé × modèle) qui portent les deux bras : `st_recall` monte dans **15/17** (Δ pondéré par n +0,189, non pondéré +0,155) ; `st_all_kept` 8 ↑ / 2 ↓ / 7 = ; `id_recall` 9 ↑ / 8 ↓ (+0,038) ; `num_recall` 6 ↑ / 11 ↓ (−0,017). **Le gain porte sur les états, pas sur les identifiants ni les nombres.**

| Famille (présente → retrouvée) | PRE | POST |
|---|---|---|
| `pause` | 0,45 (38) | **0,83** (145) |
| `claim` | 0,63 (62) | **0,83** (153) |
| `question_id` | 0,66 (53) | **0,86** (194) |
| `exit1` | 0,44 (25) | **0,77** (75) |
| `registre` | 0,43 (65) | **0,61** (209) |
| `uac` | 0,33 (15) | **0,59** (39) |
| `fenetre_user` | 0,22 (9) | **0,68** (25) |
| `handoff` | 0,00 (1) | 0,67 (21) |
| `deny` | 0,50 (4) | 0,80 (15) |
| `ask_user` | 0,38 (26) | 0,40 (115) |
| `urgent` | 0,24 (41) | 0,21 (63) |
| `degraded` | 0,68 (50) | 0,68 (151) |

**Trois familles ne bougent pas** : `ask_user`, `urgent`, `degraded` — la question user ouverte, le risque vif et l'organe dégradé ne sont pas mieux conservés qu'avant la garde, alors qu'ils sont les classes 2, 3 et 4 de G7a-1.

### Le plafond de 5 Ko — trouvé dominant

`MAX_SUMMARY_SIZE_BYTES = 5 * 1024` (`dashboard.ts:223`), appliqué après génération (`dashboard.ts:7861`) ; au-delà, `truncateWithOmissionMarker` (`dashboard.ts:6839`) retire des lignes **sans LLM** et préfixe `… N lignes omises`.

| | PRE | POST |
|---|---|---|
| résumés portant le marqueur | 7/75 (9,3 %) | **175/247 (70,9 %)** |
| lignes retirées — médiane / moyenne / max | 3 / 6,0 / 19 | 6 / 7,1 / 27 |
| plus gros corps publié | — | 5 133 o |

- Le marqueur dit que le résumé **publié** a été amputé ; l'archive garde les messages entiers. Ce n'est pas un artefact d'archive.
- **La taille mesurée est censurée** : le gain de longueur (+23 %) est une borne basse, et le plafond est atteint sur 7 résumés POST sur 10.
- Coût dans le bras POST : non tronqués (n = 72) `st_recall` 0,710 / `st_all_kept` 0,246 ; tronqués (n = 175) 0,673 / 0,183. Écart brut 3,7 points ; **stratifié sur la densité d'états (7 strates de familles présentes) : +2,4 points, 6 strates sur 7 dans le même sens.** Les lots tronqués sont plus denses en états (5,11 familles présentes contre 4,31) à volume de messages égal — l'écart brut surestime légèrement le coût du plafond. `num_recall` : 0,473 → 0,420. En PRE, 7 tronqués seulement : non concluant.

### Couche 2 — relecture aveugle de 24 résumés

Chaque lecteur (sous-agent `sonnet`) reçoit les messages originaux d'un lot et le résumé publié qui les condense, **sans le bras**, et rend les états transverses qu'il identifie (les 8 classes de G7a-1), ceux que le résumé porte ou omet (extrait cité), les lignes fausses ou non sourcées, les nombres vérifiés, les contradictions non signalées. Un lecteur = deux résumés voisins du tirage (S01-S02, …, S23-S24) ; aucun n'a vu les métriques ni le bras.

| Couche 2 | PRE (n = 12) | POST (n = 12) |
|---|---|---|
| états transverses identifiés dans les originaux | 239 | 256 |
| omis / portés | 70 / 169 | **58 / 198** |
| **part d'omission (poolée)** | **0,293** | **0,227** |
| portés par résumé (moyenne) | 0,724 | **0,810** |
| résumés sans aucune omission | 0/12 | 1/12 |
| lignes fausses | 1 | 0 |
| lignes non sourcées, après traçage sur le résumé antérieur | 3 | 2 |
| lignes tracées au résumé antérieur (légitimes) | 3 | 22 |
| lignes « non sourcées » partielles / non testables | 5 / 3 | 8 / 2 |
| contradictions non signalées | 7 | 7 |
| nombres faux / vérifiés | 3 / 180 | 1 / 181 |

**Le sens ne vient pas d'un lecteur indulgent.** La sévérité mesurée varie de 0,07 (S05-S06) à 0,52 (S01-S02) de part d'omission — un lecteur qui n'aurait lu que du POST déplacerait le résultat. Sur les **8 lecteurs qui ont lu un PRE et un POST** : POST meilleur dans **6/8** (écart moyen −0,088 ; poolé 0,316 → 0,256). L'appariement par cellule et voisinage temporel (12 paires, 8 en faveur de POST, écart moyen −0,086) donne le même ordre de grandeur. Les deux comparaisons écartent un confondant différent — le lecteur pour l'une, la cellule pour l'autre — et concordent ; aucune n'est un essai randomisé (les deux bras coexistent du 21 au 23/11, siège par siège).

**Par classe** (part d'omission, PRE → POST) :

| Classe G7a-1 | PRE | POST |
|---|---|---|
| 1 — fenêtre UAC / contrainte user planifiée | 0/5 = 0,00 | 2/5 = 0,29 |
| 2 — question user ouverte | 10/16 = 0,38 | **2/15 = 0,12** |
| 3 — organe dégradé / incomplet | 7/26 = 0,21 | 7/31 = 0,18 |
| 4 — risque vif | 12/52 = 0,19 | **5/45 = 0,10** |
| 5 — pause datée / claim actif | 6/11 = 0,35 | 4/9 = 0,31 |
| 6 — handoff en attente | 26/31 = 0,46 | **23/64 = 0,26** |
| 7 — capacité bloquée | 7/8 = 0,47 | 5/10 = 0,33 |
| 8 — changement de config en vigueur | 2/20 = 0,09 | **10/19 = 0,34** |

Le gain se concentre sur les classes 2, 6 et 4 ; 3, 5 et 7 baissent légèrement. **La classe 8 recule nettement** : trois fois plus omise en POST (10/19 contre 2/20), répartie sur 7 résumés (S02, S07, S09, S14, S15, S16, S22) dont deux tronqués seulement (S07, S16) — un changement de config en vigueur n'est donc pas, en soi, un état que la section « États transverses » fait remonter. La classe 1 ne porte que 5 états : non concluant.

Deux réserves sur ce tableau. **La classe 2 s'améliore ici alors que la couche 1 ne voit pas bouger `ask_user`** (0,38 → 0,40, mieux instrumenté : 141 états) : les deux ne portent pas sur le même objet — marqueur lexical dans le texte pour la couche 1, état reconstitué par un lecteur pour la couche 2 — mais **31 états ne renversent pas une mesure mieux instrumentée** ; c'est le gain le moins solide de la couche 2. Et aucune des 12 familles lexicales de la couche 1 ne cible la classe 8 : celle-ci n'est visible que par la relecture.

### Trois corrections d'instrument, appliquées avant d'écrire les chiffres

1. **Le résumé voit le résumé antérieur.** Le résumé publié est reposté dans l'intercom comme message `system|system` (`dashboard.ts:8066-8076`), archivé par la passe suivante et redonné au modèle : **24/24 archives portent un résumé antérieur, 4,2 Ko en moyenne**. Un lecteur à qui on donne le lot **sans** ces blocs compte comme « non sourcée » toute ligne reprise de la passe précédente — POST : 34 lignes signalées, **22 tracées** au résumé antérieur, contre 3 en PRE. Sans cette correction, le bras POST paraissait produire plus de deux fois plus de lignes non sourcées (34 contre 15).
2. **`messageCount` du frontmatter = messages non système + 2** (les deux notices de condensation) — vérifié 24/24. Les 30 « divergences » de compte relevées par les lecteurs sont des artefacts de convention.
3. **Arbitrage des jetons citations** : contrôle mécanique des 24 sorties (`verify_quotes.py`) — **2 défauts de citation** (un caractère, `4 d` pour `4 j`, S10 ; une ligne préfixée d'une glose autour d'une citation exacte, S10) et **1 défaut de jeton** (S24, jeton absent de l'extrait). Les 51 jetons retrouvés dans le résumé couvrent 44 omissions candidates : **2 sur-comptées**, 42 confirmées. Règle fixée avant lecture : une omission est sur-comptée quand le résumé porte **le même état (même objet, même prédicat)** en d'autres mots ; un prédicat différent sur le même objet (PR ouverte vs revue due, chiffre disque vs copie hors-site absente) reste une omission.

### Limites de la couche 2

- **24 résumés sur 322**, les paires les plus proches en temps par cellule ; **2 tronqués sur 24 contre 56,5 % dans la population** — la couche 2 sous-représente le plafond, que la couche 1 mesure (70,9 % des POST).
- **12 lecteurs non calibrés**, un seul passage, sans mesure de répétabilité ; la dispersion de sévérité (0,07-0,52) est traitée par les comparaisons appariées, pas éliminée.
- « Non sourcée » est un **proxy lexical** (recouvrement ≥ 0,8 des mots de contenu avec les blocs système de l'archive ; 0,5-0,8 = « partielle ») : une reformulation qui change le vocabulaire reste « non testable » (5 lignes).
- **79 résumés non appariés** ne sont pas mesurés — rien ne dit qu'ils ressemblent aux 322.

### Suite proposée (non tranchée ici)

Le plafond de 5 Ko touche **7 résumés POST sur 10** et ampute sans LLM : c'est le défaut le plus large mesuré. Trois options, à arbitrer dans le fil (#4434) — aucune n'est appliquée par cette mesure : (a) relever `MAX_SUMMARY_SIZE_BYTES` (coût : un résumé plus long à chaque passe, la fenêtre du lecteur) ; (b) rendre la troncature section-aware en préservant « États transverses » en dernier (le plafond reste, il ne coupe plus l'état) ; (c) statu quo, en sachant que les classes 8, 7, 5 et 1 restent omises environ une fois sur trois en POST (effectifs faibles pour 1, 5 et 7). La mesure ne dit pas laquelle : elle dit que (c) a un coût mesuré et que la classe 8 n'est pas couverte par la garde actuelle.


## Décisions

- **Seuil refs/Ko 4,0 : gardé** (G3, 15/11) — le seuil est passé sous le P25 actuel (flague la vraie queue, plus conservateur qu'à l'activation) ; monter = bruit (CoursIA-3/claudish légitimes) ; descendre ferme le signal `global` (16/16 statuts sous 4,0 — genre prose, 2,03 P25). Report-only : si le WARN devient bloquant, `global` exige une décision de genre. Trouvaille pour le template-statut : les vues [ASK-USER] deviennent invisibles dès la condensation (2/2 omissions du relecture global).
- **Auto-feedback : réfuté dans sa forme forte** (16/11, c.6924889054 §1) — ne justifie à lui seul ni changement de modèle ni format imposé.
- **Petits modèles payants : `glm-4.7` adopté pour la jambe résumé** (bascule 17/11, c.6940185160, livrée par ms#1797) — les deux conditions du user (RX149 b) remplies. La jambe statut reste sur sa chaîne cloud actuelle : `deepseek-v4-flash` n'était pas dans la comparaison G4, il n'est pas remplacé sans le mesurer. `qwen3.6-flash` et `MiniMax-M3.1-Flash` rejetés sur (a)(b) — troncature, pas dérive de format. Format imposé : **écarté** (c.6924889054 §6) ; modèle dédié : le sort suit l'essai — tranché par le verdict ci-dessus.

## Recommandations du 29/10 — état au 18/11

| Levier préliminaire du 29/10 | État |
|---|---|
| (a) garde de **structure** (en-tête `## [key]` + sections) en plus de la taille | **Livré** — plancher section-aware ms#1649 + passe `enforceStatusBudget` ms#1712 |
| (b) troncature **par section** plutôt que par ligne depuis la fin | **Livré** — le plancher et la passe budget retirent des sections entières, jamais l'en-tête seul |
| (b') borner la verbosité **par section dans le prompt** | **Livré** — bloc `BUDGET PAR SECTION (#4434)` ms#1633 (02/11, po-2025), déjà présent au 09/11 (c.6739556626 : le modèle le dépasse dans chaque section — d'où la passe déterministe ms#1712) |
| (c) consigne/template pour les `update` manuels plats | **Non traité** — reste ouvert |
| Modèle en tête de chaîne | **Tranché 17/11** — jambe résumé basculée sur `glm-4.7` cloud-first (c.6940185160, ms#1797, kill-switch `CONDENSE_SUMMARY_CLOUD_FIRST=0`) ; jambe statut inchangée (`deepseek-v4-flash` à mesurer avant tout remplacement) |

## Instruments

- `scripts/analysis/condensation_corpus_scan.py` — inchangé (fragilités ci-dessus toujours d'actualité).
- `scripts/analysis/replay-4434.py` — le rejeu du 02/11 (po-2025) : paires réelles, prompts de production extraits mécaniquement de `dashboard.ts`, paramètres de production, séquentiel. **Versionné le 16/11 sous forme de reconstruction étiquetée** (PR #4793, §1.3 de #4434) : l'original de po-2025 vivait sur un scratchpad de session et son transfert (`msg-20261115T150322-vl3zv0`, demandé le 15/11) n'a pas atterri. Si l'original atterrit, il remplace la reconstruction. **Étendu le 17/11** : option `--leg summary` (PR #4811, mergée `7cec82b9`) avec test de parité du prompt résumé — instrument de la mesure G4 jambe résumé.
- **Appariement statut ↔ messages** (G3, vérifié à la seconde près) : le statut produit par la passe T est horodaté ~T (26-31 s avant l'écriture de l'archive) et se lit dans l'archive T+1 au bloc « Statut avant condensation » ; une passe peut archiver **sans** produire de statut (cas CoursIA 06:49:55 — le premier statut consommant le feed est cloud-first, 09:06:03).
- **Chaîne G8a** (`scripts/analysis/condensation-g8a/`, versionnée le 26/11 avec le § G8a) — cinq étapes, chacune idempotente, sorties en compteurs/tailles/noms de sections, jamais le texte des dashboards :
  1. `scan.py <archive_dir> <scan.json> [since]` — un enregistrement par archive (sections présentes, taille, en-tête du résumé).
  2. `pair.py <archive_dir> <scan.json> <pairs.json> <since>` — apparie chaque résumé à l'archive qu'il résume par la notice système de la passe ; repli = même clé à ≤ 300 s ; lit `summaryFallbackModel`/`summaryOutcome`/`messageCount` dans le frontmatter **de la passe productrice**.
  3. `metrics.py <archive_dir> <pairs.json> <metrics.json>` — couche 1 lexicale (12 familles d'états, identifiants, nombres, auteurs).
  4. `sample.py <archive_dir> <pairs.json> <samples_dir>` — tirage aveugle déterministe (`seed` 4434) : paires PRE/POST les plus proches en temps par cellule (clé × modèle).
  5. `verify_quotes.py <samples_dir> <findings_dir> <checked.json>` puis `aggregate.py <samples_dir> <findings_dir> <archive_dir> <adjudication.json> <truncation.json> <out.json>` — contrôle mécanique des citations produites par les lecteurs (extrait ⊆ originaux, ligne ⊆ résumé, repli d'accents sur tout le jeu de voyelles latin-1) et agrégation finale avec les corrections de la couche 2 : traçage des lignes sur le résumé antérieur de l'archive, convention `messageCount` n+2, arbitrage des sur-comptes (`adjudication.json`), blocs par lecteur et intra-lecteur.
  **Les sorties 1 à 4 contiennent des extraits de dashboards** (l'étape 4 écrit les 24 paires dans `<samples_dir>`), et les entrées 4-5 aussi (`adjudication.json`, sorties des lecteurs) : écrire dans un répertoire gitignoré, ne jamais committer — seuls les comptes et les instruments sont versionnés.
