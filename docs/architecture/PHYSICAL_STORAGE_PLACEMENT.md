# Placement physique des données — disques, VHDX et volumes

**Version :** 1.0.0
**Mesuré le :** 2026-09-05 sur `myia-ai-01` (instruments : `Get-PhysicalDisk`, `Get-Disk`, `docker system df -v`, `docker inspect`, `df` WSL)
**Portée :** où vivent *physiquement* les données sur une machine de la flotte.

> Ce document complète [`DATA_STORAGE_POLICY.md`](DATA_STORAGE_POLICY.md) sans le contredire.
> Celui-là répond à « **quoi va dans git, quoi va dans le drive partagé** » ; celui-ci répond à
> « **sur quel disque et dans quel conteneur de stockage** ». Deux axes orthogonaux : un artefact
> peut être correctement hors-git *et* mal placé physiquement.

---

## 1. Le principe qui commande tout : un VHDX ne rend jamais rien

Un fichier VHDX **croît de façon monotone**. Chaque bloc réécrit alloue du neuf ; rien n'est
restitué à l'hôte tant qu'une **compaction** explicite n'a pas tourné. Trois conséquences, toutes
vérifiées sur ai-01 :

1. **Supprimer des données à l'intérieur ne libère rien à l'extérieur.** Un `docker prune` de
   35 Go rend 35 Go *dans* le vhdx, et **0 octet** sur le disque hôte.
2. **Un petit écrivain très actif gonfle énormément.** Une base de 1 Go qui réécrit sans cesse
   (WAL, VACUUM, dual-write) peut ajouter des dizaines de Go au vhdx. Sa taille logique ne dit
   donc rien de son empreinte réelle — et l'empreinte s'impute au vhdx, pas à elle.
3. **La mutualisation propage la contention.** Tous les locataires d'un même vhdx partagent le
   même fichier, donc les mêmes `fsync` et la même file d'E/S.

**Corollaire opérationnel :** l'ordre des gestes est **imposé, pas choisi** —
**compacter → déplacer → purger → compacter**. Un déplacement non suivi d'une compaction est
invisible sur le disque hôte.

### Ne pas confondre le stock et le flux

« C: se remplit de +16,9 Go en 5,5 h » est une mesure de **dérivée**. « C: est saturé » est une
mesure de **stock**. Les deux peuvent être vraies sans que la seconde découle de la première — et
sur ai-01 le 2026-09-05, le stock mesuré était **902,8 Go libres (24,2 %)**.

De même, « C: à 100 % » dans le gestionnaire des tâches Windows désigne le **temps actif d'E/S**,
pas le taux de remplissage. Un disque à 100 % d'activité avec 900 Go libres décrit une
**contention**, pas un épuisement. Nommer le bon phénomène change entièrement le correctif : la
contention se résout en **séparant les écrivains**, pas en libérant de la place.

---

## 2. Classer par motif d'écriture, jamais par commodité

Le bon critère n'est ni la taille ni la lettre du disque, c'est **comment la donnée est écrite**.

| Classe | Motif d'écriture | Exigence de placement |
|---|---|---|
| **Transactionnel** | churn permanent, `fsync` synchrones, durabilité exigée | **volume dédié sur un FS réel** — jamais dans un vhdx partagé |
| **Index / vectoriel** | rafales massives à l'indexation, lecture dominante ensuite | disque rapide dédié, isolé des autres écrivains |
| **Cache régénérable** | écrit une fois, relu, **reconstructible à volonté** | n'importe où sauf le disque système ; jetable |
| **Éphémère CI** | créé/détruit à chaque run | jetable, hors disque système |
| **Stockage long terme partagé** | **écrit une fois, lu par tous, jamais muté** | **G: / F:** — c'est leur rôle |
| **Archive froide** | écrit une fois, relu rarement | F: (bus USB acceptable) |
| **Journal / rotation** | churn permanent, faible valeur unitaire | **jamais** sur un montage de synchronisation |

### Le cas de G: (Google Drive) et F: — leur rôle est légitime

G: **n'est pas interdit**, et le présenter comme tel serait une erreur. Avec F:, c'est **notre lieu
de stockage long terme accessible par tous les agents** : la messagerie de coordination de la
flotte y vit, et `DATA_STORAGE_POLICY.md` prescrit explicitement le drive partagé pour l'état
opérationnel partagé.

Ce qui leur nuit n'est pas le volume, c'est le **churn** : DriveFS réconcilie chaque mutation, et
un écrivain à rotation rapide sature la réconciliation pour tout le monde. Le coût mesuré de
DriveFS est **l'ouverture par fichier**, ce qui pénalise les motifs à beaucoup de petites écritures
bien plus que les gros objets écrits une fois.

> **La règle se formule par motif, jamais par lettre de disque.**
> G: et F: accueillent ce qui est **écrit une fois et lu souvent**.
> Ils n'accueillent **jamais** ce qui est réécrit en boucle — logs, temporaires, bases actives,
> caches à rotation. Le critère est l'obstruction, pas la présence.

