/**
 * Script de test pour le prototype minimal viable du MCP GitHub Projects
 */

const axios = require('axios');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

// Charger les variables d'environnement
dotenv.config({ path: path.join(__dirname, '../../mcp-servers/servers/github-projects-mcp/.env') });

// Configuration
const PORT = process.env.MCP_PORT || 3002;
const HOST = process.env.MCP_HOST || 'localhost';
const BASE_URL = `http://${HOST}:${PORT}/api/mcp`;

// Fonction pour afficher les messages de log
function log(message, level = 'INFO') {
  const timestamp = new Date().toISOString();
  const colorMap = {
    'INFO': '\x1b[36m', // Cyan
    'SUCCESS': '\x1b[32m', // Vert
    'WARNING': '\x1b[33m', // Jaune
    'ERROR': '\x1b[31m', // Rouge
    'RESET': '\x1b[0m' // Reset
  };
  
  console.log(`${colorMap[level]}[${timestamp}] [${level}] ${message}${colorMap['RESET']}`);
}

// Fonction pour tester le statut du serveur
async function testServerStatus() {
  try {
    log('Test du statut du serveur MCP GitHub Projects...');
    const response = await axios.get(`${BASE_URL}/status`);
    
    if (response.data && response.data.status === 'running') {
      log(`Serveur MCP en cours d'exécution: ${JSON.stringify(response.data)}`, 'SUCCESS');
      return true;
    } else {
      log(`Réponse inattendue du serveur: ${JSON.stringify(response.data)}`, 'WARNING');
      return false;
    }
  } catch (error) {
    log(`Erreur lors du test du statut du serveur: ${error.message}`, 'ERROR');
    return false;
  }
}

// Fonction pour tester la découverte des outils et ressources
async function testDiscovery() {
  try {
    log('Test de la découverte des outils et ressources...');
    const response = await axios.get(`${BASE_URL}/discovery`);
    
    if (response.data && response.data.tools && response.data.resources) {
      log(`Découverte réussie: ${response.data.tools.length} outils et ${response.data.resources.length} ressources`, 'SUCCESS');
      log(`Outils disponibles: ${response.data.tools.map(t => t.name).join(', ')}`, 'INFO');
      log(`Ressources disponibles: ${response.data.resources.map(r => r.name).join(', ')}`, 'INFO');
      return true;
    } else {
      log(`Réponse inattendue du serveur: ${JSON.stringify(response.data)}`, 'WARNING');
      return false;
    }
  } catch (error) {
    log(`Erreur lors du test de découverte: ${error.message}`, 'ERROR');
    return false;
  }
}

// Fonction pour tester l'outil list_projects
async function testListProjects(owner = 'octocat') {
  try {
    log(`Test de l'outil list_projects pour l'utilisateur ${owner}...`);
    const response = await axios.post(`${BASE_URL}/invoke`, {
      tool_name: 'list_projects',
      arguments: {
        owner,
        type: 'user'
      }
    });
    
    if (response.data && response.data.success) {
      log(`Liste des projets récupérée avec succès: ${response.data.projects.length} projets trouvés`, 'SUCCESS');
      if (response.data.projects.length > 0) {
        log(`Premier projet: ${JSON.stringify(response.data.projects[0])}`, 'INFO');
        return response.data.projects[0];
      } else {
        log(`Aucun projet trouvé pour ${owner}`, 'WARNING');
        return null;
      }
    } else {
      log(`Erreur lors de la récupération des projets: ${JSON.stringify(response.data)}`, 'WARNING');
      return null;
    }
  } catch (error) {
    log(`Erreur lors du test de list_projects: ${error.message}`, 'ERROR');
    if (error.response) {
      log(`Détails de l'erreur: ${JSON.stringify(error.response.data)}`, 'ERROR');
    }
    return null;
  }
}

