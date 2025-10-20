# 📨 RooSync Messaging System - Guide Complet

**Version** : 2.0 + Amendment Feature  
**Date** : 20 octobre 2025  
**Status** : ✅ Production Ready

---

## 🎯 Vue d'Ensemble

Système de messagerie asynchrone pour communication inter-machines RooSync v2.0 MCP. Permet l'échange de messages structurés entre agents Claude via un répertoire partagé (Google Drive).

**7 outils MCP disponibles** :

1. [`roosync_send_message`](#roosync_send_message) - Envoyer message
2. [`roosync_read_inbox`](#roosync_read_inbox) - Lire boîte de réception
3. [`roosync_get_message`](#roosync_get_message) - Obtenir détails message
4. [`roosync_mark_read`](#roosync_mark_read) - Marquer comme lu
5. [`roosync_archive_message`](#roosync_archive_message) - Archiver message
6. [`roosync_reply_message`](#roosync_reply_message) - Répondre à message
7. [`roosync_amend_message`](#roosync_amend_message) - Modifier message envoyé ✨ **NOUVEAU**

---

## 📊 Architecture Fichiers

### Répertoires de Stockage

```
.shared-state/messages/
├── inbox/          # Messages reçus (tous agents)
│   └── msg-{timestamp}-{random}.json
├── sent/           # Messages envoyés (tous agents)
│   └── msg-{timestamp}-{random}.json
└── archive/        # Messages archivés
    └── msg-{timestamp}-{random}.json
```

### Format Message JSON

```json
{
  "id": "msg-20251019T225546-u85bim",
  "from": "myia-po-2024",
  "to": "myia-ai-01",
  "subject": "Diagnostic RooSync",
  "body": "Le problème est dans InventoryCollector.ts ligne 151",
  "priority": "HIGH",
  "status": "unread",
  "tags": ["diagnostic", "bug-fix"],
  "thread_id": "roosync-debug-session-20251019",
  "reply_to": null,
  "timestamp": "2025-10-19T22:55:46.000Z",
  "read_at": null,
  "metadata": {
    "amended": false,
    "original_content": null,
    "amendment_reason": null,
    "amendment_timestamp": null
  }
}
```

**Champs clés** :
- `id` : Identifiant unique (`msg-{ISO8601}-{random}`)
- `status` : `'unread' | 'read' | 'archived'`
- `priority` : `'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT'`
- `metadata` : Informations amendements (si applicable)

---

## 🛠️ Outils MCP

### roosync_send_message

**Description** : Envoyer un message structuré à une machine destinataire.

**Paramètres** :

```typescript
{
  to: string;          // Machine ID destinataire (ex: 'myia-ai-01')
  subject: string;     // Sujet du message
  body: string;        // Contenu du message (markdown accepté)
  priority?: string;   // 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT' (défaut: 'MEDIUM')
  tags?: string[];     // Tags optionnels pour catégorisation
  thread_id?: string;  // ID de thread pour conversations groupées
}
```

**Retour** :

```typescript
{
  id: string;          // ID du message créé
  timestamp: string;   // ISO 8601 timestamp
  from: string;        // Machine ID émettrice
  to: string;          // Machine ID destinataire
  status: 'unread';    // Statut initial toujours 'unread'
}
```

**Exemple** :

```typescript
const message = await roosync_send_message({
  to: 'myia-ai-01',
  subject: 'Correction InventoryCollector',
  body: 'Bug corrigé dans InventoryCollector.ts ligne 151. Tests validés.',
  priority: 'HIGH',
  tags: ['bug-fix', 'validation'],
  thread_id: 'inventory-debug-20251019'
});

// message.id: "msg-20251019T225546-u85bim"
```

---

### roosync_read_inbox

**Description** : Lire tous les messages de la boîte de réception avec filtrage optionnel.

**Paramètres** :

```typescript
{
  status?: string;     // Filtrer par statut ('unread' | 'read' | 'all')
  limit?: number;      // Nombre max de messages (défaut: 50)
}
```

**Retour** :

```typescript
{
  messages: Array<{
    id: string;
    from: string;
    subject: string;
    priority: string;
    status: string;
    timestamp: string;
    preview: string;   // Aperçu des 100 premiers caractères
  }>;
  total: number;       // Nombre total de messages
  unread: number;      // Nombre de messages non lus
}
```

**Exemple** :

```typescript
// Lire uniquement messages non lus
const inbox = await roosync_read_inbox({
  status: 'unread',
  limit: 10
});

console.log(`${inbox.unread} messages non lus`);
// Affiche liste avec aperçus
```

---

### roosync_get_message

**Description** : Obtenir le contenu complet d'un message spécifique.

**Paramètres** :

```typescript
{
  message_id: string;     // ID du message à lire
  mark_as_read?: boolean; // Marquer automatiquement comme lu (défaut: false)
}
```

**Retour** :

```typescript
{
  message: {
    id: string;
    from: string;
    to: string;
    subject: string;
    body: string;        // Contenu complet (markdown)
    priority: string;
    status: string;
    tags: string[];
    thread_id?: string;
    reply_to?: string;
    timestamp: string;
    read_at?: string;
    metadata?: object;   // Métadonnées amendements si applicable
  };
}
```

**Exemple** :

```typescript
// Lire message et marquer comme lu
const result = await roosync_get_message({
  message_id: 'msg-20251019T225546-u85bim',
  mark_as_read: true
});

console.log(result.message.body); // Contenu complet
```

---

### roosync_mark_read

**Description** : Marquer un message comme lu. Met à jour le statut dans **`inbox/` ET `sent/`** pour synchronisation complète.

**Paramètres** :

```typescript
{
  message_id: string;  // ID du message à marquer
}
```

**Retour** :

```typescript
{
  success: boolean;
  message_id: string;
  marked_at: string;   // ISO 8601 timestamp
}
```

**Exemple** :

```typescript
await roosync_mark_read({
  message_id: 'msg-20251019T225546-u85bim'
});

// Status: 'unread' → 'read'
// Fichier mis à jour dans inbox/ ET sent/
```

---

### roosync_archive_message

**Description** : Archiver un message. Déplace le fichier de `inbox/` vers `archive/` et met à jour `sent/`.

**Paramètres** :

```typescript
{
  message_id: string;  // ID du message à archiver
}
```

**Retour** :

```typescript
{
  success: boolean;
  message_id: string;
  archived_at: string; // ISO 8601 timestamp
}
```

**Exemple** :

```typescript
await roosync_archive_message({
  message_id: 'msg-20251019T225546-u85bim'
});

// Status: 'read' → 'archived'
// Fichier déplacé : inbox/ → archive/
// Fichier mis à jour dans sent/
```

---

### roosync_reply_message

**Description** : Répondre à un message existant. Crée un nouveau message lié avec héritage de contexte.

**Paramètres** :

```typescript
{
  message_id: string;  // ID du message original
  body: string;        // Contenu de la réponse
  priority?: string;   // Priorité (hérite du message original si omis)
}
```

**Retour** :

```typescript
{
  id: string;          // ID du nouveau message
  reply_to: string;    // ID du message original
  thread_id: string;   // ID de thread (hérité)
  timestamp: string;
}
```

**Fonctionnalités automatiques** :
- ✅ Inversion `from` ↔ `to`
- ✅ Héritage `thread_id`
- ✅ Héritage `priority` (si non spécifiée)
- ✅ Ajout tag `"reply"`
- ✅ Préfixe `"Re:"` au sujet

**Exemple** :

```typescript
const reply = await roosync_reply_message({
  message_id: 'msg-20251019T225546-u85bim',
  body: 'Correction validée. Pull effectué avec succès.'
});

// Nouveau message créé avec :
// - subject: "Re: Correction InventoryCollector"
// - reply_to: "msg-20251019T225546-u85bim"
// - thread_id: "inventory-debug-20251019" (hérité)
```

---

### roosync_amend_message

✨ **NOUVELLE FONCTIONNALITÉ**

**Description** : Modifier le contenu d'un message **envoyé** avant qu'il ne soit lu par le destinataire.

**Cas d'usage** :
- Corriger faute de frappe ou information incorrecte
- Ajouter détails oubliés
- Reformuler pour améliorer clarté
- Retirer informations sensibles exposées par erreur

**Paramètres** :

```typescript
{
  message_id: string;      // ID du message à modifier (requis)
  new_content: string;     // Nouveau contenu (remplace original)
  reason?: string;         // Raison de l'amendement (optionnel)
}
```

**Retour** :

```typescript
{
  success: true;
  message_id: string;
  amended_at: string;      // ISO 8601 timestamp
  reason: string;
  original_content_preserved: boolean;  // Toujours true
}
```

**Contraintes** :

❌ **Interdit si** :
- Message déjà lu (`status !== 'unread'`)
- Message archivé (`status === 'archived'`)
- Émetteur n'est pas la machine courante (`from !== machine_id`)

✅ **Autorisé** :
- Message non lu, non archivé, émis par machine courante
- Plusieurs amendements successifs (original toujours préservé)

**Exemple** :

```typescript
// 1. Envoyer message initial
const msg = await roosync_send_message({
  to: 'myia-po-2024',
  subject: 'Diagnostic RooSync',
  body: 'Le problème est dans InventoryCollectur.ts ligne 151'  // Typo!
});

// 2. Corriger le message (avant lecture)
await roosync_amend_message({
  message_id: msg.id,
  new_content: 'Le problème est dans InventoryCollector.ts ligne 151',
  reason: 'Fix typo in filename'
});

// 3. Le destinataire verra le contenu corrigé
```

**Métadonnées ajoutées** :

Lorsqu'un message est amendé, les métadonnées suivantes sont ajoutées :

```json
{
  "metadata": {
    "amended": true,
    "original_content": "Le problème est dans InventoryCollectur.ts ligne 151",
    "amendment_reason": "Fix typo in filename",
    "amendment_timestamp": "2025-10-19T22:00:00.000Z"
  }
}
```

**Note** : Le contenu original est **toujours préservé**, même en cas d'amendements multiples.

---

## 🔄 Workflow Complet

### Scénario : Correction Message avec Erreur

```typescript
// 1. Envoi initial
const msg = await roosync_send_message({
  to: 'myia-ai-01',
  subject: 'Urgent: Config Error',
  body: 'Check file confg.json ligne 42',  // Typo!
  priority: 'URGENT'
});

// 2. Détection erreur
// Agent remarque la faute de frappe

// 3. Amendement (avant lecture)
await roosync_amend_message({
  message_id: msg.id,
  new_content: 'Check file config.json ligne 42',
  reason: 'Fix filename typo'
});

// 4. Agent distant lit message
// Voit contenu corrigé directement

// 5. Historique préservé
// Métadonnées conservent version originale pour audit
```

---

## 🆚 Amendement vs Suppression + Renvoi

### Approche Ancienne (Problématique)

```typescript
// ❌ Supprimer message original
await roosync_archive_message({ message_id: old_msg_id });

// ❌ Envoyer nouveau message
await roosync_send_message({
  to: 'agent-distant',
  subject: 'Diagnostic RooSync',
  body: 'Contenu corrigé'
});
```

**Problèmes** :
- ❌ Perte traçabilité (message original supprimé)
- ❌ Nouveau message ID (référence cassée si déjà partagée)
- ❌ Pollution boîte de réception (2 messages au lieu d'1)
- ❌ Risque confusion destinataire (2 sujets similaires)

### Approche Recommandée (Amendement)

```typescript
// ✅ Amender message existant
await roosync_amend_message({
  message_id: existing_msg_id,
  new_content: 'Contenu corrigé',
  reason: 'Fix critical error'
});
```

**Avantages** :
- ✅ Même message ID (références préservées)
- ✅ Traçabilité complète (original + raison)
- ✅ Boîte de réception propre (1 seul message)
- ✅ Clarté pour destinataire (voit version finale)

---

## 🔒 Sécurité et Contraintes

### Permissions

| Opération | Émetteur | Destinataire | Tiers |
|-----------|----------|--------------|-------|
| `send_message` | ✅ | ❌ | ❌ |
| `amend_message` | ✅ | ❌ | ❌ |
| `reply_message` | ✅ | ✅ | ❌ |
| `mark_read` | ✅ | ✅ | ❌ |
| `archive_message` | ✅ | ✅ | ❌ |

**Règles** :
- ✅ **Émetteur** : Peut amender ses propres messages uniquement
- ❌ **Destinataire** : Ne peut PAS amender messages reçus (doit répondre via `reply`)
- ❌ **Tiers** : Aucune machine tierce ne peut amender

### États Bloquants

| État | Amendement Autorisé | Raison |
|------|---------------------|--------|
| `unread` + `sent/` | ✅ OUI | Message modifiable |
| `read` | ❌ NON | Destinataire a déjà lu |
| `archived` | ❌ NON | Message archivé (historique figé) |
| Émetteur différent | ❌ NON | Permissions insuffisantes |

### Traçabilité

**Garanties** :
- ✅ Contenu original **TOUJOURS** préservé dans `metadata.original_content`
- ✅ Raison amendement documentée (obligatoire si non fournie : "Aucune raison fournie")
- ✅ Timestamp amendement enregistré
- ✅ Flag `amended: true` permanent (jamais supprimé)

---

## 💡 Bonnes Pratiques

### Avant Envoi

1. ✅ **Relire message** : Vérifier orthographe et informations
2. ✅ **Vérifier destinataire** : Confirmer machine ID correcte
3. ✅ **Choisir priorité** : Adapter urgence au contexte
4. ✅ **Ajouter tags** : Faciliter recherche ultérieure

### Amendement

1. ✅ **Amender rapidement** : Corriger immédiatement si erreur détectée
2. ✅ **Raison explicite** : Toujours fournir `reason` pour traçabilité
3. ✅ **Éviter amendements répétés** : Vérifier corrections avant amender
4. ❌ **Ne pas amender après lecture** : Utiliser `reply` pour compléter

### Archivage

1. ✅ **Archiver après traitement** : Garder boîte de réception propre
2. ✅ **Archiver conversations complètes** : Conserver threads ensemble
3. ❌ **Ne pas archiver trop tôt** : Attendre fin de conversation

---

## 🧪 Tests E2E

Suite complète disponible : [`src/tools/roosync/__tests__/amend_message.test.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/__tests__/amend_message.test.ts)

**7 tests couverts** (100% passés) :

1. ✅ Amendement message non lu (cas nominal)
2. ✅ Refus amendement message lu
3. ✅ Refus amendement message archivé
4. ✅ Refus amendement message autre machine
5. ✅ Refus amendement message inexistant
6. ✅ Préservation original lors amendements multiples
7. ✅ Raison par défaut si non fournie

**Commande test** :

```bash
cd mcps/internal/servers/roo-state-manager
npm test -- --run src/tools/roosync/__tests__/amend_message.test.ts
```

---

## 📈 Statistiques Système

| Métrique | Valeur |
|----------|--------|
| **Outils MCP** | 7 |
| **Lignes de code** | ~2800 (service + outils + tests) |
| **Tests unitaires** | 49+ (MessageManager + outils) |
| **Coverage** | 70-100% |
| **Tests E2E** | 8/8 (100%) |
| **Documentation** | 1200+ lignes |

---

## 🔗 Références

**Fichiers source** :
- Service : [`MessageManager.ts`](../../mcps/internal/servers/roo-state-manager/src/services/MessageManager.ts)
- Outil amendement : [`amend_message.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/amend_message.ts)
- Tests : [`amend_message.test.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/__tests__/amend_message.test.ts)

**Documentation complémentaire** :
- Architecture temporelle : [`roosync-temporal-messages-architecture.md`](../architecture/roosync-temporal-messages-architecture.md)
- Rapports implémentation :
  - Phase 1 : [`roosync-messaging-phase1-implementation-20251016.md`](../../roo-config/reports/roosync-messaging-phase1-implementation-20251016.md)
  - Tests E2E : [`roosync-messaging-e2e-test-report-20251016.md`](../../roo-config/reports/roosync-messaging-e2e-test-report-20251016.md)

---

## 🎯 Conclusion

`roosync_amend_message` complète le système de messagerie RooSync avec capacité de correction pré-lecture, essentielle pour communication inter-agents fiable.

**Intégration** : Disponible dès compilation `roo-state-manager`, aucune configuration supplémentaire requise.

**Prochaines évolutions** :
- 🔄 Synchronisation temps-réel (webhooks)
- 📊 Dashboard analytics messages
- 🔍 Recherche full-text dans historique
- 📎 Support pièces jointes (références fichiers)

---

**Dernière mise à jour** : 20 octobre 2025  
**Auteur** : myia-ai-01 (Code Mode)  
**Version doc** : 1.0