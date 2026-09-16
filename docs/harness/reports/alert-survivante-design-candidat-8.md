# Alerte survivante — design proposal (Epic #3111 phase 2, candidat #8)

**Date :** 2026-09-15
**Issue :** [#3678](https://github.com/jsboige/roo-extensions/issues/3678)
**Dépendance :** [#3676](https://github.com/jsboige/roo-extensions/issues/3676) (candidat #3 — claim sur issue, registre de verrous hors GDrive)
**Cause racine :** [#2875](https://github.com/jsboige/roo-extensions/issues/2875) (GoogleDriveFS silent-exit — état CLOSED, contournement par watchdog #2933)
**Statut :** [PROPOSAL] — arbitrage user/coordinateur requis avant implémentation.
**Mise à jour 2026-09-16 (po-2023) :** implémenté sur les défauts proposés au §7 (GitHub Issue
label `gdrivefs-watchdog-alert`, 6 h, skip-threshold 2, poll rapide 1 min × 10 min option (b),
#2875 acté permanent, couche 3 non-implémentée) — voir le README du watchdog et l'issue #3678.
Les défauts restent réversibles : chaque valeur est un paramètre du body.

---

## 1. Le constat (audit live, 16/08, PR #3155)

Le watchdog GDriveFS (`scripts/gdrivefs-watchdog/gdrivefs-watchdog.ps1`, lignes 110-120, 460, 511-517)
**fait correctement son travail** et signale ses alertes **uniquement en local** (fichier + Event Log).
Les canaux de coordination de la flotte — ceux qui auraient permis de prévenir les autres machines —
ne sont **pas appelés par le watchdog** et sont de toute façon **muets pendant l'outage** (ils passent
par le mount `G:\` que la panne vient de tuer) :

| Stade watchdog | Canal d'alerte | Survit à l'outage GDrive ? |
|---|---|---|
| C0/C1 `FAIL` (relaunch) | `Write-Log` → fichier local `outputs\gdrivefs-watchdog\watchdog-YYYYMMDD.log` | OUI (disque local) |
| C2 escalation | `Write-EventLog` source `GDriveFS-Watchdog` EventId 2001 (script l.460) | OUI (Event Log Windows local) |
| Fin de cycle | `Write-EventLog` EventIds 1000 (info, l.511) / 2000 (alerte, l.517) | OUI (Event Log Windows local) |
| *(non appelé par le watchdog)* | Dashboard `workspace` (comment `[ALERT]`) — canal de coordination **indisponible pendant l'outage** | **NON — passe par GDriveFS** |
| *(non appelé par le watchdog)* | RooSync `messages.send(to: ...)` — canal de coordination **indisponible pendant l'outage** | **NON — passe par GDriveFS** |

L'incident du 16/08 (~15 min sourdes et muettes) ne résultait **pas** d'un défaut de détection :
le watchdog a vu la panne, a relancé DriveFS, et a marqué le retour à `mount-stat+enum-ok` dans
son log local. **Ce qui manquait** était le canal d'alerte externe : pendant ces ~15 min,
**personne d'autre que la machine elle-même** ne savait que la flotte était sourde et muette.

## 2. Trois candidats analysés

Le corps de l'issue #3678 énumère trois canaux candidats pour l'alerte survivante. Analyse
honnête de chacun — viabilité, coût, dépendances, pièges.

### 2.1 Candidat A — GitHub (issue/commit) via `gh`

| Aspect | Évaluation |
|---|---|
| Survit à un outage GDrive | **OUI** — GitHub est indépendant du mount `G:\` |
| Survit à un outage réseau étendu | **NON** — mais c'est une panne différente (perte d'API), et le coût d'un canal redondant à GitHub lui-même est prohibitif |
| Survit à une panne `gh` auth (token stale) | Risque réel, déjà rencontré (#3591 RSM identity delegated to proxy-chain) — **un fallback `gh` mort ne sert à rien** |
| Coût de mise en place | Bas — `gh issue create` est déjà outillé |
| Coût d'usage | ~1-3 calls GitHub par alerte — bien en dessous des 5000/h budget |
| Surface d'observabilité | Bonne — qui regarde les issues `jsboige/roo-extensions` voit l'alerte |
| Auditabilité | Excellente — alerte = issue/commit = horodatée et immuable |
| **Risque principal** | **Le destinataire humain doit regarder GitHub pour voir l'alerte** — pas de push, pas de SMS, pas de mail auto. C'est un canal de **log distribué**, pas un canal de **notification** |

**Viabilité :** Bonne comme **canal de log persistant** (deuxième exemplaire de l'alerte). Faible
comme **canal de notification temps réel**.

### 2.2 Candidat B — fichier local + listener hors-GDrive

| Aspect | Évaluation |
|---|---|
| Survit à un outage GDrive | **OUI par construction** (le fichier est sur disque local) |
| Survit à une panne machine | NON — le listener n'est pas plus robuste que le watchdog lui-même |
| Coût de mise en place | **Élevé** — il faut un daemon hors-GDrive qui pousse le fichier vers un destinataire externe. Si le destinataire est GDrive, on est dans la même impasse. Si c'est GitHub, on retombe sur le candidat A |
| Surface d'observabilité | Dépend du destinataire |
| **Risque principal** | **Où pousse-t-on le fichier ?** Tout destinataire externe autre que GitHub exige une infra nouvelle — non, c'est exactement le « second canal complet » que l'issue exclut explicitement dans ses non-buts |

**Viabilité :** Médiocre. C'est un intermédiaire qui doit lui-même avoir un destinataire — il
n'apporte rien si le destinataire est GitHub (on prend directement le candidat A), et il apporte
un second canal complet si le destinataire est autre (ce que l'issue exclut).

### 2.3 Candidat C — Windows Event Log + collecteur externe

| Aspect | Évaluation |
|---|---|
| Survit à un outage GDrive | **OUI** — Event Log est local à la machine |
| Survit à une panne machine | OUI (le log reste sur disque, lisible au reboot) |
| Survit à un crash du watchdog lui-même | **NON** — si le watchdog meurt avant `Write-EventLog`, l'alerte est perdue. Mais le watchdog est un schtask, pas un service long-lived : il finit toujours par sortir |
| Survit à un OS cassé | NON — mais c'est aussi un cas hors-périmètre |
| Coût de mise en place | **Minimal** — `Write-EventLog` est déjà câblé dans le watchdog (lignes 110-120, `Write-WatchdogEvent` EventId 2000/2001) |
| Coût de lecture | **Élevé sans collecteur** — qui regarde l'Event Log d'une machine distante ? Personne en routine |
| Surface d'observabilité | **Faible tant qu'aucun collecteur n'est branché** — l'Event Log est un sink, pas une source |
| **Risque principal** | **L'Event Log sans collecteur est un canal qui parle dans le vide.** Le destinataire (humain ou fleet) doit explicitement venir le lire |

**Viabilité :** Le canal est déjà implémenté — il suffit, mais il **n'est lu par personne**.
Pour qu'il serve, il faut soit (i) un collecteur distant qui le pousse ailleurs, soit (ii) un
script de check périodique depuis une autre machine (ce qui est précisément la proposition du
**watchdog inter-machines** : chaque machine lit l'Event Log des autres et lève une alerte si
l'absence d'événement « OK » dépasse le seuil).

## 3. Recommandation — défense en deux couches

Aucun canal unique ne couvre tous les cas. La proposition est :

**Couche 1 — Local, persistante, gratuite (déjà en place) :**
- `Write-EventLog` EventIds 2001 (escalation, script l.460) et 1000/2000 (fin de cycle, l.511-517). Rien à coder.
- `Write-Log` fichier `outputs\gdrivefs-watchdog\watchdog-YYYYMMDD.log` (déjà câblé). Rien à coder.

**Couche 2 — Distante, persistante, à coût borné (à ajouter) :**
- À chaque `cooldown` engagé (C2 escalation) OU à chaque `cooldown-skip` répété N fois dans une fenêtre, poster une **GitHub Issue** dans `jsboige/roo-extensions` avec le label `gdrivefs-watchdog-alert`, le timestamp, la raison, et l'état de l'instance.
- Justification du choix GitHub : c'est le seul candidat qui **persiste** (l'Event Log est volatile au-delà de la taille du journal), **ne dépend pas de GDriveFS** (l'`gh` CLI tape l'API REST directement), et **est déjà outillé** (l'auth multi-bot est en place, voir [`docs/harness/reference/gh-identity-concurrency.md`](../reference/gh-identity-concurrency.md)).
- Garde anti-dédoublement : état JSON du watchdog garde un `last_github_alert_at` ; une nouvelle issue ne part que si `now - last_github_alert_at > 6 h`. **Coût plafond** : ~4 issues / 24 h en cas de panne continue (une par tranche de 6 h), soit ~0,2 appel/h contre un quota horaire de 5 000 — ~0,003 % du quota horaire.

**Couche 3 — Détection croisée inter-machines (option, post-MVP) :**
- Chaque machine, à chaque cycle `Claude-DashboardListener` (déjà déployé, ~5 min de heartbeat), vérifie l'Event Log des **autres** machines de la flotte via une commande win-cli (`Get-WinEvent -ComputerName <host> -FilterHashtable @{LogName='Application';ProviderName='GDriveFS-Watchdog'}`) si WinRM est ouvert, **OU** via la présence d'un ping GitHub périodique (chaque machine commit `watchdog-heartbeat-YYYYMMDD.json` toutes les ~30 min dans une branche dédiée `fleet-heartbeats`).
- Cette couche **détecte la panne par absence** (« aucune machine n'a posté de heartbeat depuis > 30 min ») — elle ne dépend pas du canal d'alerte lui-même.

> **Note :** la couche 3 est une refonte du listener fleet et dépasse le scope « canal d'alerte
> minimal » de l'issue. Elle est mentionnée pour complétude, pas pour exécution dans cette PR.

## 4. Sur la fenêtre d'indisponibilité (livrable 2)

Le poll est à 15 min. L'auditeur PR #3155 a recommandé « plus court sur détection, sans
régresser le coût ». Proposition concrète :

- **Poll normal : 15 min** (inchangé — coût de 96 polls / 24 h par machine).
- **Poll rapide : 1 min, pendant 10 min, après un C2 escalation**, puis retour à 15 min si la machine est de nouveau saine, OU maintien en poll rapide si elle retombe.
- **Coût — deux implémentations possibles, deux coûts nominaux différents** :
  - **(a) Deux triggers permanents** (15 min + 1 min installés en permanence, le body sort tôt hors fenêtre rapide) : coût marginal ~10 polls utiles par escalation, **mais coût nominal réel de ~1 440 démarrages PowerShell / 24 h / machine** (15× les 96 de base) — chaque démarrage paie l'init PowerShell même s'il sort aussitôt. **Pas nul en régime nominal.**
  - **(b) Armement dynamique du trigger rapide** : le trigger 1 min n'existe qu'armé par le body à l'escalation (`Enable-ScheduledTask`), désarmé à la sortie de fenêtre — coût nominal réellement **nul** (+~10 polls par escalation), au prix d'une dépendance de fiabilité à l'activation/désactivation du trigger par le script.
  - Recommandation : **(b)** pour PR-B ; le choix d'implémentation reste à PR-B, mais le coût affiché ici est celui de chaque option — ce proposal ne présuppose pas un « coût nul » que seul (b) délivre.
- **Implémentation** : le watchdog expose un état `fast_poll_until` ; selon l'option retenue en PR-B, soit deux triggers (15 min + 1 min) avec sortie précoce hors fenêtre, soit un trigger rapide armé/désarmé dynamiquement.

## 5. Sur la cause racine #2875 (livrable 3)

État actuel : **CLOSED via le watchdog #2933 ; le caractère permanent du contournement reste
l'objet de l'arbitrage §7** (l'issue #2875 est CLOSED/COMPLETED sans décision documentée de
permanence). L'investigation de la cause racine (`OOM kill silencieux`, conflit d'indexation,
flakiness Drive File Stream v127) est **marquée inconclusive** par l'issue #2875 elle-même.

Proposition **soumise à l'arbitrage §7** : le cas échéant, documenter le contournement comme
permanent dans le `README.md` du watchdog (statut passé de « interim fix » à « production
control »), et acter en ce sens dans une note `decision-history.md` (ou équivalent). Aucune
investigation supplémentaire n'est entreprise tant qu'un signal discriminant n'est pas remonté
(un crash loggué, un comportement reproductible).

## 6. Sur le registre de verrous hors GDrive (livrable 4)

**Dépend explicitement de #3676 (candidat #3)** — le tie-break `claim-issue > claim-dashboard`
doit être tranché et l'organe `check_lane_claim.py` (l'équivalent roo-extensions) doit être
livré avant que ce livrable puisse être actionné. Pas d'action ici tant que #3676 n'a pas
atterri.

---

## 7. Ce qui reste à arbitrer avant implémentation

| Question | Choix par défaut proposé | Arbitrage requis |
|---|---|---|
| Quel canal pour la couche 2 ? | GitHub Issue (label `gdrivefs-watchdog-alert`) | user/coordinateur |
| Cadence du poll rapide ? | 1 min × 10 min après escalation | user/coordinateur |
| Cooldown entre issues GitHub ? | 6 h par machine | user/coordinateur |
| Acter le contournement #2875 comme permanent ? | OUI, documenter | user/coordinateur (validation user-only, règle issue-closure) |
| Implémenter la couche 3 (heartbeat croisé) ? | NON dans cette PR — post-MVP | user/coordinateur |

---

## 8. PR(s) envisageables après arbitrage

Une fois les questions tranchées, deux PRs bornées :

**PR-A — `feat(watchdog): GitHub-issue alert on cooldown escalation`**
- Ajoute au body : une fonction `Send-GitHubAlert` qui crée une issue via `gh` (label `gdrivefs-watchdog-alert`, titre formaté, body horodaté) **uniquement** quand C2 escalade OU cooldown-skip N fois.
- Garde `last_github_alert_at` dans `watchdog-state.json` ; plafond 6 h entre issues.
- Tests : `test-gdrivefs-watchdog.ps1` étendu pour simuler l'escalation et vérifier l'appel (avec un wrapper mockable).
- Aucune modification du chemin `Write-EventLog` ni `Write-Log` (ils restent).

**PR-B — `feat(watchdog): fast-poll on escalation`**
- Ajoute `fast_poll_until` à l'état.
- `install-gdrivefs-watchdog-schtask.ps1` ajoute un second trigger `1 min repeat`, le body sort tôt si on n'est pas en fenêtre rapide.
- Tests : vérifie le compteur `fast_poll_count`, l'auto-arm et l'auto-clear.

PR-A et PR-B sont **indépendantes** et peuvent atterrir dans n'importe quel ordre. PR-A est
prioritaire (canal d'alerte = le livrable principal de l'issue).

---

## 9. Non-buts réaffirmés

- **Pas de second canal de coordination complet.** Dashboard reste le canal de narration.
- **Pas de heartbeat croisé inter-machines dans cette PR.** C'est une refonte du listener fleet (post-MVP).
- **Pas de fix #2875 root cause.** Acter le contournement comme permanent.

---

🤖 claude-interactive · myia-web1 · Epic #3111 phase 2, candidat #8
