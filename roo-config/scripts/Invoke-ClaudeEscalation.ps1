<#
.SYNOPSIS
    Escalade automatiquement vers Claude Code quand Roo est bloqué.

.DESCRIPTION
    Ce script permet d'escalader automatiquement vers Claude Code quand Roo est bloqué.
    Il écrit un message INTERCOM de type [ESCALADE] dans le fichier INTERCOM de la machine
    et peut optionnellement lancer Claude Code automatiquement.

.PARAMETER Reason
    Raison de l'escalade (obligatoire). Décrit pourquoi Roo est bloqué et nécessite une escalade.

.PARAMETER Context
    Contexte supplémentaire (optionnel). Fournit des informations additionnelles pour aider Claude Code
    à comprendre la situation.

.PARAMETER LaunchClaudeCode
    Switch pour lancer Claude Code automatiquement (optionnel). Si activé, tente de lancer Claude Code
    après avoir écrit le message INTERCOM.

.PARAMETER Machine
    Nom de la machine (défaut: myia-po-2023). Utilisé pour construire le chemin du fichier INTERCOM.

.EXAMPLE
    Invoke-ClaudeEscalation.ps1 -Reason "Roo est bloqué sur une erreur de compilation"

    Écrit un message d'escalade dans l'INTERCOM sans lancer Claude Code.

.EXAMPLE
    Invoke-ClaudeEscalation.ps1 -Reason "Erreur critique dans le déploiement" -Context "Le script de déploiement échoue à l'étape 3" -LaunchClaudeCode

    Écrit un message d'escalade avec contexte et lance Claude Code automatiquement.

.EXAMPLE
    Invoke-ClaudeEscalation.ps1 -Reason "Timeout sur l'API" -Machine "myia-ai-01"

    Écrit un message d'escalade pour une machine spécifique.

.NOTES
    Auteur: Roo System
    Version: 1.0.0
    Date: 2025-01-29

    Le script est idempotent : il peut être appelé plusieurs fois sans effets secondaires indésirables.
    Le contenu existant du fichier INTERCOM n'est jamais supprimé ou modifié.
    Les nouveaux messages sont toujours ajoutés à la fin du fichier.

.LINK
    https://github.com/anthropics/claude-code
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Raison de l'escalade")]
    [ValidateNotNullOrEmpty()]
    [string]$Reason,

    [Parameter(Mandatory = $false)]
    [string]$Context,

    [Parameter(Mandatory = $false)]
    [switch]$LaunchClaudeCode,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Machine = "myia-po-2023"
)

begin {
    # Configuration des chemins
    # Le répertoire .claude est à la racine du workspace
    $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:IntercomDir = Join-Path $workspaceRoot ".claude\local"
    $script:IntercomFile = Join-Path $script:IntercomDir "INTERCOM-$Machine.md"
    $script:Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $script:TimestampISO = Get-Date -AsUTC -Format "o"

    Write-Verbose "Configuration :"
    Write-Verbose "  Machine: $Machine"
    Write-Verbose "  Fichier INTERCOM: $script:IntercomFile"
    Write-Verbose "  Timestamp: $script:Timestamp"
}

process {
    # Vérifier que le répertoire INTERCOM existe
    if (-not (Test-Path $script:IntercomDir)) {
        Write-Error "Le répertoire INTERCOM n'existe pas : $script:IntercomDir"
        return
    }

    # Construire le message INTERCOM
    $intercomMessage = @"

## [$script:Timestamp] roo → claude-code [ESCALADE]

### Raison
$Reason

### Contexte
$(if ($Context) { $Context } else { "Non fourni" })

### Machine
$Machine

### Timestamp
$script:TimestampISO
"@

    # Écrire le message dans le fichier INTERCOM
    if ($PSCmdlet.ShouldProcess($script:IntercomFile, "Ajouter un message d'escalade")) {
        try {
            # Ajouter le message à la fin du fichier (créer le fichier s'il n'existe pas)
            Add-Content -Path $script:IntercomFile -Value $intercomMessage -Encoding UTF8
            Write-Host "✓ Message d'escalade écrit dans : $script:IntercomFile" -ForegroundColor Green
        }
        catch {
            Write-Error "Erreur lors de l'écriture dans le fichier INTERCOM : $_"
            return
        }
    }

    # Optionnellement lancer Claude Code
    if ($LaunchClaudeCode) {
        Write-Host "Tentative de lancement de Claude Code..." -ForegroundColor Yellow

        # Chercher Claude Code dans les emplacements courants
        $claudeCodePaths = @(
            "claude-code",
            "claude",
            "code"
        )

        $claudeCodeFound = $false
        foreach ($path in $claudeCodePaths) {
            try {
                $command = Get-Command $path -ErrorAction SilentlyContinue
                if ($command) {
                    Write-Host "✓ Claude Code trouvé : $($command.Source)" -ForegroundColor Green
                    Start-Process $path -ArgumentList @("--project", (Get-Location).Path)
                    $claudeCodeFound = $true
                    break
                }
            }
            catch {
                # Continuer à chercher
            }
        }

        if (-not $claudeCodeFound) {
            Write-Warning "Claude Code n'a pas été trouvé dans le PATH. Veuillez l'installer ou le lancer manuellement."
        }
    }
}

end {
    Write-Verbose "Script Invoke-ClaudeEscalation terminé."
}
