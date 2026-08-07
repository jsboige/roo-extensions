# Le harnais, vue d'ensemble

**Ce que c'est.** La documentation de ce dépôt vit dans 70 fichiers de référence, chacun exact sur son sujet et muet sur le reste. Ce document est la vue d'ensemble qui manquait : ce que le harnais fait, avec quoi, et pourquoi il est construit ainsi.

**À qui ça s'adresse.** À un agent ou un humain qui arrive sur le cluster et veut comprendre l'ensemble avant de plonger dans une règle particulière. C'est aussi la **source de vérité** dont le module pédagogique [`NOTRE-STACK.md`](https://github.com/jsboige/CoursIA/blob/main/MyIA.AI.Notebooks/GenAI/Vibe-Coding/docs/NOTRE-STACK.md) du dépôt CoursIA tire sa matière — le rendu pédagogique est chez eux, les faits techniques sont ici (précédent [`1f26d9fb`](https://github.com/jsboige/roo-extensions/commit/1f26d9fb), Epic #2877).

**Ce que ce document n'est pas.** Il ne duplique pas les références détaillées : il les situe et pointe vers elles. Chaque section se termine par ses liens.

---

## 1. La forme générale

Six machines, deux agents par machine (un Roo, un Claude Code), un dépôt commun. Une machine coordonne (`myia-ai-01`), les autres exécutent. Il n'y a **pas** de serveur d'orchestration : la coordination passe par des fichiers partagés sur Google Drive et par GitHub. C'est un choix, et il a une conséquence directe — tout état partagé est *éventuellement cohérent*, jamais transactionnel. Une bonne part des règles qui suivent existent pour rendre ce compromis vivable.

Les agents ne tournent pas en continu. Chacun est réveillé par un cron, exécute un cycle de travail autonome, écrit son bilan, et se rendort. Le coordinateur a sa propre cadence (3 h). Rien ne garantit que deux agents soient éveillés en même temps — d'où le fait que **tous les canaux de coordination soient asynchrones et durables**.

---

## 2. `roo-state-manager` — les 15 outils

C'est le serveur MCP central du harnais, écrit en TypeScript, vivant dans le sous-module `mcps/internal`. Il expose **15 outils** au handshake MCP.

> **Le compte est 15, pas 34.** Les consolidations « CONS » ont regroupé des dizaines d'outils unitaires en outils-familles paramétrés par une `action`. Le chiffre 34 circule encore dans des documents antérieurs à ce regroupement ; il est faux depuis. La mesure qui fait autorité est le handshake : ce qu'une session voit réellement.

### 2.1 Coordination (6 outils)

| Outil | Ce qu'il fait | Ce qu'il remplace |
|---|---|---|
| `roosync_dashboard` | Lit et écrit les tableaux de bord partagés (`global`, `machine`, `workspace`). C'est **le** canal de coordination. Actions : `read`, `append`, `write`, `update`, `list`, `refresh`, `read_overview`, `read_archive`, `delete`. | Les fichiers `INTERCOM-*.md` locaux, dépréciés en avril 2026 |
| `roosync_messages` | Messagerie point-à-point entre machines, avec priorités (`LOW`→`URGENT`), fils de discussion, pièces jointes et TTL d'auto-destruction. Survit à la condensation des dashboards. | Le courrier électronique interne qui n'a jamais existé |
| `roosync_inventory` | État des machines : inventaire de configuration locale, heartbeats, santé du cluster avec score. | Des scripts d'inventaire ad-hoc par machine |
| `roosync_compare_config` | Compare les configurations entre deux machines, par granularité (`mcp`, `mode`, `settings`, `claude`, `modes-yaml`, `full`), avec sévérités. | La comparaison manuelle de fichiers JSON |
| `roosync_config` | Collecte, publie et applique des paquets de configuration via Google Drive. | La copie manuelle de configs entre machines |
| `roosync_baseline` | Gère la configuration de référence : versionner, restaurer, exporter, lister les versions. | Rien — cette capacité n'existait pas |

**Les deux canaux, et pourquoi ils coexistent.** Le dashboard est *diffusé* : tout le monde le lit, il porte l'état collectif. Les messages sont *dirigés* : ils portent une instruction à une machine précise. La distinction n'est pas cosmétique — le dashboard s'auto-condense à 92 % de sa taille limite, ce qui archive les messages anciens. Une instruction postée uniquement sur le dashboard peut donc disparaître avant d'avoir été lue par une machine endormie. **Une consigne qui doit survivre passe par `roosync_messages`.** C'est une règle née d'instructions perdues, pas d'une préférence esthétique.

### 2.2 Mémoire et recherche (4 outils)

