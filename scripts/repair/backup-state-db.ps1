param(
    [string]$BackupPath = "$env:APPDATA\Code\User\globalStorage\"
)

try {
    # Importer le module SQLite
    Install-Module -Name PSSQLite -Confirm:$false -Force -Scope CurrentUser
    Import-Module PSSQLite

    # Définir les chemins
    $sourceDb = "$env:APPDATA\Code\User\globalStorage\state.vscdb"
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDb = Join-Path -Path $BackupPath -ChildPath "state.vscdb.bak-$timestamp"

    # Se connecter à la base de données source
    $sourceConnection = [System.Data.SQLite.SQLiteConnection]::new("Data Source=$sourceDb")
    $sourceConnection.Open()

    # Créer une nouvelle base de données pour la sauvegarde
    $backupConnection = [System.Data.SQLite.SQLiteConnection]::new("Data Source=$backupDb")
    $backupConnection.Open()

    # Copier les données
    $sourceConnection.BackupDatabase($backupConnection, "main", "main", -1, $null, 0)

    # Fermer les connexions
    $sourceConnection.Close()
    $backupConnection.Close()

    Write-Host "Sauvegarde de la base de données effectuée avec succès : $backupDb"
}
catch {
    Write-Error "Une erreur est survenue lors de la sauvegarde de la base de données : $_"
    exit 1
}