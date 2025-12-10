# 📘 Recommandations Intégration Multi-Agent System Safety

**Date** : 08 Octobre 2025  
**Spécification** : [`multi-agent-system-safety.md`](../specifications/multi-agent-system-safety.md)  
**Objectif** : Intégrer les règles multi-agent dans les instructions globales et mode-specific

---

## 🎯 Vue d'Ensemble

Cette spécification doit être intégrée à **tous les modes** manipulant des ressources système (processus, ports, fichiers, configuration). L'intégration se fait à deux niveaux :

1. **Instructions Globales** (`.roo/rules/`) : Règles applicables à tous modes
2. **Instructions Mode-Specific** : Règles renforcées pour modes système

---

## 📋 Niveau 1 : Instructions Globales

### Fichier à Créer : `.roo/rules/multi-agent-safety.md`

Ce fichier sera automatiquement chargé par Roo pour tous les modes.

```markdown
# Multi-Agent System Safety - Règles Globales

## 🚨 Principe Cardinal

**RÈGLE ABSOLUE** : Toujours supposer qu'il y a d'autres agents LLM travaillant simultanément sur cette machine.

Ne JAMAIS utiliser d'opérations affectant tous les processus/ressources sans ciblage spécifique.

---

## ❌ Opérations STRICTEMENT INTERDITES

Sans validation utilisateur explicite, les opérations suivantes sont **INTERDITES** :

### Processus
```powershell
# ❌ INTERDIT : Tue TOUS les processus de ce nom
Stop-Process -Name powershell -Force
Stop-Process -Name node -Force
Get-Process python | Stop-Process -Force
```

```bash
# ❌ INTERDIT : Tue TOUS les processus de ce nom
killall bash
pkill -9 python
killall -KILL node
```

**Pourquoi** : Tue processus d'autres agents, perte travail en cours

### Fichiers Temporaires
```powershell
# ❌ INTERDIT : Supprime TOUS les fichiers temporaires
Remove-Item "$env:TEMP\*" -Force -Recurse
Remove-Item "C:\Users\*\.cache" -Force -Recurse
```

```bash
# ❌ INTERDIT : Supprime TOUS les fichiers temporaires
rm -rf /tmp/*
rm -rf ~/.cache/*
```

**Pourquoi** : Supprime fichiers d'autres agents, corruption données

### Configuration Système
```powershell
# ❌ INTERDIT : Modifie configuration pour tous
[Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
Set-ItemProperty HKLM:\...
```

```bash
# ❌ INTERDIT : Modifie configuration globale
sudo echo "export PATH=/new/path" >> /etc/environment
sudo vim /etc/hosts
```

**Pourquoi** : Affecte tous utilisateurs et agents, risque incompatibilité

### Services et Système
```powershell
# ❌ INTERDIT : Affecte système entier
Restart-Computer
Shutdown /s /t 0
Stop-Service Docker
```

```bash
# ❌ INTERDIT : Affecte système entier
sudo reboot
sudo systemctl restart docker
sudo systemctl stop nginx
```

**Pourquoi** : Interrompt travail de tous agents et utilisateurs

---

## ✅ Règles OBLIGATOIRES

### 1. Ciblage Spécifique TOUJOURS

```powershell
# ✅ CORRECT : Utiliser PID spécifique
$myProcess = Start-Process app.exe -PassThru
$myPID = $myProcess.Id
# Plus tard...
Stop-Process -Id $myPID -Force
```

```python
# ✅ CORRECT : Conserver PID à la création
process = subprocess.Popen(['python', 'script.py'])
my_pid = process.pid
# Plus tard...
os.kill(my_pid, signal.SIGTERM)
```

### 2. Fichiers Temporaires : UUID Agent

```powershell
# ✅ CORRECT : Préfixer avec UUID agent
$agentUUID = [guid]::NewGuid().ToString()
$tempFile = "$env:TEMP\roo-agent-$agentUUID-output.log"

# Nettoyage ciblé
Get-ChildItem "$env:TEMP\roo-agent-$agentUUID-*" | Remove-Item -Force
```

```python
# ✅ CORRECT : UUID dans nom de fichier
import uuid
agent_uuid = str(uuid.uuid4())
temp_file = f"/tmp/roo-agent-{agent_uuid}-data.tmp"

# Nettoyage ciblé
import glob
for f in glob.glob(f"/tmp/roo-agent-{agent_uuid}-*"):
    os.remove(f)
```

### 3. Ports : Dynamiques (>= 10000)

```python
# ✅ CORRECT : Trouver port libre dynamiquement
def find_free_port(start=10000):
    for port in range(start, 65536):
        try:
            with socket.socket() as s:
                s.bind(('', port))
                return port
        except OSError:
            continue

port = find_free_port()
app.run(port=port)
```

### 4. Configuration : User Scope + Backup

```powershell
# ✅ CORRECT : User scope avec backup
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")

# Backup obligatoire
$backupPath = "$env:TEMP\path-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$userPath | Out-File $backupPath

# Modification User (pas Machine)
$newPath = "$userPath;C:\NewTool\bin"
[Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
```

---

## 🔍 Détection Autres Agents OBLIGATOIRE

Avant toute opération potentiellement impactante :

```powershell
# PowerShell : Détecter autres agents
$otherAgents = Get-Process code,powershell,pwsh,node -ErrorAction SilentlyContinue |
    Where-Object { $_.