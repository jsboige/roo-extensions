import * as fs from "fs";
import * as path from "path";
import { executeRipgrep, executeRipgrepForFiles } from "./src/services/search/file-search";
// Configuration des cas de test
const TEST_WORKSPACE = path.join(__dirname, "test-workspace-search");
// Cas de test avec noms problématiques
const TEST_CASES = [
    {
        name: "Chemins avec espaces",
        dirs: ["dossier avec espaces", "Program Files"],
        files: ["dossier avec espaces/fichier test.txt", "Program Files/mon app.js"]
    },
    {
        name: "Caractères accentués",
        dirs: ["dossier-éléphant", "répertoire"],
        files: ["dossier-éléphant/café.ts", "répertoire/naïve.json"]
    },
    {
        name: "Caractères spéciaux",
        dirs: ["special-chars&$@#", "parenthèses (test)"],
        files: ["special-chars&$@#/file.txt", "parenthèses (test)/fichier.md"]
    },
    {
        name: "Quotes et apostrophes",
        dirs: ["dossier'avec'apostrophes", 'dossier"avec"guillemets'],
        files: ["dossier'avec'apostrophes/test.js", 'dossier"avec"guillemets/data.json']
    }
];
async function setupTestEnvironment() {
    console.log("🔧 Configuration de l'environnement de test...");
    // Supprimer l'ancien répertoire de test s'il existe
    if (fs.existsSync(TEST_WORKSPACE)) {
        fs.rmSync(TEST_WORKSPACE, { recursive: true, force: true });
    }
    // Créer le répertoire de base
    fs.mkdirSync(TEST_WORKSPACE, { recursive: true });
    // Créer les structures de test
    for (const testCase of TEST_CASES) {
        console.log(`  Création des cas: ${testCase.name}`);
        // Créer les répertoires
        for (const dir of testCase.dirs) {
            const dirPath = path.join(TEST_WORKSPACE, dir);
            fs.mkdirSync(dirPath, { recursive: true });
        }
        // Créer les fichiers
        for (const file of testCase.files) {
            const filePath = path.join(TEST_WORKSPACE, file);
            fs.writeFileSync(filePath, `Contenu de test pour ${file}`);
        }
    }
    console.log("✅ Environnement de test créé dans:", TEST_WORKSPACE);
}
async function testRipgrepExecution() {
    console.log("\n🧪 Test d'exécution de ripgrep...");
    const testScenarios = [
        {
            name: "Recherche de fichiers standard",
            args: ["--files", "--follow", "--hidden", TEST_WORKSPACE]
        },
        {
            name: "Recherche avec glob patterns",
            args: ["--files", "--follow", "--hidden", "-g", "*.ts", "-g", "*.js", TEST_WORKSPACE]
        },
        {
            name: "Recherche de contenu avec regex",
            args: ["--", "Contenu", TEST_WORKSPACE]
        }
    ];
    for (const scenario of testScenarios) {
        console.log(`\n--- ${scenario.name} ---`);
        try {
            console.log(`Arguments: ${JSON.stringify(scenario.args)}`);
            const results = await executeRipgrep({
                args: scenario.args,
                workspacePath: TEST_WORKSPACE,
                limit: 100
            });
            console.log(`✅ Succès: ${results.length} résultats trouvés`);
            // Afficher quelques résultats pour debug
            results.slice(0, 5).forEach((result, i) => {
                console.log(`  ${i + 1}. ${result.path} (${result.type})`);
            });
        }
        catch (error) {
            console.error(`❌ Erreur:`, error.message);
        }
    }
}
async function testSearchWorkspaceFiles() {
    console.log("\n🔍 Test de la fonction searchWorkspaceFiles...");
    try {
        const results = await executeRipgrepForFiles(TEST_WORKSPACE, 100);
        console.log(`✅ Succès: ${results.length} fichiers trouvés`);
        // Afficher les résultats intéressants (avec caractères spéciaux)
        const specialResults = results.filter(r => r.path.includes(' ') ||
            r.path.includes('é') ||
            r.path.includes("'") ||
            r.path.includes('"') ||
            r.path.includes('&'));
        console.log("📋 Fichiers avec caractères spéciaux trouvés:");
        specialResults.forEach((result, i) => {
            console.log(`  ${i + 1}. "${result.path}" (${result.type})`);
        });
    }
    catch (error) {
        console.error(`❌ Erreur dans searchWorkspaceFiles:`, error.message);
    }
}
async function cleanupTestEnvironment() {
    console.log("\n🧹 Nettoyage de l'environnement de test...");
    if (fs.existsSync(TEST_WORKSPACE)) {
        fs.rmSync(TEST_WORKSPACE, { recursive: true, force: true });
        console.log("✅ Environnement de test supprimé");
    }
}
async function runTests() {
    console.log("🚀 Démarrage des tests de recherche de fichiers");
    console.log("=".repeat(60));
    try {
        await setupTestEnvironment();
        await testRipgrepExecution();
        await testSearchWorkspaceFiles();
    }
    catch (error) {
        console.error("💥 Erreur fatale:", error);
    }
    finally {
        // Note: On ne nettoie PAS automatiquement pour pouvoir inspecter les résultats
        // await cleanupTestEnvironment()
        console.log("\n📝 Note: L'environnement de test est conservé pour inspection");
        console.log(`   Répertoire: ${TEST_WORKSPACE}`);
    }
}
// Exécution si appelé directement
if (require.main === module) {
    runTests().catch(console.error);
}
export { runTests, setupTestEnvironment, cleanupTestEnvironment, TEST_WORKSPACE };