Le même conteneur peut donc être à la fois conforme et fautif : sur ai-01,
`livresagites-wordpress` monte depuis G: ses **backups** (légitimes, classe « stockage long
terme ») **et** ses **logs** (fautifs, classe « journal / rotation »). Le disque n'est pas en
cause ; le motif l'est.

---

## 3. Matrice de placement — `myia-ai-01`

| Support | Nature | Rôle assigné | Ne doit pas héberger |
|---|---|---|---|
| **C:** Crucial T705 4 To | NVMe Gen5, le plus rapide | OS, moteur Docker, système WSL | données en vrac, index, bases |
| **D:** Samsung 990 PRO 1 To | NVMe | code, configs, **volumes transactionnels (PG)** | archives |
| **E:** Samsung 990 PRO 1 To | NVMe | **Qdrant (toutes instances)** | le reste |
| **F:** SanDisk Desk SSD 8 To | **USB** | archives, images de VM, sauvegardes, stockage long terme | tout ce qui est chaud |
| **G:** Google Drive | montage de synchro | **état partagé flotte, sauvegardes, artefacts durables** | **tout ce qui churn** |

---

## 4. Inventaire mesuré (ai-01, 2026-09-05)

### Disques

| # | Modèle | Bus | Lettre | Total | Libre |
|---|---|---|---|---|---|
| 0 | Crucial T705 4 To | NVMe Gen5 | C: | 3 723 Go | 902 Go (24,2 %) |
| 1 | Samsung 990 PRO 1 To | NVMe | D: « Apps » | 932 Go | 445 Go |
| 2 | Samsung 990 PRO 1 To | NVMe | E: « Data » | 932 Go | 356 Go |
| 3 | SanDisk Desk SSD 8 To | **USB** | F: | 7 452 Go | 2 818 Go |
| — | Google Drive | DriveFS | G: | 3 723 Go | 376 Go |

### VHDX — les conteneurs de stockage réels

| Fichier | Taille sur disque | Contenu utile | Hôte |
|---|---|---|---|
| `docker_data.vhdx` | **926 Go** | ~597 Go récupérables | **C:** |
| `ext4.vhdx` (WSL Ubuntu) | **575 Go** | héberge les binds des 7 OWUI | **C:** |
| `E:\wsl-data\qdrant.vhdx` | 566 Go | **107 Go utilisés** → ~459 Go de vide | E: |
| `F:\UploadSSD\*.vhdx` | 703 Go | images de VM (archive) | F: ✅ |

**C: porte 1 501 Go de VHDX**, plus le cache DriveFS, plus l'OS.

> ⚠️ **Le « disque dédié à Qdrant » est lui-même un VHDX.** `Get-PhysicalDisk` présente le disque #4
> comme `Msft Virtual Disk / bus = File Backed Virtual` ; `Get-Disk -Number 4` donne
> `Location : E:\wsl-data\qdrant.vhdx`. Il paraissait plein à 62 % en ne portant que 107 Go de
> données : la différence est la monotonie du §1, pas de la donnée. **Vérifier le bus avant de
> planifier un déplacement vers un « disque ».**

### Docker (`docker system df`)

| Type | Taille | Récupérable |
|---|---|---|
| Images | 673,7 Go | **471 Go (69 %)** |
| Conteneurs | 36,2 Go | 4,7 Go |
| Volumes locaux | 760,9 Go | 116,7 Go |
| Cache de build | 98,3 Go | 9,1 Go |

---

## 5. Défauts constatés sur ai-01

### D1 — PostgreSQL dans le vhdx Docker partagé

Les trois instances vivent en volumes nommés dans `docker_data.vhdx` :

| Volume | Taille |
|---|---|
| `myia-open-webui_postgres-data` | 1,547 Go |
| `pg_unified_data` | 989,3 Mo |
| `onecli_pgdata` | 72,3 Mo |

**2,6 Go au total, soit 0,3 % du vhdx** — et pourtant trois défauts simultanés :

- l'espace repris par un `VACUUM` n'est **jamais** rendu à l'hôte ;
- les `fsync` concourent avec ~920 Go de voisins, dont un index vectoriel de 582 Go ;
- la croissance s'impute à « Docker », ce qui **fabrique une erreur d'attribution** : on accuse la
  base d'occuper de la **place** alors qu'elle consomme de la **bande passante**.

> Un moteur transactionnel exige un volume à lui. C'est la classe « Transactionnel » du §2.

