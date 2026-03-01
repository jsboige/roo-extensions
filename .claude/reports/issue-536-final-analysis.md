# Issue #536 - Analyse Finale : Évaluation Qwen 3.5 35B A3B

**Machine:** myia-po-2025
**Date:** 2026-03-01
**Auteur:** Claude Code (Sonnet 4.5)

---

## Statut Global

| Phase | Statut | Notes |
|-------|--------|-------|
| **Évaluation théorique** | ✅ **COMPLÈTE** | Rapport complet dans `docs/evaluation/qwen-3.5-35b-a3b-evaluation-536.md` |
| **Configuration** | ✅ **PRÊTE** | `roo-config/model-configs.json` déjà configuré avec Qwen 3.5 35B A3B |
| **Déploiement pratique** | ⏸️ **BLOQUÉ** | 3 blocages identifiés (détails ci-dessous) |

---

## Résumé de l'Évaluation Théorique

L'évaluation complète a été réalisée et documentée par Roo Code (mode complex) le 2026-02-25. Les conclusions sont **très positives** :

### Performance vs GLM-4.7-Flash

| Critère | GLM-4.7-Flash | Qwen 3.5 35B A3B | Verdict |
|---------|--------------|-------------------|---------|
| **Contexte** | 131K réel | 256K (ext. 1M) | ✅ Qwen (2x) |
| **Code quality** | Bon | Très bon (SWE-bench 74.6%) | ✅ Qwen |
| **Instruction following** | Moyen (~85%) | Bon (IFEval 91.9%) | ✅ Qwen |
| **Vision** | ❌ | ✅ Natif multimodal | ✅ Qwen |
| **VRAM (4-bit)** | ~12 GB | ~22 GB | ⚠️ GLM (moins) |
| **Active params** | ~7B | 3B MoE | ✅ Qwen (efficace) |
| **Speed (tok/s)** | ~80 | 60-80 | ≈ Égal |

### Recommandation Théorique

✅ **MIGRATION FORTEMENT RECOMMANDÉE pour GPU 24GB+** (RTX 4090/3090)

**Raisons :**
1. Vision natif (screenshots, diagrams) - utile pour debug UI
2. Meilleure qualité code (SWE-bench +2.6 points)
3. Contexte 2x plus grand (256K vs 131K)
4. Instruction following supérieur (IFEval +6.9 points)
5. MoE efficace (3B actifs surpasse 7B GLM)

⚠️ **Pour GPU <24GB :** Conserver GLM-4.7-Flash (VRAM insuffisante)

---

## Configuration Actuelle

### model-configs.json (DÉJÀ CONFIGURÉ ✅)

Le fichier `roo-config/model-configs.json` contient **déjà** la configuration complète :

```json
{
  "profiles": [
    {
      "name": "Production (Qwen 3.5 local + GLM-5 cloud)",
      "modeOverrides": {
        "code-simple": "simple",
        "code-complex": "default",
        "debug-simple": "simple",
        "debug-complex": "default",
        "architect-simple": "simple",
        "architect-complex": "default",
        "ask-simple": "simple",
        "ask-complex": "default",
        "orchestrator-simple": "simple",
        "orchestrator-complex": "default"
      }
    }
  ],
  "apiConfigs": {
    "simple": {
      "apiProvider": "openai",
      "openAiBaseUrl": "https://api.medium.text-generation-webui.myia.io/v1",
      "openAiApiKey": "${env:LOCAL_LLM_API_KEY}",
      "openAiModelId": "qwen3.5-35b-a3b",
      "description": "Qwen 3.5 35B A3B auto-hébergé via text-generation-webui"
    },
    "default": {
      "apiProvider": "openai",
      "openAiBaseUrl": "https://api.z.ai/api/anthropic",
      "openAiApiKey": "${env:ZAI_API_KEY}",
      "openAiModelId": "glm-5"
    }
  }
}
```

**Dernière mise à jour :** 2026-02-26 (commit `f3b75531`)

---

## Blocages Pratiques Identifiés

### 1. Modèle vLLM Non Swappé (CRITIQUE)

**Statut :** Endpoint configuré mais charge GLM-4.7-Flash, pas Qwen 3.5 35B A3B

