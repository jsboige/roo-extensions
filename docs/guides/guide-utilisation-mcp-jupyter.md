# 📚 GUIDE D'UTILISATION - MCP Jupyter Corrigé

**Version** : 1.0.0 (Post-correction SDDD)  
**Date** : 8 octobre 2025  
**Statut** : ✅ Validé pour production

---

## 🎯 APERÇU

Ce guide explique comment utiliser efficacement le **MCP Jupyter corrigé** après la résolution critique du bug de working directory. Le serveur MCP est maintenant **stable et prêt pour la production** avec des notebooks réels.

### ⚡ **Points Clés**
- **Working directory stable** : Plus de pollution environnement
- **Support multi-kernel** : Python, .NET, etc. (selon installation)
- **Exécution asynchrone** : Recommandée pour notebooks > 1 minute
- **Gestion robuste d'erreurs** : Le serveur ne crash plus

---

## 🚀 DÉMARRAGE RAPIDE

### 1. Vérification de l'État du Serveur

```javascript
// Vérifier que le MCP Jupyter fonctionne
await mcp.callTool('jupyter-papermill-mcp-server', 'system_info', {});
```

**Réponse attendue :**
```json
{
  "success": true,
  "python_version": "3.10.18",
  "jupyter_version": "...",
  "working_directory": "/path/to/mcp/server"
}
```

### 2. Premier Test - Kernel Simple

```javascript
// Démarrer un kernel Python
const kernelResult = await mcp.callTool('jupyter-papermill-mcp-server', 'start_kernel', {
  kernel_name: 'python3'
});

const kernelId = kernelResult.kernel_id;

// Exécuter du code
await mcp.callTool('jupyter-papermill-mcp-server', 'execute_cell', {
  kernel_id: kernelId,
  code: 'print("Hello MCP Jupyter!")'
});

// Arrêter le kernel
await mcp.callTool('jupyter-papermill-mcp-server', 'stop_kernel', {
  kernel_id: kernelId
});
```

---

## 🛠️ OUTILS DISPONIBLES

### **Gestion des Kernels**

| Outil | Usage | Commentaire |
|-------|-------|-------------|
| `list_kernels` | Lister kernels disponibles | Python toujours disponible |
| `start_kernel` | Démarrer nouveau kernel | Spécifier kernel_name |
| `stop_kernel` | Arrêter kernel | Libère ressources |
| `restart_kernel` | Redémarrer kernel | En cas de blocage |
| `get_kernel_status` | État détaillé kernel | Debug & monitoring |

### **Exécution Directe**

| Outil | Usage | Recommandation |
|-------|-------|----------------|
| `execute_cell` | Code dans kernel actif | ✅ Toujours fiable |
| `execute_notebook_sync` | Notebook < 1 min | ⚠️ Timeout 60s client |
| `start_notebook_async` | Notebook > 1 min | ✅ **RECOMMANDÉ** |
| `get_execution_status_async` | Statut job async | Monitoring essentiel |

### **Gestion des Notebooks**

| Outil | Usage | Notes |
|-------|-------|--------|
| `create_notebook` | Créer nouveau notebook | Kernel par défaut Python |
| `read_notebook` | Lire contenu notebook | Métadonnées incluses |
| `add_cell` / `update_cell` | Modifier cellules | Types: code, markdown |
| `list_notebook_files` | Scanner répertoire | Récursif optionnel |

---

## 📖 PATTERNS D'UTILISATION

### **Pattern 1 : Notebook Synchrone (< 1 minute)**

```javascript
async function executeShortNotebook(notebookPath) {
  try {
    const result = await mcp.callTool('jupyter-papermill-mcp-server', 
      'execute_notebook_sync', {
        notebook_path: notebookPath,
        timeout_seconds: 45  // Sous les 60s
      }
    );
    
    if (result.success) {
      console.log('✅ Notebook exécuté:', result.output_path);
    }
    
    return result;
  } catch (error) {
    console.log('⚠️ Timeout probable - Utiliser méthode async');
    throw error;
  }
}
```

### **Pattern 2 : Notebook Asynchrone (> 1 minute) - RECOMMANDÉ**

