#!/usr/bin/env pwsh

# Script d'urgence pour envoyer un broadcast RooSync

$ErrorActionPreference = "Stop"

$Machines = @('myia-ai-01', 'myia-po-2023', 'myia-po-2024', 'myia-web1')
$Subject = "[URGENT] RÉGRESSION CRITIQUE - Ordre INTERCOM inversé"
$Body = @"
# 🚨 RÉGRESSION CRITIQUE - Action immédiate requise

## Problème identifié

Bug dans les workflows scheduler : **ordre INTERCOM inversé** (nouveau→ancien au lieu de ancien→nouveau).

## Impact

Sans correction, vos fichiers INTERCOM seront écrits en ordre inversé, rendant impossible la lecture chronologique des événements.

## Action requise MAINTENANT

``````powershell
cd [votre-roo-extensions-path]
git pull
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy
# PUIS redémarrer VS Code immédiatement
``````

## Commit correctif

Commit: b1ab272
Fichiers: .roo/scheduler-workflow-executor.md + coordinator.md
Correction: Écrire À LA FIN (chronologique) au lieu de AU DÉBUT

## Urgent

Le prochain tick scheduler pourrait écraser vos INTERCOM avec l'ordre inversé.
**Agir avant le prochain tick (toutes les 3h).**

---
Envoyé depuis myia-po-2026
"@

Write-Host "🚨 Envoi message URGENT à $($Machines.Count) machines..." -ForegroundColor Red
Write-Host ""

# Import du module RooSync
$RooSyncPath = "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
if (-not (Test-Path $RooSyncPath)) {
    Write-Host "❌ Chemin RooSync introuvable: $RooSyncPath" -ForegroundColor Red
    exit 1
}

foreach ($Machine in $Machines) {
    Write-Host "📤 Envoi à: $Machine..." -NoNewline

    # Générer ID de message
    $Timestamp = Get-Date -Format "yyyyMMdd'T'HHmmss"
    $Random = -join ((65..90) + (97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})
    $MessageId = "msg-${Timestamp}-${Random}"

    # Créer le message JSON
    $Message = @{
        id = $MessageId
        from = "myia-po-2026"
        to = $Machine
        subject = $Subject
        body = $Body
        priority = "URGENT"
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
        status = "unread"
        tags = @("scheduler", "critical", "bug")
    } | ConvertTo-Json -Depth 10

    # Écrire dans inbox de la machine cible
    $InboxPath = Join-Path $RooSyncPath "messages/inbox/${MessageId}.json"
    $Message | Out-File -FilePath $InboxPath -Encoding UTF8 -NoNewline

    Write-Host " ✅" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Messages envoyés avec succès!" -ForegroundColor Green
Write-Host ""
Write-Host "Les machines recevront l'alerte au prochain check RooSync." -ForegroundColor Yellow
