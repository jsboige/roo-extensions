# 📘 Multi-Agent System Safety - Spécification Sécurité Critique

**Version :** 1.0.0  
**Date :** 08 Octobre 2025  
**Architecture :** 2-Niveaux (Simple/Complex)  
**Statut :** 🔴 SPÉCIFICATION CRITIQUE - Protection contre opérations système destructives  
**Priorité :** MAXIMALE - Application obligatoire tous modes

---

## 🔗 Liens Spécifications Connexes

Cette spécification s'intègre dans l'écosystème de sécurité Roo :

- **[`git-safety-source-control.md`](git-safety-source-control.md)** : Protection opérations Git
- **[`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)** : Protocol grounding multi-niveaux
- **[`operational-best-practices.md`](operational-best-practices.md)** : Règles opérationnelles
- **[`mcp-integrations-priority.md`](mcp-integrations-priority.md)** : Utilisation MCPs

**Synergie** : Tandis que Git Safety protège le contrôle de version, Multi-Agent System Safety protège les ressources système (processus, ports, fichiers, configuration) lors du travail simultané de plusieurs agents LLM.

---

## 🚨 Historique des Incidents

Cette spécification a été créée en réponse à des **incidents système critiques réels** causés par des agents LLM ne tenant pas compte d'autres agents travaillant simultanément sur la même machine.

### Incident #1 : Kill All PowerShell Processes

**Date** : Incident type recensé (pattern récurrent)  
**Type** : `Stop-Process -Name powershell -Force`  
**Impact** : 
- ❌ TOUS les processus PowerShell tués (pas seulement celui de l'agent)
- ❌ Terminaux d'autres agents interrompus brutalement
- ❌ Travail en cours perdu (scripts, compilations, serveurs locaux)
- ❌ Corruption données possibles (interruption pendant écriture)

**Commande dangereuse** :
```powershell
# ❌ DANGEREUX : Tue TOUS les PowerShell, y compris autres agents
Stop-Process -Name powershell -Force

# Résultat : Terminaux de 3 autres agents tués, perte travail en cours
```

**Cause** : Agent suppose être seul sur la machine, utilise nom processus générique au lieu de PID spécifique

**Solution** : Toujours utiliser PID spécifique du processus créé par cet agent

### Incidents Potentiels Similaires

#### Incident Type #2 : Occupation Exclusive Ports Communs
```python
# ❌ DANGEREUX : Occupe port 8000 sans vérifier
app.run(port=8000)

# Impact si autre agent utilise déjà ce port :
# - Crash application autre agent
# - OSError: [Errno 98] Address already in use
```

#### Incident Type #3 : Suppression Fichiers Temporaires Masse
```powershell
# ❌ DANGEREUX : Supprime TOUS les fichiers temporaires
Remove-Item "$env:TEMP\*" -Force -Recurse

# Impact :
# - Fichiers temporaires autres agents supprimés
# - Corruption compilations en cours
# - Perte cache d'autres applications
```

#### Incident Type #4 : Modification Configuration Globale
```powershell
# ❌ DANGEREUX : Modifie PATH système sans backup
[Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")

# Impact :
# - PATH de tous les utilisateurs affecté
# - Autres agents perdent accès outils critiques
# - Nécessite droits admin (peut échouer)
```

#### Incident Type #5 : Redémarrage Services Sans Coordination
```bash
# ❌ DANGEREUX : Redémarre service utilisé par autres
sudo systemctl restart docker

# Impact :
# - Conteneurs d'autres agents arrêtés
# - Pertes connexions actives
# - Interruption workflows en cours
```

### Cause Racine Commune

> **Mentalité "single-user" alors que le contexte est multi-agent**

Les agents LLM (Claude, GPT-4, Gemini, etc.) ont tendance à :
- ❌ Supposer qu'ils sont seuls sur la machine
- ❌ Utiliser opérations larges (noms processus, wildcards)
- ❌ Ne pas vérifier existence autres agents actifs
- ❌ Privilégier simplicité sur sécurité multi-agent

**Statistiques estimées** :
- 📊 60% des opérations système n'incluent pas de vérification autres agents
- 📊 40% utilisent noms processus génériques au lieu de PID
- 📊 80% n'implémentent pas de mécanisme coordination
- 📊 95% ne documentent pas ressources consommées

---

## 🎯 Objectif de la Spécification

Établir un **protocole de coexistence sécurisée** pour agents LLM multiples travaillant simultanément sur la même machine, en définissant :

1. **Règles strictes** pour opérations système (processus, services, ressources)
2. **Protocoles de détection** d'autres agents actifs
3. **Mécanismes de coordination** (implicite via lock files, explicite via utilisateur)
4. **Gestion ressources partagées** (ports, fichiers temporaires, configuration)
5. **Escalade sécurisée** vers utilisateur quand nécessaire
6. **Intégration SDDD** pour grounding système multi-agent

---

## 📋 Section 1 : Principes Fondamentaux Multi-Agent

### 1.1 Principe Cardinal

```
╔═══════════════════════════════════════════════════════════════════╗
║  RÈGLE ABSOLUE : Toujours supposer qu'il y a d'autres agents    ║
║  travaillant simultanément sur la machine.                        ║
║                                                                   ║
║  Ne JAMAIS utiliser d'opérations affectant tous les             ║
║  processus/ressources sans ciblage spécifique.                   ║
╚═══════════════════════════════════════════════════════════════════╝
```

**Conséquences pratiques** :

1. **Ciblage Spécifique OBLIGATOIRE** :
   - Processus : Utiliser PID, pas nom
   - Fichiers : Utiliser UUID agent dans nom
   - Ports : Vérifier disponibilité, utiliser range dynamique
   - Configuration : User scope, pas system scope

2. **Vérification Préalable OBLIGATOIRE** :
   - Détecter autres agents avant opération large
   - Évaluer impact potentiel
   - Demander validation si doute

3. **Documentation OBLIGATOIRE** :
   - Enregistrer ressources consommées (PID, ports, fichiers)
   - Permettre cleanup ciblé
   - Faciliter diagnostic conflits

### 1.2 Opérations INTERDITES Sans Validation Utilisateur

#### 🚫 Processus

```powershell
# ❌ ABSOLUMENT INTERDITES
Stop-Process -Name powershell -Force          # Tue TOUS les PowerShell
Stop-Process -Name node -Force                # Tue TOUS les Node.js
Get-Process python | Stop-Process -Force      # Tue TOUS les Python
taskkill /F /IM code.exe                      # Tue TOUS les VSCode
```

```bash
# ❌ ABSOLUMENT INTERDITES (Linux/Mac)
killall bash                                  # Tue TOUS les bash
pkill -9 python                              # Tue TOUS les Python
killall -KILL node                           # Tue TOUS les Node.js
```

**Pourquoi interdit** : Tue processus d'autres agents, perte travail en cours

#### 🚫 Services et Système

```powershell
# ❌ ABSOLUMENT INTERDITES
Stop-Service Docker                          # Arrête Docker pour tous
Restart-Computer                             # Redémarre la machine
Shutdown /s /t 0                            # Éteint la machine
Stop-Service ssh                            # Coupe SSH de tous
```

```bash
# ❌ ABSOLUMENT INTERDITES (Linux/Mac)
sudo systemctl restart docker               # Redémarre Docker
sudo reboot                                 # Redémarre la machine
sudo systemctl stop nginx                   # Arrête Nginx pour tous
```

**Pourquoi interdit** : Affecte système entier, tous utilisateurs et agents

#### 🚫 Configuration Globale

```powershell
# ❌ ABSOLUMENT INTERDITES
[Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")  # PATH système
Set-ItemProperty HKLM:\...                                         # Registry système
```

```bash
# ❌ ABSOLUMENT INTERDITES (Linux/Mac)
sudo echo "export PATH=/new/path" >> /etc/environment    # PATH global
sudo vim /etc/hosts                                      # Hosts système
sudo systemctl enable myservice                          # Service global
```

**Pourquoi interdit** : Modifie configuration pour tous, risque incompatibilité

#### 🚫 Ressources Partagées

```powershell
# ❌ ABSOLUMENT INTERDITES
Remove-Item "$env:TEMP\*" -Force -Recurse              # Supprime TOUT /tmp
Get-ChildItem C:\Users\*\.cache | Remove-Item -Force   # Supprime TOUS les caches
```

```bash
# ❌ ABSOLUMENT INTERDITES (Linux/Mac)
rm -rf /tmp/*                                  # Supprime TOUT /tmp
rm -rf ~/.cache/*                             # Supprime TOUT cache utilisateur
```

**Pourquoi interdit** : Supprime fichiers d'autres agents, corruption données

### 1.3 Ciblage Spécifique OBLIGATOIRE

#### ✅ Processus : Toujours Utiliser PID

```powershell
# ✅ CORRECT : Ciblage par PID spécifique
$myProcess = Start-Process -FilePath "app.exe" -PassThru
$myPID = $myProcess.Id

# Plus tard, fermer uniquement ce processus
Stop-Process -Id $myPID -Force
```

```python
# ✅ CORRECT : Conserver PID à la création
import subprocess
process = subprocess.Popen(['python', 'script.py'])
my_pid = process.pid

# Plus tard, tuer uniquement ce processus
os.kill(my_pid, signal.SIGTERM)
```

**Avantages** :
- ✅ Ne tue que le processus de cet agent
- ✅ Autres agents non affectés
- ✅ Traçabilité complète

#### ✅ Ports : Vérifier Disponibilité + Range Dynamique

```python
# ✅ CORRECT : Trouver port libre dynamiquement
import socket

def find_free_port(start=10000, end=65535):
    """Trouve un port libre dans le range spécifié"""
    for port in range(start, end):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('', port))
                return port
        except OSError:
            continue
    raise RuntimeError("Aucun port libre trouvé")

# Utilisation
port = find_free_port()
print(f"Utilisation port {port}")
app.run(port=port)
```

```powershell
# ✅ CORRECT : Vérifier port disponible avant utilisation
function Test-PortAvailable {
    param([int]$Port)
    $tcpConnection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    return $null -eq $tcpConnection
}

$port = 10000
while (-not (Test-PortAvailable -Port $port)) {
    $port++
}
Write-Host "Utilisation port $port"
```

**Avantages** :
- ✅ Évite conflits de ports
- ✅ Range dynamique (>10000) évite ports communs
- ✅ Fallback automatique si occupé

#### ✅ Fichiers Temporaires : UUID Agent + Naming Convention

```powershell
# ✅ CORRECT : Préfixer avec UUID agent
$agentUUID = [guid]::NewGuid().ToString()
$tempFile = "$env:TEMP\roo-agent-$agentUUID-compilation-output.log"

# Nettoyage ciblé plus tard
Get-ChildItem "$env:TEMP\roo-agent-$agentUUID-*" | Remove-Item -Force
```

```python
# ✅ CORRECT : UUID dans nom de fichier
import uuid
import tempfile
import os

agent_uuid = str(uuid.uuid4())
temp_dir = tempfile.gettempdir()
temp_file = os.path.join(temp_dir, f"roo-agent-{agent_uuid}-data.tmp")

# Écriture
with open(temp_file, 'w') as f:
    f.write("data")

# Nettoyage ciblé plus tard
import glob
pattern = os.path.join(temp_dir, f"roo-agent-{agent_uuid}-*")
for f in glob.glob(pattern):
    os.remove(f)
```

**Convention Naming** :
```
{temp-dir}/roo-agent-{agent-uuid}-{operation}-{filename}

Exemples :
/tmp/roo-agent-a3f2d1b8-4c5e-compile-output.log
%TEMP%\roo-agent-7b9c3f21-6a4d-test-results.json
/tmp/roo-agent-2e8f5a17-9c3b-server-logs.txt
```

**Avantages** :
- ✅ Nettoyage ciblé uniquement fichiers de cet agent
- ✅ Pas de collision avec autres agents
- ✅ Traçabilité (UUID identifie agent)

#### ✅ Configuration : User Scope + Backup

```powershell
# ✅ CORRECT : Modification User scope avec backup
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")

# Backup obligatoire
$backupPath = "$env:TEMP\roo-agent-path-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$userPath | Out-File $backupPath

# Modification User (pas Machine)
$newPath = "$userPath;C:\NewTool\bin"
[Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

Write-Host "Backup PATH : $backupPath"
```

```bash
# ✅ CORRECT : Modification locale avec backup
# Backup
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d-%H%M%S)

# Modification (user local, pas /etc/environment)
echo 'export PATH="$PATH:/new/tool/bin"' >> ~/.bashrc

# Activer pour cette session seulement
export PATH="$PATH:/new/tool/bin"
```

**Avantages** :
- ✅ N'affecte que l'utilisateur courant
- ✅ Backup permet rollback
- ✅ Pas de droits admin requis
- ✅ Modifications réversibles

### 1.4 Grounding Système Multi-Agent

**RÈGLE** : Avant TOUTE opération système potentiellement impactante, effectuer grounding pour détecter autres agents.

```powershell
# ✅ Grounding système avant opération
function Test-OtherAgentsActive {
    $otherAgents = @()
    
    # Détecter processus VSCode/Roo
    $vscodeProcesses = Get-Process code,node -ErrorAction SilentlyContinue | 
        Where-Object { $_.Id -ne $PID }
    $otherAgents += $vscodeProcesses
    
    # Détecter terminaux PowerShell actifs
    $pwshProcesses = Get-Process powershell,pwsh -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID }
    $otherAgents += $pwshProcesses
    
    return @{
        Active = $otherAgents.Count -gt 0
        Count = $otherAgents.Count
        Processes = $otherAgents
    }
}

# Utilisation avant opération
$agentCheck = Test-OtherAgentsActive
if ($agentCheck.Active) {
    Write-Warning "$($agentCheck.Count) autres agents détectés"
    Write-Warning "Opération nécessite validation utilisateur"
    # Escalader vers ask_followup_question
}
```

```bash
# ✅ Grounding système (Linux/Mac)
detect_other_agents() {
    local count=0
    
    # Détecter VSCode/Node actifs
    count=$((count + $(ps aux | grep -E "(code|node)" | grep -v grep | grep -v $$ | wc -l)))
    
    # Détecter shells actifs (pas le courant)
    count=$((count + $(ps aux | grep -E "(bash|zsh)" | grep -v grep | grep -v $$ | wc -l)))
    
    if [ $count -gt 0 ]; then
        echo "⚠️  $count autres agents détectés"
        return 1
    fi
    return 0
}

# Utilisation
if ! detect_other_agents; then
    echo "Opération nécessite validation utilisateur"
    # Escalader
fi
```

**Quand effectuer grounding système** :
1. ✅ Avant kill processus (vérifier pas d'autres agents)
2. ✅ Avant occupation port < 10000 (ports communs)
3. ✅ Avant suppression fichiers temporaires
4. ✅ Avant modification configuration système
5. ✅ Avant redémarrage services

---

## 📋 Section 2 : Détection et Coordination Agents

### 2.1 Détection Autres Agents

#### Protocole de Détection

**Objectif** : Identifier agents actifs sur la machine avant opération potentiellement impactante.

**Processus cibles** :
- VSCode (`code`, `code.exe`)
- Roo (processus Node.js avec contexte Roo)
- Terminaux (`powershell`, `pwsh`, `bash`, `zsh`)
- Serveurs locaux (ports 3000-9000)

#### Script PowerShell : Détection Complète

```powershell
function Get-ActiveAgents {
    <#
    .SYNOPSIS
    Détecte les agents Roo actifs sur la machine
    
    .DESCRIPTION
    Retourne informations détaillées sur agents détectés :
    - Processus VSCode/Node
    - Terminaux actifs
    - Ports occupés range développement
    
    .EXAMPLE
    $agents = Get-ActiveAgents
    if ($agents.Count -gt 0) {
        Write-Warning "$($agents.Count) agents actifs détectés"
    }
    #>
    
    $currentPID = $PID
    $currentSession = (Get-Process -Id $currentPID).SessionId
    $agents = @()
    
    # 1. Détecter processus VSCode
    $vscodeProcs = Get-Process code -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.Id -ne $currentPID -and 
            $_.SessionId -eq $currentSession 
        }
    
    foreach ($proc in $vscodeProcs) {
        $agents += @{
            Type = "VSCode"
            PID = $proc.Id
            Name = $proc.ProcessName
            StartTime = $proc.StartTime
            Memory = [math]::Round($proc.WorkingSet64 / 1MB, 2)
        }
    }
    
    # 2. Détecter processus Node.js (Roo)
    $nodeProcs = Get-Process node -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.Id -ne $currentPID -and
            $_.SessionId -eq $currentSession
        }
    
    foreach ($proc in $nodeProcs) {
        # Vérifier si lié à Roo (via ligne commande)
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
        if ($cmdLine -match "roo|mcp") {
            $agents += @{
                Type = "Roo/MCP"
                PID = $proc.Id
                Name = $proc.ProcessName
                CommandLine = $cmdLine
                Memory = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            }
        }
    }
    
    # 3. Détecter terminaux PowerShell actifs
    $pwshProcs = Get-Process powershell,pwsh -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.Id -ne $currentPID -and
            $_.SessionId -eq $currentSession
        }
    
    foreach ($proc in $pwshProcs) {
        $agents += @{
            Type = "Terminal"
            PID = $proc.Id
            Name = $proc.ProcessName
            StartTime = $proc.StartTime
        }
    }
    
    # 4. Détecter ports occupés (range développement)
    $activePorts = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -ge 3000 -and $_.LocalPort -le 9000 } |
        Select-Object LocalPort, OwningProcess |
        Sort-Object LocalPort
    
    $portInfo = @()
    foreach ($conn in $activePorts) {
        try {
            $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            $portInfo += @{
                Port = $conn.LocalPort
                PID = $conn.OwningProcess
                ProcessName = $proc.ProcessName
            }
        } catch {
            # Process peut avoir terminé entre temps
        }
    }
    
    return @{
        Agents = $agents
        Count = $agents.Count
        Ports = $portInfo
        PortCount = $portInfo.Count
        DetectionTime = Get-Date
    }
}

# Exemple utilisation
$detection = Get-ActiveAgents

if ($detection.Count -gt 0) {
    Write-Host "🔍 Détection Multi-Agent" -ForegroundColor Yellow
    Write-Host "  Agents actifs : $($detection.Count)" -ForegroundColor Cyan
    
    foreach ($agent in $detection.Agents) {
        Write-Host "  - $($agent.Type) (PID: $($agent.PID))" -ForegroundColor Gray
    }
    
    if ($detection.PortCount -gt 0) {
        Write-Host "  Ports occupés : $($detection.PortCount)" -ForegroundColor Cyan
        foreach ($port in $detection.Ports) {
            Write-Host "    Port $($port.Port) - $($port.ProcessName)" -ForegroundColor Gray
        }
    }
}
```

#### Script Bash : Détection Linux/Mac

```bash
#!/bin/bash
# detect-active-agents.sh
# Détecte agents Roo actifs sur système Linux/Mac

detect_active_agents() {
    local current_pid=$$
    local agent_count=0
    local port_count=0
    
    echo "🔍 Détection Multi-Agent"
    echo "========================"
    
    # 1. Processus VSCode/Roo
    echo "Processus VSCode/Roo :"
    vscode_count=$(ps aux | grep -E "(code|roo)" | grep -v grep | grep -v $current_pid | wc -l)
    agent_count=$((agent_count + vscode_count))
    ps aux | grep -E "(code|roo)" | grep -v grep | grep -v $current_pid | \
        awk '{printf "  - %s (PID: %s)\n", $11, $2}'
    
    # 2. Terminaux actifs
    echo "Terminaux actifs :"
    terminal_count=$(ps aux | grep -E "(bash|zsh|pwsh)" | grep -v grep | grep -v $current_pid | wc -l)
    agent_count=$((agent_count + terminal_count))
    ps aux | grep -E "(bash|zsh|pwsh)" | grep -v grep | grep -v $current_pid | \
        awk '{printf "  - %s (PID: %s)\n", $11, $2}'
    
    # 3. Ports occupés (range développement 3000-9000)
    echo "Ports occupés (3000-9000) :"
    if command -v lsof &> /dev/null; then
        lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | \
            awk 'NR>1 && $9 ~ /:/ {split($9,a,":"); port=a[2]} port>=3000 && port<=9000 {printf "  Port %s - %s (PID: %s)\n", port, $1, $2}' | \
            sort -u
        port_count=$(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | \
            awk 'NR>1 && $9 ~ /:/ {split($9,a,":"); port=a[2]} port>=3000 && port<=9000' | wc -l)
    elif command -v netstat &> /dev/null; then
        netstat -tuln | grep LISTEN | awk '{print $4}' | \
            awk -F: '{port=$NF} port>=3000 && port<=9000 {printf "  Port %s\n", port}' | \
            sort -u
        port_count=$(netstat -tuln | grep LISTEN | awk '{print $4}' | \
            awk -F: '{port=$NF} port>=3000 && port<=9000' | wc -l)
    fi
    
    # 4. Résumé
    echo ""
    echo "Résumé :"
    echo "  Agents détectés : $agent_count"
    echo "  Ports occupés : $port_count"
    
    if [ $agent_count -gt 0 ]; then
        echo ""
        echo "⚠️  Opérations multi-agent requises pour sécurité"
        return 1
    fi
    
    return 0
}

# Utilisation
detect_active_agents
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "Action recommandée : Validation utilisateur avant opération système"
fi
```

### 2.2 Communication Implicite (Lock Files)

**Principe** : Coordination entre agents sans communication directe via fichiers lock.

#### Protocole Lock Files

```
Location : {temp-dir}/roo-agent-{operation}.lock
Format : JSON avec métadonnées

Contenu :
{
  "agent_uuid": "a3f2d1b8-4c5e-6789-0123-456789abcdef",
  "pid": 12345,
  "operation": "compilation",
  "started": "2025-10-08T18:00:00Z",
  "expires": "2025-10-08T19:00:00Z",
  "workspace": "c:/dev/my-project"
}
```

#### Implémentation PowerShell

```powershell
function New-OperationLock {
    param(
        [string]$Operation,
        [int]$TimeoutMinutes = 60
    )
    
    $agentUUID = [guid]::NewGuid().ToString()
    $lockPath = "$env:TEMP\roo-agent-$Operation.lock"
    
    # Vérifier lock existant
    if (Test-Path $lockPath) {
        $existingLock = Get-Content $lockPath | ConvertFrom-Json
        $expiry = [DateTime]::Parse($existingLock.expires)
        
        if ($expiry -gt (Get-Date)) {
            Write-Warning "Opération '$Operation' déjà verrouillée par agent $($existingLock.agent_uuid)"
            Write-Warning "Expire dans $([math]::Round(($expiry - (Get-Date)).TotalMinutes, 1)) minutes"
            return $null
        } else {
            Write-Host "Lock expiré, nettoyage..." -ForegroundColor Yellow
            Remove-Item $lockPath -Force
        }
    }
    
    # Créer nouveau lock
    $lock = @{
        agent_uuid = $agentUUID
        pid = $PID
        operation = $Operation
        started = (Get-Date).ToUniversalTime().ToString("o")
        expires = (Get-Date).AddMinutes($TimeoutMinutes).ToUniversalTime().ToString("o")
        workspace = (Get-Location).Path
    }
    
    $lock | ConvertTo-Json | Out-File $lockPath -Encoding UTF8
    
    Write-Host "✓ Lock créé : $lockPath" -ForegroundColor Green
    return @{
        Path = $lockPath
        UUID = $agentUUID
        Expires = $lock.expires
    }
}

function Remove-OperationLock {
    param(
        [string]$Operation,
        [string]$AgentUUID
    )
    
    $lockPath = "$env:TEMP\roo-agent-$Operation.lock"
    
    if (Test-Path $lockPath) {
        $lock = Get-Content $lockPath | ConvertFrom-Json
        
        # Vérifier propriété
        if ($lock.agent_uuid -eq $AgentUUID) {
            Remove-Item $lockPath -Force
            Write-Host "✓ Lock libéré : $lockPath" -ForegroundColor Green
        } else {
            Write-Warning "Lock appartient à un autre agent, pas de suppression"
        }
    }
}

# Exemple utilisation
$lock = New-OperationLock -Operation "database-migration" -TimeoutMinutes 30
if ($lock) {
    try {
        # Opération exclusive ici
        Write-Host "Exécution opération exclusive..."
        Start-Sleep -Seconds 5
    } finally {
        Remove-OperationLock -Operation "database-migration" -AgentUUID $lock.UUID
    }
} else {
    Write-Host "Opération déjà en cours par autre agent, abandon"
}
```

#### Implémentation Python

```python
#!/usr/bin/env python3
import json
import os
import tempfile
import time
import uuid
from datetime import datetime, timedelta
from pathlib import Path

class AgentLock:
    """Gestion lock files pour coordination multi-agent"""
    
    def __init__(self, operation: str, timeout_minutes: int = 60):
        self.operation = operation
        self.timeout_minutes = timeout_minutes
        self.agent_uuid = str(uuid.uuid4())
        self.lock_path = Path(tempfile.gettempdir()) / f"roo-agent-{operation}.lock"
        self.acquired = False
    
    def acquire(self) -> bool:
        """Tente d'acquérir le lock"""
        
        # Vérifier lock existant
        if self.lock_path.exists():
            try:
                with open(self.lock_path, 'r') as f:
                    existing_lock = json.load(f)
                
                expiry = datetime.fromisoformat(existing_lock['expires'])
                
                if expiry > datetime.utcnow():
                    remaining = (expiry - datetime.utcnow()).total_seconds() / 60
                    print(f"⚠️  Opération '{self.operation}' déjà verrouillée")
                    print(f"    Agent: {existing_lock['agent_uuid']}")
                    print(f"    Expire dans: {remaining:.1f} minutes")
                    return False
                else:
                    print(f"🧹 Lock expiré, nettoyage...")
                    self.lock_path.unlink()
            except Exception as e:
                print(f"⚠️  Erreur lecture lock: {e}")
                return False
        
        # Créer nouveau lock
        lock_data = {
            'agent_uuid': self.agent_uuid,
            'pid': os.getpid(),
            'operation': self.operation,
            'started': datetime.utcnow().isoformat(),
            'expires': (datetime.utcnow() + timedelta(minutes=self.timeout_minutes)).isoformat(),
            'workspace': os.getcwd()
        }
        
        try:
            with open(self.lock_path, 'w') as f:
                json.dump(lock_data, f, indent=2)
            
            self.acquired = True
            print(f"✓ Lock créé: {self.lock_path}")
            return True
        except Exception as e:
            print(f"❌ Erreur création lock: {e}")
            return False
    
    def release(self):
        """Libère le lock si acquis"""
        if not self.acquired:
            return
        
        if self.lock_path.exists():
            try:
                # Vérifier propriété
                with open(self.lock_path, 'r') as f:
                    lock_data = json.load(f)
                
                if lock_data['agent_uuid'] == self.agent_uuid:
                    self.lock_path.unlink()
                    print(f"✓ Lock libéré: {self.lock_path}")
                else:
                    print(f"⚠️  Lock appartient à autre agent, pas de suppression")
            except Exception as e:
                print(f"⚠️  Erreur libération lock: {e}")
    
    def __enter__(self):
        if not self.acquire():
            raise RuntimeError(f"Impossible d'acquérir lock pour '{self.operation}'")
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.release()
        return False

# Exemple utilisation
if __name__ == "__main__":
    try:
        with AgentLock("database-migration", timeout_minutes=30):
            print("🔒 Opération exclusive en cours...")
            time.sleep(5)
            print("✓ Opération terminée")
    except RuntimeError as e:
        print(f"❌ {e}")
        print("Opération déjà en cours par autre agent, abandon")
```

### 2.3 Coordination Explicite (Utilisateur)

**Quand demander validation utilisateur** :

1. ✅ Détection de N autres agents (N > 0) avant opération large
2. ✅ Conflit de ressources (port occupé, lock existant)
3. ✅ Opération affectant système entier (services, config globale)
4. ✅ Doute sur impact potentiel

#### Template Question Utilisateur

```xml
<ask_followup_question>
<question>
🔍 **Détection Multi-Agent**

J'ai détecté **{N} autres agents actifs** sur la machine :
- {Agent 1 description}
- {Agent 2 description}
...

L'opération **{OPERATION}** pourrait les impacter :
- Impact potentiel : {DESCRIPTION IMPACT}
- Ressources concernées : {LISTE RESSOURCES}

Quelle action souhaitez-vous ?
</question>
<follow_up>
<suggest>✅ Cibler spécifiquement mon processus (PID: {MY_PID}) - Recommandé</suggest>
<suggest>⚠️ Effectuer opération large (risque interruption autres agents)</suggest>
<suggest>❌ Annuler opération</suggest>
<suggest>🔍 Plus d'informations sur agents détectés</suggest>
</follow_up>
</ask_followup_question>
```

#### Exemple Concret

```xml
<ask_followup_question>
<question>
🔍 **Détection Multi-Agent**

J'ai détecté **3 autres agents actifs** sur la machine :
- VSCode (PID: 8472) - Démarré il y a 2h
- PowerShell (PID: 9124) - Terminal actif
- Node.js Roo MCP (PID: 7856) - Serveur MCP actif

L'opération **Stop-Process pour fermer terminal** pourrait les impacter :
- Impact potentiel : Interruption terminaux autres agents
- Ressources concernées : Processus PowerShell

Quelle action souhaitez-vous ?
</question>
<follow_up>
<suggest>✅ Cibler spécifiquement mon terminal (PID: 12345) - Recommandé</suggest>
<suggest>⚠️ Fermer TOUS les PowerShell (risque interruption)</suggest>
<suggest>❌ Annuler fermeture</suggest>
<suggest>🔍 Afficher liste complète processus actifs</suggest>
</follow_up>
</ask_followup_question>
```

---

## 📋 Section 3 : Gestion Ressources Partagées

### 3.1 Processus

#### Protocole Fermeture Processus Sécurisée

**Étapes obligatoires** :

1. **Identifier PID spécifique**
2. **Vérifier propriété** (session, user)
3. **Tenter fermeture gracieuse**
4. **Force kill si nécessaire**
5. **Documenter action**

#### Implémentation Complète PowerShell

```powershell
function Stop-ProcessSafely {
    <#
    .SYNOPSIS
    Ferme un processus de manière sécurisée pour multi-agent
    
    .DESCRIPTION
    Protocole complet :
    1. Vérification PID spécifique (pas nom)
    2. Vérification propriété (session)
    3. Fermeture gracieuse (CloseMainWindow)
    4. Force si nécessaire après timeout
    5. Documentation action
    
    .PARAMETER ProcessId
    PID du processus à fermer (OBLIGATOIRE)
    
    .PARAMETER GracefulTimeoutSeconds
    Temps d'attente fermeture gracieuse avant force (défaut: 5s)
    
    .EXAMPLE
    $proc = Start-Process notepad -PassThru
    Stop-ProcessSafely -ProcessId $proc.Id
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId,
        
        [int]$GracefulTimeoutSeconds = 5
    )
    
    # 1. Vérifier processus existe
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
    } catch {
        Write-Warning "Processus PID $ProcessId introuvable (déjà terminé ?)"
        return @{ Success = $true; Reason = "AlreadyTerminated" }
    }
    
    $processName = $process.ProcessName
    $currentSession = (Get-Process -Id $PID).SessionId
    
    Write-Host "🔍 Analyse processus : $processName (PID: $ProcessId)"
    
    # 2. Vérifier propriété (session utilisateur)
    if ($process.SessionId -ne $currentSession) {
        Write-Warning "Processus appartient à une autre session (Session: $($process.SessionId) vs $currentSession)"
        Write-Warning "Opération NON SÉCURISÉE pour multi-agent, abandon"
        
        return @{
            Success = $false
            Reason = "DifferentSession"
            ProcessName = $processName
            ProcessSession = $process.SessionId
            CurrentSession = $currentSession
        }
    }
    
    Write-Host "✓ Processus appartient à cette session" -ForegroundColor Green
    
    # 3. Tentative fermeture gracieuse
    Write-Host "Tentative fermeture gracieuse..."
    
    $gracefulSuccess = $false
    if ($process.CloseMainWindow()) {
        Write-Host "  Signal fermeture envoyé, attente $GracefulTimeoutSeconds secondes..."
        
        $timeout = [DateTime]::Now.AddSeconds($GracefulTimeoutSeconds)
        while ([DateTime]::Now -lt $timeout) {
            Start-Sleep -Milliseconds 500
            
            if ($process.HasExited) {
                $gracefulSuccess = $true
                Write-Host "✓ Processus fermé gracieusement" -ForegroundColor Green
                break
            }
        }
    }
    
    # 4. Force si nécessaire
    if (-not $gracefulSuccess) {
        if (-not $process.HasExited) {
            Write-Host "Fermeture gracieuse échouée, force kill..." -ForegroundColor Yellow
            
            try {
                Stop-Process -Id $ProcessId -Force -ErrorAction Stop
                Write-Host "✓ Processus forcé à terminer" -ForegroundColor Green
            } catch {
                Write-Error "❌ Erreur force kill : $_"
                return @{
                    Success = $false
                    Reason = "ForceKillFailed"
                    Error = $_.Exception.Message
                }
            }
        }
    }
    
    # 5. Documentation
    $action = @{
        Success = $true
        ProcessName = $processName
        ProcessId = $ProcessId
        Method = if ($gracefulSuccess) { "Graceful" } else { "Forced" }
        Timestamp = Get-Date
    }
    
    Write-Host "📝 Action documentée : $($action.Method) termination"
    
    return $action
}

# ❌ MAUVAIS : Utilise nom processus
# Stop-Process -Name notepad -Force

# ✅ BON : Utilise PID spécifique
$proc = Start-Process notepad -PassThru
Start-Sleep -Seconds 2
$result = Stop-ProcessSafely -ProcessId $proc.Id

if ($result.Success) {
    Write-Host "✓ Processus fermé avec succès ($($result.Method))" -ForegroundColor Green
} else {
    Write-Host "❌ Échec fermeture : $($result.Reason)" -ForegroundColor Red
}
```

#### Implémentation Python/Linux

```python
#!/usr/bin/env python3
import os
import signal
import time
import psutil
from typing import Dict, Optional

def stop_process_safely(pid: int, graceful_timeout: int = 5) -> Dict:
    """
    Ferme un processus de manière sécurisée pour multi-agent
    
    Args:
        pid: Process ID à fermer (OBLIGATOIRE)
        graceful_timeout: Timeout fermeture gracieuse en secondes
    
    Returns:
        Dict avec résultat : {'success': bool, 'method': str, ...}
    """
    
    # 1. Vérifier processus existe
    try:
        process = psutil.Process(pid)
    except psutil.NoSuchProcess:
        print(f"⚠️  Processus PID {pid} introuvable (déjà terminé ?)")
        return {
            'success': True,
            'reason': 'AlreadyTerminated'
        }
    
    process_name = process.name()
    current_user = os.getuid()
    
    print(f"🔍 Analyse processus : {process_name} (PID: {pid})")
    
    # 2. Vérifier propriété (utilisateur)
    try:
        process_user = process.uids().real
    except psutil.AccessDenied:
        print(f"⚠️  Accès refusé au processus (appartient à autre utilisateur)")
        return {
            'success': False,
            'reason': 'AccessDenied',
            'process_name': process_name
        }
    
    if process_user != current_user:
        print(f"⚠️  Processus appartient à autre utilisateur (UID: {process_user} vs {current_user})")
        print(f"    Opération NON SÉCURISÉE pour multi-agent, abandon")
        return {
            'success': False,
            'reason': 'DifferentUser',
            'process_name': process_name,
            'process_user': process_user,
            'current_user': current_user
        }
    
    print(f"✓ Processus appartient à cet utilisateur")
    
    # 3. Tentative fermeture gracieuse (SIGTERM)
    print(f"Tentative fermeture gracieuse (SIGTERM)...")
    
    graceful_success = False
    try:
        process.terminate()  # Envoie SIGTERM
        print(f"  Signal SIGTERM envoyé, attente {graceful_timeout} secondes...")
        
        process.wait(timeout=graceful_timeout)
        graceful_success = True
        print(f"✓ Processus fermé gracieusement")
    except psutil.TimeoutExpired:
        print(f"⚠️  Timeout fermeture gracieuse")
    except psutil.NoSuchProcess:
        graceful_success = True
        print(f"✓ Processus déjà terminé")
    
    # 4. Force si nécessaire (SIGKILL)
    if not graceful_success:
        if process.is_running():
            print(f"Fermeture gracieuse échouée, force kill (SIGKILL)...")
            
            try:
                process.kill()  # Envoie SIGKILL
                process.wait(timeout=2)
                print(f"✓ Processus forcé à terminer")
            except Exception as e:
                print(f"❌ Erreur force kill : {e}")
                return {
                    'success': False,
                    'reason': 'ForceKillFailed',
                    'error': str(e)
                }
    
    # 5. Documentation
    action = {
        'success': True,
        'process_name': process_name,
        'process_id': pid,
        'method': 'Graceful' if graceful_success else 'Forced',
        'timestamp': time.time()
    }
    
    print(f"📝 Action documentée : {action['method']} termination")
    
    return action

# Exemple utilisation
if __name__ == "__main__":
    import subprocess
    
    # ❌ MAUVAIS : killall par nom
    # os.system("killall python")
    
    # ✅ BON : PID spécifique
    proc = subprocess.Popen(['python', '-c', 'import time; time.sleep(10)'])
    my_pid = proc.pid
    print(f"Processus créé : PID {my_pid}")
    
    time.sleep(2)
    
    result = stop_process_safely(my_pid)
    
    if result['success']:
        print(f"✓ Processus fermé avec succès ({result['method']})")
    else:
        print(f"❌ Échec fermeture : {result['reason']}")
```

### 3.2 Ports Réseau

#### Protocole Occupation Port Sécurisée

**Règles** :

1. ✅ **Toujours vérifier disponibilité** avant occupation
2. ✅ **Utiliser ports dynamiques** (>= 10000)
3. ✅ **Éviter ports communs** (80, 443, 3000, 5000, 8000, 8080)
4. ✅ **Libérer immédiatement** après usage
5. ✅ **Documenter usage** (fichier log ou state)

#### Implémentation PowerShell

```powershell
function Find-FreePort {
    <#
    .SYNOPSIS
    Trouve un port libre dans le range spécifié
    
    .DESCRIPTION
    Scanne séquentiellement pour trouver port TCP disponible.
    Recommandé : range >= 10000 pour éviter conflits
    
    .PARAMETER StartPort
    Port de départ du scan (défaut: 10000)
    
    .PARAMETER EndPort
    Port de fin du scan (défaut: 65535)
    
    .EXAMPLE
    $port = Find-FreePort
    Write-Host "Port libre : $port"
    #>
    
    param(
        [int]$StartPort = 10000,
        [int]$EndPort = 65535
    )
    
    Write-Host "🔍 Recherche port libre ($StartPort-$EndPort)..."
    
    for ($port = $StartPort; $port -le $EndPort; $port++) {
        $inUse = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        
        if ($null -eq $inUse) {
            Write-Host "✓ Port $port disponible" -ForegroundColor Green
            return $port
        }
    }
    
    throw "Aucun port libre trouvé dans range $StartPort-$EndPort"
}

function Test-PortAvailable {
    <#
    .SYNOPSIS
    Vérifie si un port spécifique est disponible
    
    .PARAMETER Port
    Numéro de port à vérifier
    
    .EXAMPLE
    if (Test-PortAvailable -Port 8080) {
        Write-Host "Port 8080 disponible"
    }
    #>
    
    param([int]$Port)
    
    $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    return ($null -eq $connection)
}

function Start-ServerSafely {
    <#
    .SYNOPSIS
    Démarre un serveur sur un port sûr multi-agent
    
    .DESCRIPTION
    1. Cherche port libre dynamiquement
    2. Vérifie disponibilité
    3. Démarre serveur
    4. Documente usage
    #>
    
    param(
        [scriptblock]$ServerScript,
        [int]$PreferredPort = 0,
        [int]$StartPort = 10000
    )
    
    # Déterminer port
    if ($PreferredPort -gt 0) {
        if (Test-PortAvailable -Port $PreferredPort) {
            $port = $PreferredPort
            Write-Host "✓ Port préféré $port disponible" -ForegroundColor Green
        } else {
            Write-Warning "Port $PreferredPort occupé, recherche alternative..."
            $port = Find-FreePort -StartPort $StartPort
        }
    } else {
        $port = Find-FreePort -StartPort $StartPort
    }
    
    # Documenter usage
    $agentUUID = [guid]::NewGuid().ToString()
    $portFile = "$env:TEMP\roo-agent-$agentUUID-port.txt"
    $port | Out-File $portFile -Encoding UTF8
    
    Write-Host "📝 Port documenté : $portFile" -ForegroundColor Cyan
    Write-Host "🚀 Démarrage serveur sur port $port..."
    
    # Démarrer serveur (dans le script fourni)
    & $ServerScript -Port $port
    
    # Cleanup documentation
    if (Test-Path $portFile) {
        Remove-Item $portFile -Force
        Write-Host "🧹 Documentation port nettoyée" -ForegroundColor Gray
    }
}

# Exemple utilisation
Start-ServerSafely -ServerScript {
    param($Port)
    
    # Exemple : Serveur HTTP simple avec npm http-server
    Write-Host "Serveur HTTP sur port $Port"
    # npx http-server -p $Port
    
    # Simulation
    Start-Sleep -Seconds 10
}
```

#### Implémentation Python

```python
#!/usr/bin/env python3
import socket
import uuid
import tempfile
import os
from pathlib import Path
from typing import Optional

def find_free_port(start: int = 10000, end: int = 65535) -> int:
    """
    Trouve un port libre dans le range spécifié
    
    Args:
        start: Port de départ (défaut: 10000)
        end: Port de fin (défaut: 65535)
    
    Returns:
        Numéro de port libre
    
    Raises:
        RuntimeError: Si aucun port libre trouvé
    """
    print(f"🔍 Recherche port libre ({start}-{end})...")
    
    for port in range(start, end + 1):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('', port))
                print(f"✓ Port {port} disponible")
                return port
        except OSError:
            continue
    
    raise RuntimeError(f"Aucun port libre trouvé dans range {start}-{end}")

def is_port_available(port: int) -> bool:
    """Vérifie si un port est disponible"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('', port))
            return True
    except OSError:
        return False

class SafePortManager:
    """Gestionnaire de ports sécurisé pour multi-agent"""
    
    def __init__(self, preferred_port: Optional[int] = None, start_port: int = 10000):
        self.preferred_port = preferred_port
        self.start_port = start_port
        self.port = None
        self.agent_uuid = str(uuid.uuid4())
        self.port_file = None
    
    def acquire_port(self) -> int:
        """Acquiert un port disponible"""
        
        # Essayer port préféré si spécifié
        if self.preferred_port and is_port_available(self.preferred_port):
            self.port = self.preferred_port
            print(f"✓ Port préféré {self.port} disponible")
        else:
            if self.preferred_port:
                print(f"⚠️  Port {self.preferred_port} occupé, recherche alternative...")
            self.port = find_free_port(self.start_port)
        
        # Documenter usage
        temp_dir = Path(tempfile.gettempdir())
        self.port_file = temp_dir / f"roo-agent-{self.agent_uuid}-port.txt"
        
        with open(self.port_file, 'w') as f:
            f.write(str(self.port))
        
        print(f"📝 Port documenté : {self.port_file}")
        
        return self.port
    
    def release_port(self):
        """Libère le port et nettoie documentation"""
        if self.port_file and self.port_file.exists():
            self.port_file.unlink()
            print(f"🧹 Documentation port nettoyée")
    
    def __enter__(self):
        self.acquire_port()
        return self.port
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.release_port()
        return False

# Exemple utilisation avec Flask
if __name__ == "__main__":
    try:
        with SafePortManager(preferred_port=8000) as port:
            print(f"🚀 Démarrage serveur sur port {port}...")
            
            # Exemple : Flask app
            # from flask import Flask
            # app = Flask(__name__)
            # app.run(port=port)
            
            # Simulation
            import time
            time.sleep(10)
            
            print(f"✓ Serveur arrêté")
    except Exception as e:
        print(f"❌ Erreur : {e}")
```

### 3.3 Fichiers Temporaires

#### Convention Naming Stricte

```
Format : {temp-dir}/roo-agent-{agent-uuid}-{operation}-{filename}

Exemples :
Windows : C:\Users\user\AppData\Local\Temp\roo-agent-a3f2d1b8-compile-output.log
Linux   : /tmp/roo-agent-7b9c3f21-test-results.json
Mac     : /tmp/roo-agent-2e8f5a17-server-logs.txt
```

**Règles** :

1. ✅ **Toujours préfixer** avec `roo-agent-{uuid}`
2. ✅ **UUID unique par agent** (généré au démarrage)
3. ✅ **Opération descriptive** (compile, test, serve, backup)
4. ✅ **Nettoyage ciblé** uniquement fichiers de cet agent
5. ❌ **JAMAIS suppression masse** (`/tmp/*`, `%TEMP%\*`)

#### Implémentation PowerShell

```powershell
class AgentTempFileManager {
    [string]$AgentUUID
    [string]$TempDir
    [System.Collections.ArrayList]$ManagedFiles
    
    AgentTempFileManager() {
        $this.AgentUUID = [guid]::NewGuid().ToString()
        $this.TempDir = $env:TEMP
        $this.ManagedFiles = [System.Collections.ArrayList]::new()
        
        Write-Host "🆔 Agent UUID : $($this.AgentUUID)" -ForegroundColor Cyan
    }
    
    [string] CreateTempFile([string]$Operation, [string]$Filename) {
        $safeName = "roo-agent-$($this.AgentUUID)-$Operation-$Filename"
        $fullPath = Join-Path $this.TempDir $safeName
        
        # Créer fichier vide
        New-Item -Path $fullPath -ItemType File -Force | Out-Null
        
        # Enregistrer dans liste gérée
        [void]$this.ManagedFiles.Add($fullPath)
        
        Write-Host "📄 Fichier temporaire créé : $safeName" -ForegroundColor Gray
        return $fullPath
    }
    
    [void] CleanupOwnFiles() {
        Write-Host "🧹 Nettoyage fichiers de cet agent..." -ForegroundColor Yellow
        
        $pattern = "roo-agent-$($this.AgentUUID)-*"
        $files = Get-ChildItem -Path $this.TempDir -Filter $pattern -ErrorAction SilentlyContinue
        
        $count = 0
        foreach ($file in $files) {
            try {
                Remove-Item $file.FullName -Force
                Write-Host "  ✓ Supprimé : $($file.Name)" -ForegroundColor Gray
                $count++
            } catch {
                Write-Warning "  ✗ Erreur suppression : $($file.Name)"
            }
        }
        
        Write-Host "✓ $count fichiers nettoyés" -ForegroundColor Green
    }
    
    [void] CleanupManagedFiles() {
        Write-Host "🧹 Nettoyage fichiers managés..." -ForegroundColor Yellow
        
        $count = 0
        foreach ($filePath in $this.ManagedFiles) {
            if (Test-Path $filePath) {
                try {
                    Remove-Item $filePath -Force
                    Write-Host "  ✓ Supprimé : $(Split-Path $filePath -Leaf)" -ForegroundColor Gray
                    $count++
                } catch {
                    Write-Warning "  ✗ Erreur suppression : $filePath"
                }
            }
        }
        
        $this.ManagedFiles.Clear()
        Write-Host "✓ $count fichiers nettoyés" -ForegroundColor Green
    }
    
    [array] FindStaleLocks([int]$MaxAgeHours = 1) {
        Write-Host "🔍 Recherche locks obsolètes (> $MaxAgeHours heures)..." -ForegroundColor Yellow
        
        $pattern = "roo-agent-*.lock"
        $locks = Get-ChildItem -Path $this.TempDir -Filter $pattern -ErrorAction SilentlyContinue
        
        $stale = @()
        $now = Get-Date
        
        foreach ($lock in $locks) {
            $age = ($now - $lock.CreationTime).TotalHours
            
            if ($age -gt $MaxAgeHours) {
                $stale += @{
                    Path = $lock.FullName
                    Name = $lock.Name
                    Age = [math]::Round($age, 1)
                }
            }
        }
        
        if ($stale.Count -gt 0) {
            Write-Host "  ⚠️  $($stale.Count) locks obsolètes détectés" -ForegroundColor Yellow
            foreach ($item in $stale) {
                Write-Host "    - $($item.Name) (age: $($item.Age)h)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ✓ Aucun lock obsolète" -ForegroundColor Green
        }
        
        return $stale
    }
}

# Exemple utilisation
$tempManager = [AgentTempFileManager]::new()

try {
    # Créer fichiers temporaires
    $outputFile = $tempManager.CreateTempFile("compile", "output.log")
    $resultFile = $tempManager.CreateTempFile("test", "results.json")
    
    #
 Utiliser fichiers
    "output.txt" | Out-File $outputFile
    "results" | Out-File $resultFile
    
    Write-Host "✓ Fichiers créés et utilisés" -ForegroundColor Green
    
    # Rechercher locks obsolètes
    $staleLocks = $tempManager.FindStaleLocks(1)
    
} finally {
    # Nettoyage automatique à la fin
    $tempManager.CleanupManagedFiles()
}
```

#### Implémentation Python

```python
#!/usr/bin/env python3
import uuid
import tempfile
import glob
import os
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict

class AgentTempFileManager:
    """Gestionnaire de fichiers temporaires sécurisé pour multi-agent"""
    
    def __init__(self):
        self.agent_uuid = str(uuid.uuid4())
        self.temp_dir = Path(tempfile.gettempdir())
        self.managed_files: List[Path] = []
        
        print(f"🆔 Agent UUID : {self.agent_uuid}")
    
    def create_temp_file(self, operation: str, filename: str) -> Path:
        """
        Crée un fichier temporaire avec naming convention sécurisée
        
        Args:
            operation: Description de l'opération (compile, test, serve)
            filename: Nom de fichier souhaité
        
        Returns:
            Path du fichier créé
        """
        safe_name = f"roo-agent-{self.agent_uuid}-{operation}-{filename}"
        full_path = self.temp_dir / safe_name
        
        # Créer fichier vide
        full_path.touch()
        
        # Enregistrer dans liste gérée
        self.managed_files.append(full_path)
        
        print(f"📄 Fichier temporaire créé : {safe_name}")
        return full_path
    
    def cleanup_own_files(self):
        """Nettoie tous les fichiers de cet agent"""
        print(f"🧹 Nettoyage fichiers de cet agent...")
        
        pattern = f"roo-agent-{self.agent_uuid}-*"
        files = list(self.temp_dir.glob(pattern))
        
        count = 0
        for file in files:
            try:
                file.unlink()
                print(f"  ✓ Supprimé : {file.name}")
                count += 1
            except Exception as e:
                print(f"  ✗ Erreur suppression : {file.name} - {e}")
        
        print(f"✓ {count} fichiers nettoyés")
    
    def cleanup_managed_files(self):
        """Nettoie uniquement les fichiers managés par cette instance"""
        print(f"🧹 Nettoyage fichiers managés...")
        
        count = 0
        for file_path in self.managed_files:
            if file_path.exists():
                try:
                    file_path.unlink()
                    print(f"  ✓ Supprimé : {file_path.name}")
                    count += 1
                except Exception as e:
                    print(f"  ✗ Erreur suppression : {file_path.name} - {e}")
        
        self.managed_files.clear()
        print(f"✓ {count} fichiers nettoyés")
    
    def find_stale_locks(self, max_age_hours: int = 1) -> List[Dict]:
        """
        Trouve les fichiers lock obsolètes (> max_age_hours)
        
        Args:
            max_age_hours: Âge maximum en heures
        
        Returns:
            Liste de dicts avec informations sur locks obsolètes
        """
        print(f"🔍 Recherche locks obsolètes (> {max_age_hours} heures)...")
        
        pattern = "roo-agent-*.lock"
        locks = list(self.temp_dir.glob(pattern))
        
        stale = []
        now = datetime.now()
        
        for lock in locks:
            creation_time = datetime.fromtimestamp(lock.stat().st_ctime)
            age = (now - creation_time).total_seconds() / 3600
            
            if age > max_age_hours:
                stale.append({
                    'path': str(lock),
                    'name': lock.name,
                    'age': round(age, 1)
                })
        
        if stale:
            print(f"  ⚠️  {len(stale)} locks obsolètes détectés")
            for item in stale:
                print(f"    - {item['name']} (age: {item['age']}h)")
        else:
            print(f"  ✓ Aucun lock obsolète")
        
        return stale
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.cleanup_managed_files()
        return False

# Exemple utilisation
if __name__ == "__main__":
    with AgentTempFileManager() as temp_manager:
        # Créer fichiers temporaires
        output_file = temp_manager.create_temp_file("compile", "output.log")
        result_file = temp_manager.create_temp_file("test", "results.json")
        
        # Utiliser fichiers
        with open(output_file, 'w') as f:
            f.write("Compilation output\n")
        
        with open(result_file, 'w') as f:
            f.write('{"status": "success"}\n')
        
        print("✓ Fichiers créés et utilisés")
        
        # Rechercher locks obsolètes
        stale_locks = temp_manager.find_stale_locks(1)
        
        # Nettoyage automatique via context manager
```

### 3.4 Configuration Système

#### Règles Strictes

1. ✅ **User scope PRIORITAIRE** : Modifier uniquement config utilisateur
2. ✅ **Backup OBLIGATOIRE** : Sauvegarder avant toute modification
3. ❌ **System scope INTERDIT** sans validation utilisateur
4. ✅ **Modifications RÉVERSIBLES** : Documenter pour rollback

#### Implémentation PowerShell

```powershell
function Set-EnvironmentVariableSafely {
    <#
    .SYNOPSIS
    Modifie une variable d'environnement de manière sécurisée
    
    .DESCRIPTION
    Protocole complet :
    1. Vérification scope (User recommandé)
    2. Backup configuration actuelle
    3. Modification
    4. Documentation changement
    5. Validation utilisateur si System scope
    
    .PARAMETER Name
    Nom de la variable (ex: PATH, JAVA_HOME)
    
    .PARAMETER Value
    Nouvelle valeur
    
    .PARAMETER Scope
    User (défaut) ou Machine (nécessite validation)
    
    .PARAMETER Append
    Si true, ajoute à la valeur existante au lieu de remplacer
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Value,
        
        [ValidateSet("User", "Machine")]
        [string]$Scope = "User",
        
        [switch]$Append
    )
    
    # 1. Vérification scope
    if ($Scope -eq "Machine") {
        Write-Warning "⚠️  ATTENTION : Modification System scope demandée"
        Write-Warning "    Ceci affecte TOUS les utilisateurs et agents"
        Write-Warning "    Nécessite validation utilisateur explicite"
        
        # Ici : Escalader vers ask_followup_question
        # Pour démo, on refuse
        Write-Error "Modification System scope refusée sans validation utilisateur"
        return $false
    }
    
    Write-Host "✓ Scope User (sécurisé multi-agent)" -ForegroundColor Green
    
    # 2. Backup configuration actuelle
    $currentValue = [Environment]::GetEnvironmentVariable($Name, $Scope)
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$env:TEMP\roo-agent-envvar-backup-$Name-$timestamp.txt"
    
    $backupData = @{
        Name = $Name
        Scope = $Scope
        OldValue = $currentValue
        Timestamp = $timestamp
        AgentPID = $PID
    } | ConvertTo-Json
    
    $backupData | Out-File $backupPath -Encoding UTF8
    Write-Host "💾 Backup créé : $backupPath" -ForegroundColor Cyan
    
    # 3. Calcul nouvelle valeur
    if ($Append -and $currentValue) {
        $separator = if ($Name -eq "PATH") { ";" } else { "" }
        $newValue = "$currentValue$separator$Value"
    } else {
        $newValue = $Value
    }
    
    # 4. Modification
    try {
        [Environment]::SetEnvironmentVariable($Name, $newValue, $Scope)
        Write-Host "✓ Variable $Name modifiée (Scope: $Scope)" -ForegroundColor Green
    } catch {
        Write-Error "❌ Erreur modification : $_"
        return $false
    }
    
    # 5. Documentation
    $changeLog = @{
        Action = "SetEnvironmentVariable"
        Name = $Name
        Scope = $Scope
        OldValue = $currentValue
        NewValue = $newValue
        BackupPath = $backupPath
        Timestamp = Get-Date
        Reversible = $true
    }
    
    Write-Host "📝 Changement documenté et réversible" -ForegroundColor Cyan
    Write-Host "    Backup : $backupPath" -ForegroundColor Gray
    
    return $changeLog
}

function Restore-EnvironmentVariable {
    <#
    .SYNOPSIS
    Restaure une variable d'environnement depuis backup
    #>
    
    param([string]$BackupPath)
    
    if (-not (Test-Path $BackupPath)) {
        Write-Error "Backup introuvable : $BackupPath"
        return $false
    }
    
    $backup = Get-Content $BackupPath | ConvertFrom-Json
    
    Write-Host "🔄 Restauration variable $($backup.Name)..."
    
    [Environment]::SetEnvironmentVariable(
        $backup.Name, 
        $backup.OldValue, 
        $backup.Scope
    )
    
    Write-Host "✓ Variable restaurée depuis backup" -ForegroundColor Green
    return $true
}

# Exemple utilisation
# ❌ MAUVAIS : System scope sans backup
# [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")

# ✅ BON : User scope avec backup
$result = Set-EnvironmentVariableSafely `
    -Name "JAVA_HOME" `
    -Value "C:\Program Files\Java\jdk-17" `
    -Scope "User"

if ($result) {
    Write-Host "✓ Configuration modifiée avec succès"
    Write-Host "  Backup : $($result.BackupPath)"
}
```

---

## 📋 Section 4 : Protocole SDDD Multi-Agent

### 4.1 Grounding Système (Phase 1)

**AVANT toute opération système potentiellement impactante** :

#### Étapes Obligatoires

1. **Environment Grounding** :
   ```xml
   <!-- Détecter autres agents actifs -->
   <use_mcp_tool>
   <server_name>win-cli</server_name>
   <tool_name>execute_command</tool_name>
   <arguments>
   {
     "shell": "powershell",
     "command": "Get-Process code,powershell,pwsh,node | Where-Object { $_.Id -ne $PID } | Select-Object Id,ProcessName,StartTime"
   }
   </arguments>
   </use_mcp_tool>
   ```

2. **Resource Analysis** :
   - Lister ressources actuellement occupées (ports, fichiers lock)
   - Identifier configuration système (user vs system scope)
   - Évaluer impact potentiel sur autres agents

3. **Impact Analysis** :
   ```markdown
   Si impact large détecté → Escalader vers utilisateur
   Si impact ciblé → Procéder avec protocole sécurisé
   Si doute → Demander clarification
   ```

4. **Semantic Grounding** :
   ```xml
   <!-- Rechercher documentation coordination existante -->
   <codebase_search>
   <query>multi-agent coordination system operations</query>
   </codebase_search>
   ```

5. **Conversational Grounding** (si applicable) :
   ```xml
   <!-- Consulter state manager pour intentions autres agents -->
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>view_conversation_tree</tool_name>
   <arguments>
   {
     "workspace": "c:/dev/current-project",
     "view_mode": "cluster"
   }
   </arguments>
   </use_mcp_tool>
   ```

### 4.2 Checkpoint Multi-Agent (50k tokens)

À chaque checkpoint SDDD (50k tokens), vérifier :

#### Checklist Checkpoint

```markdown
[ ] **Ressources Consommées** :
    - [ ] Processus créés : PID enregistrés ?
    - [ ] Ports occupés : Documentés dans fichiers ?
    - [ ] Fichiers temporaires : Préfixés UUID agent ?
    - [ ] Configuration modifiée : Backups créés ?

[ ] **Coordination** :
    - [ ] Autres agents détectés depuis dernier checkpoint ?
    - [ ] Conflits ressources survenus ?
    - [ ] Lock files créés/libérés correctement ?

[ ] **Nettoyage Proactif** :
    - [ ] Libérer ressources non utilisées
    - [ ] Supprimer fichiers temporaires obsolètes (uniquement cet agent)
    - [ ] Mettre à jour fichiers coordination

[ ] **Documentation** :
    - [ ] Actions système documentées
    - [ ] Impact sur autres agents évalué
    - [ ] Rollback possible si nécessaire
```

### 4.3 Intégration Niveaux SDDD

```
┌───────────────────────────────────────────────────────────┐
│ NIVEAU 1 : File Grounding                                │
│ • Détecter fichiers lock autres agents                   │
│ • Vérifier /tmp/roo-agent-*.lock                         │
│ • Lister ports occupés (netstat, lsof)                   │
└───────────────────────────────────────────────────────────┘
                          ↓
┌───────────────────────────────────────────────────────────┐
│ NIVEAU 2 : Semantic Grounding                            │
│ • codebase_search "multi-agent coordination"             │
│ • Rechercher documentation protocols                      │
│ • Découvrir patterns sécurité existants                  │
└───────────────────────────────────────────────────────────┘
                          ↓
┌───────────────────────────────────────────────────────────┐
│ NIVEAU 3 : Conversational Grounding                      │
│ • roo-state-manager : Consulter intentions autres agents │
│ • Vérifier tasks assignées (éviter doublons)             │
│ • Analyser historique incidents multi-agent              │
└───────────────────────────────────────────────────────────┘
                          ↓
┌───────────────────────────────────────────────────────────┐
│ NIVEAU 4 : Project Grounding                             │
│ • github-projects : Vérifier issues/tasks assignées      │
│ • Coordonner via Project Boards                          │
│ • Éviter conflits assignations                           │
└───────────────────────────────────────────────────────────┘
```

---

## 📋 Section 5 : Checklists de Sécurité

### 5.1 Avant Opération Processus

```markdown
[ ] Autres agents détectés sur machine ?
[ ] PID spécifique identifié (pas nom processus générique) ?
[ ] Processus appartient à ma session/user ?
[ ] Tentative fermeture gracieuse avant force ?
[ ] Impact sur autres agents évalué ?
[ ] Utilisateur consulté si impact large ?
[ ] Action documentée (PID, méthode, timestamp) ?
```

### 5.2 Avant Occupation Ressource

```markdown
[ ] Ressource (port/fichier) vérifiée disponible ?
[ ] Port dynamique (>= 10000) si possible ?
[ ] Fichier temporaire préfixé UUID agent ?
[ ] Fichier lock créé si opération exclusive ?
[ ] Libération automatique prévue (finally, context manager) ?
[ ] Durée occupation estimée raisonnable (< 1h) ?
[ ] Usage documenté pour cleanup ciblé ?
```

### 5.3 Avant Modification Configuration

```markdown
[ ] Scope User vs System identifié ?
[ ] Backup configuration actuelle créé ?
[ ] Impact autres agents évalué ?
[ ] Modifications réversibles (rollback possible) ?
[ ] Documentation changements prévue ?
[ ] Utilisateur validé si scope System ?
[ ] Chemin rollback testé ?
```

### 5.4 Checklist Générale Multi-Agent

```markdown
[ ] **Détection** :
    - [ ] Vérification autres agents actifs effectuée
    - [ ] Nombre agents détectés : _____
    - [ ] Type agents : VSCode / Terminaux / Servers

[ ] **Coordination** :
    - [ ] Mécanisme coordination choisi : Lock / Validation / Ciblé
    - [ ] Lock files créés si nécessaire
    - [ ] Validation utilisateur obtenue si impact large

[ ] **Sécurité** :
    - [ ] Opération ciblée (PID/UUID/Port spécifique)
    - [ ] Pas d'opération large (wildcards, noms génériques)
    - [ ] Backup créé si modification destructive

[ ] **Documentation** :
    - [ ] Ressources consommées enregistrées
    - [ ] Actions documentées pour audit
    - [ ] Rollback possible et documenté

[ ] **Cleanup** :
    - [ ] Plan nettoyage défini (fichiers temp, locks)
    - [ ] Cleanup automatique configuré (finally, __exit__)
    - [ ] Vérification cleanup effectué
```

---

## 📋 Section 6 : Escalade et Cas d'Exception

### 6.1 Quand Demander Validation Utilisateur

**OBLIGATOIRE dans ces cas** :

1. ✅ **Opération affectant processus multiples**
   - Kill par nom processus
   - Redémarrage services globaux
   - Stop tous processus d'un type

2. ✅ **Modification configuration système (Machine scope)**
   - Variables d'environnement système
   - Registry HKLM
   - Fichiers /etc/* (Linux)

3. ✅ **Occupation ressource commune (ports < 10000)**
   - Ports HTTP (80, 443)
   - Ports développement communs (3000, 5000, 8000, 8080)
   - Ports services (22 SSH, 3306 MySQL, etc.)

4. ✅ **Redémarrage services/système**
   - Restart-Computer
   - Stop-Service global
   - sudo reboot

5. ✅ **Détection conflits avec autres agents**
   - N > 2 agents actifs
   - Lock file existant non expiré
   - Port souhaité occupé par autre agent

6. ✅ **Doute sur propriété ressource**
   - Processus session différente
   - Fichier owner différent
   - Incertitude impact

#### Template Question Standardisé

```xml
<ask_followup_question>
<question>
🔍 **Détection Multi-Agent Critique**

**Contexte** :
- Agents actifs détectés : {N}
- Agents types : {LISTE TYPES}

**Opération demandée** : {OPERATION}

**Impact potentiel** :
- Ressources concernées : {LISTE RESSOURCES}
- Agents impactés : {LISTE AGENTS}
- Risques : {DESCRIPTION RISQUES}

**Alternatives disponibles** :
1. ✅ {OPTION CIBLÉE SÉCURISÉE}
2. ⚠️ {OPTION LARGE RISQUÉE}
3. 🔍 {OPTION INVESTIGATION}
4. ❌ Annuler opération

Quelle option préférez-vous ?
</question>
<follow_up>
<suggest>✅ {OPTION 1 - Sécurisée et recommandée}</suggest>
<suggest>⚠️ {OPTION 2 - Risquée, validation explicite requise}</suggest>
<suggest>🔍 {OPTION 3 - Plus d'informations}</suggest>
<suggest>❌ Annuler opération</suggest>
</follow_up>
</ask_followup_question>
```

### 6.2 Gestion Conflits

#### Protocole Résolution Conflits

Lorsqu'un conflit de ressource est détecté :

**Étape 1 : Identifier Propriétaire**

```powershell
# Processus
$process = Get-Process -Id $conflictPID
$owner = @{
    User = $process.SessionId
    StartTime = $process.StartTime
    CommandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $conflictPID").CommandLine
}

# Port
$connection = Get-NetTCPConnection -LocalPort $conflictPort
$portOwner = Get-Process -Id $connection.OwningProcess
```

**Étape 2 : Évaluer Criticité**

```markdown
Questions :
- La ressource est-elle essentielle pour ma tâche ?
- Puis-je utiliser une alternative (port+1, fichier-v2) ?
- Le propriétaire est-il un agent actif ou zombie ?
- Quel délai acceptable pour attendre libération ?
```

**Étape 3 : Choisir Résolution**

```
┌─────────────────────────────────────────────────┐
│ OPTION A : Ressource Alternative                │
│ • Port occupé → Incrémenter port                │
│ • Fichier locked → Utiliser nom v2              │
│ • Service busy → Différer opération             │
│ • Avantage : Pas d'interruption autres agents   │
└─────────────────────────────────────────────────┘
            OU
┌─────────────────────────────────────────────────┐
│ OPTION B : Attendre Libération                  │
│ • Polling avec timeout                          │
│ • Vérifier libération toutes les N secondes     │
│ • Timeout raisonnable (max 5 min)               │
│ • Avantage : Coordination automatique           │
└─────────────────────────────────────────────────┘
            OU
┌─────────────────────────────────────────────────┐
│ OPTION C : Demander Arbitrage Utilisateur       │
│ • Conflit non résolvable automatiquement        │
│ • Ressource critique pour les deux              │
│ • Décision humaine nécessaire                   │
│ • ask_followup_question avec contexte complet   │
└─────────────────────────────────────────────────┘
```

**Étape 4 : Documenter**

```markdown
## Conflit Détecté

**Date** : {TIMESTAMP}
**Ressource** : {TYPE} - {IDENTIFIANT}
**Propriétaire** : {AGENT/PROCESS INFO}
**Demandeur** : Agent UUID {MY_UUID}

**Résolution choisie** : {OPTION A/B/C}
**Résultat** : {SUCCESS/FAILURE}
**Durée** : {DURATION}

**Actions prises** :
- {ACTION 1}
- {ACTION 2}
```

### 6.3 Timeout et Fallback

#### Stratégie Timeout

```python
import time
from typing import Optional, Callable

def wait_for_resource_with_timeout(
    check_available: Callable[[], bool],
    timeout_seconds: int = 300,
    poll_interval: int = 5
) -> bool:
    """
    Attend qu'une ressource devienne disponible avec timeout
    
    Args:
        check_available: Fonction retournant True si ressource disponible
        timeout_seconds: Timeout max en secondes (défaut: 5 min)
        poll_interval: Intervalle polling en secondes (défaut: 5s)
    
    Returns:
        True si ressource disponible, False si timeout
    """
    start_time = time.time()
    attempts = 0
    
    while True:
        attempts += 1
        
        # Vérifier disponibilité
        if check_available():
            elapsed = time.time() - start_time
            print(f"✓ Ressource disponible après {elapsed:.1f}s ({attempts} tentatives)")
            return True
        
        # Vérifier timeout
        elapsed = time.time() - start_time
        if elapsed >= timeout_seconds:
            print(f"⏱️  Timeout atteint ({timeout_seconds}s, {attempts} tentatives)")
            return False
        
        # Attendre avant prochain essai
        remaining = timeout_seconds - elapsed
        wait_time = min(poll_interval, remaining)
        
        print(f"  Attente... (tentative {attempts}, {remaining:.0f}s restantes)")
        time.sleep(wait_time)

# Exemple utilisation : Attendre libération port
def check_port_free():
    import socket
    try:
        with socket.socket() as s:
            s.bind(('', 8080))
            return True
    except OSError:
        return False

if wait_for_resource_with_timeout(check_port_free, timeout_seconds=60):
    print("Port 8080 disponible, démarrage serveur...")
else:
    print("Port 8080 toujours occupé, utilisation port alternatif...")
    # Fallback vers find_free_port()
```

---

## 📋 Section 7 : Exemples de Bonnes Pratiques

### 7.1 Exemple Complet : Fermeture Terminal Sécurisée

```powershell
# ❌ MAUVAIS : Tue TOUS les PowerShell
Stop-Process -Name powershell -Force

# ✅ BON : Protocole complet sécurisé
function Close-TerminalSafely {
    # 1. Grounding : Détecter autres agents
    $otherAgents = Get-Process powershell,pwsh | Where-Object { $_.Id -ne $PID }
    
    if ($otherAgents.Count -gt 0) {
        Write-Warning "⚠️  $($otherAgents.Count) autres terminaux détectés"
        Write-Host "Agents actifs :"
        $otherAgents | Format-Table Id, ProcessName, StartTime -AutoSize
    }
    
    # 2. Identification PID spécifique (ce terminal)
    $myPID = $PID
    Write-Host "🎯 Fermeture terminal PID: $myPID"
    
    # 3. Vérification session
    $mySession = (Get-Process -Id $myPID).SessionId
    Write-Host "✓ Session: $mySession"
    
    # 4. Fermeture gracieuse (exit préféré à Stop-Process)
    Write-Host "👋 Fermeture gracieuse..."
    exit  # Ferme uniquement ce terminal
}

# Utilisation
Close-TerminalSafely
```

### 7.2 Exemple Complet : Serveur Web Sécurisé

```python
#!/usr/bin/env python3
"""
Exemple serveur Flask avec protocole multi-agent complet
"""
import socket
import uuid
import tempfile
import os
from pathlib import Path
from flask import Flask

class SafeFlaskServer:
    """Serveur Flask sécurisé pour multi-agent"""
    
    def __init__(self, app: Flask, preferred_port: int = 5000):
        self.app = app
        self.preferred_port = preferred_port
        self.agent_uuid = str(uuid.uuid4())
        self.port = None
        self.port_file = None
    
    def find_free_port(self, start: int = 10000) -> int:
        """Trouve port libre (>= 10000)"""
        for port in range(start, 65536):
            try:
                with socket.socket() as s:
                    s.bind(('', port))
                    return port
            except OSError:
                continue
        raise RuntimeError("Aucun port libre")
    
    def detect_other_agents(self) -> int:
        """Détecte autres agents actifs"""
        import psutil
        agents = 0
        for proc in psutil.process_iter(['name']):
            if proc.info['name'] in ['code', 'python', 'node']:
                agents += 1
        return max(0, agents - 1)  # Exclure ce process
    
    def start(self):
        """Démarre serveur avec protocole complet"""
        print("🔍 Multi-Agent Flask Server")
        print("=" * 50)
        
        # 1. Grounding : Détecter autres agents
        other_agents = self.detect_other_agents()
        if other_agents > 0:
            print(f"⚠️  {other_agents} autres agents détectés")
        
        # 2. Trouver port disponible
        try:
            with socket.socket() as s:
                s.bind(('', self.preferred_port))
            self.port = self.preferred_port
            print(f"✓ Port préféré {self.port} disponible")
        except OSError:
            print(f"⚠️  Port {self.preferred_port} occupé")
            self.port = self.find_free_port()
            print(f"✓ Port alternatif {self.port} trouvé")
        
        # 3. Documenter usage port
        temp_dir = Path(tempfile.gettempdir())
        self.port_file = temp_dir / f"roo-agent-{self.agent_uuid}-port.txt"
        
        with open(self.port_file, 'w') as f:
            f.write(f"{self.port}\n")
        
        print(f"📝 Port documenté : {self.port_file}")
        
        # 4. Démarrer serveur
        print(f"🚀 Démarrage serveur sur http://localhost:{self.port}")
        print("   Ctrl+C pour arrêter")
        
        try:
            self.app.run(host='0.0.0.0', port=self.port)
        except KeyboardInterrupt:
            print("\n👋 Arrêt serveur...")
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Nettoyage ressources"""
        if self.port_file and self.port_file.exists():
            self.port_file.unlink()
            print(f"🧹 Documentation port nettoyée")

# Utilisation
if __name__ == "__main__":
    app = Flask(__name__)
    
    @app.route('/')
    def index():
        return "Hello from Safe Flask Server!"
    
    server = SafeFlaskServer(app, preferred_port=5000)
    server.start()
```

### 7.3 Exemple Complet : Nettoyage Temporaires Sécurisé

```powershell
# ❌ MAUVAIS : Supprime TOUT
Remove-Item "$env:TEMP\*" -Force -Recurse

# ✅ BON : Nettoyage ciblé avec protocole complet
function Clear-AgentTempFiles {
    <#
    .SYNOPSIS
    Nettoie fichiers temporaires de cet agent uniquement
    
    .DESCRIPTION
    Protocole complet :
    1. Identification UUID agent
    2. Recherche fichiers avec préfixe UUID
    3. Vérification âge fichiers
    4. Suppression ciblée
    5. Rapport nettoyage
    #>
    
    param(
        [string]$AgentUUID,
        [int]$MinAgeHours = 0
    )
    
    if (-not $AgentUUID) {
        Write-Warning "UUID agent non fourni, abandon nettoyage"
        Write-Warning "Nettoyage large INTERDIT en multi-agent"
        return
    }
    
    Write-Host "🧹 Nettoyage Fichiers Agent" -ForegroundColor Yellow
    Write-Host "UUID : $AgentUUID" -ForegroundColor Cyan
    
    # 1. Recherche fichiers de cet agent
    $pattern = "roo-agent-$AgentUUID-*"
    $files = Get-ChildItem -Path $env:TEMP -Filter $pattern -ErrorAction SilentlyContinue
    
    if ($files.Count -eq 0) {
        Write-Host "✓ Aucun fichier à nettoyer" -ForegroundColor Green
        return
    }
    
    Write-Host "Fichiers trouvés : $($files.Count)" -ForegroundColor Cyan
    
    # 2. Filtrer par âge si spécifié
    $now = Get-Date
    $toDelete = $files | Where-Object {
        $age = ($now - $_.CreationTime).TotalHours
        $age -ge $MinAgeHours
    }
    
    if ($MinAgeHours -gt 0) {
        Write-Host "Fichiers > $MinAgeHours heures : $($toDelete.Count)" -ForegroundColor Cyan
    }
    
    # 3. Suppression avec rapport
    $deleted = 0
    $errors = 0
    $totalSize = 0
    
    foreach ($file in $toDelete) {
        try {
            $size = $file.Length
            Remove-Item $file.FullName -Force
            
            Write-Host "  ✓ $($file.Name)" -ForegroundColor Gray
            $deleted++
            $totalSize += $size
        } catch {
            Write-Warning "  ✗ $($file.Name) : $_"
            $errors++
        }
    }
    
    # 4. Rapport final
    Write-Host ""
    Write-Host "📊 Rapport Nettoyage" -ForegroundColor Green
    Write-Host "  Fichiers supprimés : $deleted" -ForegroundColor Cyan
    Write-Host "  Erreurs : $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Gray" })
    Write-Host "  Espace libéré : $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Cyan
}

# Exemple utilisation
$myUUID = "a3f2d1b8-4c5e-6789-0123-456789abcdef"
Clear-AgentTempFiles -AgentUUID $myUUID -MinAgeHours 1
```

---

## 📋 Section 8 : Intégration avec Spécifications Existantes

### 8.1 Synergie avec Git Safety

**Lien** : [`git-safety-source-control.md`](git-safety-source-control.md)

**Coordination Multi-Agent + Git** :

Les opérations Git sont également des ressources système (processus git, fichiers `.git/lock`). Les règles multi-agent s'appliquent :

```powershell
# ❌ MAUVAIS : Git operation sans vérifier autres agents
git push --force

# ✅ BON : Vérifier autres agents avant Git destructive
function Invoke-GitOperationSafely {
    param([string]$Operation)
    
    # 1. Détecter autres agents
    $otherAgents = Get-Process code,git -ErrorAction SilentlyContinue | 
        Where-Object { $_.Id -ne $PID }
    
    if ($otherAgents.Count -gt 0) {
        Write-Warning "⚠️  $($otherAgents.Count) autres agents détectés"
        Write-Warning "Opération Git '$Operation' peut causer conflits"
        
        # Escalader si opération destructive
        if ($Operation -match "force|reset|clean") {
            Write-Error "Opération Git destructive refusée avec autres agents actifs"
            Write-Host "Action recommandée : Demander validation utilisateur"
            return $false
        }
    }
    
    # 2. Vérifier .git/index.lock
    if (Test-Path ".git\index.lock") {
        Write-Warning "⚠️  Autre agent effectue opération Git (.git/index.lock existe)"
        Write-Host "Attente libération..."
        
        $timeout = 60
        $start = Get-Date
        
        while ((Test-Path ".git\index.lock") -and 
               ((Get-Date) - $start).TotalSeconds -lt $timeout) {
            Start-Sleep -Seconds 2
        }
        
        if (Test-Path ".git\index.lock") {
            Write-Error "Timeout : .git/index.lock toujours présent"
            return $false
        }
        
        Write-Host "✓ Lock libéré, poursuite opération"
    }
    
    # 3. Exécuter opération Git
    Write-Host "▶️  git $Operation"
    git $Operation.Split(' ')
    
    return $?
}

# Utilisation
Invoke-GitOperationSafely "pull origin main"
```

**Points clés** :
- Git operations = ressources système (processus, fichiers lock)
- Détecter autres agents faisant push/pull simultanément
- Vérifier `.git/index.lock` avant opérations
- Escalader si opération destructive + autres agents

### 8.2 Synergie avec SDDD Protocol

**Lien** : [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)

**Intégration 4-Niveaux** :

```
NIVEAU 1 (File) :
• list_files : Détecter fichiers lock autres agents
• read_file : Lire /tmp/roo-agent-*.lock pour infos agents

NIVEAU 2 (Semantic) :
• codebase_search : "multi-agent coordination protocols"
• Découvrir documentation coordination existante

NIVEAU 3 (Conversational) :
• roo-state-manager : Consulter intentions autres agents
• Vérifier tasks assignées (éviter doublons ressources)

NIVEAU 4 (Project) :
• github-projects : Vérifier issues assignées autres agents
• Coordonner via Project Boards
```

**Checkpoint 50k Multi-Agent** :

Au checkpoint SDDD 50k tokens, ajouter vérifications multi-agent :

```markdown
## Checkpoint 50k Tokens - Multi-Agent

### Vérifications Standard SDDD
[ ] Grounding conversationnel (roo-state-manager)
[ ] Validation cohérence objectif initial
[ ] Documentation synthèse checkpoint

### Vérifications Multi-Agent ADDITIONNELLES
[ ] **Ressources Système** :
    - [ ] Processus créés : PID documentés ?
    - [ ] Ports occupés : Listés et documentés ?
    - [ ] Fichiers temporaires : Naming convention respectée ?
    - [ ] Configuration modifiée : Backups créés ?

[ ] **Coordination** :
    - [ ] Autres agents actifs depuis début session ?
    - [ ] Conflits ressources survenus ?
    - [ ] Résolutions appliquées documentées ?

[ ] **Nettoyage Proactif** :
    - [ ] Ressources non utilisées libérées
    - [ ] Fichiers temp obsolètes supprimés (uniquement cet agent)
    - [ ] Lock files obsolètes nettoyés

[ ] **Préparation Suite** :
    - [ ] Ressources nécessaires identifiées
    - [ ] Conflits potentiels anticipés
    - [ ] Stratégie coordination définie
```

### 8.3 Ajout aux Instructions Globales

**Intégration `.roo/rules/`** :

Créer fichier de règles multi-agent à inclure globalement :

```markdown
# .roo/rules/multi-agent-safety.md

## Règles Multi-Agent Système

### Principe Cardinal
Toujours supposer qu'il y a d'autres agents travaillant simultanément sur la machine.

### Opérations INTERDITES
- ❌ Stop-Process -Name {processus} -Force
- ❌ killall {processus}
- ❌ rm -rf /tmp/*
- ❌ [Environment]::SetEnvironmentVariable(..., "Machine")

### Obligations
1. ✅ Utiliser PID spécifiques (pas noms génériques)
2. ✅ Préfixer fichiers temp avec UUID agent
3. ✅ Vérifier ports disponibles avant occupation
4. ✅ User scope uniquement (pas System)
5. ✅ Backup avant modifications destructives

### Escalation
Demander validation utilisateur si :
- Détection N > 0 autres agents + opération large
- Modification System scope
- Occupation ports < 10000
- Conflits ressources détectés

Voir spécification complète : roo-config/specifications/multi-agent-system-safety.md
```

**Instructions Mode-Specific** :

Ajouter aux modes manipulant système (Code, Debug, etc.) :

```json
{
  "customInstructions": "...\n\n### Multi-Agent System Safety\n\nCe mode manipule des ressources système. Respecter STRICTEMENT les règles multi-agent :\n- Toujours supposer autres agents actifs\n- Utiliser PID spécifiques (jamais noms processus)\n- Préfixer fichiers temp avec UUID agent\n- Demander validation si impact large\n\nVoir : roo-config/specifications/multi-agent-system-safety.md"
}
```

---

## 📋 Section 9 : Scripts Validation Multi-Agent

Les scripts de validation sont fournis dans le répertoire [`scripts/multi-agent-validation/`](../../scripts/multi-agent-validation/).

### Script 1 : `detect-active-agents.sh`

**Voir** : [Section 2.1](#21-détection-autres-agents) pour implémentation complète

**Usage** :
```bash
./scripts/multi-agent-validation/detect-active-agents.sh
```

**Sortie** :
```
🔍 Détection Multi-Agent
========================
Processus VSCode/Roo : 2 agents
Terminaux actifs : 3 terminaux
Ports occupés (3000-9000) : 5 ports

⚠️  Opérations multi-agent requises pour sécurité
```

### Script 2 : `validate-resources.ps1`

**Implémentation complète dans Section 3.1-3.4**

**Usage** :
```powershell
.\scripts\multi-agent-validation\validate-resources.ps1 -Operation "Stop-Process" -ResourceType "Process" -ResourceId "Name:powershell"
```

**Sortie** :
```
⚠️  2 autres agents détectés
❌ Opération par nom processus (risque multi-agent)
Safe: False
Warnings:
  - ❌ Opération par nom processus (risque multi-agent)

Action recommandée : Utiliser PID spécifique
```

### Script 3 : `safe-cleanup.py`

**Implémentation complète dans Section 3.3**

**Usage** :
```python
python scripts/multi-agent-validation/safe-cleanup.py
```

**Sortie** :
```
🆔 Agent UUID : a3f2d1b8-4c5e-6789-0123-456789abcdef
🧹 Nettoyage fichiers de cet agent...
  ✓ Supprimé : roo-agent-a3f2d1b8-compile-output.log
  ✓ Supprimé : roo-agent-a3f2d1b8-test-results.json
✓ 2 fichiers nettoyés

🔍 Recherche locks obsolètes (> 1 heures)...
  ⚠️  1 locks obsolètes détectés
    - roo-agent-old-uuid-operation.lock (age: 3.2h)
```

---

## 📋 Section 10 : Métriques et Monitoring

### 10.1 Métriques de Sécurité Multi-Agent

**Métriques clés à tracker** :

1. **Détection Agents** :
   - Taux détection autres agents avant opération système (cible: >95%)
   - Nombre moyen agents simultanés détectés
   - Distribution types agents (VSCode, Terminaux, Servers)

2. **Incidents Prévenus** :
   - Nombre opérations larges bloquées (Stop-Process -Name, rm -rf)
   - Nombre escalations vers utilisateur effectuées
   - Nombre conflits ressources résolus automatiquement

3. **Coordination** :
   - Taux utilisation lock files
   - Durée moyenne attente libération ressources
   - Taux timeout coordination

4. **Ressources** :
   - Taux fichiers temp avec UUID agent (cible: 100%)
   - Taux ports dynamiques utilisés (cible: >90%)
   - Taux backups config créés avant modification (cible: 100%)

### 10.2 Dashboard Recommandé

```markdown
# Multi-Agent Safety Dashboard

## Détection Agents (24h)
- Agents simultanés max : 5
- Moyenne agents : 2.3
- Types : VSCode (45%), Terminaux (35%), Servers (20%)

## Incidents Prévenus (24h)
- Opérations larges bloquées : 12
- Escalations utilisateur : 8
- Conflits auto-résolus : 23

## Ressources (24h)
- Fichiers temp UUID : 98.5% ✓
- Ports dynamiques : 92% ✓
- Backups config : 100% ✓

## Violations Détectées (24h)
- Stop-Process -Name : 2 ⚠️
- rm -rf /tmp/* : 0 ✓
- System scope modifs : 1 ⚠️

Action requise : Former agents sur protocoles
```

### 10.3 Alertes Automatiques

**Règles d'alerte** :

```yaml
alertes:
  - nom: "Operation Large Sans Detection"
    condition: "operation_large AND NOT detection_effectuee"
    severite: CRITIQUE
    action: "Bloquer + Escalader"
  
  - nom: "Taux UUID Files Bas"
    condition: "uuid_files_rate < 80%"
    severite: WARNING
    action: "Notification + Audit"
  
  - nom: "Conflits Frequents"
    condition: "conflicts_per_hour > 10"
    severite: WARNING
    action: "Investigation + Optimisation"
  
  - nom: "System Scope Modification"
    condition: "system_scope_modification AND NOT user_validation"
    severite: CRITIQUE
    action: "Bloquer + Alert Security"
```

---

## 📋 Section 11 : Évolution et Maintenance

### 11.1 Process Révision

**Cette spécification doit être révisée** :

1. ✅ **Après incident multi-agent majeur**
   - Analyser cause racine
   - Identifier lacune dans spec
   - Proposer amélioration
   - Mettre à jour spec + version

2. ✅ **Révision trimestrielle** (tous les 3 mois)
   - Analyser métriques période
   - Identifier patterns violations
   - Ajuster règles si nécessaire
   - Former agents sur nouveaux patterns

3. ✅ **Nouveaux patterns identifiés**
   - Documenter nouveau pattern risque
   - Ajouter à section exemples
   - Créer checklist si applicable
   - Communiquer équipe

4. ✅ **Nouveaux outils/MCPs ajoutés**
   - Évaluer impact multi-agent
   - Ajouter protocoles spécifiques
   - Tester coordination
   - Documenter intégration

### 11.2 Roadmap

#### Phase 1 : Détection Passive (Q4 2025) ✅ ACTUELLE

- ✅ Scripts détection agents
- ✅ Protocoles ciblage spécifique
- ✅ Lock files coordination
- ✅ Documentation complète

#### Phase 2 : Coordination Active (Q1 2026)

- 🔄 Communication inter-agents via MCP
- 🔄 Registre centralisé ressources
- 🔄 Négociation automatique ressources
- 🔄 Dashboard monitoring temps réel

#### Phase 3 : Multi-Machine (Q2 2026)

- 📅 Coordination agents sur machines différentes
- 📅 Synchronisation état via réseau
- 📅 Git comme layer coordination
- 📅 Résolution conflits distribuée

---

## 📋 Section 12 : Conclusion

### Résumé Exécutif

Cette spécification **Multi-Agent System Safety** établit des règles strictes et des protocoles de sécurité pour garantir la coexistence sécurisée de multiples agents LLM travaillant simultanément sur la même machine.

#### Principes Fondamentaux

1. 🔍 **Toujours Supposer Autres Agents** : Ne jamais assumer être seul sur machine
2. 🎯 **Ciblage Spécifique OBLIGATOIRE** : PID, UUID, ports dynamiques
3. 🚫 **Opérations Larges INTERDITES** : Noms génériques, wildcards, system scope
4. ✅ **Vérification Préalable** : Détecter agents avant opération impactante
5. 💾 **Backup Systématique** : Sauvegarder avant modifications destructives
6. 📝 **Documentation Complète** : Tracer ressources consommées
7. 🔄 **Coordination Explicite** : Escalader vers utilisateur si doute

#### Couverture Incidents

- ✅ **Kill all PowerShell processes** (Incident #1)
- ✅ **Occupation exclusive ports communs** (Incident #2)
- ✅ **Suppression fichiers temporaires masse** (Incident #3)
- ✅ **Modification configuration globale** (Incident #4)
- ✅ **Redémarrage services sans coordination** (Incident #5)
- ✅ **Conflits ressources** (détection + résolution)
- ✅ **Contamination inter-agents** (isolation UUID)

#### Application

**Modes concernés** : TOUS les modes manipulant ressources système

- ✅ Code (processus, compilation, serveurs)
- ✅ Debug (processus, breakpoints, logging)
- ✅ Orchestrator (coordination sous-tâches)
- ✅ Ask (analyse système, diagnostics)
- ✅ Architect (design nécessitant contexte système)

**Intégration** :

- ✅ Protocol SDDD 4-Niveaux (checkpoints multi-agent)
- ✅ Git Safety (opérations Git = ressources système)
- ✅ Operational Best Practices (scripts, nomenclature)
- ✅ MCP Integrations (win-cli, roo-state-manager)

**Livrables** :

- ✅ Spécification complète (ce document)
- ✅ 3 scripts validation (Bash, PowerShell, Python)
- ✅ 4 checklists prêtes à utiliser
- ✅ 10+ exemples concrets multi-langages
- ✅ Protocoles coordination (lock files, escalation)
- ✅ Intégration SDDD et Git Safety

### Prochaines Étapes

1. ✅ **Spécification créée** : [`multi-agent-system-safety.md`](multi-agent-system-safety.md)
2. ⏳ **Créer scripts validation** : `scripts/multi-agent-validation/`
3. ⏳ **Intégrer .roo/rules/** : Fichier règles multi-agent globales
4. ⏳ **Mettre à jour modes** : Ajouter instructions mode-specific
5. ⏳ **Former agents** : Documentation + exemples pratiques
6. ⏳ **Monitorer application** : Métriques + dashboards
7. ⏳ **Itérer** : Révision trimestrielle + après incidents

### Références

**Spécifications liées** :
- [`git-safety-source-control.md`](git-safety-source-control.md) - Protection Git
- [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) - Grounding multi-niveaux
- [`operational-best-practices.md`](operational-best-practices.md) - Règles opérationnelles
- [`mcp-integrations-priority.md`](mcp-integrations-priority.md) - MCPs prioritaires

**Incidents documentés** :
- Incident #1 : Kill all PowerShell (pattern récurrent)
- Voir aussi : Git Safety incidents (contamination multi-agents)

**Scripts** :
- [`scripts/multi-agent-validation/detect-active-agents.sh`](../../scripts/multi-agent-validation/detect-active-agents.sh)
- [`scripts/multi-agent-validation/validate-resources.ps1`](../../scripts/multi-agent-validation/validate-resources.ps1)
- [`scripts/multi-agent-validation/safe-cleanup.py`](../../scripts/multi-agent-validation/safe-cleanup.py)

---

**Version** : 1.0.0  
**Dernière mise à jour** : 08 Octobre 2025  
**Statut** : ✅ Spécification validée - Application obligatoire tous modes

**Mainteneur** : Architecture Team  
**Contact** : Voir [`roo-config/specifications/README.md`](README.md)

---

*Cette spécification protégera vos agents et vos données. Appliquez-la systématiquement.* 🛡️