⚠️ `pg_unified_data` porte le canal RooSync (#3151) : l'arrêter affecte **les sept machines**.
Migration **par copie puis bascule**, jamais par déplacement, et dans une fenêtre annoncée.

### D2 — La moitié de Qdrant n'est pas sur le disque qui lui est dédié

| Instance | Stockage | Taille |
|---|---|---|
| `qdrant_production` | bind → `/mnt/qdrant-e` (`E:\wsl-data\qdrant.vhdx`) ✅ | 107 Go |
| `qdrant_students` | volumes Docker → `docker_data.vhdx` **sur C:** ❌ | **582 Go** (+ 28 Go snapshots) |

`qdrant_students` pèse **63 % du vhdx Docker** et constitue le premier écrivain partageant C: avec
DriveFS et l'OS. Le disque qui lui est destiné est réellement occupé à **12 %** — la place existe,
elle est emmurée dans les 459 Go de vide de `qdrant.vhdx`. **C'est le plus gros levier unique.**

### D3 — Un conteneur écrit ses journaux sur G:

`livresagites-wordpress-1` et `livresagites-wordpress_cli-1` montent depuis
`G:\Mon Drive\MyIA\Comptes\LivresAgités\...` :

- leurs **backups** — classe « stockage long terme partagé », **légitime**, c'est le rôle de G: ;
- leurs **logs** — classe « journal / rotation », **fautif** : churn permanent sur le montage de
  synchronisation.

Signalé comme **candidat à examiner**, pas comme cause établie. Le motif est exactement celui que
le §2 proscrit, et l'incident du 2026-09-05 a commencé par deux redémarrages de GoogleDriveFS
(15:37:47Z et 15:40:19Z) suivis d'un démontage de G: jusqu'à 16:00:53Z.

### D4 — ~102 Go de volumes sans conteneur attaché

`profiles_hf-cache` 51,31 Go · `llamacpp_llamacpp-model-cache` 18,31 Go ·
`qdrant_qdrant-students-snapshots` 13,14 Go · caches HF partagés ~15 Go · caches de compilation.

> **Zéro conteneur ne prouve pas « mort ».** Un cache HF se re-télécharge (coût : bande passante et
> temps) ; un snapshot Qdrant orphelin peut être la **seule copie** d'un état. Appliquer
> [`no-deletion-without-proof.md`](../../.claude/rules/no-deletion-without-proof.md) avant toute
> suppression : preuve de préservation d'abord, suppression ensuite.

---

## 6. Séquence d'exécution

L'ordre découle du §1 et **ne peut pas être permuté** :

| # | Geste | Gain attendu | Coût / risque |
|---|---|---|---|
| 1 | **Compacter `E:\wsl-data\qdrant.vhdx`** | ~459 Go rendus à E: | arrêt `qdrant_production` |
| 2 | **Déplacer `qdrant_students` vers `/mnt/qdrant-e`** | −610 Go dans le vhdx C: | arrêt instance students, copie longue |
| 3 | **Volume dédié pour les 3 PG sur D:**, copie puis bascule | −2,6 Go, surtout **découplage E/S** | ⚠️ canal RooSync → fenêtre annoncée, impact flotte |
| 4 | **Purger images + cache de build** | ~480 Go dans le vhdx | nul (régénérable) |
| 5 | **Compacter `docker_data.vhdx`** | **rend enfin les gains 2-4 à C:** | arrêt Docker |
| 6 | Arbitrer D3 (logs G:) et D4 (volumes orphelins) | churn G: + ~102 Go | lecture avant suppression |

**Sans l'étape 5, les étapes 2 à 4 ne libèrent rien sur C:.** C'est le piège central de ce
document : chacune de ces étapes « réussit » visiblement tout en laissant l'occupation hôte
inchangée.

Chaque étape exige une **fenêtre nommée par l'utilisateur** : toutes arrêtent un service dont
dépend au moins une autre machine.

---

## 7. Portée flotte — ce n'est pas propre à ai-01

L'issue **#2475** (`[po-2023] Planifier migration docker_data.vhdx (409 Go) C: → D: en fenêtre
creuse`, ouverte le 2026-06-02) décrit **le même défaut structurel sur une autre machine**, et
porte déjà une procédure complète rédigée le 2026-07-28 : pré-vol (≥ 450 Go libres sur la cible),
snapshot de `%APPDATA%\Docker\settings-store.json`, clé `CustomWslDistroDir`, points de rollback,
durée estimée, conséquences d'une interruption.

Deux enseignements :

- **La procédure existe déjà** — réutilisable telle quelle pour ai-01, il n'y a pas à la
  réinventer. Elle a été **rédigée et jamais exécutée** : le blocage n'est pas technique, il est de
  fenêtre.
- **Le vhdx de po-2023 faisait 409 Go à l'ouverture de l'issue ; celui d'ai-01 en fait 926
  aujourd'hui.** Le défaut ne se stabilise pas tout seul : sans compaction périodique, il croît de
  façon monotone, par construction.

**Chaque machine doit faire son propre relevé.** Ne pas transposer les chiffres d'ai-01 : les
modèles de disques, les lettres et les instances diffèrent d'une machine à l'autre.

---

## Références

- [`DATA_STORAGE_POLICY.md`](DATA_STORAGE_POLICY.md) — axe git vs drive partagé (orthogonal)
- [`no-deletion-without-proof.md`](../../.claude/rules/no-deletion-without-proof.md)
- Issue #2475 — migration `docker_data.vhdx` po-2023 : **procédure réutilisable**
- Issue #3151 — canal RooSync sous PostgreSQL (impact flotte de l'étape 3)
