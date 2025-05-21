@echo off
echo ===== Compilation du MCP Quickfiles =====
echo.

cd /d %~dp0

echo 1. Installation des dépendances...
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo Erreur lors de l'installation des dépendances.
    exit /b %ERRORLEVEL%
)
echo Dépendances installées avec succès.
echo.

echo 2. Nettoyage du répertoire de build...
if exist build rmdir /s /q build
mkdir build
echo Répertoire de build nettoyé.
echo.

echo 3. Compilation du code TypeScript...
call npm run build
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

echo ===== Compilation terminée avec succès =====
echo.