```javascript
async function executeLongNotebook(notebookPath) {
  // Démarrer l'exécution asynchrone
  const job = await mcp.callTool('jupyter-papermill-mcp-server', 
    'start_notebook_async', {
      input_path: notebookPath,
      timeout_seconds: 300  // 5 minutes
    }
  );
  
  const jobId = job.job_id;
  console.log('🚀 Job démarré:', jobId);
  
  // Polling du statut
  let status;
  do {
    await new Promise(resolve => setTimeout(resolve, 2000)); // Attendre 2s
    
    const statusResult = await mcp.callTool('jupyter-papermill-mcp-server',
      'get_execution_status_async', { job_id: jobId }
    );
    
    status = statusResult.status;
    console.log(`📊 Statut: ${status} (${statusResult.duration_seconds}s)`);
    
    // Logs optionnels pour debug
    if (status === 'RUNNING') {
      const logs = await mcp.callTool('jupyter-papermill-mcp-server',
        'get_job_logs', { job_id: jobId }
      );
      // Traiter les logs...
    }
    
  } while (status === 'PENDING' || status === 'RUNNING');
  
  // Résultat final
  if (status === 'SUCCEEDED') {
    console.log('✅ Notebook terminé avec succès');
  } else {
    console.log('❌ Échec:', statusResult.error_summary);
  }
  
  return statusResult;
}
```

### **Pattern 3 : Création et Exécution Complète**

```javascript
async function createAndExecuteNotebook(notebookPath, cells) {
  // Créer notebook
  await mcp.callTool('jupyter-papermill-mcp-server', 'create_notebook', {
    path: notebookPath,
    kernel: 'python3'
  });
  
  // Ajouter cellules
  for (const cell of cells) {
    await mcp.callTool('jupyter-papermill-mcp-server', 'add_cell', {
      path: notebookPath,
      cell_type: cell.type,
      source: cell.code
    });
  }
  
  // Exécuter (méthode async recommandée)
  return await executeLongNotebook(notebookPath);
}

// Usage
const cells = [
  { type: 'markdown', code: '# Test Notebook\nNotebook généré automatiquement' },
  { type: 'code', code: 'import pandas as pd\nprint("Pandas importé")' },
  { type: 'code', code: 'df = pd.DataFrame({"test": [1,2,3]})\nprint(df)' }
];

await createAndExecuteNotebook('./test-generated.ipynb', cells);
```

---

## 🔧 BONNES PRATIQUES

### **✅ À Faire**

1. **Toujours utiliser l'exécution asynchrone** pour notebooks > 1 minute
2. **Nettoyer les kernels** après utilisation (`stop_kernel`)
3. **Vérifier la connectivité** (`system_info`) avant opérations lourdes
4. **Monitorer les jobs** avec `get_execution_status_async`
5. **Utiliser des timeouts appropriés** selon complexité notebook

### **❌ À Éviter**

1. **Ne pas compter sur execute_notebook_sync** pour notebooks longs
2. **Ne pas oublier d'arrêter les kernels** (fuite mémoire)
3. **Ne pas lancer trop de jobs simultanés** (ressources limitées)
4. **Ne pas ignorer les erreurs** de gestion de chemin
5. **Ne pas modifier manuellement** le working directory du serveur

---

## 🚨 GESTION D'ERREURS

### **Erreurs Communes et Solutions**

#### **1. Timeout Client (60s)**
```
Error: Request timeout after 60 seconds
```
**Solution :** Utiliser `start_notebook_async` au lieu de `execute_notebook_sync`

#### **2. Kernel Non Trouvé**
```
NoSuchKernel: No such kernel named .net-csharp
```
**Solution :** 
- Lister kernels disponibles : `list_kernels`
- Installer kernel manquant si nécessaire
- Fallback sur `python3`

#### **3. Fichier Non Trouvé**
```
FileNotFoundError: [Errno 2] No such file or directory
```
**Solution :**
- Vérifier chemin absolu
- Tester avec `list_notebook_files` dans répertoire parent

#### **4. Job Échoué**
```
status: "FAILED", return_code: 1
```
**Solution :**
- Récupérer logs : `get_job_logs`
- Analyser `error_summary`
- Vérifier dépendances notebook

---

## 📊 MONITORING ET DIAGNOSTICS

### **Surveillance des Performances**

```javascript
// Monitoring complet d'un job
async function monitorJob(jobId) {
  let iteration = 0;
  const maxIterations = 60; // Max 2 minutes de polling
  
  while (iteration < maxIterations) {
    const status = await mcp.callTool('jupyter-papermill-mcp-server',
      'get_execution_status_async', { job_id: jobId }
    );
    
    console.log(`[${iteration}] Status: ${status.status}, Duration: ${status.duration_seconds}s`);
    
    if (status.status === 'SUCCEEDED' || status.status === 'FAILED') {
      return status;
    }
    
    // Logs toutes les 10 itérations
    if (iteration % 10 === 0) {
      const logs = await mcp.callTool('jupyter-papermill-mcp-server',
        'get_job_logs', { job_id: jobId }
      );
      console.log('Recent logs:', logs.stderr_chunk.slice(-3));
    }
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    iteration++;
  }
  
  throw new Error('Job monitoring timeout');
}
```

### **Diagnostic Système**

