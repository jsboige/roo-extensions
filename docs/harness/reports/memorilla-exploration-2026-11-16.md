# Exploration Memorilla (snap-stanford) — pilote vs recall RooSync

**Issue :** [#4801](https://github.com/jsboige/roo-extensions/issues/4801) — origine : demande du canal cluster, 16/11 22:49
**Date :** 2026-11-16 · **Lane :** myia-ai-01:roo-extensions (worker interactif)
**Statut :** étapes 1-2 livrées, protocole bench prêt (étape 3), gate tranchée par le user (étape 4)
**Révisé le 17/11 :** verdict matériel corrigé après lecture du code (§2) — une carte 24 Go suffit au chemin d'évaluation (vérifié au code, non mesuré) ; décision user RX161 = pas de location (§8).

---

## TL;DR

1. **Une carte 24 Go suffit au bench, sous Linux** (révisé le 17/11, vérifié au code, non mesuré — §2). Le README demande « one 80 GB GPU », mais `evaluate.py` ne charge jamais l'encodeur et le décodeur ensemble : pic estimé ~19-21 Go avec `--gpu_memory_utilization` ≈ 0,8. ai-01 a une 4090 libre (3ᵉ carte, 34 MiB au relevé du 17/11). Restent : un environnement Linux (WSL2 ou conteneur avec accès GPU) et l'accord du propriétaire de la carte. La première version de ce rapport additionnait les poids des deux modèles (25 Go) et concluait à une location : c'était faux pour ce chemin.
2. **Éval étiquetée : graine de 15 paires construite et mesurée.** Baseline recall RooSync sur ces questions de connaissance institutionnelle : **hit@1 = 20 %, hit@3 (plein) = 20 %, partiel@3 = +20 %, rien d'utilisable sur 60 %** — dont une requête à zéro résultat et plusieurs faits récents (oct.-nov.) introuvables.
3. La comparaison honnête n'est pas « Memorilla vs Qdrant » sur la même métrique : notre rappel échoue à l'étape **retrieval** pour des faits-aiguilles qui tiennent en 15 fiches ; Memorilla (paradigme *compress-then-read*) verrait ces fiches entières dans son corpus et n'aurait à payer que la distillation. C'est exactement l'angle mort documenté (résumés statiques = ce que la requête aurait voulu).
4. **Gate (étape 4), décision user du 17/11 :** pas de location ; on vérifie que Memorilla tourne sur notre matériel, et/ou on attend une version compatible (§8). Prochain pas : un run unique sur la carte libre d'ai-01, après accord de son propriétaire. À défaut, Memorilla reste une **référence de design** (distillation à la lecture) pour la condensation RooSync — leviers §7. Dans tous les cas, le papier ne devient **jamais** une dépendance du runtime agent (non-goals respectés).

---

## 1. Ce que c'est (vérifié aux sources primaires, 16/11)

Mesuré sur le [repo GitHub](https://github.com/snap-stanford/memorilla) (README lu intégralement) et l'[abstract arXiv 2610.21375](https://arxiv.org/abs/2610.21375) (v3, 03/11/2026 — Fallahpour, Idehpour, Kothapalli, Mounier, Wu, Pardis, Leskovec / SNAP Stanford). Apache-2.0, 1,3k étoiles, 85 forks, 29 commits, poussé encore le 16/11. Toutes les affirmations ci-dessous sont VERIFIÉES aux sources :

- **Architecture :** un encodeur (Qwen3-Embedding-4B) encode chaque document **une fois** en embeddings réutilisables ; un module mémoire appris (cross-attention) récupère et place l'information dépendante de la requête dans l'espace d'embedding d'entrée d'un LLM **gelé** (Qwen3-8B) sous forme de **16 tokens mémoire** fixes, quel que soit le volume de la collection.
- **Revendications clés :** meilleure moyenne vs Mem0/MemoRAG sur 5/8 benchmarks ; FactKG 84,33 % vs 80,43 % full-context avec 108× moins de tokens ; NarrativeQA comprimé >4000× ; latence stable 0,74 s de 1 à 512 documents (~128k tokens) vs 19,9 s full-prompt ; agent TextWorld 18,6 % → 24,2 % (8 tokens).
- **Memory cache (profiling) :** KV de la cross-attention précalculée à l'écriture — question à 8,1 ms pour 1 M documents ; cache 4× la taille des embeddings (80 GiB pour 4 M docs, tient sur 1 GPU). Précision FactKG à ±0,06 point du défaut.
- **Exigences d'exécution (README, verbatim) :** « Linux with CUDA GPUs and Python 3.11 », recettes sur H100 80 Go ; « **You need one 80 GB GPU**, and the first run downloads about 25 GB of models ». Dépendances épinglées avec advisories publics (vLLM 0.9.1, transformers 4.53.3, torch 2.7.0 — GHSA cités dans leur README ; applicables aux modèles/checkpoints non fiables seulement).
- **Données personnelles :** PersonaMem-v2 (107 conversations ~32k tokens → question), PersonalizationV4 (149 utilisateurs fictifs × 200 conversations) — **le format exact de notre cas conversation_browser/memory**.
- **Format own-data :** un parquet par split, colonnes `collection_id` (entier `int64`, que le lecteur convertit par `int()`), `question`, `answer`, `documents` — consommé tel quel par `evaluate.py`/`train.py`.

## 2. Étape 1 — Inventaire VRAM : une carte 24 Go suffit au chemin d'évaluation (révisé 17/11)

| Siège | GPU | VRAM | Statut | Source |
|---|---|---|---|---|
| **myia-ai-01** | 3× RTX 4090 | 3× 24 564 MiB (2 chargées à ~21 Go par le hub vLLM, 1 libre à 76 MiB) | **MESURÉ firsthand 16/11 22:48Z** (`nvidia-smi`) | ce run |
| **myia-ai-01** (relevé 2) | idem | cartes 0 et 1 à 21 716 / 20 770 MiB (~80 % d'utilisation), **carte 2 libre à 34 MiB** | **MESURÉ 17/11 07:36Z** (`nvidia-smi`) | révision |
| po-2023…po-2028 | 3090/4090, 8-24 Go max | ≤ 24 Go | RAPPORTE (discussion cluster 21:51 ; po-2026 = RTX 3080 16 Go vu dans l'issue #4081) | dashboard cluster-coordination |
| web1 / web2 | VPS web (web2 = VPS distant) | pas de GPU | SUPPOSÉ structurel (classe VPS) | — |

**Première version (16/11), retirée :** les poids bf16 additionnés (Qwen3-8B ≈ 16,4 Go + Qwen3-Embedding-4B ≈ 8 Go + module mémoire) ≈ 25 Go > 24 Go, d'où « inférence impossible sur la flotte, location obligatoire ». Ce calcul suppose les deux modèles résidents en même temps. **Le code dit le contraire pour l'évaluation.** La revue Hermes (#4801, 16/11 22:00Z) l'avait déjà signalé : un 8B bf16 tient sur une 4090.

**Correction (17/11, VÉRIFIÉ au code, commit `6864db7a` du dépôt Memorilla, lecture seule) :**

1. **L'encodeur tourne seul, avant tout le reste, dans un processus séparé.** `load_target` appelle `ensure_embeddings` (`evaluate.py:161`). Pour des données maison, ce dernier lance `run_isolated(compute_embeddings, …)` (`memorilla/embeddings.py:528`), qui charge l'encodeur, encode, puis le libère (`embeddings.py:444-449` : `del engine`, `release_gpu_memory()`). Pic de cette phase ≈ 8 Go de poids + cache.
2. **Le décodeur est construit sans encodeur.** `evaluate.py:237-247` instancie `MemoryVLLM(...)` sans argument `encoder`. Les embeddings sont relus depuis le disque.
3. **Pas d'évaluateur en scoring `generation`.** `memorilla/metrics.py:545-546` ne charge l'encodeur de scoring que pour le scoring `choice`.
4. **Budget de la phase décodeur, estimé :**

   | Poste | Taille | Origine |
   |---|---|---|
   | Poids Qwen3-8B (moteur vLLM) | ≈ 16,4 Go | poids bf16 |
   | Copie de la matrice d'embedding (`_load_embedding_matrix`) | ≈ 1,2 Go | 151 936 × 4 096 en bf16 |
   | Module mémoire | 0,39 Go | `pmv2/memory.pt` = 388 258 057 octets, API Hugging Face, 17/11 |
   | Cache KV | quelques centaines de Mo par séquence | `CUSTOM_MAX_LENGTH = 2048`, `evaluate.py:40` |
   | **Total** | **≈ 19-21 Go** | moins que 24 Go |

5. **Un seul drapeau à changer.** Le défaut `DECODER_GPU_MEMORY_UTILIZATION = 0.6` (`memorilla/vllm.py:22`) ne réserve que 14,7 Go sur une carte de 24 Go, moins que les poids. Il faut passer `--gpu_memory_utilization` ≈ 0,8 (marge laissée à la copie d'embedding, allouée hors du moteur).
6. **Origine du « one 80 GB GPU » du README.** Il vise le chemin `MemoryVLLM.from_pretrained` (`memorilla/vllm.py:136-166`), qui fait cohabiter sur la même carte l'encodeur (part 0,25, `vllm.py:23`) et le décodeur (part 0,6). Ce n'est pas le chemin de `evaluate.py`.

**Ce qui reste vrai :**
- vLLM 0.9.1 exige Linux : il faut WSL2 ou un conteneur Linux avec accès GPU.
- Les dépendances épinglées ont des advisories publics : environnement isolé, checkpoints de confiance seulement.
- L'entraînement (4× H100, 19 h, 310 GiB) reste hors de portée.

**Statut : NON MESURÉ.** Seul un run tranche, sur une carte 24 Go libre (ai-01, carte 2) et avec l'accord de son propriétaire. Plan B, si la mesure échoue sur la mémoire : quantification fp8 du décodeur, gérée par les 4090 (Ada). Elle altère un décodeur gelé pendant l'entraînement, et le verdict du bench devrait le dire.

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

## 4. Étape 3 — Protocole bench (prêt à jouer sur une carte 24 Go libre)

Sous Linux (WSL2 ou conteneur avec accès GPU), sur **une** carte 24 Go libre désignée par `CUDA_VISIBLE_DEVICES`, avec l'accord du propriétaire de la carte :

1. `git clone snap-stanford/memorilla` + venv uv (Python 3.11). L'éval n'a pas besoin de flash-attn.
2. `hf download memorilla/Memorilla-Qwen3-8B --local-dir checkpoints` (~25 Go).
3. `python export_memorilla_dataset.py --eval seed-eval.jsonl --corpus-dir <mémoire workspace> --output-dir my_data` (livré ce run).
4. `python evaluate.py --data_repo my_data --config roo_memory --split test --scoring generation --gpu_memory_utilization 0.8 --checkpoint memorilla/Memorilla-Qwen3-8B:pmv2` (checkpoint pmv2 = entraîné sur le paradigme PersonaMem, le plus proche de notre corpus ; `--gpu_memory_utilization 0.8` obligatoire sur 24 Go, §2). Relever le pic mémoire (`nvidia-smi`) des deux phases : c'est la mesure qui confirme ou infirme §2.
5. **Métriques des deux côtés** : (a) Memorilla — exactitude de réponse (le fait-or est-il restitué ; jugé contenance des faits clés, pas mot-à-mot) + budget fixe 16 tokens + latence ; (b) recall RooSync — hit@k (graine ci-dessus, re-jouée à l'identique sur la machine de bench pour la symétrie temporelle) + tokens rendus (~1k/question). **Les métriques diffèrent par nature** (réponse distillée vs chunks retrouvés) : le rapport de bench tranchera sur « l'agent obtient-il la réponse utilisable, à quel coût », pas sur un score commun.
6. Gate (étape 4) : Memorilla nettement meilleur à coût raisonnable → proposer une **lane sidecar oracle** (jamais une dépendance runtime, non-goal) ; sinon → §7 seulement.

Cohérence : compléter la graine vers 50-100 paires avant le bench (mécanique : mêmes sources — fiches, dashboard, registre des questions — mêmes rubriques ; 1-2 sessions de lane).

## 5. Objections de l'issue, vérifiées

1. **Hardware** — LEVÉE sous réserve de mesure (§2, révisé 17/11). Une carte 24 Go suffit au chemin d'évaluation ; il reste Linux et une carte libre. La première version la disait bloquante : c'était une erreur de calcul (poids additionnés).
2. **Architecture** — CONFIRMÉE au README : Memorilla répond AVEC son Qwen3-8B gelé ; les 16 tokens sont des embeddings latents pour SON décodeur, pas du texte portable dans nos fenêtres Claude/GLM. Usage réaliste = **oracle mémoire sidecar** interrogé à la demande (il faudrait alors juger sa réponse, pas l'ingérer). Le papier reste une référence de design quoi qu'il arrive.
3. **Maturité** — CONFIRMÉE : code de recherche de juin 2026, 29 commits, deps épinglées à advisories publics ; jamais en prod cluster sans audit (règle sécurité : modèles HF de confiance seulement, `weights_only=True` déjà leur défaut).

## 6. Complémentarité avec l'initiative Hermes (aucun chevauchement)

La lane cluster-coordination (ai-01/Hermes) a posté le même soir (dashboard 21:51Z) une proposition d'onboarding **pédagogique** : carnet RAG-série n°13 « compress-then-read » + section GRPO-mémoire PostTraining. Ce rapport est l'axe **pilote/bench** de roo-extensions : assets d'éval, baseline mesurée, gate. Les deux se nourrissent (leur mini-benchmark jouet local peut réutiliser notre graine) sans dupliquer.

## 7. Enseignements design — distillation à la lecture pour RooSync (valables même sans bench)

1. **Le split écriture/lecture de Memorilla est le même que le nôtre** (encoder une fois à l'écriture, récupérer à la lecture) ; la différence est **ce qui est récupéré** : chunks texte statiques vs représentation conditionnée par la requête. Notre condensation dashboard (résumé LLM statique à 92 %) et nos fiches sont à l'extrême « statique » — la baseline §3 (60 % de faits-aiguilles introuvables) en est le symptôme mesuré.
2. **Levier immédiat, sans aucun GPU** : à la lecture, quand une question institutionnelle échoue au recall, la lane dispose déjà du corpus **fiches** (petit : quelques centaines de Ko) — un lecteur à budget (l'agent lui-même, ou un passage sk-agent) qui lit **tout le corpus fiches** et distille la réponse est un « Memorilla pauvre » jouable aujourd'hui. La graine livrée est son éval.
3. **Le « memory cache » de Memorilla** (précalculer la cross-attention à l'écriture, 4× les embeddings) valide notre choix squelettes/Qdrant (précalcul à l'écriture) et suggère l'étape suivante : précalculer à l'écriture des **résumés par facettes** (quoi/pourquoi/preuve) plutôt qu'un résumé unique — plus cher à l'écriture, meilleur à la lecture.
4. **Budget fixe ≠ résumé fixe** : leurs 16 tokens sont *dépendants de la requête*. Toute transposition à la condensation RooSync doit garder cette propriété (distiller **pour la question en cours**), sinon on recrée le résumé statique qui a déjà perdu (§3, Q01).

## 8. Gate — décision user

**Question posée (16/11)** : valider la location ponctuelle d'une instance GPU 80 Go (~2-5 USD, 1-2 h) ?

**Réponse du user (17/11, verbatim)** : « on vérifie ou/et on attend d'avoir un solution compatible avec notre matériel ». Donc **pas de location**.

**Suite :**
1. **Vérifier.** La lecture du code (§2) montre qu'une carte 24 Go suffit. Il faut un run unique sur la carte libre d'ai-01, avec l'accord de son propriétaire, en relevant le pic mémoire. Ce n'est pas une installation : environnement jetable, aucun service touché.
2. **Si le run confirme** : bench complet (§4), puis rapport comparatif et décision lane sidecar oracle vs non.
3. **Si le run échoue sur la mémoire** : essayer le décodeur en fp8 (plan B §2), ou attendre un checkpoint plus petit. Au 17/11, l'organisation Hugging Face `memorilla` ne publie que `Memorilla-Qwen3-8B`.
4. **Dans tous les cas** : la graine reste une éval réutilisable, y compris pour le levier « pauvre » §7.2.

**Ce que cette session a livré** : étape 1 (inventaire VRAM mesuré, verdict corrigé le 17/11 au code), étape 2 (15 paires + baseline mesurée), étape 3 (protocole + exporteur prêts), étape 4 (décision user enregistrée). Non-goals respectés : aucune dépendance runtime, aucune migration d'index, aucun déploiement.

---

**Fichiers livrés :** `scripts/analysis/memorilla-pilot/seed-eval.jsonl` · `scripts/analysis/memorilla-pilot/export_memorilla_dataset.py` · ce rapport.
**Sources primaires consultées 16/11 :** github.com/snap-stanford/memorilla (README intégral), arxiv.org/abs/2610.21375 (v3), huggingface.co/memorilla (référencé par le README), dashboard workspace (intercom 21:51Z, discussion Hermes), `nvidia-smi` ai-01.
**Sources de la révision 17/11 :** code source Memorilla au commit `6864db7a` (clone en lecture seule, rien exécuté), API Hugging Face (fichiers de `pmv2`, modèles de l'organisation `memorilla`), `nvidia-smi` ai-01 07:36Z.
