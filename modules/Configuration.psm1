function Get-SyncConfiguration {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    # Vérifier que le fichier existe
    if (-not (Test-Path $Path)) {
        throw "Le fichier de configuration '$Path' est introuvable."
    }
    
    try {
        # Lire le contenu du fichier
        $content = Get-Content -Path $Path -Raw
        
        # Parser le JSON
        $config = $content | ConvertFrom-Json
        
        # Valider la configuration minimale
        if (-not $config.version) {
            throw "La configuration doit contenir une version."
        }
        
        return $config
    }
    catch {
        if ($_.Exception.Message -match "JSON") {
            throw "Le fichier de configuration '$Path' contient du JSON invalide."
        } else {
            throw "Erreur lors de la lecture du fichier de configuration '$Path': $($_.Exception.Message)"
        }
    }
}

function Set-SyncConfiguration {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [object]$Configuration
    )
    
    try {
        # Convertir en JSON
        $json = $Configuration | ConvertTo-Json -Depth 10
        
        # Écrire dans le fichier
        Set-Content -Path $Path -Value $json -Encoding UTF8
        
        return $true
    }
    catch {
        throw "Erreur lors de l'écriture du fichier de configuration '$Path': $($_.Exception.Message)"
    }
}

function Test-SyncConfiguration {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    try {
        $config = Get-SyncConfiguration -Path $Path
        return @{
            IsValid = $true
            Configuration = $config
            Message = "Configuration valide"
        }
    }
    catch {
        return @{
            IsValid = $false
            Configuration = $null
            Message = $_.Exception.Message
        }
    }
}

# Exporter les fonctions
Export-ModuleMember -Function Get-SyncConfiguration, Set-SyncConfiguration, Test-SyncConfiguration