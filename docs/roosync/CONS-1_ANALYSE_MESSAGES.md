# CONS-1 : Analyse Préparatoire - Outils Messages (7→3)

**Date:** 2026-01-19
**Auteur:** roo
**Tâche:** CONS-1 - Consolidation des outils Messages
**Objectif:** Réduire de 7 à 3 le nombre d'outils Messages

---

## 1. Liste des 7 Outils Messages Actuels

### 1.1 `send_message.ts`
**Description:** Envoie un message structuré à une autre machine via RooSync

**Paramètres:**
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `to` | string | ✅ | ID de la machine destinataire (ex: myia-ai-01) |
| `subject` | string | ✅ | Sujet du message |
| `body` | string | ✅ | Corps du message (markdown supporté) |
| `priority` | enum | ❌ | Priorité (LOW, MEDIUM, HIGH, URGENT) - défaut: MEDIUM |
| `tags` | string[] | ❌ | Tags optionnels pour catégoriser le message |
| `thread_id` | string | ❌ | ID du thread pour regrouper les messages |
| `reply_to` | string | ❌ | ID du message auquel on répond |

**Dépendances:**
- `MessageManager` (service)
- `getSharedStatePath()` (utilitaire)
- `createLogger()` (utilitaire)
- `MessageManagerError`, `MessageManagerErrorCode` (types)
- `getLocalMachineId()` (fonction locale)

---

### 1.2 `reply_message.ts`
**Description:** Répond à un message existant en créant un nouveau message lié

**Paramètres:**
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `message_id` | string | ✅ | ID du message auquel répondre |
| `body` | string | ✅ | Corps de la réponse |
| `priority` | enum | ❌ | Priorité de la réponse - défaut: priorité du message original |
| `tags` | string[] | ❌ | Tags supplémentaires - le tag "reply" est ajouté automatiquement |

**Dépendances:**
- `MessageManager` (service)
- `getSharedStatePath()` (utilitaire)
- `createLogger()` (utilitaire)
- `MessageManagerError`, `MessageManagerErrorCode` (types)
- `formatDate()` (fonction locale)
- `getPriorityIcon()` (fonction locale)

**Logique spécifique:**
- Inversion from/to pour la réponse
- Préfixe "Re: " ajouté au sujet si absent
- Thread ID hérité ou créé avec l'ID original
- Tag "reply" ajouté automatiquement

---

### 1.3 `amend_message.ts`
**Description:** Modifie le contenu d'un message envoyé avant qu'il ne soit lu

