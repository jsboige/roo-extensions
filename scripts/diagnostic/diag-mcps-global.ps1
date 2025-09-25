# Déterminer le répertoire racine du projet de manière dynamique
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

# Chemin vers le fichier de configuration des MCPs dans AppData, tel que défini par le script d'installation
$configFile = Join-Path -Path $env:APPDATA -ChildPath "Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"

if (-not (Test-Path $configFile)) {
    Write-Error "Le fichier de configuration '$configFile' est introuvable."
    exit 1
}

$config = Get-Content $configFile | ConvertFrom-Json
$jobs = @()
# Regex mis à jour pour capturer le nom du serveur à partir d'un chemin de fichier complet.
# Il recherche 'mcps/internal/servers/' suivi par le nom du serveur (capturé), et s'arrête au prochain '/'
$mcpNameRegex = 'mcps[/\\]internal[/\\]servers[/\\]([^/\\]+)'

Write-Host "Lancement du diagnostic des serveurs MCP internes..."

foreach ($serverKey in $config.mcpServers.PSObject.Properties.Name) {
    $server = $config.mcpServers.$serverKey
    # Concaténer tous les arguments en une seule chaîne pour la recherche
    $allArgs = $server.args -join ' '
    
    if ($allArgs -match $mcpNameRegex) {
        $mcpName = $matches[1]
        $mcpPath = Join-Path $projectRoot "mcps\internal\servers\$mcpName"

        if (-not (Test-Path $mcpPath)) {
            Write-Warning "Répertoire introuvable pour '$mcpName' : $mcpPath"
            continue
        }

        $startCommand = "npx ts-node src/index.ts"

        if (Test-Path (Join-Path $mcpPath "tsconfig.json")) {
            Write-Host "-> Compilation de '$($mcpName)'..."
            Push-Location -Path $mcpPath
            npm run build # Utiliser le script de build pour une compilation correcte
            Pop-Location
            $startCommand = "node build/src/index.js" # Pointer vers le bon fichier de sortie
        }

        $finalJsFile = $startCommand.Split(' ')[-1]
        if (-not (Test-Path (Join-Path $mcpPath $finalJsFile))) {
            if (Test-Path (Join-Path $mcpPath "dist/index.js")) {
                $startCommand = "node dist/index.js"
            } elseif (Test-Path (Join-Path $mcpPath "src/index.ts")) {
                $startCommand = "npx ts-node src/index.ts"
            } else {
                Write-Warning "Impossible de trouver un script de démarrage valide pour '$mcpName'."
                continue
            }
        }
        
        $scriptBlock = {
            param($path, $command)
            Set-Location -Path $path
            Invoke-Expression $command
        }

        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $mcpPath, $startCommand -Name $mcpName
        $jobs += $job
        Write-Host "-> Job démarré pour '$mcpName' (ID: $($job.Id))"
    }
}

Write-Host "`nAttente de 10 secondes pour la stabilisation..."
Start-Sleep -Seconds 10

Write-Host "Vérification du statut des serveurs..."

foreach ($job_instance in $jobs) {
    $job = Get-Job -Id $job_instance.Id

    if ($job.State -eq 'Running') {
        Write-Host "[OK] Le serveur '$($job.Name)' est stable." -ForegroundColor Green
    }
    else {
        Write-Host "[ERREUR] Le serveur '$($job.Name)' a échoué ! (État: $($job.State))" -ForegroundColor Red
        Write-Host "--- Début des logs pour $($job.Name) ---"
        Receive-Job -Job $job
        Write-Host "--- Fin des logs pour $($job.Name) ---"
    }
}

Write-Host "`nNettoyage des jobs en cours..."
Get-Job | Stop-Job
Get-Job | Remove-Job

Write-Host "Diagnostic terminé."