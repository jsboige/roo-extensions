# Script d'exécution de notebooks Jupyter via papermill
# Usage: .\scripts\jupyter\run-notebook.ps1 [-Notebook] <path> [-Output] <path> [-Parameters] <hashtable>

param(
    [Parameter(Mandatory=$true)]
    [string]$Notebook,

    [string]$Output = "",

    [hashtable]$Parameters = @{},

    [switch]$NoReport
)

# Déterminer le chemin de sortie par défaut
if ([string]::IsNullOrEmpty($Output)) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Notebook)
    $dirName = [System.IO.Path]::GetDirectoryName($Notebook)
    if ([string]::IsNullOrEmpty($dirName)) {
        $Output = "$baseName-output.ipynb"
    } else {
        $Output = Join-Path $dirName "$baseName-output.ipynb"
    }
}

# Vérifier que papermill est installé
$papermillCheck = python -m pip show papermill 2>$null
if (-not $papermillCheck) {
    Write-Error "papermill n'est pas installé. Installez-le avec: python -m pip install papermill"
    exit 1
}

# Construire les paramètres papermill
$papermillArgs = @("-m", "papermill", $Notebook, $Output)

foreach ($key in $Parameters.Keys) {
    $value = $Parameters[$key]
    if ($value -is [string]) {
        $papermillArgs += "-p"
        $papermillArgs += $key
        $papermillArgs += "`"$value`""
    } else {
        $papermillArgs += "-p"
        $papermillArgs += $key
        $papermillArgs += $value
    }
}

# Exécuter le notebook
Write-Host "Exécution du notebook: $Notebook"
Write-Host "Sortie: $Output"

$startTime = Get-Date
python $papermillArgs 2>&1 | ForEach-Object { Write-Host $_ }
$exitCode = $LASTEXITCODE
$endTime = Get-Date

$duration = ($endTime - $startTime).TotalSeconds

if ($exitCode -eq 0) {
    Write-Host "✅ Notebook exécuté avec succès en $($duration.ToString('F2')) secondes"

    # Générer un rapport HTML si demandé
    if (-not $NoReport) {
        $htmlOutput = $Output -replace '\.ipynb$', '.html'
        Write-Host "Génération du rapport HTML: $htmlOutput"

        python -m nbconvert --to html --template basic "$Output" --output "$htmlOutput" 2>$null

        if (Test-Path $htmlOutput) {
            Write-Host "✅ Rapport HTML généré: $htmlOutput"
        }
    }

    # Retourner le chemin de sortie
    return $Output
} else {
    Write-Error "❌ Erreur lors de l'exécution du notebook (code: $exitCode)"
    exit $exitCode
}
