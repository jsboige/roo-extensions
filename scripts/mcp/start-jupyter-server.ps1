# Script de démarrage pour le serveur Jupyter avec paramètres optimaux pour MCP
# Ce script démarre un serveur Jupyter avec:
# - Token simplifié pour les tests
# - Autorisation des origines croisées
# - Mode sans navigateur

# Définition des paramètres
$token = "simple-token-for-testing"
$port = 8888
$ip = "localhost"
$notebook_dir = Join-Path $PSScriptRoot ".." -Resolve

Write-Host "Démarrage du serveur Jupyter..."
Write-Host "URL: http://$ip`:$port"
Write-Host "Token: $token"
Write-Host "Répertoire de travail: $notebook_dir"

# Vérification de l'installation de Jupyter
try {
    $jupyterVersion = python -m jupyter --version
    Write-Host "Version de Jupyter détectée:"
    Write-Host $jupyterVersion
}
catch {
    Write-Host "Erreur: Jupyter n'est pas correctement installé ou accessible."
    Write-Host "Veuillez installer Jupyter avec: pip install jupyter notebook"
    exit 1
}

# Démarrage du serveur Jupyter avec les paramètres optimaux
try {
    # Préparation des arguments
    $arguments = @("-m", "jupyter", "notebook",
                "--no-browser",
                "--ip=$ip",
                "--port=$port",
                "--NotebookApp.token=$token",
                "--NotebookApp.allow_origin='*'",
                "--NotebookApp.allow_remote_access=True",
                "--notebook-dir=$notebook_dir")
    
    # Démarrage du processus
    $process = Start-Process -FilePath "python" -ArgumentList $arguments -PassThru -NoNewWindow
    
    Write-Host "Serveur Jupyter démarré avec PID: $($process.Id)"
    Write-Host "Pour accéder au serveur Jupyter: http://$ip`:$port/?token=$token"
    Write-Host "Pour arrêter le serveur, fermez cette fenêtre ou utilisez Ctrl+C"
    
    # Attendre que le processus se termine (si l'utilisateur appuie sur Ctrl+C)
    $process.WaitForExit()
}
catch {
    Write-Host "Erreur lors du démarrage du serveur Jupyter:"
    Write-Host $_.Exception.Message
    exit 1
}