**Paramètres:**
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `message_id` | string | ✅ | ID du message à modifier |
| `new_content` | string | ✅ | Nouveau contenu du message (remplace l'original) |
| `reason` | string | ❌ | Raison de l'amendement (pour traçabilité) |

**Dépendances:**
- `MessageManager` (service)
- `getSharedStatePath()` (utilitaire)
- `createLogger()` (utilitaire)
- `StateManagerError` (types)
- `getLocalMachineId()` (fonction locale)

**Contraintes:**
- ❌ Impossible d'amender un message déjà lu
- ❌ Impossible d'amender un message archivé
- ✅ Seul l'émetteur peut amender ses messages
- ✅ Amendements multiples possibles (original toujours préservé)

---

### 1.4 `read_inbox.ts`
**Description:** Lit la boîte de réception des messages RooSync

**Paramètres:**
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `status` | enum | ❌ | Filtrer par status (unread, read, all) - défaut: all |
| `limit` | number | ❌ | Nombre maximum de messages à retourner |

**Dépendances:**
- `MessageManager` (service)
- `getSharedStatePath()` (utilitaire)
- `createLogger()` (utilitaire)
- `getLocalMachineId()` (fonction locale)
- `formatDate()` (fonction locale)
- `getPriorityIcon()` (fonction locale)
- `getStatusIcon()` (fonction locale)

**Sortie:** Tableau markdown avec colonnes: ID, De, Sujet, Priorité, Status, Date

---

### 1.5 `get_message.ts`
**Description:** Obtient les détails complets d'un message spécifique

**Paramètres:**
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `message_id` | string | ✅ | ID du message à récupérer |
| `mark_as_read` | boolean | ❌ | Marquer automatiquement comme lu - défaut: false |

**Dépendances:**
- `MessageManager` (service)
- `getSharedStatePath()` (utilitaire)
- `createLogger()` (utilitaire)
- `MessageManagerError`, `MessageManagerErrorCode` (types)
- `formatDate()` (fonction locale)
- `getPriorityIcon()` (fonction locale)
- `getStatusIcon()` (fonction locale)

**Recherche:** Cherche dans inbox/, sent/, puis archive/

---

### 1.6 `mark_message_read.ts`
**Description:** Marque un message comme lu en mettant à jour son statut

**Paramètres:**
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `message_id` | string | ✅ | ID du message à marquer comme lu |

**Dépendances:**
- `MessageManager` (service)
- `getSharedStatePath()` (utilitaire)
- `createLogger()` (utilitaire)
- `MessageManagerError`, `MessageManagerErrorCode` (types)
- `formatDate()` (fonction locale)

**Comportement:**
- Retourne un message d'info si déjà lu
- Met à jour inbox/ et sent/ si le message existe dans les deux

---

### 1.7 `archive_message.ts`
**Description:** Archive un message en le déplaçant de inbox/ vers archive/

**Paramètres:**
| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `message_id` | string | ✅ | ID du message à archiver |

**Dépendances:**
- `MessageManager` (service)
- `getSharedStatePath()` (utilitaire)
- `createLogger()` (utilitaire)
- `MessageManagerError`, `MessageManagerErrorCode` (types)
- `formatDate()` (fonction locale)

**Comportement:**
- Retourne un message d'info si déjà archivé
- Déplace le fichier de inbox/ vers archive/
- Met à jour sent/ si le message existe dans les deux

---

## 2. Dépendances Communes

### 2.1 Services Partagés

| Service | Utilisation | Outils concernés |
|---------|-------------|------------------|
| `MessageManager` | Service principal de messagerie | Tous (7/7) |
| `getSharedStatePath()` | Chemin vers .shared-state | Tous (7/7) |
| `createLogger()` | Logging | Tous (7/7) |

### 2.2 Types d'Erreurs

| Type | Utilisation | Outils concernés |
|------|-------------|------------------|
| `MessageManagerError` | Erreurs de messagerie | send_message, reply_message, get_message, mark_message_read, archive_message |
| `MessageManagerErrorCode` | Codes d'erreur | send_message, reply_message, get_message, mark_message_read, archive_message |
| `StateManagerError` | Erreurs générales | amend_message |

### 2.3 Fonctions Utilitaires Dupliquées

| Fonction | Description | Outils concernés | Duplication |
|----------|-------------|------------------|-------------|
| `formatDate()` | Formatte la date en français | reply_message, read_inbox, get_message, mark_message_read, archive_message | 5x |
| `getPriorityIcon()` | Emoji de priorité | reply_message, read_inbox, get_message | 3x |
| `getStatusIcon()` | Emoji de statut | read_inbox, get_message | 2x |
| `getLocalMachineId()` | ID machine locale | send_message, read_inbox, amend_message | 3x |

---

## 3. Tests Existants

### 3.1 Résultat de la recherche

**Recherche effectuée:** `tests/**/*.test.ts` avec pattern `(send_message|reply_message|amend_message|read_inbox|get_message|mark_message_read|archive_message)`

**Résultat:** **0 tests trouvés**

### 3.2 Analyse

- **Aucun test unitaire** pour les outils Messages
- **Aucun test d'intégration** pour les outils Messages
- **Risque élevé** de régression lors de la consolidation

### 3.3 Recommandation

Créer une suite de tests complète avant la consolidation :
- Tests unitaires pour chaque outil
- Tests d'intégration pour les workflows (envoi → lecture → réponse → archivage)
- Tests de validation des paramètres
- Tests de gestion des erreurs

---

## 4. Proposition Structure Consolidée `roosync_messages.ts`

### 4.1 Architecture Proposée

Regrouper les 7 outils en **3 outils consolidés** :

| Catégorie | Outils actuels | Outil consolidé |
|-----------|----------------|-----------------|
| **Écriture** | send_message, reply_message, amend_message | `roosync_send_message` |
| **Lecture** | read_inbox, get_message | `roosync_read_messages` |
| **Gestion** | mark_message_read, archive_message | `roosync_manage_message` |

### 4.2 Structure du Fichier Consolidé

```typescript
/**
 * Outil MCP consolidé : roosync_messages
 * 
 * Regroupe les 7 outils Messages en 3 outils consolidés :
 * - send_message : Envoi, réponse, amendement
 * - read_messages : Lecture inbox, récupération message
 * - manage_message : Marquer comme lu, archiver
 * 
 * @module roosync/roosync_messages
 */

import { MessageManager } from '../../services/MessageManager.js';
import { getSharedStatePath } from '../../utils/server-helpers.js';
import { createLogger, Logger } from '../../utils/logger.js';
import { MessageManagerError, MessageManagerErrorCode } from '../../types/errors.js';
import os from 'os';

// ============================================================================
// UTILITAIRES PARTAGÉS (factorisés)
// ============================================================================

const logger: Logger = createLogger('RooSyncMessagesTool');

function getLocalMachineId(): string {
  return os.hostname().toLowerCase().replace(/[^a-z0-9-]/g, '-');
}

function formatDate(isoDate: string): string {
  const date = new Date(isoDate);
  return date.toLocaleString('fr-FR', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
}

function getPriorityIcon(priority: string): string {
  switch (priority) {
    case 'URGENT': return '🔥';
    case 'HIGH': return '⚠️';
    case 'MEDIUM': return '📝';
    case 'LOW': return '📋';
    default: return '📝';
  }
}

function getStatusIcon(status: string): string {
  switch (status) {
    case 'unread': return '🆕';
    case 'read': return '✅';
    case 'archived': return '📦';
    default: return '📧';
  }
}

// ============================================================================
// OUTIL 1 : roosync_send_message (Écriture)
// ============================================================================

interface SendMessageArgs {
  action: 'send' | 'reply' | 'amend';
  to?: string;
  subject?: string;
  body?: string;
  priority?: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT';
  tags?: string[];
  thread_id?: string;
  reply_to?: string;
  message_id?: string;
  new_content?: string;
  reason?: string;
}

export async function sendMessage(
  args: SendMessageArgs
): Promise<{ content: Array<{ type: string; text: string }> }> {
  const { action } = args;

  switch (action) {
    case 'send':
      return await sendNewMessage(args);
    case 'reply':
      return await replyToMessage(args);
    case 'amend':
      return await amendExistingMessage(args);
    default:
      throw new MessageManagerError(
        `Action invalide: ${action}. Actions valides: send, reply, amend`,
        MessageManagerErrorCode.INVALID_MESSAGE_FORMAT,
        { action, validActions: ['send', 'reply', 'amend'] }
      );
  }
}

// ... implémentation des 3 sous-fonctions ...

// ============================================================================
// OUTIL 2 : roosync_read_messages (Lecture)
// ============================================================================

interface ReadMessagesArgs {
  action: 'inbox' | 'get';
  message_id?: string;
  status?: 'unread' | 'read' | 'all';
  limit?: number;
  mark_as_read?: boolean;
}

export async function readMessages(
  args: ReadMessagesArgs
): Promise<{ content: Array<{ type: string; text: string }> }> {
  const { action } = args;

  switch (action) {
    case 'inbox':
      return await readInbox(args);
    case 'get':
      return await getMessage(args);
    default:
      throw new MessageManagerError(
        `Action invalide: ${action}. Actions valides: inbox, get`,
        MessageManagerErrorCode.INVALID_MESSAGE_FORMAT,
        { action, validActions: ['inbox', 'get'] }
      );
  }
}

// ... implémentation des 2 sous-fonctions ...

// ============================================================================
// OUTIL 3 : roosync_manage_message (Gestion)
// ============================================================================

interface ManageMessageArgs {
  action: 'mark_read' | 'archive';
  message_id: string;
}

export async function manageMessage(
  args: ManageMessageArgs
): Promise<{ content: Array<{ type: string; text: string }> }> {
  const { action } = args;

  switch (action) {
    case 'mark_read':
      return await markMessageAsRead(args);
    case 'archive':
      return await archiveMessage(args);
    default:
      throw new MessageManagerError(
        `Action invalide: ${action}. Actions valides: mark_read, archive`,
        MessageManagerErrorCode.INVALID_MESSAGE_FORMAT,
        { action, validActions: ['mark_read', 'archive'] }
      );
  }
}

// ... implémentation des 2 sous-fonctions ...
```

### 4.3 Avantages de la Consolidation

| Aspect | Avant (7 fichiers) | Après (1 fichier) |
|--------|---------------------|-------------------|
| **Nombre de fichiers** | 7 | 1 |
| **Lignes de code** | ~1000 | ~800 (-20%) |
| **Duplication de code** | Élevée (5x formatDate, 3x getPriorityIcon, etc.) | Nulle (factorisée) |
| **Maintenance** | 7 fichiers à modifier | 1 fichier à modifier |
| **Tests** | 0 tests | Facile à tester (1 fichier) |
| **Documentation** | 7 fichiers à documenter | 1 fichier à documenter |
| **Complexité** | 7 exports MCP | 3 exports MCP |

---

## 5. Risques et Défis Identifiés

### 5.1 Risques Techniques

| Risque | Sévérité | Probabilité | Mitigation |
|--------|-----------|-------------|------------|
| **Régression fonctionnelle** | Élevée | Moyenne | Créer une suite de tests complète avant consolidation |
| **Breaking change pour les utilisateurs** | Élevée | Haute | Maintenir la compatibilité avec les anciens noms d'outils (aliases) |
| **Perte de flexibilité** | Moyenne | Faible | Conserver les paramètres optionnels existants |
| **Complexité accrue du fichier consolidé** | Moyenne | Moyenne | Documenter clairement la structure et les actions |

### 5.2 Défis d'Implémentation

| Défi | Description | Solution proposée |
|------|-------------|-------------------|
| **Gestion des erreurs** | Chaque outil a sa propre logique d'erreur | Factoriser la gestion des erreurs dans des fonctions utilitaires |
| **Validation des paramètres** | Duplication de la logique de validation | Créer une fonction de validation générique |
| **Formatage des réponses** | Chaque outil formate sa réponse différemment | Standardiser le formatage avec des templates |
| **Tests** | Aucun test existant | Créer une suite de tests complète (unitaires + intégration) |

### 5.3 Risques de Migration

| Risque | Description | Mitigation |
|--------|-------------|------------|
| **Perte de messages** | Migration des fichiers de messages | Sauvegarder les messages avant migration |
| **Incompatibilité avec les clients existants** | Changement des noms d'outils | Maintenir les anciens noms comme aliases |
| **Rétrogradation impossible** | Pas de rollback facile | Conserver les anciens fichiers dans une branche de backup |

---

## 6. Recommandations

### 6.1 Avant la Consolidation

1. **Créer une suite de tests complète**
   - Tests unitaires pour chaque outil
   - Tests d'intégration pour les workflows
   - Tests de validation des paramètres
   - Tests de gestion des erreurs

2. **Sauvegarder les messages existants**
   - Copier le répertoire `messages/` vers un backup
   - Vérifier l'intégrité des messages

3. **Documenter les cas d'utilisation**
   - Identifier tous les workflows possibles
   - Documenter les edge cases

### 6.2 Pendant la Consolidation

1. **Factoriser le code dupliqué**
   - Créer des fonctions utilitaires partagées
   - Standardiser la gestion des erreurs

2. **Maintenir la compatibilité**
   - Conserver les anciens noms d'outils comme aliases
   - Documenter les changements

3. **Tester continuellement**
   - Exécuter les tests après chaque modification
   - Vérifier que tous les workflows fonctionnent

### 6.3 Après la Consolidation

1. **Mettre à jour la documentation**
   - Mettre à jour les README
   - Mettre à jour les exemples d'utilisation

2. **Former les utilisateurs**
   - Expliquer les changements
   - Fournir des exemples de migration

3. **Surveiller les erreurs**
   - Vérifier les logs
   - Corriger les bugs rapidement

---

## 7. Plan d'Action Proposé

### Phase 1 : Préparation (1-2 jours)
- [ ] Créer une suite de tests complète
- [ ] Sauvegarder les messages existants
- [ ] Documenter les cas d'utilisation

### Phase 2 : Consolidation (2-3 jours)
- [ ] Créer le fichier `roosync_messages.ts`
- [ ] Factoriser le code dupliqué
- [ ] Implémenter les 3 outils consolidés
- [ ] Tester tous les workflows

### Phase 3 : Migration (1 jour)
- [ ] Mettre à jour la documentation
- [ ] Former les utilisateurs
- [ ] Surveiller les erreurs

### Phase 4 : Validation (1 jour)
- [ ] Exécuter tous les tests
- [ ] Vérifier que tous les workflows fonctionnent
- [ ] Corriger les bugs restants

**Total estimé : 5-7 jours**

---

## 8. Conclusion

Cette analyse préparatoire identifie les opportunités de consolidation des 7 outils Messages en 3 outils consolidés. Les principaux avantages sont :

- **Réduction de la duplication de code** (factorisation des utilitaires)
- **Simplification de la maintenance** (1 fichier au lieu de 7)
- **Amélioration de la testabilité** (facile à tester)
- **Réduction de la complexité** (3 exports MCP au lieu de 7)

Les principaux risques sont :

- **Régression fonctionnelle** (mitigé par une suite de tests complète)
- **Breaking change pour les utilisateurs** (mitigé par des aliases)
- **Complexité accrue du fichier consolidé** (mitigé par une documentation claire)

La consolidation est recommandée, mais doit être effectuée avec précaution et une suite de tests complète.

---

**Document créé:** 2026-01-19
**Prochaine étape:** Validation de l'analyse par Claude Code