**Détails :**
- Endpoint actuel : `http://myia-ai-01:5002/v1`
- API key fournie par coordinateur : `vllm-placeholder-key-2024`
- Modèle chargé : GLM-4.7-Flash (ancien)
- Modèle attendu : Qwen/Qwen3.5-35B-A3B

**Action requise (coordinateur myia-ai-01) :**
```bash
# Sur myia-ai-01, GPU 2
vllm serve Qwen/Qwen3.5-35B-A3B \
    --tensor-parallel-size 1 \
    --gpu-memory-utilization 0.9 \
    --max-model-len 32768 \
    --port 5002
```

**Alternative si text-generation-webui déjà configuré :**
Le fichier `model-configs.json` pointe vers `https://api.medium.text-generation-webui.myia.io/v1`, donc si tgwui est déjà configuré avec Qwen 3.5 35B A3B, aucune action n'est nécessaire.

### 2. Variables d'Environnement Non Déployées

**Statut :** API keys .env manquantes sur machines exécutantes

**Machines concernées :** myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026, myia-web1

**Variables requises :**
```bash
# Dans mcps/internal/servers/roo-state-manager/.env (ou global)
LOCAL_LLM_API_KEY=vllm-placeholder-key-2024
LOCAL_LLM_API_BASE=http://myia-ai-01:5002/v1  # ou https://api.medium.text-generation-webui.myia.io/v1
```

**Action requise :**
1. Créer template `.env` dans le repo (gitignored)
2. Déployer via `roosync_config` ou script de déploiement
3. Ou : configurer directement dans les settings Roo UI de chaque machine

### 3. Mécanisme de Chargement model-configs.json À Clarifier

**Statut :** Incertain si Roo charge automatiquement ce fichier

**Questions non résolues :**
1. Roo lit-il `roo-config/model-configs.json` automatiquement ?
2. Faut-il déployer via script PowerShell (`deploy-profile-modes.ps1`) ?
3. Faut-il configurer manuellement dans Roo Settings UI ?

**Documentation contradictoire :**
- `docs/guides/guide-utilisation-profils-modes.md` suggère scripts PowerShell
- `docs/deployment/DEPLOY-SCHEDULED-ROO.md` dit "utilisateur adapte manuellement"
- `roo-config/README.md` parle de `roo.modelConfigs` dans VS Code settings

**Action requise :**
1. **Tester** : Vérifier dans Roo UI (Settings → Model Configurations) si `simple` et `default` sont visibles
2. **Si non visible** : Exécuter `deploy-profile-modes.ps1 -ProfileName "Production (Qwen 3.5 local + GLM-5 cloud)"`
3. **Si toujours non visible** : Configurer manuellement dans Roo Settings UI

---

## Plan de Déblocage Recommandé

### Phase 1 : Clarifier le Chargement (URGENT)

**Responsable :** Coordinateur myia-ai-01 ou n'importe quelle machine avec accès Roo UI

**Actions :**
1. Ouvrir Roo Code sur n'importe quelle machine
2. Aller dans Settings → Model Configurations
3. Vérifier si `simple` (Qwen 3.5 35B A3B) et `default` (GLM-5) sont listés
4. Si OUI : Noter comment ils sont définis (chemin fichier, config inline, etc.)
5. Si NON : Tester `deploy-profile-modes.ps1` et re-vérifier

**Résultat attendu :** Documentation claire du mécanisme de chargement

### Phase 2 : Déployer l'Infrastructure (COORDINATEUR)

**Responsable :** myia-ai-01

**Actions :**
1. **Endpoint vLLM ou tgwui** :
   - **Option A** (vLLM) : Swapper port 5002 vers Qwen 3.5 35B A3B
   - **Option B** (tgwui) : Vérifier que `https://api.medium.text-generation-webui.myia.io/v1` sert déjà Qwen 3.5 35B A3B
2. **Variables d'environnement** :
   - Créer template `.env` avec `LOCAL_LLM_API_KEY` et `LOCAL_LLM_API_BASE`
   - Publier via `roosync_config` ou script de déploiement
3. **Tester endpoint** :
   ```bash
   curl -X POST https://api.medium.text-generation-webui.myia.io/v1/chat/completions \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer vllm-placeholder-key-2024" \
     -d '{"model": "qwen3.5-35b-a3b", "messages": [{"role": "user", "content": "Test"}]}'
   ```

**Résultat attendu :** Endpoint répond avec Qwen 3.5 35B A3B

