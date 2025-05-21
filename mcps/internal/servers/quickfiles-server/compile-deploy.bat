@echo off
echo ===== Script de compilation et déploiement du MCP Quickfiles =====
echo.

echo 1. Vérification des dépendances...
call npm list typescript >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Installation de TypeScript...
    call npm install --save-dev typescript
    if %ERRORLEVEL% NEQ 0 (
        echo Erreur lors de l'installation de TypeScript.
        exit /b %ERRORLEVEL%
    )
    echo TypeScript installé avec succès.
) else (
    echo TypeScript est déjà installé.
)
echo.

echo 2. Nettoyage du répertoire de build...
if exist build rmdir /s /q build
mkdir build
echo Répertoire de build nettoyé.
echo.

echo 3. Compilation du code TypeScript...
call npx tsc
if %ERRORLEVEL% NEQ 0 (
    echo Erreur lors de la compilation TypeScript.
    exit /b %ERRORLEVEL%
)
echo Compilation TypeScript terminée avec succès.
echo.

echo 4. Vérification des fichiers générés...
if not exist build\index.js (
    echo Erreur: Le fichier build\index.js n'a pas été généré.
    exit /b 1
)
echo Fichiers générés avec succès.
echo.

echo 5. Redémarrage du serveur MCP Quickfiles...
echo Arrêt des instances en cours...
taskkill /f /im node.exe /fi "WINDOWTITLE eq quickfiles-server" 2>nul
echo Démarrage du serveur MCP...
start "quickfiles-server" cmd /c "node build\index.js"
echo Serveur MCP Quickfiles redémarré.
echo.

echo ===== Déploiement terminé avec succès =====
echo Les nouveaux outils sont maintenant disponibles.
echo.