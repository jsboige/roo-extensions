# 🔧 Résolution des Problèmes Résiduels MCP Post-Redémarrage

## 📋 Vue d'ensemble

Ce document présente la résolution complète des problèmes identifiés après le redémarrage des serveurs MCP, en utilisant la méthodologie SDDD (Situation-Diagnostic-Décision-Documentation).

---

## 🎯 Problèmes Traités

### 1. ✅ **roo-state-manager** - Rate Limiting Excessif (RÉSOLU)
- **Statut**: ✅ Complètement résolu
- **Impact**: Critique
- **Solution**: Voir [fix-mcp-residual-issues-sddd.md](./fix-mcp-residual-issues-sddd.md)

### 2. ⚠️ **markitdown** - Warning ffmpeg
- **Statut**: ⚠️ Non-critique, documenté
- **Impact**: Mineur (affecte uniquement la transcription audio)
- **Solution**: Installation optionnelle de ffmpeg

### 3. ⚠️ **GitHub API** - Erreur 403
- **Statut**: ⚠️ Nécessite vérification des tokens
- **Impact**: Modéré
- **Solution**: Validation/renouvellement des tokens GitHub

### 4. ✅ **quickfiles** - Fermeture stdin temporaire
- **Statut**: ✅ Auto-recovery fonctionnel
- **Impact**: Négligeable
- **Solution**: Aucune action requise

---

## 🛠️ Solutions Détaillées

### 1. roo-state-manager (RÉSOLU)

#### Problème
- Incohérence DB : écart de 23828 entrées entre squelettes et Qdrant
- Rate limiting excessif : boucle infinie de messages toutes les 20-30 secondes

#### Solution Appliquée
```typescript
// task-indexer.ts
const MAX_OPERATIONS_PER_WINDOW = 100; // Augmenté de 10 à 100
const EMBEDDING_CACHE_TTL = 7 * 24 * 60 * 60 * 1000; // Augmenté à 7 jours

// Nouvelle méthode pour architecture propre
async updateSkeletonIndexTimestamp(taskId: string, storageLocation: string)
```

#### Résultat
- ✅ Plus de boucle infinie
- ✅ Indexation progressive fonctionnelle
- ✅ Architecture améliorée

---

### 2. markitdown - ffmpeg Warning

#### Diagnostic
Le warning provient de la bibliothèque `pydub` utilisée pour la transcription audio :

```python
# _transcribe_audio.py ligne 17
import pydub  # Génère le warning si ffmpeg non installé
```

#### Impact
- Conversion de documents normaux : **Non affecté** ✅
- Transcription audio (mp3, mp4) : **Dégradé** ⚠️

#### Solutions Possibles

##### Option A : Ignorer (Recommandé pour usage standard)
Le MCP fonctionne parfaitement pour :
- Conversion PDF → Markdown
- Conversion DOCX → Markdown  
- Conversion HTML → Markdown
- Toutes les conversions non-audio

##### Option B : Installer ffmpeg (Pour transcription audio)
```bash
# Windows - avec Chocolatey
choco install ffmpeg

# Windows - avec winget
winget install ffmpeg

# Ou téléchargement manuel
# https://www.ffmpeg.org/download.html
# Ajouter au PATH système
```

##### Option C : Supprimer le warning
Ajouter dans le fichier de démarrage du MCP :
```python
import warnings
warnings.filterwarnings("ignore", message="Couldn't find ffmpeg or avconv")
```

---

### 3. GitHub API - Erreur 403

#### Diagnostic
```
GET /search/issues?q=... - 403 with id EF68:285450
```

#### Causes Possibles
1. **Token expiré** : Les tokens dans `.env` peuvent être périmés
2. **Permissions insuffisantes** : Le token n'a pas les scopes nécessaires
3. **Rate limit** : Limite de 5000 req/h avec authentification

#### Vérification du Token
```bash
# Test du token principal
curl -H "Authorization: token VOTRE_GITHUB_TOKEN" \
     https://api.github.com/rate_limit

# Si erreur 401 : token invalide
# Si erreur 403 : permissions insuffisantes
# Si succès : vérifier "remaining" dans la réponse
```

#### Solutions

