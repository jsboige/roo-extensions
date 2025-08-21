# Chemin vers le fichier de configuration des MCPs
$configFile = "d:\Dev\roo-extensions\mcp_settings.json"

if (-not (Test-Path $configFile)) {
    Write-Error "Le fichier de configuration '$configFile' est introuvable."
    exit 1
}

$config = Get-Content $configFile | ConvertFrom-Json
$jobs = @()
$mcpNameRegex = '\${mcp_paths:(.*?)}'

Write-Host "Lancement du diagnostic des serveurs MCP internes..."

foreach ($server in $config.mcpServers.PSObject.Properties.Value) {
    foreach ($arg in $server.args) {
        if ($arg -match $mcpNameRegex) {
            $mcpName = $matches[1]
            $mcpPath = "d:\Dev\roo-extensions\mcps\internal\servers\$mcpName"

            if (-not (Test-Path $mcpPath)) {
                Write-Warning "Répertoire introuvable pour '$mcpName' : $mcpPath"
                continue
            }

            $startCommand = "npx ts-node src/index.ts"

            if (Test-Path (Join-Path $mcpPath "tsconfig.json")) {
                Write-Host "-> Compilation de '$($mcpName)'..."
                Push-Location -Path $mcpPath
                npx tsc
                Pop-Location
                $startCommand = "node build/index.js"
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