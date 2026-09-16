# Plans / Progress — Schéma et discipline

**Version :** 1.0.0 (initial, #3674 / ADR 015)
**Statut :** Convention acceptée, application **optionnelle** (cf. règle d'usage).
**Référence :** [`docs/harness/adr/015-plans-progress-convergence-coursia.md`](../adr/015-plans-progress-convergence-coursia.md)

> **TL;DR.** Pour un chantier long (>1 session, reprise après restart, multi-agents), crée
> `.claude/plans/<id>.md` (phases + checklists + journal) et `.claude/progress/<id>.json`
> (items + status + checkpoints, **machine-readable** pour la reprise). Pour le reste, ne
> fais rien — Project #67 + issue + branche suffisent.

---

## Quand les utiliser

Les trois critères (au moins **un**) justifient plans + progress. Hors de ces trois cas,
n'en crée pas.

1. **Durée inter-sessions** — le chantier survit à un redémarrage de session
   (cron qui reprend, worker redémarré, machine ré-armée).
2. **Reprise automatique** — un script/agent doit pouvoir **reprendre là où il s'est
   arrêté** sans intervention humaine.
3. **Multi-agents coordonnés** — plusieurs agents partagent un état structuré au-delà de
   ce que portent les messages dashboard.

## Nommage

- **`<chantier-id>`** en kebab-case.
- Préfère un identifiant d'Epic (`3111`) ou d'issue majeure (`3674-plans-progress`).
- Plusieurs chantiers par Epic sont permis si l'Epic a des phases distinctes ; un seul
  par chantier autonome.
- Les fichiers vont par paire : `<id>.md` (plan) et `<id>.json` (progress), même `id`.

## Emplacement

| Fichier | Chemin |
|---|---|
| Plan lisible humainement | `.claude/plans/<id>.md` |
| État machine-readable | `.claude/progress/<id>.json` |

Les deux répertoires sont **dans le repo** par défaut (versionnés). Un chantier archivé
peut être gitignored ou supprimé (cf. ADR 015 §Décision).

---

## `progress.json` — schéma

Le fichier est lisible par un humain, écrit par un agent, parsé par un outil de reprise.
Toutes les écritures sont **atomiques** (write `.tmp` puis `replace()`).

```json
{
  "$schema": "TODO — pointer vers un JSON Schema si on en pose un",
  "chantier_id": "3111",
  "epic_or_issue": "https://github.com/jsboige/roo-extensions/issues/3111",
  "owner_machine": "myia-ai-01",
  "created_at": "2026-09-16T02:30:00Z",
  "updated_at": "2026-09-16T02:30:00Z",
  "completed_at": null,
  "config": {
    "resume": true,
    "parallel": 1,
    "quality_target": null,
    "max_iterations": null
  },
  "items": {
    "<item_id>": {
      "status": "pending",
      "title": "<titre humain>",
      "path": "<chemin PR/issue/branche>",
      "started_at": null,
      "completed_at": null,
      "metric_before": null,
      "metric_after": null,
      "notes": ""
    }
  },
  "statistics": {
    "total": 0,
    "completed": 0,
    "in_progress": 0,
    "pending": 0,
    "failed": 0,
    "skipped": 0
  },
  "checkpoints": [
    {
      "timestamp": "2026-09-16T02:30:00Z",
      "item_id": "<item_id>",
      "action": "started|completed|failed|resumed",
      "actor": "myia-web1:claude-interactive",
      "note": ""
    }
  ]
}
```

### Champs imposés

| Champ | Type | Règle |
|---|---|---|
| `chantier_id` | string | Identifiant kebab-case, identique au nom de fichier (sans extension). |
| `epic_or_issue` | URL ou n° | Lien canonique (GitHub). Pour un chantier hors-Project, n° d'issue. |
| `owner_machine` | string | Machine initiatrice du chantier (coordinateur pour un Epic). |
| `created_at` / `updated_at` / `completed_at` | ISO 8601 UTC | `completed_at` non-null **seulement** quand `statistics.failed == 0` et `statistics.completed == statistics.total`. |
| `config.resume` | bool | `true` par défaut — un agent qui démarre et voit ce fichier doit demander à reprendre. |
| `items.<id>.status` | enum | `pending` \| `in_progress` \| `completed` \| `failed` \| `skipped`. |
| `items.<id>.completed_at` | ISO 8601 UTC | Obligatoire si et seulement si `status == "completed"`. C'est le garde anti-mensonge : un `completed` sans `completed_at` est un bug de l'agent qui a écrit. |
| `items.<id>.metric_before` / `metric_after` | number \| null | Pour les chantiers à métrique (ratio, coverage, etc.). Le `metric_after` est la **valeur mesurée** au moment du `completed`, pas une promesse. |
| `statistics` | object | Recomputé à chaque écriture. Ne pas écrire à la main. |
| `checkpoints[].timestamp` | ISO 8601 UTC | Append-only. Ne jamais éditer un checkpoint passé. |

### Garde-fous « ne pas mentir »

1. **`status: "completed"` exige `completed_at` et `metric_after`** (si le chantier est
   à métrique). L'absence de l'un des deux = l'item n'est pas vraiment terminé.
2. **`status: "in_progress"` exige `started_at`**. Un item `in_progress` sans
   `started_at` = un item dont l'agent a oublié comment il a commencé.
3. **`statistics` est recomputé** à chaque écriture, jamais posé à la main. Si le champ
   ne colle pas avec `items.*`, c'est que le fichier est dans un état inconsistant —
   ne pas écrire par-dessus en aveugle, ouvrir une passe de réparation.
4. **Le `checkpoints[]` est append-only**. Un checkpoint existant ne se modifie jamais
   (c'est le journal). Pour « corriger » un événement, on ajoute un checkpoint ultérieur
   qui le nuance.
5. **Les écritures sont atomiques** : écrire `.tmp` puis `os.replace()`. Pas
   d'écritures concurrentes (le `config.parallel` documente les sessions parallèles).

### Reprise après redémarrage

Le protocole **reprise** d'un agent qui trouve un `progress.json` existant :

1. Charger le fichier, valider le schéma (manuellement ou via un futur validateur).
2. Calculer `statistics` à partir de `items.*` (ne pas faire confiance au champ stocké).
3. Pour chaque item `in_progress` au moment de l'arrêt : **reprendre depuis le début**
   (safer — un crash a peut-être laissé l'item dans un état partiel). Ajouter un
   checkpoint `resumed`.
4. Présenter à l'utilisateur (ou au coordinateur) : « Chantier existant détecté, X/Y
   terminés, Z en cours. Reprendre ? [O/n] » — sauf si `config.resume == true` et la
   session est de même owner_machine, auquel cas reprise silencieuse et log checkpoint.
5. Itérer les items `pending` / `in_progress` selon `config.parallel`.

---

## `plans.md` — structure

Le plan est **une fois** par chantier, mis à jour **au rythme des jalons** (pas à
chaque item). Sa fonction est de garder la trace lisible de l'intention et de
l'avancement macroscopique.

### Sections imposées

```markdown
# <Titre du chantier>

**ID :** `<chantier-id>` (identique au fichier progress.json)
**Epic/Issue :** <lien>
**Owner :** <machine>
**Démarré :** <YYYY-MM-DD>
**Cible :** <objectif humain, une phrase>

## Vue d'ensemble

<description courte du chantier — ce qu'on cherche à obtenir, pas la liste des tâches>

## Phases

### Phase 1 — <titre>
**Statut :** ⬜ Non démarré / 🟡 En cours / ✅ Terminé
**Livrables :**
- [ ] <item_1>
- [ ] <item_2>

### Phase 2 — <titre>
…

## Légende des statuts

⬜ Non démarré / 🟡 En cours / ✅ Terminé / ⚠️ Bloqué / ❌ Échoué / ⏭️ Skippé

## Journal des sessions

### Session <N> — <YYYY-MM-DD>
**Objectif :** …
**Actions :** …
**Résultats :** …
**Problèmes :** …
**Prochaines étapes :** …
```

### Sections facultatives (selon le chantier)

- **Statistiques agrégées** — un tableau récapitulatif si le chantier a beaucoup
  d'items ; sinon le `progress.json` suffit.
- **Décisions architecturales** — si le chantier implique des choix qui méritent un
  ADR ou une note. Pointer vers le fichier.
- **Risques et dépendances** — externes (autres PRs, autres Epics).

### Discipline

1. **Mise à jour macroscopique** — pas à chaque item. Un « ✅ Phase 2 terminée » peut
   rester tel quel pendant 3 jours si les items ne sont pas finis ; il devient
   `🟡 En cours` au premier item terminé.
2. **Append-only sur le journal des sessions** — chaque session ajoute une entrée,
   n'édite jamais une entrée précédente (c'est la trace historique).
3. **Statut légende cohérent avec progress.json** — si `progress.json` dit `failed`,
   le plan le dit aussi (`❌` ou `⚠️ Bloqué`). Un écart = signal de désynchronisation.

---

## Cross-références

- **Project #67** : l'inventaire. Le plan ne crée pas d'issues par item ; il pointe
  vers celles qui existent.
- **Open-questions (#3656)** : registre séparé, même cible (continuité inter-sessions),
  autre contenu (questions user en attente). Le plan peut **référencer** des
  questions ouvertes (champ « Prochaines étapes » → lien vers le registre), mais ne les
  **porte pas**.
- **Dashboard `[PROGRESS]`** : un événement `[PROGRESS]` est posté quand un jalon
  macroscopique est franchi (phase terminée, Epic fermé, etc.). Pas à chaque item —
  le bruit tuera le signal.

## Anti-patterns

- **Écrire `status: "completed"` sans `metric_after`** — c'est un mensonge, le garde
  le détecte.
- **Éditer un `checkpoints[]` existant** — c'est de la falsification de journal.
- **Un plan par item** — un plan par **chantier**, pas par item. Le progress.json
  porte les items.
- **Un progress.json par PR** — pour une PR isolée, l'issue suffit. Le progress.json
  est pour les chantiers longs (≥1 session, multi-items).
- **Écriture automatique par hook** — aucune écriture silencieuse. L'agent qui
  accomplit un jalon écrit ; personne d'autre.