##### Renouvellement du Token
1. Aller sur GitHub → Settings → Developer settings → Personal access tokens
2. Créer un nouveau token avec les scopes :
   - `repo` (accès complet aux dépôts)
   - `project` (accès aux projets)
   - `read:org` (lecture organisation)
3. Mettre à jour `.env` :
```env
GITHUB_TOKEN=ghp_NOUVEAU_TOKEN_ICI
```
4. Redémarrer le MCP

##### Rotation des Tokens
Si rate limit atteinte, utiliser le token alternatif :
```env
GITHUB_TOKEN_ACTIVE=epita  # Bascule sur le token secondaire
```

---

### 4. quickfiles - Stdin Close

#### Comportement Observé
```
[quickfiles] Stdin has been closed. Exiting...
[quickfiles] Reconnecting...
```

#### Analyse
- ✅ Auto-recovery fonctionnel
- ✅ Reconnexion automatique réussie
- ✅ Aucune perte de fonctionnalité

#### Conclusion
**Aucune action requise** - Le comportement est normal au démarrage.

---

## 📊 Tableau de Synthèse

| Serveur MCP | Problème | Criticité | Statut | Action Requise |
|-------------|----------|-----------|---------|----------------|
| roo-state-manager | Rate limiting + DB | 🔴 Critique | ✅ Résolu | Aucune |
| markitdown | Warning ffmpeg | 🟡 Mineur | ⚠️ Documenté | Optionnelle |
| github-projects | API 403 | 🟠 Modéré | ⚠️ À vérifier | Renouveler token |
| quickfiles | Stdin close | 🟢 Négligeable | ✅ Auto-résolu | Aucune |

---

## 🚀 Scripts de Diagnostic

### Vérification Globale des MCPs
```powershell
# Script PowerShell pour vérifier l'état des MCPs
$mcps = @("roo-state-manager", "markitdown", "github-projects", "quickfiles")

foreach ($mcp in $mcps) {
    Write-Host "Checking $mcp..." -ForegroundColor Cyan
    $process = Get-Process -Name "*$mcp*" -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "✅ $mcp is running (PID: $($process.Id))" -ForegroundColor Green
    } else {
        Write-Host "❌ $mcp is not running" -ForegroundColor Red
    }
}
```

### Test Token GitHub
```bash
# Tester la validité du token
TOKEN="VOTRE_GITHUB_TOKEN_ICI"
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $TOKEN" \
  https://api.github.com/user
```

---

## 📝 Recommandations

1. **Monitoring Continu**
   - Implémenter des health checks automatiques
   - Logger les erreurs dans des fichiers dédiés
   - Alertes sur erreurs critiques

2. **Gestion des Tokens**
   - Rotation automatique des tokens GitHub
   - Stockage sécurisé (utiliser un gestionnaire de secrets)
   - Monitoring des limites de taux

3. **Documentation**
   - Maintenir une liste des dépendances optionnelles
   - Documenter les comportements normaux vs anormaux
   - Guide de troubleshooting par MCP

---

## 🔄 Prochaines Étapes

1. **Court terme** (Cette semaine)
   - [ ] Renouveler le token GitHub principal
   - [ ] Tester la transcription audio avec ffmpeg installé
   - [ ] Valider la stabilité de roo-state-manager sur 24h

2. **Moyen terme** (Ce mois)
   - [ ] Implémenter un système de monitoring centralisé
   - [ ] Automatiser la rotation des tokens
   - [ ] Créer des tests d'intégration pour chaque MCP

3. **Long terme** (Ce trimestre)
   - [ ] Migration vers une architecture plus robuste
   - [ ] Conteneurisation des MCPs (Docker)
   - [ ] CI/CD pour les mises à jour

---

## 📚 Références

- [Documentation SDDD roo-state-manager](./fix-mcp-residual-issues-sddd.md)
- [Guide Configuration MCPs](../guide-configuration-mcps.md)
- [Architecture roo-state-manager](../architecture/roo-state-manager-architecture.md)
- [GitHub API Rate Limiting](https://docs.github.com/en/rest/rate-limit)
- [ffmpeg Installation Guide](https://www.ffmpeg.org/download.html)

---

*Document créé le 25/09/2025 - Dernière mise à jour : 25/09/2025 17h00 (Paris)*