| Outil | Ce qu'il fait |
|---|---|
| `conversation_browser` | Navigue dans l'historique des sessions : `list`, `tree`, `view`, `summarize`, `rebuild`. **`list` est obligatoire en premier** — les autres actions ont besoin des identifiants qu'il rend. |
| `roosync_search` | Recherche dans les tâches : `semantic` (vectorielle, via Qdrant), `text` (dans le cache), `diagnose` (santé de l'index). |
| `codebase_search` | Recherche sémantique dans le code, par concept plutôt que par chaîne exacte. **Le paramètre `workspace` doit toujours être passé explicitement** : l'auto-détection pointe vers le répertoire du serveur MCP, pas vers celui de l'appelant. |
| `export_data` | Exporte tâches, conversations ou projets en XML, JSON, CSV ou Markdown. |

**Recherche exacte contre recherche sémantique.** Interroger un moteur sémantique avec un identifiant exact, c'est le tester hors de son domaine : l'appariement littéral se fait enterrer sous des voisins thématiques et sort de la liste, ce qui se lit comme une panne. Pour un jeton exact, `Grep`. Pour un concept dont on ignore les mots employés, `codebase_search`. Les deux, jamais l'un à la place de l'autre.

### 2.3 Infrastructure et diagnostic (5 outils)

| Outil | Ce qu'il fait |
|---|---|
| `roosync_indexing` | Pilote l'index sémantique : indexer, réindexer, diagnostiquer, archiver, nettoyer, détecter les déchets, agréger les statistiques d'usage des outils. |
| `roosync_storage_management` | Inspection du stockage et maintenance, dont la réparation des fichiers JSONL corrompus par un BOM. |
| `roosync_mcp_management` | Gestion des serveurs MCP eux-mêmes : lire/écrire la configuration, reconstruire, forcer un rechargement. |
| `roosync_diagnose` | Diagnostics RooSync : environnement, débogage, réinitialisation, tests, santé du cache, machine à états du cycle de vie, analyse de feuille de route. |
| `read_vscode_logs` | Lit les journaux de l'hôte d'extension VS Code — utile quand un MCP ne se charge pas et qu'aucune autre trace n'existe. |

**Références :** [`tool-availability.md`](../../.claude/rules/tool-availability.md) · [`roosync-tools-guide.md`](reference/roosync-tools-guide.md) · [`conversation-browser-detailed.md`](reference/conversation-browser-detailed.md)

---

## 3. Le pattern coordinateur / workers

### 3.1 Les rôles

Le **coordinateur** (`myia-ai-01`) merge les PR, arbitre les collisions, dispatche le travail, et présente à l'utilisateur les décisions qui lui reviennent. Il n'écrit pas le contenu métier : il route et il tranche.

Les **workers** (`myia-po-2023` à `myia-po-2026`, `myia-web1`) prennent du travail, produisent des PR atomiques, et rapportent. **Un worker ne merge jamais sa propre PR** — la séparation entre celui qui produit et celui qui intègre est ce qui rend la revue réelle.

### 3.2 Les gardes, et l'incident qui a produit chacune

Ces règles ne sont pas des principes d'hygiène généraux. Chacune est la cicatrice d'une panne précise, et c'est ce qui les rend intéressantes à lire.

**Anti-double-claim.** Avant de coder sur une issue, vérifier qu'aucune PR ouverte ne la référence, lire le dashboard pour un `[CLAIMED]` récent, et poster son propre `[CLAIMED]` horodaté **avant** de modifier quoi que ce soit. *Origine :* trois implémentations parallèles de la même issue, environ douze heures de travail dupliqué. Corollaire appris plus tard : **l'urgence produit la collision** — un relevé fait à un instant ne protège pas d'une PR créée une minute après.

**PR obligatoire, aucun push direct sur `main`.** Worktree → branche → PR → revue → merge → nettoyage. *Origine :* des changements arrivés sur `main` sans revue, dont certains cassaient la CI de toute la flotte.

**Garde d'identité dans la commande agissante.** Plusieurs sessions, un worker et des conteneurs appellent `gh` de front sur la même machine ; `gh` n'a aucun modèle de concurrence et son identité vit dans un unique fichier machine-global qu'un autre processus peut réécrire entre deux commandes. La garde doit donc être **dans** la commande qui agit :
```bash
gh auth switch --user <bot> && [ "$(gh api user --jq .login)" = "<bot>" ] && gh pr merge N --squash
```
*Origine :* un merge passé sous la mauvaise identité parce que le `switch` avait été fait au tour précédent. **Une vérification faite au tour d'avant ne protège rien.**

**Pointeur de sous-module : jamais avant le merge, jamais sans vérifier l'atteignabilité.** Bumper le pointeur parent vers une SHA non mergée produit un pointeur orphelin qui casse `git pull` **sur toute la flotte**, pas seulement chez soi. La séquence est : la PR sous-module est `MERGED` → `rev-parse` → `cat-file -e` → `merge-base --is-ancestor` → `update-index --cacheinfo` → **relire `git ls-files -s`**, parce que `--cacheinfo` ne valide rien.

**Pas de suppression sans preuve de préservation.** « Code mort » est un label dangereux : le code peut être temporairement débranché, appelé dynamiquement, ou être un stub d'implémentation cible. La preuve exigée est explicite — équivalent fonctionnel, migration des imports, tests préservés, `git grep` à zéro résultat. *Origine :* des chaînes de suppression circulaires — A importe B, B est supprimé « consolidé dans C », A n'a alors plus d'importateurs et est supprimé à son tour.

**Lire le corps avant d'agir.** Avant de commenter, reviewer, merger ou dispatcher : le corps complet, **tous** les commentaires, **toutes** les revues avec leur état, et le diff. Le titre n'est pas la PR ; un `mergeStateStatus` n'est pas une revue.

**Références :** [`agent-claim-discipline.md`](../../.claude/rules/agent-claim-discipline.md) · [`pr-mandatory.md`](../../.claude/rules/pr-mandatory.md) · [`submod-pointer-safety.md`](../../.claude/rules/submod-pointer-safety.md) · [`no-deletion-without-proof.md`](../../.claude/rules/no-deletion-without-proof.md) · [`gh-identity-concurrency.md`](reference/gh-identity-concurrency.md)

---

## 4. Les règles auto-chargées

Le répertoire [`.claude/rules/`](../../.claude/rules/) est injecté dans le contexte de **chaque** session, sans invocation. C'est le mécanisme par lequel le harnais se souvient de ce qu'il a appris entre deux sessions qui ne partagent aucune mémoire.

Deux propriétés le rendent utilisable :

**Les règles sont minces, le détail est déporté.** Chaque fichier de règle tient en une page et pointe vers un document de référence pour la procédure complète. Le coût en contexte est payé à chaque session ; le détail ne l'est qu'à la demande.

**On corrige une règle en soustrayant.** Quand une ligne produit un mauvais comportement, on la supprime d'abord ; on n'ajoute un remplacement que si le retrait laisse un trou réel. Remplacer une ligne par son opposé est l'échec-pendule, et il produit des règles qui oscillent au lieu de converger. Si un mécanisme automatique traite déjà la question, ne pas ré-encoder son intention dans le prompt.

**Référence :** [`global-rules-detail.md`](global-rules-detail.md)

---

## 5. Ce qui ne marche pas

Cette section est la plus utile du document, et c'est celle que la documentation d'outillage omet systématiquement. Un harnais qui tourne depuis un an a des modes de défaillance connus ; les taire donne une image fausse de ce que coûte l'automatisation multi-agents.

### 5.1 Les faux succès

**Un rapport n'est pas une preuve.** Un agent qui déclare « terminé, PR créée » peut citer une SHA qui n'existe pas, une branche jamais poussée, une PR jamais ouverte. La discipline en vigueur exige que l'artefact soit vérifiable **à l'instant du rapport** : `git cat-file -e` pour un commit, `git ls-remote` pour une branche, `gh pr view` pour une PR. *Le principe condensé :* pas de SHA sans `git cat-file -e`, pas de PR sans URL valide, pas de `[DONE]` sur une promesse.

**Fermer une issue n'est pas la fermer.** La commande retourne un succès avant que le bot de checklist ait statué ; il rouvre l'issue quelques minutes plus tard si des cases restent décochées. Une session qui rapporte « fermée » sur le retour de la commande rapporte du faux. Il faut cocher **avant**, puis relire l'état **au moins cinq minutes après**.

**Un watchdog peut relancer un service sain.** Un script d'installation affiche « tâche enregistrée » que la tâche fonctionne ou non. Déclencher une fois et lire le résultat est la seule mesure qui distingue « installé » de « fonctionne ».

### 5.2 Les mesures qui mentent

**Un résultat vide ne se signale pas comme une erreur.** C'est la classe de panne la plus coûteuse du harnais : une commande qui rend zéro résultat parce que son motif est faux se lit exactement comme une commande qui rend zéro résultat parce que la chose est absente. La règle est devenue : *une mesure qui rend « rien » doit d'abord être suspectée elle-même.*

**Un drapeau alimenté par un champ que personne n'écrit est faux à cent pour cent, et paraît sain.** Un indicateur de synchronisation obsolète s'est déclenché sur les six machines pendant plus de cinq mois : son champ source n'était écrit que par des opérations de baseline, jamais par la coordination courante. Les tests le couvraient — mais chaque fixture passait une valeur *fraîche*, si bien que la suite n'a jamais exercé l'état permanent de la production. CI verte, cent pour cent faux en production. Un drapeau toujours allumé est pire qu'un drapeau absent : il entraîne les lecteurs à ignorer aussi ceux qui, à côté, disent vrai.

**Une fenêtre d'observation plus courte que la période du phénomène mesure zéro** — et ce zéro se lit comme « absent », jamais comme « mal échantillonné ».

**Un chiffre qui circule sans son échantillon devient un fait.** Un taux mesuré sur deux requêtes s'est propagé sur trois machines avant qu'une mesure sur douze requêtes ne le divise par deux. La direction était bonne, l'ampleur fausse — et rien dans la circulation du chiffre ne portait la taille de l'échantillon.

### 5.3 Le contexte

La fenêtre de contexte est la ressource rare, et sa gestion est un sujet à part entière. Le seuil de condensation est **universel** : 200 000 jetons, déclenchement à 90 %. La valeur par défaut de 50 % produit une boucle de condensation infinie — c'est un piège dans lequel le harnais est tombé, et la règle actuelle existe pour ça. Une session interactive ne recharge pas sa configuration en cours de route : un changement de seuil ne prend effet qu'au redémarrage.

Côté outils, la discipline de lecture est chiffrée : moins de 50 Ko se lit entièrement, entre 50 et 500 Ko avec un décalage et une limite, au-delà de 500 Ko jamais directement — un `head`, un `grep` ou un `jq`. Lire un fichier persisté énorme ne dégrade pas la tâche, il la tue.

### 5.4 L'index sémantique

L'index a des défauts mesurés, et les publier vaut mieux que les découvrir. Environ **16 %** des fragments rendus en tête de résultats sont des doublons exacts ; la moitié d'entre eux proviennent de tâches différentes, ce qu'une déduplication par identifiant de tâche ne peut pas voir. L'index avale aussi les sorties d'outils de recherche des agents, si bien qu'une recherche peut retrouver la recherche précédente plutôt que son sujet.

Ces défauts ont failli produire un mauvais correctif : cinq machines avaient convergé vers « filtrer les fragments d'interaction outil », et une mesure directe a montré que ce filtre **supprime du signal** — les fragments les plus utiles sur certaines requêtes en font partie, et l'écho, lui, est classé ailleurs. *La leçon :* cinq machines convergentes ne valent pas une mesure. La convergence portait sur le symptôme, réel, et se prolongeait en une inférence sur la cause que personne n'avait testée.

**Références :** [`agent-claim-discipline.md`](../../.claude/rules/agent-claim-discipline.md) · [`issue-closure.md`](../../.claude/rules/issue-closure.md) · [`context-window.md`](../../.claude/rules/context-window.md) · [`condensation-thresholds.md`](reference/condensation-thresholds.md) · [`context-explosion-runbook.md`](reference/context-explosion-runbook.md)

---

## 6. Le protocole de travail : SDDD

Toute tâche significative croise trois sources : **technique** (le code, qui est la vérité), **conversationnel** (l'historique des sessions), **sémantique** (la recherche par concept). Jamais une seule.

Le motif d'encadrement est simple et il paye : une recherche sémantique **au début** d'une tâche (est-ce que ça a déjà été fait ? quelle documentation existe ?) et **à la fin** (le travail est-il retrouvable ? la documentation trouvée au début est-elle devenue fausse ?). La recherche initiale évite de refaire ; la finale évite de laisser derrière soi une documentation qui contredit le code.

S'y ajoute une exigence de qualification. Une affirmation est **vérifiée** (testée soi-même), **rapportée** (un autre le dit, non confirmé), ou **supposée**. Ne jamais propager sans qualifier : le coût d'une vérification se compte en secondes, celui d'une erreur propagée en heures multipliées par six machines.

**Références :** [`sddd-grounding.md`](../../.claude/rules/sddd-grounding.md) · [`skepticism-protocol.md`](../../.claude/rules/skepticism-protocol.md)

---

## 7. Le cycle de vie d'un worker planifié

Les workers ne tournent pas en continu. Chacun est réveillé par une tâche planifiée, exécute un cycle autonome, rapporte, puis meurt. Tout ce qui doit survivre doit être écrit **avant** l'exit — il n'y a pas de mémoire entre deux cycles. Cette section décrit le cycle, et les gardes qui se sont implantées à chaque pas.

### 7.1 Le réveil

Une tâche planifiée (`schtasks` sur Windows, `cron` sur Linux) déclenche [`start-claude-worker.ps1`](../../scripts/scheduling/start-claude-worker.ps1) à intervalle régulier. La cadence par défaut est **3 h**, coordinateur compris ; deux machines exécutantes tournent à **2 h** — un compromis entre réactivité et coût en tokens, arbitré par machine et non uniformément. Le script installe un gestionnaire `trap` dès sa première ligne utile : tout signal de terminaison (SIGTERM, SIGINT, timeout) déclenche un shutdown gracieux qui préserve le travail en cours avant de rendre la main.

Le script injecte les variables d'environnement de `~/.claude.json` dans le processus worker (`#2252`) — sans cela, le sous-processus `claude -p` n'hérite pas des variables critiques (clés API, endpoints) qui ne vont qu'au serveur MCP, et la session démarre avec un MCP amputé.

### 7.2 La sélection de tâche

Le worker ne « choisit » pas librement : il prend la première tâche éligible, dans l'ordre suivant — message inbox qui le cible, issue GitHub ouverte avec le bon label, tâche dispatchée par le coordinateur. La fonction `Get-GitHubTask` effectue le **claim atomiquement au moment de la sélection** (`#1005`) : assigner l'issue + poster le commentaire `[CLAIMED]` + vérifier le résultat, dans la même transaction logique. Sans cela, deux workers peuvent prélever la même issue à quelques secondes d'intervalle — c'est l'incident fondateur de la règle anti-double-claim.

Un filtre supprime les issues déjà `[CLAIMED]` par un worker Claude dans les 6 dernières heures (`#1980`) — en lisant le motif regex précis qui est réellement posté (`[CLAIMED] by claude on <machine>`), pas une formulation idéalisée. La première version de ce filtre ne matchait rien parce qu'elle cherchait un texte différent de celui qui était réellement affiché : faux négatif silencieux, garde inopérante. *Leçon :* une garde qui valide son motif contre le texte idéalisé plutôt que contre le texte réellement posté protège contre un fantasme.

### 7.3 L'isolation par worktree

Chaque cycle crée un worktree dédié (`git worktree add .claude/worktrees/wt-<desc>`), pour deux raisons. D'abord, isoler le travail du worker des fichiers suivis par d'autres processus (un autre worker, une session interactive, un éditeur ouvert). Ensuite, garantir que le `main` local reste propre, donc que `git pull` ne produise jamais de conflit en cours de cycle.

**Le piège des worktrees imbriqués** (`#2123`, incident 2026-05-22). Un worktree créé *à l'intérieur* du working tree d'un sous-module (par ex. `mcps/internal/.claude/worktrees/wt-foo`) fait fuir le contenu du sous-module comme fichiers untracked du parent — 136 000 fichiers dans un cas mesuré. La règle : un worktree vit dans le repo git qui le gère, et jamais imbriqué dans un sous-répertoire qui est lui-même un sous-module.

### 7.4 L'exécution

Le worktree pret, le script appelle `claude -p` avec le skill `executor`, le prompt de la tâche, et les bornes (`MaxIterations`, modèle). Le modèle par défaut a évolué : Haiku en baseline depuis que le harnais a été réduit (`#1026`), avec escalade Sonnet sur retry via `Get-EscalatedModel` (`#1027`). Capée depuis `#2211` — l'escalade sans plafond consommait des crédits sur les retry en cascade.

Pendant l'exécution, le worker suit les règles auto-chargées (section 4) comme n'importe quelle session : pas de push direct sur main, pas de suppression sans preuve, lire le corps avant d'agir. La différence avec une session interactive est qu'il n'y a **pas d'humain au bout** — un worker ne peut pas demander une clarification. Il doit décider et rapporter.

### 7.5 La préservation du travail

C'est le moment où les incidents s'accumulent, parce que c'est celui où l'état est le plus fragile : travail local non encore poussé, worktree non encore nettoyé.

**Le `Detach HEAD guard`** (`#1613`, `#1666` Phase A2). Un worker qui commence à coder sur un HEAD détaché produit des commits orphelins — perdus au cleanup du worktree. La garde vérifie `git symbolic-ref -q HEAD` avant chaque commit. Si elle échoue, une branche `recovery-YYYYMMDD-HHmmss` est créée et poussée, et le worker inscrit `[RECOVERY_BRANCH]` dans son rapport pour que le coordinateur puisse la récupérer manuellement. *Origine :* un commit de travail perdu à jamais dans un cleanup de worktree.

**Pas de push pour les branches d'auto-commits uniquement** (`#1423`). Quand un cycle ne produit que des commits automatiques (metadata, sync) sans travail reviewable, pousser la branche crée une orpheline sur le remote sans PR associée. La fonction `Test-OnlyAutoCommits` détecte ce cas et skip le push — le worktree est nettoyé sans laisser de trace.

**Le shutdown gracieux** (`Invoke-GracefulShutdown`). Sur SIGTERM ou timeout, le trap handler tente, dans l'ordre : auto-commit des changements non commités, vérification que les commits ne sont pas que des auto-commits, push, et seulement alors suppression du worktree. Si le push échoue, le worktree **est conservé** pour récupération manuelle au cycle suivant (`Find-ExistingWorktree`). Nettoyer un worktree dont le travail n'est pas sur le remote est la forme la plus coûteuse de perte.

### 7.6 Le nettoyage des orphelins

À la fin de chaque cycle, le worker supprime les worktrees périmés et les branches associées. Cette étape a ses propres gardes :

**`Reset-PhantomSubmodulePointers`** — avant chaque commit qui touche un pointeur de sous-module, vérifier que la SHA cible est atteignable depuis `origin/main` du sous-module. Un pointeur orphelin casse `git pull` sur **toute la flotte**, pas seulement chez l'émetteur (incident `67514ec1`, 2026-05-11). Une session interactive qui pousse sur `main` avec un token propriétaire contourne ce garde — d'où la règle séparée [`submod-pointer-safety.md`](../../.claude/rules/submod-pointer-safety.md) pour les sessions non schedulées.

**`cleanup-orphan-branches.ps1`** — les branches dont le worktree a disparu sont supprimées par `git branch -D`. Le parsing de la sortie `git branch --list` doit stripper `*` (branche courante), `+` (marqueur *checked out in another worktree*) et les espaces (`#1417`, PR #3052) — sans cela, une branche orpheline encore checkée-out ailleurs arrive à `git branch -D` comme `"+ wt/foo"` et échoue silencieusement, laissant s'accumuler les orphelines.

### 7.7 Le rapport

Le worker poste un `[DONE]` (ou `[PROGRESS]`, `[BLOCKED]`) sur le dashboard workspace, avec : la tâche exécutée, le résultat (succès/échec), les artefacts (SHA, URL de PR), la prochaine action recommandée. La discipline [`agent-claim-discipline.md`](../../.claude/rules/agent-claim-discipline.md) exige que **chaque artefact cité soit vérifié à l'instant du rapport** — `git cat-file -e <SHA>` pour un commit, `git ls-remote origin <branche>` pour une branche, `gh pr view N --json state,url` pour une PR. Pas de SHA sans `cat-file`, pas de PR sans URL, pas de `[DONE]` sur une promesse.

### 7.8 La mort

Le process meurt. Il n'y a pas d'état persistant. Le cron suivant redéclenche un nouveau cycle, qui démarre from-scratch : dashboard, inbox, sélection, isolation, exécution, rapport, mort. Ce qui survit d'un cycle à l'autre vit dans quatre endroits — le dépôt git, les fichiers de dashboard sur Google Drive, les messages RooSync persistants, et les règles auto-chargées — jamais dans la mémoire du worker.

C'est ce qui rend le harnais robuste à ses propres pannes : un worker qui crash en milieu de cycle ne perd que son worktree (et encore, seulement si le shutdown gracieux échoue). L'état durable est ailleurs.

**Références :** [`agent-claim-discipline.md`](../../.claude/rules/agent-claim-discipline.md) · [`pr-mandatory.md`](../../.claude/rules/pr-mandatory.md) · [`submod-pointer-safety.md`](../../.claude/rules/submod-pointer-safety.md) · [`scheduled-coordinator.md`](coordinator-specific/scheduled-coordinator.md)

---

## 8. Les modes Roo et leur pipeline de génération

La coordination décrite jusqu'ici s'adresse au niveau *cluster* : qui parle à qui, sur quel canal, avec quelle garde. Elle s'exécute via Claude Code. **Le travail lui-même** — les modifications de code, les diagnostics, les analyses — est réalisé par Roo Code, et Roo n'est pas un agent monolithique : il opère sous un *mode*, qui sélectionne le jeu d'outils, le modèle, l'instruction système, et les critères d'escalade. Choisir le mauvais mode est l'une des causes structurelles de dépense excessive et de mauvais résultats.

### 8.1 Pourquoi deux niveaux, `simple` et `complex`

Chaque *famille* de tâches (code, debug, architect, ask, orchestrator) existe en deux niveaux. Le niveau `-simple` est conçu pour les tâches mécaniques bien définies : lecture de fichier, vérification de `git status`, exécution de commande, corrections localisées, formatage, documentation inline. Le niveau `-complex` absorbe la conception, le refactoring, l'analyse multi-composants et les décisions de design.

**Le coût.** Modèles petits et rapides pour `-simple` (Qwen 3 32B, GLM 4.7-Air). Modèles puissants et chers pour `-complex` (Claude Sonnet, Opus, GLM 4.7). Un orchestrateur qui décompose une tâche de 8 sous-taches en 8 appels `-complex` consomme l'équivalent de plusieurs heures d'un modèle lourd ; la même décomposition en `-simple` monte une fraction de cela. **Le bon mode est presque toujours le mode le moins cher qui réussit** — l'escalade est un recours, pas un réflexe.

**Le piège symétrique.** L'inverse existe : un `-simple` qui tente une modification d'API publique, un refactoring de schéma, ou un changement d'outil MCP est une mauvaise escalade *par le bas*. Le résultat est presque bon, les tests passent localement, et trois jours plus tard un autre composant casse parce que le contrat a dérivé. La règle de discrimination est exposée dans les `escalationCriteria` et `deescalationCriteria` de chaque mode, et c'est par là que le choix se fait — pas à l'instinct.

### 8.2 Les cinq familles

| Famille | Ce qu'elle fait | Mode `-simple` | Mode `-complex` |
|---|---|---|---|
| **code** | Modifier le code : du correctif au refactoring | `code-simple` | `code-complex` |
| **debug** | Diagnostiquer et corriger : du bug évident au problème système | `debug-simple` | `debug-complex` |
| **architect** | Décider et documenter l'architecture ; *modifie les `.md` uniquement* (regex native Roo) | `architect-simple` | `architect-complex` |
| **ask** | Lire et expliquer sans modifier | `ask-simple` | `ask-complex` |
| **orchestrator** | Décomposer et déléguer via `new_task` ; *aucun outil direct* | `orchestrator-simple` | `orchestrator-complex` |

L'orchestrateur est particulier : il n'exécute jamais lui-même. **Tout** ce qu'il fait passe par `new_task` à un autre mode. Cette contrainte n'est pas une suggestion — c'est l'invariant qui empêche un orchestrateur de prendre des décisions qu'il n'a pas les outils pour assumer. La règle est rendue littérale par un `groups: []` dans la configuration : *aucun groupe d'outils*, pas même `read`.

Cinq familles × deux niveaux = **dix modes générés**, et c'est exactement ce que produit le pipeline décrit ci-dessous. D'autres jeux de modes coexistent dans le dépôt (configurations historiques, profils par machine) et peuvent en contenir davantage ; ils ne sont pas produits par ce pipeline et ne s'y substituent pas.

### 8.3 Le pipeline de génération

Les modes ne sont pas écrits à la main dans `.roomodes`. Ils sont *générés* à partir de deux sources. Le pipeline est délibéré : il garantit qu'un changement de configuration (un nouveau critère d'escalade, une consigne d'orchestrateur) traverse une étape de validation avant d'atterrir dans la configuration effective de VS Code.

**Sources.**
1. [`roo-config/modes/modes-config.json`](../../roo-config/modes/modes-config.json) — les données : familles, `roleDefinition`, `groups`, `escalationCriteria`, `deescalationCriteria`, instructions d'escalade inter-niveaux.
2. [`roo-config/modes/templates/commons/mode-instructions.md`](../../roo-config/modes/templates/commons/mode-instructions.md) — le squelette Markdown qui assemble les champs en `customInstructions`.

**Cible.**
3. [`roo-config/modes/generated/simple-complex.roomodes`](../../roo-config/modes/generated/simple-complex.roomodes) — la sortie JSON ou YAML (YAML requis pour Roo 3.51.1+ en déploiement global).

**Le générateur.** [`generate-modes.js`](../../roo-config/scripts/generate-modes.js) lit les sources, applique le template avec un moteur `{{VAR}}` et `{{#if VAR}}…{{else}}…{{/if}}`, sérialise en JSON ou YAML et écrit la cible. Le sérialiseur YAML est *maison* — la dépendance externe a été retirée parce que les dépendances tierces sur un fichier critique de configuration sont un risque non rémunéré.

```powershell
# Génération standard
node roo-config/scripts/generate-modes.js
# Avec profil de modèle (résolution depuis model-configs.json)
node roo-config/scripts/generate-modes.js --profile <nom>
# Et déploiement direct vers .roomodes à la racine
node roo-config/scripts/generate-modes.js --deploy
```

**Pourquoi pas éditer `.roomodes` directement.** Trois raisons :
1. **Dérive silencieuse.** Une modification manuelle sera écrasée à la prochaine génération, sans avertissement. Seul le source est versionné.
2. **Pas de validation partagée.** Le format JSON/YAML n'est validé qu'en sortie du générateur. Une édition directe contourne ce filet.
3. **Pas de format commun entre machines.** Les profils de modèles, les groupes d'outils réglementés, et les instructions communes sont des sources ; les copier-coller dérive.

**Validation.** Avant commit, le script `check-mode-api-configs-drift` détecte la dérive entre le profil déclaré dans `modes-config.json` et la résolution effective dans `model-configs.json`. Une dérive non corrigée produit un mode qui pointe sur un modèle qui n'existe pas dans la configuration effective.

### 8.4 Le routage inter-famille pendant l'exécution

Une sous-tâche peut changer de nature en cours d'exécution. Un mode `code` qui découvre un bug pendant l'implémentation ne continue pas à coder sur un terrain devenu glissant — il délègue à `debug-simple`, qui lui-même peut escalader à `debug-complex` si la cause racine est multi-composants. Un `debug-simple` qui a besoin d'une décision d'architecture remonte à `architect-simple`, jamais au coordinateur du cluster.

**Seuls les orchestrateurs font ce routage.** Les workers spécialisés restent dans leur famille. C'est ce qui empêche un cycle d'escalade sans fin : un `-simple` qui appellerait un `-complex` sans passer par l'orchestrateur consommerait des appels que personne n'arbitre.

**Références :** [`roo-config/README.md`](../../roo-config/README.md) · [`modes-config.json`](../../roo-config/modes/modes-config.json) · [`generate-modes.js`](../../roo-config/scripts/generate-modes.js) · [`check-mode-api-configs-drift.js`](../../roo-config/scripts/check-mode-api-configs-drift.js)

---

## 9. L'architecture interne du serveur MCP `roo-state-manager`

Les 15 outils décrits en section 2 sont la face visible. En dessous, le serveur est un programme TypeScript structuré pour répondre à trois exigences contradictoires : démarrer vite (le client MCP attend un handshake rapide), supporter des outils lourds sans bloquer le démarrage, et dégrader proprement quand une dépendance externe est indisponible.

### 9.1 Forme générale

[`roo-state-manager`](../../mcps/internal/servers/roo-state-manager/) vit comme **sous-module** (`mcps/internal`) et non comme dossier du dépôt racine. C'est délibéré : il a son propre cycle de release, ses propres tests, son propre `package.json`, et il est partagé entre plusieurs extensions (Roo et, via le routeur, Claude Code). Le dépôt parent le consume via un gitlink bumper par PR — voir section 3.2 sur le bump de pointeur obligatoire après merge.

Le code source tient dans `src/` :
- `index.ts` — point d'entrée, bootstrap.
- `tools/` — les handlers MCP, un fichier par outil ou par famille d'outils.
- `services/` — la logique métier : `state-manager`, `background-services`, plus un sous-dossier par domaine (`roosync/`, `task-indexer/`, `unified-store/`, `synthesis/`…).
- `notifications/` — la couche de notification push, à côté de `services/` et non dedans.
- `config/` — lecture et validation de la configuration statique.
- `schemas/` — schémas Zod des arguments par outil — le contrat d'API interne.
- `interfaces/`, `types/`, `models/` — types partagés.
- `utils/` — utilitaires : logger, format d'erreur, détecteurs de stockage.
- `__tests__/`, `tests/` — batteries de tests unitaires, intégration, e2e.

### 9.2 Le démarrage rapide

Le client MCP attend que `tools/list` réponde pour considérer le serveur prêt. Tout ce qui retarde ce moment — un import profond, une connexion réseau, un parsing lourd — retarde l'agent qui appelle. L'architecture observée trace cet arbitrage explicitement.

**Étape 1 — bootstrap synchrone et silencieux (`src/index.ts`).** Le serveur charge `dotenv`, valide les variables d'environnement critiques, installe le monkey-patch `graceful-fs` *avant tout import touchant `fs`* (#2312), et redirige `console.log` vers `stderr` parce que `stdout` porte exclusivement le JSON-RPC du transport stdio. La redirection n'est pas cosmétique : plus de 730 appels `console.log` répartis sur 63 fichiers pollueraient le flux et casseraient le handshake. Pas d'import lourd ici.

**Étape 2 — connexion transport ASAP.** Le `StdioServerTransport` est connecté dès que possible, ce qui débloque `tools/list` même si le reste du système n'est pas prêt. *Latence mesurée du handshake* : sous la seconde sur la machine de référence.

**Étape 3 — chargement paresseux des services lourds (`tools/registry.ts`, #1140, #1145).** `tools/list` lit un fichier `tool-definitions.ts` *statique*, zéro import de handler. `tools/call` importe le handler du nom d'outil à la première invocation, puis le cache. Les modules lourds (détecteurs de stockage, services d'arrière-plan, indexeur) sont tous derrière des accesseurs lazy. *Réduction mesurée (#1140) :* un import statique de tous les handlers ajoutait **8,6 secondes** au démarrage (barrel `tools/index.js` profilé à 8,6 s, dominé par `roosync/index.js` à 8,3 s) ; en paresseux, le premier appel paye le coût et les suivants sont gratuits.

**Étape 4 — services d'arrière-plan.** Une fois le handshake passé, les `background-services` démarrent : heartbeat automatique, indexeur sémantique, notifications. Ils ne bloquent ni le client ni les outils.

### 9.3 L'enregistrement des outils

Le fichier [`tools/registry.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/registry.ts) est le point d'entrée des appels. Il fait trois choses :

1. **Maintenir un registre nom → handler.** L'enregistrement est explicite pour rendre auditable la liste des outils — c'est ce qui permet d'affirmer « 15 outils » sans grep dans tout `src/`.
2. **Appliquer un timeout par outil.** Défaut 120 s ; outils lourds (`roosync_indexing` 300 s, `codebase_search` 180 s, `roosync_storage_management` 180 s). *Origine :* un appel MCP resté pendant 22 heures en attendant une dépendance morte (#2267). Le timeout ne résout pas la cause, il borne le coût.
3. **Déléguer vers les accesseurs paresseux** présentés en 9.2.

### 9.4 La dégradation progressive (#1635)

Le serveur n'échoue pas au démarrage si une dépendance est manquante. Au lieu de cela, il *marque* la capacité correspondante comme « dégradée » via [`utils/server-capabilities.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/server-capabilities.ts), et les outils affectés retournent une erreur explicite quand on les appelle. Les variables `ROOSYNC_SHARED_PATH`, `QDRANT_URL`, `QDRANT_API_KEY`, `QDRANT_COLLECTION_NAME` sont requises ; `EMBEDDING_API_KEY` ou `OPENAI_API_KEY` est requise pour la recherche sémantique. Manquer l'une d'elles ne casse pas le démarrage, mais le cluster n'a plus de dashboards / plus de recherche sémantique — *et c'est visible*.

**L'invariant.** `tools/list` répond toujours avec la liste complète des 15 outils, même dégradé. C'est ce qui permet à l'orchestrateur ou au coordinateur d'appeler un outil de diagnostic, d'apprendre que la capacité est dégradée, et d'agir — au lieu de recevoir un crash incompréhensible au démarrage.

### 9.5 Le cycle de vie d'une tâche indexée

La section 5.4 a parlé des défauts de l'index sémantique. Côté serveur, ce que cet index fait, et c'est ce qu'il faut comprendre pour interpréter ses résultats :

1. **Capture.** Chaque session agent — Roo ou Claude — produit un JSONL de messages horodatés. Le stockage vit sur disque local à chaque machine, puis est centralisé sur Google Drive via le watcher RooSync.
2. **Indexation.** `roosync_indexing(action: "index")` segmente chaque JSONL en chunks (`message_exchange` pour les paires user/assistant, `tool_interaction` pour les paires assistant/tool+résultat), les envoie au modèle d'embedding déclaré dans `EMBEDDING_*`, et pousse les vecteurs dans Qdrant sous la collection `QDRANT_COLLECTION_NAME` (1,78 million de points mesurés).
3. **Recherche.** `roosync_search(action: "semantic")` encode la requête, cherche les plus proches voisins dans Qdrant, déduplique par similarité intra-cluster, et rend un top-K.
4. **Reconstruction.** `conversation_browser(action: "view")` lit une conversation par son identifiant, en reconstituant le squelette depuis l'index si nécessaire (auto-rétraction du cache).

**Ce qui se passe mal.** Les `[tool_result]` massifs issus d'appels de recherche antérieurs sont indexés avec leur propre contenu ; une recherche qui retrouve une recherche précédente n'est pas un bug, c'est l'effet direct d'un index qui contient ses propres entrées. C'est ce qui a produit la fausse piste « filtrer les fragments d'interaction outil » évoquée en 5.4 — la mesure a montré que ce filtre *supprime du signal*, et le filtre a été retiré.

### 9.6 Tests et validation

Trois batteries coexistent :
- **Unit (`vitest`).** Couvrent les services et les outils, par dossier (`tests/unit/services`, `tests/unit/tools`).
- **Intégration (`vitest run tests/integration`).** Couvrent les interactions entre services, avec dépendances réelles (Qdrant, GDrive).
- **E2E (`vitest run tests/e2e`).** Parcours complet d'un cas d'usage.

Le script [`validate-before-push.ps1`](../../scripts/mcp/validate-before-push.ps1) enchaîne build + tests `vitest` sur le sous-module avant tout push — c'est la garde contre la régression silencieuse dans `mcps/internal`. Un raccourci à la racine du dépôt est `npm run test:mcp`, qui délègue au sous-module sans risquer un `vitest` root qui ne découvrirait rien d'utile (un garde `vitest.config.ts` à la racine limite la découverte aux tests de la racine).

**L'invariant.** Aucune modification de `mcps/internal` ne doit être poussée sans ce passage en vert. La règle n'est pas négociable, parce que les six machines consomment le même module — une régression ici se voit partout.

**Références :** [`roo-state-manager/src/index.ts`](../../mcps/internal/servers/roo-state-manager/src/index.ts) · [`registry.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/registry.ts) · [`server-capabilities.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/server-capabilities.ts) · [`ci-guardrails.md`](../../.claude/rules/ci-guardrails.md) · [`mcp-diagnosis.md`](../../.claude/rules/mcp-diagnosis.md)

---

## Portée de ce document

Rédigé comme corpus source pour l'issue #3054, en réponse au mandat utilisateur du 2026-08-07 demandant que roo-extensions s'implique directement dans la documentation pédagogique du harnais plutôt que de la laisser s'écrire de l'extérieur.

Il est **anonymisé** au même standard que le module CoursIA : rôles et familles de machines, aucun hôte sensible, aucun secret, aucune clé.

Les sections 1 à 7 couvrent l'ossature, les sections 8 et 9 ajoutent la couche générative et la structure du serveur MCP qui les rend opérantes.
