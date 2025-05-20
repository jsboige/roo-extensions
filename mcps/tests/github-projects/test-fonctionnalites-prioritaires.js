/**
 * Tests unitaires pour les fonctionnalités prioritaires du MCP GitHub Projects
 * 
 * Ce fichier contient des tests pour les fonctionnalités suivantes:
 * - create_project: Création d'un nouveau projet
 * - update_project_item_field: Mise à jour des champs d'un élément dans un projet
 * - delete_project_item: Suppression d'un élément d'un projet
 */

const axios = require('axios');
const assert = require('assert');

// Configuration
const MCP_HOST = process.env.MCP_HOST || 'localhost';
const MCP_PORT = process.env.MCP_PORT || 3002;
const BASE_URL = `http://${MCP_HOST}:${MCP_PORT}/api/mcp/invoke`;

// Paramètres de test
const TEST_OWNER = process.env.GITHUB_TEST_OWNER || 'votre-nom-utilisateur'; // À remplacer par votre nom d'utilisateur GitHub
const TEST_REPO = process.env.GITHUB_TEST_REPO || 'votre-repo-test'; // À remplacer par un repo de test

// Fonction utilitaire pour invoquer un outil MCP
async function invokeTool(toolName, args) {
  try {
    const response = await axios.post(BASE_URL, {
      tool_name: toolName,
      arguments: args
    });
    return response.data;
  } catch (error) {
    console.error(`Erreur lors de l'invocation de l'outil ${toolName}:`, error.response?.data || error.message);
    throw error;
  }
}

// Fonction pour attendre un certain temps
function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Tests
async function runTests() {
  console.log('='.repeat(50));
  console.log('Démarrage des tests des fonctionnalités prioritaires');
  console.log('='.repeat(50));

  let projectId;
  let projectNumber;
  let itemId;

  try {
    // Test 1: Création d'un projet
    console.log('\n1. Test de create_project');
    console.log('-'.repeat(30));
    
    const projectTitle = `Projet de test ${new Date().toISOString()}`;
    const projectDescription = 'Projet créé automatiquement pour les tests unitaires';
    
    const createResult = await invokeTool('create_project', {
      owner: TEST_OWNER,
      title: projectTitle,
      description: projectDescription,
      type: 'user'
    });
    
    console.log('Résultat:', JSON.stringify(createResult, null, 2));
    
    assert(createResult.success, 'La création du projet a échoué');
    assert(createResult.project.title === projectTitle, 'Le titre du projet ne correspond pas');
    assert(createResult.project.description === projectDescription, 'La description du projet ne correspond pas');
    
    projectId = createResult.project.id;
    projectNumber = createResult.project.number;
    
    console.log(`Projet créé avec succès: #${projectNumber} (${projectId})`);

    // Attendre un peu pour s'assurer que le projet est bien créé
    await wait(2000);

    // Test 2: Ajout d'un élément au projet (note)
    console.log('\n2. Test de add_item_to_project (note)');
    console.log('-'.repeat(30));
    
    const noteTitle = `Note de test ${new Date().toISOString()}`;
    const noteBody = 'Note créée automatiquement pour les tests unitaires';
    
    const addItemResult = await invokeTool('add_item_to_project', {
      project_id: projectId,
      content_type: 'draft_issue',
      draft_title: noteTitle,
      draft_body: noteBody
    });
    
    console.log('Résultat:', JSON.stringify(addItemResult, null, 2));
    
    assert(addItemResult.success, 'L\'ajout de la note au projet a échoué');
    assert(addItemResult.item_id, 'L\'ID de l\'élément n\'a pas été retourné');
    
    itemId = addItemResult.item_id;
    
    console.log(`Note ajoutée avec succès: ${itemId}`);

    // Attendre un peu pour s'assurer que l'élément est bien ajouté
    await wait(2000);

    // Test 3: Mise à jour d'un champ d'un élément
    console.log('\n3. Test de update_project_item_field');
    console.log('-'.repeat(30));
    
    // D'abord, récupérer les champs du projet pour trouver un champ à mettre à jour
    const fieldsResult = await invokeTool('get_project_fields', {
      owner: TEST_OWNER,
      project_number: projectNumber
    });
    
    console.log('Champs disponibles:', JSON.stringify(fieldsResult.fields, null, 2));
    
    // Trouver un champ de type texte
    const textField = fieldsResult.fields.find(field => field.type === 'TEXT');
    
    if (textField) {
      const updateFieldResult = await invokeTool('update_project_item_field', {
        project_id: projectId,
        item_id: itemId,
        field_id: textField.id,
        field_type: 'text',
        value: `Valeur mise à jour ${new Date().toISOString()}`
      });
      
      console.log('Résultat:', JSON.stringify(updateFieldResult, null, 2));
      
      assert(updateFieldResult.success, 'La mise à jour du champ a échoué');
      assert(updateFieldResult.item_id === itemId, 'L\'ID de l\'élément ne correspond pas');
      
      console.log(`Champ mis à jour avec succès pour l'élément ${itemId}`);
    } else {
      console.log('Aucun champ de type texte trouvé, test ignoré');
    }

    // Attendre un peu pour s'assurer que la mise à jour est bien effectuée
    await wait(2000);

    // Test 4: Suppression d'un élément du projet
    console.log('\n4. Test de delete_project_item');
    console.log('-'.repeat(30));
    
    const deleteResult = await invokeTool('delete_project_item', {
      owner: TEST_OWNER,
      project_number: projectNumber,
      item_id: itemId
    });
    
    console.log('Résultat:', JSON.stringify(deleteResult, null, 2));
    
    assert(deleteResult.success, 'La suppression de l\'élément a échoué');
    assert(deleteResult.deleted_item_id === itemId, 'L\'ID de l\'élément supprimé ne correspond pas');
    
    console.log(`Élément supprimé avec succès: ${itemId}`);

    console.log('\nTous les tests ont réussi!');
  } catch (error) {
    console.error('\nErreur lors des tests:', error);
    process.exit(1);
  }
}

// Exécuter les tests
runTests().catch(error => {
  console.error('Erreur non gérée:', error);
  process.exit(1);
});