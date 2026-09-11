# Procédure de retrait d'un secret publié sur un dashboard RooSync

**Version:** 1.0.0
**Origine:** #3584 — fuite du 11/09/2026 (clé embeddings, 64 hex nus, publiée sur le dashboard global à 09:48Z)
**Portée:** tout siège découvrant un secret publié sur un dashboard (`global`/`machine`/`workspace`) ou dans un DM RooSync.

---

## 0. Principe

Le garde #1144 (submod) masque **à l'écriture** (`writeDashboardFile`) ; le volet rétention
masque **à la condensation** (prompts LLM, archives, intercom réécrit) et couvre les copies
d'archives directes. Ces gardes ferment l'avenir — le **retrait d'un secret déjà publié**
reste une procédure opérateur, exécutée à la demande.

Règle d'or (consigne de lane du 11/09, toujours valable) : on publie
`{endpoint exact, sha8 attendu, sha8 observé}` — **jamais une valeur**, même « pour vérifier ».

## 1. Inventaire des copies d'un secret publié

| # | Copie | Localisation | Retrait |
|---|-------|--------------|---------|
| 1 | Dashboard vivant | `$ROOSYNC_SHARED_PATH/dashboards/<key>.md` | **`action:"scrub"`** — automatique |
| 2 | Miroir PostgreSQL | PG (upsert sync à chaque écriture) | **`scrub`** réécrit le miroir via le dual-write |
| 3 | Archive de condensation (succès) | `dashboards/archive/<key>-<ts>.md` | manuel (§3.3) |
| 4 | Archive fallback (`-fallback.md`) | idem | manuel |
| 5 | Archives pre-delete / wt-cleanup / pre-merge | idem | manuel |
| 6 | Tâche synthétique + index Qdrant | stockage Roo local `tasks/_cond-*` + collection Qdrant | purge d'index (§3.4, cf. #2783) |
| 7 | Résumé LLM (`CONDENSATION-SUMMARY`) | message système du dashboard vivant | `scrub` le masque comme tout message ; sinon régénéré à la condensation suivante |
| 8 | Transit provider LLM (prompts) | vLLM local / fallback cloud | **non retirable** — c'est précisément ce que le masquage pré-LLM (volet rétention) empêche pour l'avenir |
| 9 | Miroirs DriveFS des autres sièges | caches locaux de G: | rien à faire — la réécriture du fichier G: se propage |
| 10 | DM RooSync (`roosync_messages`) | store messages GDrive + PG | pas d'équivalent scrub — geste manuel + rotation |

## 2. Détection d'une empreinte vs d'une valeur

- Une **empreinte** (8 hex, `sha256(valeur)[:8]`) n'est PAS un secret — sa publication est le protocole.
- Une **valeur** (64 hex nus, `sk-…`, `ghp_…`, `Bearer …`, `NAME=VALUE`) l'est. Contrôle :
  `sha256(<chaîne publiée>)[:8]` == empreinte quorum annoncée → c'est la clé elle-même (cas #3584).

## 3. Procédure de retrait

### 3.1 Fenêtre courte (avant condensation — minutes à heures)

1. **Scrub depuis un siège détenteur** — le masquage par valeur exige que `process.env` du
   siège exécutant contienne la valeur (cf. `utils/secret-redaction.ts`) :

   ```
   roosync_dashboard(action: "scrub", type: "global")   // ou machine/workspace
   ```

   Relit le dashboard vivant, masque status + messages, réécrit fichier **et** miroir PG
   (mêmes verrous que `write`). Idempotent. Ne couvre PAS les archives.

2. Vérifier par relecture (`action:"read"`) que la valeur a disparu.

### 3.2 Fenêtre longue (après condensation)

La condensation a archivé le message et/ou produit un résumé :

1. Exécuter §3.1 d'abord (le dashboard vivant garde le message tant que le seuil 92 % n'est pas franchi).
2. Passer à §3.3.

### 3.3 Archives (manuel, geste opérateur G:)

1. Lister : `roosync_dashboard(action:"read_archive", type:…)` ou filesystem
   `$ROOSYNC_SHARED_PATH/dashboards/archive/`.
2. Le grep de l'**empreinte** ne trouve pas une valeur nue : chercher par la valeur elle-même
   (localement connue) — jamais en la republiant.
3. Supprimer ou éditer le fichier d'archive fautif. La suppression se propage aux autres
   sièges via DriveFS. Le retrait d'archive est **irréversible** : ne le faire que pour un
   secret confirmé.

### 3.4 Index Qdrant / tâches synthétiques

Si le message est passé par un fallback de condensation antérieur au volet rétention, il a pu
être indexé verbatim (tâche `_cond-*`). Purger comme #2783 : `roosync_indexing` (garbage_scan /
cleanup ciblés), puis vérification par `roosync_search` que la valeur n'est plus retrouvée.

### 3.5 Rotation

Le retrait ne remplace pas la rotation. Si la valeur a transité vers un provider externe
(fallback cloud) ou un index avant les gardes, la considérer **exposée** — décision
rotation-vs-risque-accepté à l'ayant-cause (lane propriétaire + user), pas au découvreur.

## 4. Qui peut retirer, dans quelle fenêtre

| Fenêtre | Qui | Moyen |
|---------|-----|-------|
| Avant condensation | tout siège détenteur du secret | `scrub` |
| Après condensation | opérateur G: (siège détenteur de préférence, pour grep la valeur) | §3.3 |
| Après indexation | siège avec accès `roosync_indexing` | §3.4 |
| Décision rotation | ayant-cause + user | §3.5 |

Le garde d'écriture journalise tout masquage (`[DASHBOARD-REDACTION]`, nom de variable + compte —
jamais la valeur) : c'est le signal qu'un auteur reçoit que son message a été altéré.

## 5. Prévention (rappel)

- **Jamais de valeur** dans un contenu publié — empreintes uniquement.
- Garde #1144 : masquage à l'écriture (formes auto-descriptives + valeurs connues du process).
- Volet rétention : masquage à l'entrée de condensation (prompts LLM, archives succès/fallback,
  tâche synthétique, intercom réécrit — auto-nettoyage du vivant au cycle suivant).
- Fichiers de rotation : jamais dans le dépôt — `gitignore` ad-hoc (submod #1145) ; corps de PR/
  commentaires via `--body-file`, jamais `--body` inline.

---

**Historique:** fuite fondatrice 11/09 09:48Z (dashboard global) · prévention #1144 (12:05Z) ·
volet rétention/retrait (cette procédure + `scrub`).