### Phase 3 : Tests Scheduler (TOUTES MACHINES GPU 24GB+)

**Responsable :** myia-ai-01, myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026

**Actions :**
1. Configurer les variables d'environnement
2. Activer le profil "Production (Qwen 3.5 local + GLM-5 cloud)" dans Roo
3. Exécuter 5 tâches scheduler en mode `-simple` :
   - 1x code-simple (correction syntaxe)
   - 1x debug-simple (bug évident)
   - 1x architect-simple (revue doc)
   - 1x ask-simple (question codebase)
   - 1x orchestrator-simple (workflow 3 étapes)
4. Comparer qualité avec GLM-4.7-Flash (référence historique)
5. Valider support vision (screenshot, diagram)

**Résultat attendu :**
- Taux de succès ≥90% (comparable ou supérieur à GLM-4.7-Flash)
- Vision fonctionne (test avec screenshot de code)
- Throughput acceptable (60-80 tok/s)

### Phase 4 : Migration Si Validé

**Responsable :** Coordinateur myia-ai-01

**Actions :**
1. Si Phase 3 réussie : Documenter les résultats
2. Mettre à jour `model-configs.json` comme config par défaut (déjà fait ✅)
3. Déployer sur toutes les machines GPU 24GB+
4. Annoncer dans INTERCOM + RooSync
5. Mettre à jour documentation :
   - `DEPLOY-SCHEDULED-ROO.md`
   - `roo-config/README.md`
   - `docs/evaluation/qwen-3.5-35b-a3b-evaluation-536.md` (section résultats terrain)

**Résultat attendu :** Migration complète et documentée

---

## Recommandations Finales

### Recommandation 1 : Priorité au Déblocage Phase 1

**Sans clarifier le mécanisme de chargement, impossible de valider.** C'est le goulot d'étranglement critique.

**Action immédiate :** N'importe quelle machine avec Roo accessible doit vérifier la section Model Configurations dans les settings et documenter ce qu'elle voit.

### Recommandation 2 : Endpoint text-generation-webui Probable

Le fichier `model-configs.json` pointe vers `https://api.medium.text-generation-webui.myia.io/v1`, ce qui suggère que l'infrastructure est déjà en place via text-generation-webui, pas vLLM.

**Hypothèse à tester :** Le modèle Qwen 3.5 35B A3B est peut-être **déjà chargé** sur ce endpoint, et il suffit de configurer les API keys + activer le profil.

### Recommandation 3 : Validation Incrémentale

Ne pas attendre une "big bang migration". Tester d'abord sur **une seule machine** (myia-ai-01), valider, puis étendre.

**Workflow :**
1. myia-ai-01 : Clarifier + tester + valider (Phase 1-3)
2. Si succès : Déployer sur myia-po-2023, myia-po-2024
3. Si succès : Déployer sur myia-po-2025, myia-po-2026
4. myia-web1 : Conserver GLM-4.7-Flash (2GB RAM insuffisante)

### Recommandation 4 : Fallback GLM-4.7-Flash

Si Qwen 3.5 35B A3B pose des problèmes (instabilité, throughput, qualité inférieure en pratique), **conserver GLM-4.7-Flash** comme backup.

**Critères de rollback :**
- Taux de succès <80% sur tests scheduler
- Throughput <40 tok/s
- Vision non fonctionnelle
- Erreurs fréquentes (OOM, timeout)

---

## Conclusion

**L'évaluation théorique #536 est COMPLÈTE et POSITIVE.** Qwen 3.5 35B A3B surpasse GLM-4.7-Flash sur tous les benchmarks mesurables.

**Le déploiement pratique attend 3 déblocages :**
1. ✅ Configuration `model-configs.json` (FAIT)
2. ⏸️ Clarifier mécanisme de chargement Roo (Phase 1)
3. ⏸️ Déployer infrastructure (endpoint + API keys) (Phase 2)
4. ⏸️ Valider sur terrain avec tests scheduler (Phase 3)

**Effort estimé pour déblocage complet :** 2-4h (si endpoint déjà configuré) à 6-8h (si nouvelle config vLLM)

**Difficulté :** Moyenne (dépend de la clarté du mécanisme Roo)

---

**Prochaine étape recommandée :** Phase 1 (clarifier mécanisme de chargement) - n'importe quelle machine avec Roo peut le faire.

