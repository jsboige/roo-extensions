# Script pour exécuter les tests unitaires des outils dans roo-state-manager
$workingDir = "mcps/internal/servers/roo-state-manager"
Push-Location $workingDir
npm run test:unit:tools
Pop-Location
