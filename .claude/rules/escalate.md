# Escalade Claude Code - Protocole Niveaux 4/5

**Version:** 1.0.0
**Créé:** 2026-03-24
**Issue:** #842

---

## Principe

Quand un agent Claude Code est bloqué ou face à un problème qu'il ne peut résoudre avec ses capacités actuelles, il doit **escalader** vers un niveau supérieur de puissance/complexité.

---

## Niveaux d'Escalade

### Niveau 1-3 : Modes Claude Code (Standard)

| Niveau | Mode | Capacité | Usage |
|--------|------|----------|------|
| 1 | ask-simple | Questions simples | Recherche documentaire |
| 2 | code-simple/debug-simple | Code simple | Tâches courantes |
| 3 | code-complex/debug-complex/orchestrator-complex | Code complexe | Tâches avancées |

**Règle:** Toujours commencer au niveau le plus bas possible. N'escalader que si nécessaire.

---

### Niveau 4 : Claude CLI (Sonnet/Opus)

**Quand escalader:**
- **2 échecs consécutifs** au même niveau 3 avec des approches différentes
- **Problème complexe** nécessitant plus de contexte ou de puissance de raisonnement
- **Blocage persistant** après avoir essayé plusieurs solutions

**Procédure:**

```bash
# Installer Claude CLI si pas déjà fait
npm install -g @anthropic-ai/claude-code

# Escalader vers Sonnet (niveau 4)
claude -p "Votre prompt..." --model sonnet-4-20250514

# Ou Opus pour problèmes encore plus complexes (niveau 4.5)
claude -p "Votre prompt..." --model claude-opus-4-20250514
```

**Modèles disponibles:**
- `sonnet-4-20250514` : Équilibré, bonne vitesse
- `claude-opus-4-20250514` : Maximum puissance, plus lent

**⚠️ IMPORTANT:** L'escalade CLI ne fonctionne PAS depuis une session VS Code active (variable CLAUDECODE bloquante). Utiliser depuis un terminal séparé.

---

### Niveau 5 : Anthropic API Direct (Critique)

**Quand escalader:**
- **Échec du niveau 4** (CLI n'a pas résolu le problème)
- **Problème critique** bloquant le projet entier
- **Besoin de contrôle total** (temperature, max_tokens, system prompt personnalisé)

**Procédure:**

```python
import anthropic

client = anthropic.Anthropic(api_key="sk-ant-...")

message = client.messages.create(
    model="claude-3-5-sonnet-20241022",
    max_tokens=4096,
    temperature=0.7,
    system="Votre system prompt personnalisé...",
    messages=[
        {"role": "user", "content": "Votre prompt..."}
    ]
)

print(message.content[0].text)
```

**Modèles API:**
- `claude-3-5-sonnet-20241022` : Dernier Sonnet (recommandé)
- `claude-3-5-haiku-20241022` : Rapide, pour tâches simples
- `claude-3-opus-20240229` : Opus v2 (ancien, très puissant)

---

## Critères d'Escalade

### ✅ Escalader si:

1. **Échecs répétés** : 2+ tentatives avec des approches différentes ont échoué
2. **Problème hors portée** : La tâche nécessite des capacités non disponibles (ex: système externe)
3. **Blocage structurel** : Un problème architectural nécessite une refonte complète
4. **Urgence critique** : Le problème bloque toute progression sur le projet

### ❌ NE PAS escalader si:

1. **Premier échec** : Toujours réessayer avec une approche différente
2. **Manque d'information** : Chercher d'abord dans la documentation/code
3. **Problème simple** : La tâche peut être résolue avec plus de temps/patience
4. **Question utilisateur** : Demander à l'utilisateur est plus approprié

---

## Format de Rapport d'Escalade

Quand vous escaladez, documentez toujours:

```markdown
## Escalade Niveau X - [Tâche]

**Problème:** [Description]
**Tentatives:**
1. [Approche 1] - Résultat: [échec/partiel]
2. [Approche 2] - Résultat: [échec/partiel]

**Raison escalade:** [Pourquoi le niveau actuel est insuffisant]

**Action:** [CLI ou API call]
**Résultat:** [Success/Echec]
```

---

## Références

- Issue #842 : Création de ce fichier
- Roo equivalent : `.roo/rules/01-sddd-escalate.md` (si existe)
- Anthropic Docs : https://docs.anthropic.com/

---

**Dernière mise à jour:** 2026-03-24
