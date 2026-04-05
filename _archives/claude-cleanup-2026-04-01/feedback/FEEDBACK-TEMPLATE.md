# Template Feedback - [TITRE COURT DE L'AMÉLIORATION]

**Machine:** [VOTRE_MACHINE_ID]
**Date:** [YYYY-MM-DD]
**Soumis par:** Claude Code
**Statut:** 🔄 EN CONSULTATION

---

## ✋ Checklist Avant Soumission

Avant de soumettre ce feedback, vérifie :

- [ ] J'ai **vraiment** rencontré ce problème (pas théorique)
- [ ] Je peux documenter la **fréquence** (combien de fois?)
- [ ] J'ai quantifié l'**impact** (temps perdu, frustration)
- [ ] Ma solution est **minimale** (< 3 fichiers modifiés)
- [ ] J'ai identifié les **risques** (feature creep, complexité)
- [ ] Ce n'est PAS une feature "nice to have"

**Si toutes les cases sont cochées, continue !** Sinon, reconsidère ta proposition.

---

## 🔍 Friction Identifiée

### Description du Problème Concret

[Décris le problème que tu as rencontré. Sois spécifique et factuel.]

**Exemple GOOD :**
> Durant mes 3 derniers sync-tours (sessions 2026-01-20, 21, 22), j'ai dû manuellement vérifier les issues GitHub fermées car la Phase 5 ne détecte pas automatiquement les items marqués "Done" dans Project #67 mais dont l'issue GitHub reste "Open".

**Exemple BAD :**
> Ce serait bien d'avoir un système pour gérer les incohérences GitHub.

### Fréquence

**Combien de fois as-tu rencontré ce problème?**
- [X] fois sur [Y] sessions récentes
- Période : [dates]

**Exemple :** 3 fois sur 5 sync-tours (dernières 2 semaines)

### Impact Mesurable

