# Protocol: Session ACK + End-of-Summary + Autonomous Continuation

**Version:** 1.0.0
**Issue:** #1637
**MAJ:** 2026-04-23
**Objectif:** Prévenir les "silent agent stalls" par coordination formalisée

---

## 1. ACK机制 - Mandate OBLIGATOIRE

Lorsqu'un agent reçoit une requête (dans la première heure après l'arrivée du message):

```bash
roosync_dashboard(action: "append", tags: ["ACK"], content: "RECU: [description de la requête] - ID:[taskId] - ETA:[estimation]")
```

**Format OBLIGATOIRE:**
- RECU: + description exacte de la demande
- ID: + ID de la tâche (si applicable)
- ETA: + estimation réaliste (ex: "2h", "30m", "complex - 4h", "invalid")
- Réponse en < 1h - PAS D'EXCEPTION

**Objet:** Affirmer réception et comprendre la demande (pas acceptation de responsabilité).

---

## 2. End-of-Session Summary - Template OBLIGATOIRE

Avant de poster [DONE] en fin de session:

```markdown
# Résumé de session - [machine-id] - [date]

## Réalisé
- [ ] Tâche A: completé avec succès
- [ ] Tâche B: partiel (blocé par X)
- [ ] Tâche C: invalidée (doublon)

## PR créés
- PR #NNN: "Titre" (merged)

## Issues fermées
- Issue #NNN: vérification confirmée

## Demande de continuation
- [ ] continuer dans prochaine session
- [ ] suspendre jusqu'à nouvel ordre
- [ ] coordonner avec X agent

## Notes critiques
- [ ] code critique présent
- [ ] security warning détecté
- [ ] performance alert
```

**Règles:**
- Objectif: transparence complète
- TACHE OBLIGATOIRE: poster [DONE] MÊME si échec ou incomplet
- Interdit: omettre des tâches "difficiles"

---

## 3. Autonomous Continuation

### Continuation conditionnelle
- Si "continuer dans prochaine session" → Coordinateur déclenche relance
- Si "suspendre" → Ne PAS relancer sans nouvelle instruction
- Si "coordonner" → Réveiller agent concerné via RooSync

### Cluster Tour Scheduler
- Coordinateur (myia-ai-01) tourne "tour de cluster" toutes 6-12h
- Scan dashboard de chaque workspace (status: idle/blocked/critical)
- Priorité absolue: réactiver agents bloqués > 4h

### Relance automatique
```bash
# Pattern pour reactivation
roosync_send(to: [machine-id], content: "RELANCER: [task-id] - nouvelle approche: X")
```

---

## 4. Coordinator Relance Protocol

### Agent dormant (>4h inactif)
1. Vérifier presence: `roosync_get_status(machineId: [id])`
2. Si offine → enquête inter-machines
3. Si online mais idle → envoyer relance via dashboard

### Timeout handling
- Agent non-déclaré > 24h → incident CRITICAL
- Issue ouverte > 48h sans réponse → redéclarée
- PR créé > 72h sans progression → clôturée

---

## Implémentation

### 1. Intégration dans CLAUDE.md global
Ajouter ce protocole aux règles auto-chargées après la section "Session Pattern".

### 2. Dashboard tags requis
- `ACK`: Confirmation de réception
- `DONE`: Fin de session (obligatoire)
- `BLOCKED`: Signal d'urgence
- `CRITICAL`: Incident nécessitant escalade

### 3. Auto-condensation
- Messages > 50KB → condensation automatique
- Garde les derniers [ACK] et [DONE] pour traçabilité

---

**Leçon clé:** Transparency=anticipation. Silence=problème. ACK + reporting continu=cluster résilient.

---

**Historique:**
- 2026-04-23: Création du protocole pour résoudre les "silent agent stalls" (#1637)
