# Exploration Memorilla (snap-stanford) — pilote vs recall RooSync

**Issue :** [#4801](https://github.com/jsboige/roo-extensions/issues/4801) — origine : demande Emerjesse 16/11 22:49 (canal cluster)
**Date :** 2026-11-16 · **Lane :** myia-ai-01:roo-extensions (worker interactif)
**Statut :** étapes 1-2 livrées, protocole bench prêt (étape 3), gate ouverte (étape 4)

---

## TL;DR

1. **Aucun siège de la flotte ne peut exécuter l'inférence Memorilla telle quelle** (README : 1 GPU 80 Go, ~25 Go de modèles ; ai-01 mesuré = 3× RTX 4090 24 Go, dont 2 occupées par le hub vLLM de production). Le bench exige une instance GPU louée — **décision user** (dépense).
2. **Éval étiquetée : graine de 15 paires construite et mesurée.** Baseline recall RooSync sur ces questions de connaissance institutionnelle : **hit@1 = 20 %, hit@3 (plein) = 20 %, partiel@3 = +20 %, rien d'utilisable sur 60 %** — dont une requête à zéro résultat et plusieurs faits récents (oct.-nov.) introuvables.
3. La comparaison honnête n'est pas « Memorilla vs Qdrant » sur la même métrique : notre rappel échoue à l'étape **retrieval** pour des faits-aiguilles qui tiennent en 15 fiches ; Memorilla (paradigme *compress-then-read*) verrait ces fiches entières dans son corpus et n'aurait à payer que la distillation. C'est exactement l'angle mort documenté (résumés statiques = ce que la requête aurait voulu).
4. **Recommandation de gate (étape 4) :** si le user valide une location (~2-5 USD, 1-2 h), jouer le bench avec les assets livrés ici ; sinon acter Memorilla comme **référence de design** (distillation à la lecture) pour la condensation RooSync — deux leviers concrets identifiés §7. Dans les deux cas, le papier ne devient **jamais** une dépendance du runtime agent (non-goals respectés).

---

## 1. Ce que c'est (vérifié aux sources primaires, 16/11)

Mesuré sur le [repo GitHub](https://github.com/snap-stanford/memorilla) (README lu intégralement) et l'[abstract arXiv 2610.21375](https://arxiv.org/abs/2610.21375) (v3, 03/11/2026 — Fallahpour, Idehpour, Kothapalli, Mounier, Wu, Pardis, Leskovec / SNAP Stanford). Apache-2.0, 1,3k étoiles, 85 forks, 29 commits, poussé encore le 16/11. Toutes les affirmations ci-dessous sont VERIFIÉES aux sources :

- **Architecture :** un encodeur (Qwen3-Embedding-4B) encode chaque document **une fois** en embeddings réutilisables ; un module mémoire appris (cross-attention) récupère et place l'information dépendante de la requête dans l'espace d'embedding d'entrée d'un LLM **gelé** (Qwen3-8B) sous forme de **16 tokens mémoire** fixes, quel que soit le volume de la collection.
- **Revendications clés :** meilleure moyenne vs Mem0/MemoRAG sur 5/8 benchmarks ; FactKG 84,33 % vs 80,43 % full-context avec 108× moins de tokens ; NarrativeQA comprimé >4000× ; latence stable 0,74 s de 1 à 512 documents (~128k tokens) vs 19,9 s full-prompt ; agent TextWorld 18,6 % → 24,2 % (8 tokens).
- **Memory cache (profiling) :** KV de la cross-attention précalculée à l'écriture — question à 8,1 ms pour 1 M documents ; cache 4× la taille des embeddings (80 GiB pour 4 M docs, tient sur 1 GPU). Précision FactKG à ±0,06 point du défaut.
- **Exigences d'exécution (README, verbatim) :** « Linux with CUDA GPUs and Python 3.11 », recettes sur H100 80 Go ; « **You need one 80 GB GPU**, and the first run downloads about 25 GB of models ». Dépendances épinglées avec advisories publics (vLLM 0.9.1, transformers 4.53.3, torch 2.7.0 — GHSA cités dans leur README ; applicables aux modèles/checkpoints non fiables seulement).
- **Données personnelles :** PersonaMem-v2 (107 conversations ~32k tokens → question), PersonalizationV4 (149 utilisateurs fictifs × 200 conversations) — **le format exact de notre cas conversation_browser/memory**.
- **Format own-data :** un parquet par split, colonnes `collection_id` (entier `int64`, que le lecteur convertit par `int()`), `question`, `answer`, `documents` — consommé tel quel par `evaluate.py`/`train.py`.

## 2. Étape 1 — Inventaire VRAM : verdict bloquant pour la flotte

| Siège | GPU | VRAM | Statut | Source |
|---|---|---|---|---|
| **myia-ai-01** | 3× RTX 4090 | 3× 24 564 MiB (2 chargées à ~21 Go par le hub vLLM, 1 libre à 76 MiB) | **MESURÉ firsthand 16/11 22:48Z** (`nvidia-smi`) | ce run |
| po-2023…po-2028 | 3090/4090, 8-24 Go max | ≤ 24 Go | RAPPORTE (discussion cluster 21:51 ; po-2026 = RTX 3080 16 Go vu dans l'issue #4081) | dashboard cluster-coordination |
| web1 / web2 | VPS web (web2 = VPS distant) | pas de GPU | SUPPOSÉ structurel (classe VPS) | — |

**Le calcul qui tue** : les poids bf16 seuls (Qwen3-8B ≈ 16,4 Go + Qwen3-Embedding-4B ≈ 8 Go + module mémoire) ≈ **25 Go > 24 Go** de la meilleure carte de la flotte — avant KV cache, activations et overhead vLLM. La recette exige en outre Linux (nos sièges sont Windows ; WSL ne règle pas le mur VRAM) et des dépendances épinglées vulnérables. **Conclusion : inférence Memorilla impossible sur la flotte en l'état ; entraînement (4× H100, 19 h, 310 GiB) hors de question.** La seule voie de bench = **instance GPU louée** (1× A100/H100 80 Go ; ordre de grandeur SUPPOSÉ du marché : ~1-3 USD/h → **~2-5 USD pour 1-2 h** téléchargement 25 Go compris). C'est une dépense → décision user, portée à l'issue (#4801) et au registre.

## 3. Étape 2 — Éval étiquetée : graine livrée et mesurée

**Assets versionnés :**
- `scripts/analysis/memorilla-pilot/seed-eval.jsonl` — **15 paires** (question naturelle FR → réponse-or condensée + pointeur de preuve), minées des fiches mémoire du workspace (chaque réponse-or vérifiée contre la fiche lue ce run — pas de MEMORY.md recopié sans relecture).
- `scripts/analysis/memorilla-pilot/export_memorilla_dataset.py` — exporte la graine + un répertoire corpus `.md` vers le layout parquet Memorilla (`data/<task>/test-00000-of-00001.parquet`, split test uniquement — jamais de train copié de l'éval), avec manifeste SHA-256 par document.

**Protocole baseline (le recall « tel que nos lanes l'utilisent »)** : `roosync_search(action:"semantic", workspace:"roo-extensions", max_results=5)`, question = formulation naturelle sans le nom de fiche (l'agent qui ne sait pas quelle fiche chercher). Jugement gradué par un assesseur (moi) sur les snippets : 1 = le fait-or est énoncé ; 0,5 = matériel adjacent utile mais insuffisant ; 0 = rien. Run du 16/11 22:52-22:56Z.

**Résultats (n=15) :**

| Métrique | Valeur | Détail |
|---|---|---|
| **hit@1** | **3/15 = 20 %** | Q04 (ws-* écrit par Zoo), Q10 (execFile EINVAL), Q12 (.env gitignored perdu) |
| hit@3 plein | 3/15 = 20 % | mêmes |
| hit@3 partiel | +3/15 = 20 % | Q05 (règle d'appariement, pas ferme-tout), Q07 (instance du merge fantôme, pas la leçon), Q11 (topologie relais, pas les pièges) |
| Rien d'utilisable | **9/15 = 60 %** | dont Q03 = **zéro résultat** (60 candidats, tous exclus par les filtres) et Q15 (172/180 candidats exclus, budget non rempli) |
| Latence/question | ~2-24 s | horodatages des appels |
| Coût contexte/question | ~0,6-1,5 k tokens | payload JSON rendu à l'appelant |

**Lecture honnête (limites explicites) :**
1. **Asymétrie de corpus** : l'or vit dans les fiches mémoire ; `roosync_search` indexe des **sessions**. Une fiche n'apparaît en session que si elle y a été lue/écrite — Q10 hit précisément via la session fondatrice (74cf905f), Q12 via l'incident de juillet (pas la fiche d'octobre). La baseline mesure donc « le rappel retrouve-t-il le fait là où il vit dans le corpus indexé » — la question opérationnelle réelle pour un agent frais.
2. Faits **récents sous-représentés** : Q03 (15/11) et Q08 (14/11) introuvables — fraîcheur d'indexation et filtres (machine_output, provenance) plafonnent le rappel bien avant la sémantique ; plusieurs requêtes rendent < 5 groupes avec `budget_filled: false`.
3. n=15, un assesseur : **graine**, pas benchmark définitif. Extension vers 50-100 paires = protocole §4 (mécanique, pas de verrou).

**Ce que la graine montre déjà** : le point douloureux n'est pas la similarité sémantique mais la **découverte de faits-aiguilles** dans un corpus institutionnel — notre canal nominal (MEMORY.md → fiche) ne marche que si l'agent sait déjà quelle fiche ; le recall de découverte rate 60 % du temps. Un système *compress-then-read* qui voit les 15 fiches entières ne peut pas rater à l'étape retrieval — il payerait ailleurs (distillation/attention).

## 4. Étape 3 — Protocole bench (prêt à jouer, bloqué sur matériel uniquement)

Sur l'instance louée (Linux, 1× 80 Go) :

1. `git clone snap-stanford/memorilla` + venv uv (Python 3.11). L'éval n'a pas besoin de flash-attn.
2. `hf download memorilla/Memorilla-Qwen3-8B --local-dir checkpoints` (~25 Go).
3. `python export_memorilla_dataset.py --eval seed-eval.jsonl --corpus-dir <mémoire workspace> --output-dir my_data` (livré ce run).
4. `python evaluate.py --data_repo my_data --config roo_memory --split test --scoring generation --checkpoint memorilla/Memorilla-Qwen3-8B:pmv2` (checkpoint pmv2 = entraîné sur le paradigme PersonaMem, le plus proche de notre corpus).
5. **Métriques des deux côtés** : (a) Memorilla — exactitude de réponse (le fait-or est-il restitué ; jugé contenance des faits clés, pas mot-à-mot) + budget fixe 16 tokens + latence ; (b) recall RooSync — hit@k (graine ci-dessus, re-jouée à l'identique sur la machine de bench pour la symétrie temporelle) + tokens rendus (~1k/question). **Les métriques diffèrent par nature** (réponse distillée vs chunks retrouvés) : le rapport de bench tranchera sur « l'agent obtient-il la réponse utilisable, à quel coût », pas sur un score commun.
6. Gate (étape 4) : Memorilla nettement meilleur à coût raisonnable → proposer une **lane sidecar oracle** (jamais une dépendance runtime, non-goal) ; sinon → §7 seulement.

Cohérence : compléter la graine vers 50-100 paires avant le bench (mécanique : mêmes sources — fiches, dashboard, registre des questions — mêmes rubriques ; 1-2 sessions de lane).

## 5. Objections de l'issue, vérifiées

1. **Hardware** — CONFIRMÉE et quantifiée (§2) : bloquante sur flotte, ~2-5 USD en location.
2. **Architecture** — CONFIRMÉE au README : Memorilla répond AVEC son Qwen3-8B gelé ; les 16 tokens sont des embeddings latents pour SON décodeur, pas du texte portable dans nos fenêtres Claude/GLM. Usage réaliste = **oracle mémoire sidecar** interrogé à la demande (il faudrait alors juger sa réponse, pas l'ingérer). Le papier reste une référence de design quoi qu'il arrive.
3. **Maturité** — CONFIRMÉE : code de recherche de juin 2026, 29 commits, deps épinglées à advisories publics ; jamais en prod cluster sans audit (règle sécurité : modèles HF de confiance seulement, `weights_only=True` déjà leur défaut).

## 6. Complémentarité avec l'initiative Hermes (aucun chevauchement)

La lane cluster-coordination (ai-01/Hermes) a posté le même soir (dashboard 21:51Z) une proposition d'onboarding **pédagogique** : carnet RAG-série n°13 « compress-then-read » + section GRPO-mémoire PostTraining. Ce rapport est l'axe **pilote/bench** de roo-extensions : assets d'éval, baseline mesurée, gate. Les deux se nourrissent (leur mini-benchmark jouet local peut réutiliser notre graine) sans dupliquer.

## 7. Enseignements design — distillation à la lecture pour RooSync (valables même sans bench)

1. **Le split écriture/lecture de Memorilla est le même que le nôtre** (encoder une fois à l'écriture, récupérer à la lecture) ; la différence est **ce qui est récupéré** : chunks texte statiques vs représentation conditionnée par la requête. Notre condensation dashboard (résumé LLM statique à 92 %) et nos fiches sont à l'extrême « statique » — la baseline §3 (60 % de faits-aiguilles introuvables) en est le symptôme mesuré.
2. **Levier immédiat, sans aucun GPU** : à la lecture, quand une question institutionnelle échoue au recall, la lane dispose déjà du corpus **fiches** (petit : quelques centaines de Ko) — un lecteur à budget (l'agent lui-même, ou un passage sk-agent) qui lit **tout le corpus fiches** et distille la réponse est un « Memorilla pauvre » jouable aujourd'hui. La graine livrée est son éval.
3. **Le « memory cache » de Memorilla** (précalculer la cross-attention à l'écriture, 4× les embeddings) valide notre choix squelettes/Qdrant (précalcul à l'écriture) et suggère l'étape suivante : précalculer à l'écriture des **résumés par facettes** (quoi/pourquoi/preuve) plutôt qu'un résumé unique — plus cher à l'écriture, meilleur à la lecture.
4. **Budget fixe ≠ résumé fixe** : leurs 16 tokens sont *dépendants de la requête*. Toute transposition à la condensation RooSync doit garder cette propriété (distiller **pour la question en cours**), sinon on recrée le résumé statique qui a déjà perdu (§3, Q01).

## 8. Gate — décision ouverte portée au user

**Question unique (registre + issue)** : validez-vous la location ponctuelle d'une instance GPU 80 Go (~2-5 USD, 1-2 h) pour jouer le bench Memorilla sur la graine livrée ?
- **Oui** → lane sidecar de bench, rapport comparatif, décision lane sidecar oracle vs non.
- **Non / sans réponse** → Memorilla acté comme référence de design (§7), issue fermée sur ses livrables, graine conservée comme éval réutilisable (y compris pour le levier « pauvre » §7.2).

**Ce que cette session a livré** : étape 1 (verdict VRAM, mesuré), étape 2 (15 paires + baseline mesurée), étape 3 (protocole + exporteur prêts), étape 4 (analyse ; décision user pendante). Non-goals respectés : aucune dépendance runtime, aucune migration d'index, aucun déploiement.

---

**Fichiers livrés :** `scripts/analysis/memorilla-pilot/seed-eval.jsonl` · `scripts/analysis/memorilla-pilot/export_memorilla_dataset.py` · ce rapport.
**Sources primaires consultées 16/11 :** github.com/snap-stanford/memorilla (README intégral), arxiv.org/abs/2610.21375 (v3), huggingface.co/memorilla (référencé par le README), dashboard workspace (intercom 21:51Z, discussion Hermes), `nvidia-smi` ai-01.