**Quel est l'impact concret?**
- Temps perdu : [X] minutes par occurrence
- Frustration : [Basse / Moyenne / Haute]
- Blocage workflow : [Oui / Non]
- Impact équipe : [Combien d'agents concernés?]

**Exemple :**
- Temps perdu : ~5 minutes par sync-tour
- Total : 15 minutes sur 2 semaines
- Frustration : Moyenne (casse le flow de la Phase 5)
- Impact équipe : Probablement 3+ machines concernées

---

## 💡 Proposition d'Amélioration

### Solution Minimale

[Décris la **plus petite** modification qui résout le problème]

**Exemple GOOD :**
> Ajouter une vérification dans Phase 5 du sync-tour :
> ```
> Si item Project #67 = "Done" ET issue GitHub = "Open" ALORS
>   → Signaler incohérence dans output Phase 5
>   → Proposer fermeture automatique (avec confirmation)
> ```

**Exemple BAD :**
> Créer un système complet de détection d'incohérences avec dashboard, alertes email, et historique des corrections.

### Changements Requis

**Quels fichiers faut-il modifier?**

- [ ] `.claude/skills/sync-tour/SKILL.md` - Ajouter vérification Phase 5
- [ ] [Autre fichier si nécessaire]

**Nombre de fichiers :** [1-3 max idéalement]
**Complexité estimée :** [Basse / Moyenne / Haute]

### Alternatives Considérées

**As-tu envisagé d'autres solutions?**

1. [Alternative 1] - Rejetée car [raison]
2. [Alternative 2] - Rejetée car [raison]

**Exemple :**
1. Manuel (statu quo) - Rejeté car temps perdu continue
2. Détecter toutes les incohérences - Rejeté car complexité excessive

---

## ⚠️ Risques Identifiés

**Sois ton propre critique !** Identifie les risques **avant** que les autres les soulèvent.

### Risque de Feature Creep

[Est-ce que tu es en train d'ajouter une feature "nice to have"?]

**Exemple :**
- ❌ Risque : Si on essaie de détecter **toutes** les incohérences possibles, ça devient complexe
- ✅ Mitigation : Limiter à **1 seule** vérification (items Done vs issues Open)

### Risque de Complexité

[La solution ajoute-t-elle de la complexité?]

**Exemple :**
- ❌ Risque : Appels API GitHub supplémentaires ralentissent Phase 5
- ✅ Mitigation : Batch API calls, limiter aux items modifiés < 7 jours

### Risque de Faux Positifs

[La solution peut-elle détecter des problèmes qui n'en sont pas?]

**Exemple :**
- ❌ Risque : Issues volontairement laissées ouvertes pour discussion
- ✅ Mitigation : Proposer fermeture (ne pas fermer automatiquement)

### Autres Risques

[Performance, maintenance, effets secondaires...]

---

## 📝 Message RooSync à Envoyer

### Sujet

`[FEEDBACK] Amélioration [NOM_COMPOSANT]: [TITRE_COURT]`

**Exemple :** `[FEEDBACK] Amélioration sync-tour: Détection incohérences GitHub`

### Priorité

`MEDIUM` (sauf si bloquant critique → `HIGH`)

### Tags

`["feedback", "workflow-improvement"]`

### Corps du Message

```markdown
## Contexte

[Résumé de la friction identifiée - 2-3 phrases]

**Fréquence :** [X fois sur Y sessions]
**Impact :** [Temps perdu mesurable]

## Proposition

[Résumé de la solution minimale]

**Changements requis :**
- [Fichier 1]
- [Fichier 2 si nécessaire]

## Risques Identifiés

- **[Type]** : [Description] → Mitigation : [Solution]
- ...

## Question pour vous

Est-ce que vous avez aussi rencontré ce problème?
Est-ce que la solution proposée est trop complexe?
Quels autres risques voyez-vous?

**Merci de répondre dans les 24-48h !**
```

---

## 🎯 Prochaines Étapes

### 1. Envoyer Message RooSync

```bash
roosync_send_message {
  "to": "all",
  "subject": "[FEEDBACK] Amélioration [COMPOSANT]: [TITRE]",
  "priority": "MEDIUM",
  "tags": ["feedback", "workflow-improvement"],
  "body": "[Corps ci-dessus]"
}
```

### 2. Ajouter Entrée dans FEEDBACK-LOG.md

Copier le format ci-dessous et ajouter dans [FEEDBACK-LOG.md](FEEDBACK-LOG.md) :

```markdown
#### [FB-XXX] YYYY-MM-DD - [TITRE COURT]

**Machine:** [VOTRE_MACHINE]
**Soumis par:** Claude Code
**Statut:** 🔄 EN CONSULTATION

##### Friction identifiée

[Résumé problème]

**Fréquence :** [X/Y]
**Impact :** [Temps/Frustration]

##### Proposition

[Solution minimale]

**Changements requis :**
- [Fichiers]

##### Risques identifiés

- [Liste]

##### Consultation

**Message RooSync :** `msg-XXXXXXXX-XXXXX` - [FEEDBACK] [Titre]
**Délai :** 24-48h (jusqu'au YYYY-MM-DD)

**Réponses :**
- [machine] : [avis] *(sera rempli au fur et à mesure)*

##### Décision

**🔄 EN ATTENTE SYNTHÈSE COORDINATEUR**
```

### 3. Attendre 24-48h

Laisser le temps aux autres agents de répondre.

### 4. Le Coordinateur Finalisera

Le coordinateur (myia-ai-01) synthétisera les réponses et mettra à jour FEEDBACK-LOG.md avec la décision finale.

---

## 💬 Exemple Complet (Pour Référence)

Voir exemple hypothétique [FB-002 dans FEEDBACK-LOG.md](FEEDBACK-LOG.md#fb-002-exemple-hypothétique---à-supprimer-si-non-utilisé)

---

**Template Version:** 1.0.0
**Créé par:** Claude Code (myia-po-2023)
**Date:** 2026-01-23
**Issue:** [#357](https://github.com/jsboige/roo-extensions/issues/357)
