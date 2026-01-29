# CONS-1 : Analyse Consolidation Outils Messagerie RooSync

**Version :** 1.0.0
**Date :** 2026-01-29
**Auteur :** Claude Code (myia-po-2023)
**Statut :** 📝 PROPOSITION - En attente validation coordinateur

---

## 📊 État Actuel : 7 Outils de Messagerie

### Inventaire Complet

| # | Outil | Fichier | Fonction | LOC |
|---|-------|---------|----------|-----|
| 1 | `roosync_send_message` | `send_message.ts` | Envoyer un message | 151 |
| 2 | `roosync_read_inbox` | `read_inbox.ts` | Lire boîte de réception | 198 |
| 3 | `roosync_reply_message` | `reply_message.ts` | Répondre à un message | 226 |
| 4 | `roosync_get_message` | `get_message.ts` | Obtenir détails complets | 212 |
| 5 | `roosync_mark_message_read` | `mark_message_read.ts` | Marquer comme lu | 158 |
| 6 | `roosync_archive_message` | `archive_message.ts` | Archiver un message | 175 |
| 7 | `roosync_amend_message` | `amend_message.ts` | Modifier message non-lu | 164 |

**Total :** 1284 LOC (lignes de code)

### Analyse des Dépendances

Tous les outils partagent :
- `MessageManager` service central
- `getSharedStatePath()` pour le chemin
- Pattern similaire de validation/formatage
- Fonctions utilitaires dupliquées (`formatDate`, `getPriorityIcon`, `getStatusIcon`)

### Code Dupliqué Identifié

```
formatDate()       → dupliqué dans 5 fichiers
getPriorityIcon()  → dupliqué dans 4 fichiers
getStatusIcon()    → dupliqué dans 3 fichiers
getLocalMachineId() → dupliqué dans 4 fichiers
```

---

## 🎯 Proposition : 3 Outils Consolidés

### Architecture Proposée

```
┌─────────────────────────────────────────────────────────────┐
│                    AVANT (7 outils)                          │
├─────────────────────────────────────────────────────────────┤
│ send_message │ reply_message │ amend_message                │
│ read_inbox   │ get_message   │                              │
│ mark_read    │ archive       │                              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    APRÈS (3 outils)                          │
├─────────────────────────────────────────────────────────────┤
│     roosync_send     │    roosync_read    │  roosync_manage │
│  (send+reply+amend)  │  (inbox+get)       │  (mark+archive) │
└─────────────────────────────────────────────────────────────┘
```

### Outil 1 : `roosync_send` (Envoi)

**Fusionne :** `send_message` + `reply_message` + `amend_message`

```typescript
interface RooSyncSendArgs {
  // Mode opération
  action: 'send' | 'reply' | 'amend';

  // Pour send
  to?: string;
  subject?: string;
  body: string;
  priority?: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT';
  tags?: string[];

  // Pour reply
  message_id?: string;  // ID du message auquel répondre

  // Pour amend
  new_content?: string;
  reason?: string;
}
```

**Exemples d'utilisation :**
```typescript
// Envoyer
roosync_send({ action: 'send', to: 'myia-ai-01', subject: '...', body: '...' })

// Répondre
roosync_send({ action: 'reply', message_id: 'msg-xxx', body: '...' })

// Amender
roosync_send({ action: 'amend', message_id: 'msg-xxx', new_content: '...' })
```

### Outil 2 : `roosync_read` (Lecture)

**Fusionne :** `read_inbox` + `get_message`

```typescript
interface RooSyncReadArgs {
  // Mode opération
  mode: 'inbox' | 'message';

  // Pour inbox
  status?: 'unread' | 'read' | 'all';
  limit?: number;

  // Pour message
  message_id?: string;
  mark_as_read?: boolean;
}
```

**Exemples d'utilisation :**
```typescript
// Lire inbox
roosync_read({ mode: 'inbox', status: 'unread' })

// Lire un message
roosync_read({ mode: 'message', message_id: 'msg-xxx', mark_as_read: true })
```

### Outil 3 : `roosync_manage` (Gestion)

**Fusionne :** `mark_message_read` + `archive_message`

```typescript
interface RooSyncManageArgs {
  // Action
  action: 'mark_read' | 'archive' | 'delete';

  // Cible(s)
  message_id: string;
  // OU
  message_ids?: string[];  // Pour batch operations
}
```

