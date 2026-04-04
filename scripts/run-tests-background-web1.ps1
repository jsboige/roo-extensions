# Script de test en arrière-plan pour myia-web1
# Écrit le résultat dans tests-result.txt

Set-Location mcps/internal/servers/roo-state-manager

# Lancer les tests en arrière-plan
npx vitest run --maxWorkers=1 --reporter=verbose > tests-output.txt 2>&1

# Écrire le statut de sortie
if ($?) {
    "TESTS_PASSED" > tests-result.txt
} else {
    "TESTS_FAILED" > tests-result.txt
}