```javascript
async function diagnosticComplet() {
  // État serveur
  const sysInfo = await mcp.callTool('jupyter-papermill-mcp-server', 'system_info', {});
  
  // Kernels disponibles
  const kernels = await mcp.callTool('jupyter-papermill-mcp-server', 'list_kernels', {});
  
  // Jobs en cours
  const jobs = await mcp.callTool('jupyter-papermill-mcp-server', 'list_jobs', {});
  
  // Statut global
  const execStatus = await mcp.callTool('jupyter-papermill-mcp-server', 'get_execution_status', {});
  
  return {
    system: sysInfo,
    kernels: kernels,
    activeJobs: jobs,
    executionStatus: execStatus
  };
}
```

---

## 🎯 CAS D'USAGE AVANCÉS

### **1. Notebooks avec Paramètres**

```javascript
// Exécuter notebook avec paramètres injectés
async function executeParameterizedNotebook(inputPath, parameters) {
  const result = await mcp.callTool('jupyter-papermill-mcp-server',
    'start_notebook_async', {
      input_path: inputPath,
      parameters: parameters,  // Dict de paramètres à injecter
      timeout_seconds: 180
    }
  );
  
  return result;
}

// Usage
await executeParameterizedNotebook('./analysis-template.ipynb', {
  data_file: '/path/to/data.csv',
  output_format: 'png',
  threshold: 0.85
});
```

### **2. Pipeline de Notebooks**

```javascript
async function executePipeline(notebooks) {
  const results = [];
  
  for (const notebook of notebooks) {
    console.log(`🔄 Exécution: ${notebook.path}`);
    
    const result = await mcp.callTool('jupyter-papermill-mcp-server',
      'start_notebook_async', {
        input_path: notebook.path,
        parameters: notebook.params || {},
        timeout_seconds: notebook.timeout || 180
      }
    );
    
    // Attendre completion
    let status;
    do {
      await new Promise(resolve => setTimeout(resolve, 3000));
      const statusCheck = await mcp.callTool('jupyter-papermill-mcp-server',
        'get_execution_status_async', { job_id: result.job_id }
      );
      status = statusCheck.status;
    } while (status === 'PENDING' || status === 'RUNNING');
    
    if (status !== 'SUCCEEDED') {
      throw new Error(`Pipeline échoué sur: ${notebook.path}`);
    }
    
    results.push(result);
    console.log(`✅ Terminé: ${notebook.path}`);
  }
  
  return results;
}
```

### **3. Gestion Multi-Kernel**

```javascript
async function executeMultiKernelNotebook(notebookPath, kernelName) {
  // Vérifier disponibilité kernel
  const kernels = await mcp.callTool('jupyter-papermill-mcp-server', 'list_kernels', {});
  
  const availableKernels = kernels.available_kernels || [];
  if (!availableKernels.includes(kernelName)) {
    console.log(`⚠️ Kernel ${kernelName} non disponible, fallback sur python3`);
    kernelName = 'python3';
  }
  
  // Démarrer kernel spécifique
  const kernel = await mcp.callTool('jupyter-papermill-mcp-server', 'start_kernel', {
    kernel_name: kernelName
  });
  
  try {
    // Exécuter notebook avec kernel personnalisé
    const result = await mcp.callTool('jupyter-papermill-mcp-server',
      'execute_notebook', {
        path: notebookPath,
        kernel_id: kernel.kernel_id
      }
    );
    
    return result;
  } finally {
    // Toujours nettoyer
    await mcp.callTool('jupyter-papermill-mcp-server', 'stop_kernel', {
      kernel_id: kernel.kernel_id
    });
  }
}
```

---

## 🏆 RÉSUMÉ EXÉCUTIF

### **✅ Le MCP Jupyter Corrigé**

- **Working directory stable** : Context manager validé à 100%
- **Performance prévisible** : Timeouts gérés, pas de crash
- **Production-ready** : Validé sur notebooks réels complexes
- **Multi-environnement** : Support Windows/Linux, Python/autres kernels

### **🎯 Recommandations Finales**

1. **Méthode async par défaut** : `start_notebook_async` pour tous notebooks
2. **Monitoring systématique** : Toujours surveiller jobs longs
3. **Gestion ressources** : Arrêter kernels inutilisés
4. **Tests réguliers** : Utiliser script validation automatisé

### **📞 En Cas de Problème**

1. Consulter ce guide d'abord
2. Utiliser `system_info` pour diagnostic
3. Vérifier logs avec `get_job_logs`
4. Tester script validation automatisé : `tests/mcp/validate-jupyter-mcp-endtoend.js`

---

**Le MCP Jupyter est maintenant prêt pour un usage intensif en production ! 🚀**