**Exemples d'utilisation :**
```typescript
// Marquer comme lu
roosync_manage({ action: 'mark_read', message_id: 'msg-xxx' })

// Archiver
roosync_manage({ action: 'archive', message_id: 'msg-xxx' })

// Batch archive
roosync_manage({ action: 'archive', message_ids: ['msg-1', 'msg-2'] })
```

---

## 📈 Bénéfices Attendus

### Réduction de Complexité

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| Nombre d'outils | 7 | 3 | **-57%** |
| LOC total estimé | 1284 | ~600 | **-53%** |
| Fonctions utilitaires dupliquées | 16 | 4 | **-75%** |
| Fichiers à maintenir | 7 | 3 | **-57%** |

### Amélioration UX

1. **Moins d'outils à mémoriser** : 3 vs 7
2. **Découvrabilité** : Actions groupées logiquement
3. **Cohérence** : Pattern `action` uniforme
4. **Batch operations** : Nouveau (gestion multiple)

### Maintenabilité

1. **Moins de duplication** : Utils centralisées
2. **Tests simplifiés** : 3 suites vs 7
3. **Évolution facilitée** : Ajouter actions sans nouveaux outils

---

## ⚠️ Risques et Mitigation

### Risque 1 : Rétrocompatibilité

**Impact :** Les scripts/agents existants utilisent les anciens noms d'outils.

**Mitigation :**
- Maintenir les anciens outils comme alias (wrappers)
- Documentation de migration claire
- Période de dépréciation (2-4 semaines)

### Risque 2 : Complexité des Schémas

**Impact :** Les schémas Zod deviennent plus complexes (unions).

**Mitigation :**
- Validation contextuelle (selon `action`)
- Messages d'erreur explicites
- Exemples dans la doc

### Risque 3 : Logs et Debug

**Impact :** Plus difficile de tracer une opération spécifique.

**Mitigation :**
- Logger le `action` dans chaque opération
- Préfixer les logs par action

---

## 📋 Plan de Migration

### Phase 1 : Préparation (2-3 jours)

1. Créer fichier `utils/message-helpers.ts` pour utilitaires partagés
2. Écrire les 3 nouveaux outils
3. Tests unitaires complets

### Phase 2 : Déploiement (1 jour)

1. Déployer nouveaux outils
2. Ajouter au registry
3. Mettre à jour le wrapper MCP

### Phase 3 : Migration (1 semaine)

1. Créer wrappers de compatibilité (anciens noms → nouveaux)
2. Marquer anciens outils comme `@deprecated`
3. Mettre à jour documentation

### Phase 4 : Nettoyage (après 2 semaines)

1. Supprimer les wrappers de compatibilité
2. Supprimer les anciens fichiers
3. Finaliser documentation

---

## 🗳️ Décision Requise

### Option A : Consolidation Complète (Recommandé)

Implémenter les 3 outils comme décrit ci-dessus.

**Avantages :** Gains maximaux, architecture propre
**Inconvénients :** Effort de migration plus important

### Option B : Consolidation Partielle

Garder `read_inbox` et `get_message` séparés, consolider le reste.

**Avantages :** Migration plus simple
**Inconvénients :** Bénéfices réduits (5 outils au lieu de 3)

### Option C : Reporter

Attendre stabilisation complète avant consolidation.

**Avantages :** Pas de risque immédiat
**Inconvénients :** Dette technique accumulée

---

## 📎 Annexes

### A. Matrice de Correspondance

| Ancien Outil | Nouvel Outil | Action |
|--------------|--------------|--------|
| `roosync_send_message` | `roosync_send` | `action: 'send'` |
| `roosync_reply_message` | `roosync_send` | `action: 'reply'` |
| `roosync_amend_message` | `roosync_send` | `action: 'amend'` |
| `roosync_read_inbox` | `roosync_read` | `mode: 'inbox'` |
| `roosync_get_message` | `roosync_read` | `mode: 'message'` |
| `roosync_mark_message_read` | `roosync_manage` | `action: 'mark_read'` |
| `roosync_archive_message` | `roosync_manage` | `action: 'archive'` |

### B. Fichiers Concernés

```
mcps/internal/servers/roo-state-manager/src/tools/roosync/
├── send_message.ts      → À remplacer par send.ts
├── reply_message.ts     → À supprimer
├── amend_message.ts     → À supprimer
├── read_inbox.ts        → À remplacer par read.ts
├── get_message.ts       → À supprimer
├── mark_message_read.ts → À remplacer par manage.ts
├── archive_message.ts   → À supprimer
└── index.ts             → À mettre à jour
```

---

**En attente de validation du coordinateur (myia-ai-01) avant implémentation.**