// Fonction pour tester l'outil get_project
async function testGetProject(owner = 'octocat', projectNumber = 1) {
  try {
    log(`Test de l'outil get_project pour le projet #${projectNumber} de ${owner}...`);
    const response = await axios.post(`${BASE_URL}/invoke`, {
      tool_name: 'get_project',
      arguments: {
        owner,
        project_number: projectNumber
      }
    });
    
    if (response.data && response.data.success) {
      log(`Détails du projet récupérés avec succès: ${response.data.project.title}`, 'SUCCESS');
      log(`Détails: ${JSON.stringify(response.data.project)}`, 'INFO');
      return response.data.project;
    } else {
      log(`Erreur lors de la récupération des détails du projet: ${JSON.stringify(response.data)}`, 'WARNING');
      return null;
    }
  } catch (error) {
    log(`Erreur lors du test de get_project: ${error.message}`, 'ERROR');
    if (error.response) {
      log(`Détails de l'erreur: ${JSON.stringify(error.response.data)}`, 'ERROR');
    }
    return null;
  }
}

// Fonction pour tester l'outil add_item_to_project
async function testAddItemToProject(projectId, contentId = null) {
  try {
    if (!projectId) {
      log('Impossible de tester add_item_to_project: ID de projet manquant', 'WARNING');
      return null;
    }
    
    // Si aucun contentId n'est fourni, créer une note
    const args = contentId ? {
      project_id: projectId,
      content_id: contentId,
      content_type: 'issue'
    } : {
      project_id: projectId,
      content_type: 'draft_issue',
      draft_title: 'Test note from MCP',
      draft_body: 'This is a test note created by the GitHub Projects MCP prototype.'
    };
    
    log(`Test de l'outil add_item_to_project pour ${contentId ? 'une issue' : 'une note'}...`);
    const response = await axios.post(`${BASE_URL}/invoke`, {
      tool_name: 'add_item_to_project',
      arguments: args
    });
    
    if (response.data && response.data.success) {
      log(`Élément ajouté avec succès au projet: ${response.data.item_id}`, 'SUCCESS');
      return response.data.item_id;
    } else {
      log(`Erreur lors de l'ajout de l'élément au projet: ${JSON.stringify(response.data)}`, 'WARNING');
      return null;
    }
  } catch (error) {
    log(`Erreur lors du test de add_item_to_project: ${error.message}`, 'ERROR');
    if (error.response) {
      log(`Détails de l'erreur: ${JSON.stringify(error.response.data)}`, 'ERROR');
    }
    return null;
  }
}

// Fonction pour tester l'accès aux ressources
async function testResources(owner = 'octocat') {
  try {
    log(`Test de l'accès aux ressources pour l'utilisateur ${owner}...`);
    const uri = `github-projects://${owner}/user?state=open`;
    const encodedUri = encodeURIComponent(uri);
    
    const response = await axios.get(`${BASE_URL}/resource/${encodedUri}`);
    
    if (response.data && response.data.projects) {
      log(`Ressource récupérée avec succès: ${response.data.projects.length} projets trouvés`, 'SUCCESS');
      return true;
    } else {
      log(`Réponse inattendue du serveur: ${JSON.stringify(response.data)}`, 'WARNING');
      return false;
    }
  } catch (error) {
    log(`Erreur lors du test des ressources: ${error.message}`, 'ERROR');
    if (error.response) {
      log(`Détails de l'erreur: ${JSON.stringify(error.response.data)}`, 'ERROR');
    }
    return false;
  }
}

// Fonction principale pour exécuter tous les tests
async function runTests() {
  log('Démarrage des tests du prototype minimal viable du MCP GitHub Projects', 'INFO');
  
  // Test 1: Vérifier le statut du serveur
  const serverOk = await testServerStatus();
  
  if (!serverOk) {
    log('Le serveur MCP ne répond pas. Assurez-vous qu\'il est en cours d\'exécution.', 'ERROR');
    return;
  }
  
  // Test 2: Vérifier la découverte des outils et ressources
  const discoveryOk = await testDiscovery();
  
  // Test 3: Tester l'outil list_projects
  const project = await testListProjects();
  
  // Test 4: Tester l'outil get_project
  let projectDetails = null;
  if (project) {
    projectDetails = await testGetProject(project.owner, project.number);
  } else {
    // Essayer avec un projet par défaut
    projectDetails = await testGetProject();
  }
  
  // Test 5: Tester l'outil add_item_to_project
  if (projectDetails) {
    await testAddItemToProject(projectDetails.id);
  }
  
  // Test 6: Tester l'accès aux ressources
  await testResources();
  
  log('Tests terminés', 'INFO');
}

// Exécuter les tests
runTests().catch(error => {
  log(`Erreur non gérée: ${error.message}`, 'ERROR');
  process.exit(1);
});