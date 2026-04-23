#!/bin/bash

# Script to integrate dashboard protocol into global CLAUDE.md

# Backup the original file
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup

# Find the line with "### Scepticisme" and insert protocol before it
sed -i '/### Scepticisme/i\
### Protocol: Session ACK + End-of-Summary + Autonomous Continuation\
\
**Version:** 1.0.0\
**Issue:** #1637\
**MAJ:** 2026-04-23\
**Objectif:** Prévenir les "silent agent stalls" par coordination formalisée\
\
---\
\
#### 1. ACK机制 - Mandate OBLIGATOIRE\
\
Lorsqu'"'"'un agent reçoit une requête (dans la première heure après l'"'"'arrivée du message):\
\
```bash\
roosync_dashboard(action: "append", tags: ["ACK"], content: "RECU: [description de la requête] - ID:[taskId] - ETA:[estimation]")\
```\
\
**Format OBLIGATOIRE:**\
- RECU: + description exacte de la demande\
- ID: + ID de la tâche (si applicable)\
- ETA: + estimation réaliste (ex: "2h", "30m", "complex - 4h", "invalid")\
- Réponse en < 1h - PAS D'EXCEPTION\
\
**Objet:** Affirmer réception et comprendre la demande (pas acceptation de responsabilité).\
\
---\
\
#### 2. End-of-Session Summary - Template OBLIGATOIRE\
\
Avant de poster [DONE] en fin de session:\
\
```markdown\
# Résumé de session - [machine-id] - [date]\
\
## Réalisé\
- [ ] Tâche A: completé avec succès\
- [ ] Tâche B: partiel (blocé par X)\
- [ ] Tâche C: invalidée (doublon)\
\
## PR créés\
- PR #NNN: "Titre" (merged)\
\
## Issues fermées\
- Issue #NNN: vérification confirmée\
\
## Demande de continuation\
- [ ] continuer dans prochaine session\
- [ ] suspendre jusqu'"'"'à nouvel ordre\
- [ ] coordonner avec X agent\
\
## Notes critiques\
- [ ] code critique présent\
- [ ] security warning détecté\
- [ ] performance alert\
```\
\
**Règles:**\
- Objectif: transparence complète\
- TACHE OBLIGATOIRE: poster [DONE] MÊME si échec ou incomplet\
- Interdit: omettre des tâches "difficiles"\
\
---\
\
#### 3. Autonomous Continuation\
\
##### Continuation conditionnelle\
- Si "continuer dans prochaine session" → Coordinateur déclenche relance\
- Si "suspendre" → Ne PAS relancer sans nouvelle instruction\
- Si "coordonner" → Réveiller agent concerné via RooSync\
\
##### Cluster Tour Scheduler\
- Coordinateur (myia-ai-01) tourne "tour de cluster" toutes 6-12h\
- Scan dashboard de chaque workspace (status: idle/blocked/critical)\
- Priorité absolue: réactiver agents bloqués > 4h\
\
##### Relance automatique\
```bash\
# Pattern pour reactivation\
roosync_send(to: [machine-id], content: "RELANCER: [task-id] - nouvelle approche: X")\
```\
\
---\
\
#### 4. Coordinator Relance Protocol\
\
##### Agent dormant (>4h inactif)\
1. Vérifier presence: `roosync_get_status(machineId: [id])`\
2. Si offine → enquête inter-machines\
3. Si online mais idle → envoyer relance via dashboard\
\
##### Timeout handling\
- Agent non-déclaré > 24h → incident CRITICAL\
- Issue ouverte > 48h sans réponse → redéclarée\
- PR créé > 72h sans progression → clôturée\
\
---\
\
**Leçon clé:** Transparency=anticipation. Silence=problème. ACK + reporting continu=cluster résilient.\
\
' ~/.claude/CLAUDE.md

echo "Protocol successfully integrated into global CLAUDE.md"
