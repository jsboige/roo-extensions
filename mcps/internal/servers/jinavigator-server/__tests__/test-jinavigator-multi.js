// Script de test pour l'outil convert_multiple_webs_to_markdown du serveur MCP jinavigator

// Fonction pour tester l'outil convert_multiple_webs_to_markdown
async function testMultipleUrls() {
  console.log('=== Test de l\'outil convert_multiple_webs_to_markdown ===');
  
  try {
    // Utilisation de l'outil MCP
    console.log('Appel de l\'outil convert_multiple_webs_to_markdown...');
    
    // Exemple d'utilisation de l'outil
    const result = await useMcpTool('jinavigator', 'multi_convert', {
      urls: [
        { 
          url: "https://en.wikipedia.org/wiki/JavaScript", 
          start_line: 5, 
          end_line: 15 
        },
        { 
          url: "https://en.wikipedia.org/wiki/TypeScript", 
          start_line: 20, 
          end_line: 30 
        },
        { 
          url: "https://en.wikipedia.org/wiki/Node.js", 
          start_line: 15, 
          end_line: 25 
        }
      ]
    });
    
    console.log('Résultat de l\'appel à multi_convert:');
    console.log(JSON.stringify(result, null, 2));
    
    // Vérification des résultats
    if (result && Array.isArray(result)) {
      console.log(`Nombre d'URLs traitées: ${result.length}`);
      
      // Vérification de chaque résultat
      for (const item of result) {
        console.log(`\nURL: ${item.url}`);
        console.log(`Succès: ${item.success}`);
        if (item.success) {
          console.log(`Longueur du contenu: ${item.content.length} caractères`);
          console.log(`Extrait: ${item.content.substring(0, 100)}...`);
        } else {
          console.log(`Erreur: ${item.error}`);
        }
      }
    } else {
      console.log('Format de résultat inattendu:', result);
    }
  } catch (error) {
    console.error('Erreur lors du test:', error);
  }
}

// Fonction simulant l'utilisation de l'outil MCP
// Dans un environnement réel, cette fonction serait remplacée par l'appel à l'API MCP
async function useMcpTool(serverName, toolName, args) {
  console.log(`Appel de l'outil ${toolName} sur le serveur ${serverName} avec les arguments:`, JSON.stringify(args, null, 2));
  
  // Cette partie est une simulation - dans un environnement réel, vous utiliseriez l'API MCP
  // Pour tester réellement, vous devriez utiliser l'outil use_mcp_tool de Claude
  
  console.log('ATTENTION: Ceci est une simulation. Pour un test réel, utilisez l\'outil use_mcp_tool de Claude.');
  
  return [
    {
      url: "https://en.wikipedia.org/wiki/JavaScript",
      success: true,
      content: "Contenu simulé pour JavaScript..."
    },
    {
      url: "https://en.wikipedia.org/wiki/TypeScript",
      success: true,
      content: "Contenu simulé pour TypeScript..."
    },
    {
      url: "https://en.wikipedia.org/wiki/Node.js",
      success: true,
      content: "Contenu simulé pour Node.js..."
    }
  ];
}

// Exécution du test
testMultipleUrls().then(() => {
  console.log('\nTest terminé.');
}).catch(error => {
  console.error('Erreur lors de l\'exécution du test:', error);
});

console.log('Pour tester réellement avec Claude, utilisez:');
console.log(`
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>multi_convert</tool_name>
<arguments>
{
  "urls": [
    { 
      "url": "https://en.wikipedia.org/wiki/JavaScript", 
      "start_line": 5, 
      "end_line": 15 
    },
    { 
      "url": "https://en.wikipedia.org/wiki/TypeScript", 
      "start_line": 20, 
      "end_line": 30 
    },
    { 
      "url": "https://en.wikipedia.org/wiki/Node.js", 
      "start_line": 15, 
      "end_line": 25 
    }
  ]
}
</arguments>
</use_mcp_tool>
`);