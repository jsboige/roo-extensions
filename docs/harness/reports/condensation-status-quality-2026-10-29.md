# Qualité des statuts condensés — corpus historique et mécanismes identifiés (#4434)

**Date :** 2026-10-29 · **Lane :** myia-po-2024:roo-extensions · **Périmètre :** volets 1-3 de #4434 (corpus, journal des changements, hypothèse auto-feedback — première passe)
**MAJ :** 2026-11-15 — append « Suite de campagne 01/11 → 15/11 » (volet G5, lane myia-po-2023:roo-extensions) ; le corps du 29/10 ci-dessous reste celui de po-2024, inchangé.

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

Cases « — » = non mesuré dans la campagne (jamais déduites). La colonne **coût** est volontairement absente : G4 reste au coordinateur (file 20261115d). Lecture d'ensemble : en **isolation** le primaire vaut le repli ou mieux sur chaque paire (la défaite de production se joue sur l'isolement sous charge et le budget, pas sur la capacité — c.6572874103 §5) ; en **production**, la jambe statut est servie par le repli cloud depuis ms#1652 et **converge** désormais (0/33 au plancher) ; le plafond `max_tokens = 7200` reste contraignant (4/10 appels du rejeu en `finish_reason=length`, les deux sections perdues = `Patterns appris`, dernière du canevas).

## Décisions

- **Seuil refs/Ko 4,0 : gardé** (G3, 15/11) — le seuil est passé sous le P25 actuel (flague la vraie queue, plus conservateur qu'à l'activation) ; monter = bruit (CoursIA-3/claudish légitimes) ; descendre ferme le signal `global` (16/16 statuts sous 4,0 — genre prose, 2,03 P25). Report-only : si le WARN devient bloquant, `global` exige une décision de genre. Trouvaille pour le template-statut : les vues [ASK-USER] deviennent invisibles dès la condensation (2/2 omissions du relecture global).
- **Modèle** (décision user 13/11, c.6856871734) : option (b) conditionnelle — comparer de petits modèles payants **sans budget chiffré**, essai borné, coût mesuré par résumé ; verdict sur les deux conditions du user à poster dans l'issue.

## Recommandations du 29/10 — état au 15/11

| Levier préliminaire du 29/10 | État |
|---|---|
| (a) garde de **structure** (en-tête `## [key]` + sections) en plus de la taille | **Livré** — plancher section-aware ms#1649 + passe `enforceStatusBudget` ms#1712 |
| (b) troncature **par section** plutôt que par ligne depuis la fin | **Livré** — le plancher et la passe budget retirent des sections entières, jamais l'en-tête seul |
| (b') borner la verbosité **par section dans le prompt** | **Livré** — bloc `BUDGET PAR SECTION (#4434)` ms#1633 (02/11, po-2025), déjà présent au 09/11 (c.6739556626 : le modèle le dépasse dans chaque section — d'où la passe déterministe ms#1712) |
| (c) consigne/template pour les `update` manuels plats | **Non traité** — reste ouvert |
| Modèle en tête de chaîne | Ouvert — décision user 13/11 (comparaison bornée petits modèles payants) |

## Instruments

- `scripts/analysis/condensation_corpus_scan.py` — inchangé (fragilités ci-dessus toujours d'actualité).
- `scripts/analysis/replay-4434.py` — le rejeu du 02/11 (po-2025) : paires réelles, prompts de production extraits mécaniquement de `dashboard.ts`, paramètres de production, séquentiel. **Non versionné à cette tête** — transfert demandé à po-2025 le 15/11 15:03:22Z (`msg-20261115T150322-vl3zv0`), pas encore atterri : `scripts/analysis/` ne contient que `condensation_corpus_scan.py` comme script Python.
- **Appariement statut ↔ messages** (G3, vérifié à la seconde près) : le statut produit par la passe T est horodaté ~T (26-31 s avant l'écriture de l'archive) et se lit dans l'archive T+1 au bloc « Statut avant condensation » ; une passe peut archiver **sans** produire de statut (cas CoursIA 06:49:55 — le premier statut consommant le feed est cloud-first, 09:06:03).
