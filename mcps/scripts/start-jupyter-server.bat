@echo off
REM Script de démarrage pour le serveur Jupyter avec paramètres optimaux pour MCP
REM Ce script démarre un serveur Jupyter avec:
REM - Token simplifié pour les tests
REM - Autorisation des origines croisées
REM - Mode sans navigateur

setlocal enabledelayedexpansion

REM Définition des paramètres
set TOKEN=simple-token-for-testing
set PORT=8888
set IP=localhost
set NOTEBOOK_DIR=%~dp0..

echo Démarrage du serveur Jupyter...
echo URL: http://%IP%:%PORT%
echo Token: %TOKEN%
echo Répertoire de travail: %NOTEBOOK_DIR%

REM Vérification de l'installation de Jupyter
python -m jupyter --version > nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Erreur: Jupyter n'est pas correctement installé ou accessible.
    echo Veuillez installer Jupyter avec: pip install jupyter notebook
    exit /b 1
)

echo Version de Jupyter détectée:
python -m jupyter --version

REM Démarrage du serveur Jupyter avec les paramètres optimaux
echo Démarrage du serveur Jupyter...
python -m jupyter notebook ^
    --no-browser ^
    --ip=%IP% ^
    --port=%PORT% ^
    --NotebookApp.token=%TOKEN% ^
    --NotebookApp.allow_origin="*" ^
    --NotebookApp.allow_remote_access=True ^
    --notebook-dir=%NOTEBOOK_DIR%

if %ERRORLEVEL% neq 0 (
    echo Erreur lors du démarrage du serveur Jupyter.
    exit /b 1
)

echo Pour accéder au serveur Jupyter: http://%IP%:%PORT%/?token=%TOKEN%
echo Pour arrêter le serveur, fermez cette fenêtre ou utilisez Ctrl+C

REM Attendre que l'utilisateur appuie sur une touche pour terminer
pause