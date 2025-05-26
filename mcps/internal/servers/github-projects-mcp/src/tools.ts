import { Tool } from '@modelcontextprotocol/sdk/types.js';
import { CallToolRequestSchema, ListToolsRequestSchema, ErrorCode, McpError } from '@modelcontextprotocol/sdk/types.js';
// import { Octokit } from '@octokit/rest'; // Octokit est déjà initialisé via getGitHubClient
import { getGitHubClient } from './utils/github';

// Interfaces pour les réponses GraphQL (similaires à resources.ts)
interface GitHubProjectNode {
  id: string;
  title: string;
  number: number;
  shortDescription?: string;
  url: string;
  closed: boolean;
  createdAt: string;
  updatedAt: string;
  items?: {
    nodes: GitHubProjectItem[];
  };
  fields?: {
    nodes: GitHubProjectField[];
  };
}

interface GitHubProjectItemContent {
  title?: string;
  number?: number;
  state?: string;
  url?: string;
  body?: string;
}

interface GitHubProjectItem {
  id: string;
  type: string;
  content?: GitHubProjectItemContent;
  fieldValues?: {
    nodes: GitHubProjectFieldValue[];
  };
}

interface GitHubProjectFieldValue {
  text?: string;
  date?: string;
  name?: string; // For single select option name
  field?: {
    name?: string; // For field name
  };
}

interface GitHubProjectFieldOption {
  id: string;
  name: string;
  color?: string;
}

interface GitHubProjectField {
  id: string;
  name: string;
  options?: GitHubProjectFieldOption[];
}

interface GraphQLProjectsResponseUser {
  user: {
    projectsV2: {
      nodes: GitHubProjectNode[];
    };
  };
}

interface GraphQLProjectsResponseOrg {
  organization: {
    projectsV2: {
      nodes: GitHubProjectNode[];
    };
  };
}

interface GraphQLOwnerIdResponse {
  user?: { id: string };
  organization?: { id: string };
}

interface GraphQLCreateProjectResponse {
  createProjectV2: {
    projectV2: GitHubProjectNode;
  };
}

interface GraphQLGetProjectResponse {
    user?: { projectV2: GitHubProjectNode };
    organization?: { projectV2: GitHubProjectNode };
}

interface GraphQLAddProjectItemResponse {
  addProjectV2ItemById?: { // Pour issues/PRs
    item: { id: string };
  };
  addProjectV2DraftIssue?: { // Pour draft issues
    projectItem: { id: string };
  };
}

interface GraphQLUpdateProjectItemFieldResponse {
  updateProjectV2ItemFieldValue: {
    projectV2Item: {
      id: string;
    };
  };
}


// Initialiser le client GitHub
const octokit = getGitHubClient();

/**
 * Configure les outils MCP pour interagir avec GitHub Projects
 * @param server Instance du serveur MCP
 */
export function setupTools(server: any) {
  // Définir la liste des outils disponibles
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
  // Outil pour lister les projets d'un utilisateur ou d'une organisation
  {
    name: 'list_projects',
    description: 'Liste les projets GitHub d\'un utilisateur ou d\'une organisation',
    inputSchema: {
      type: 'object',
      properties: {
        owner: {
          type: 'string',
          description: 'Nom d\'utilisateur ou d\'organisation'
        },
        type: {
          type: 'string',
          enum: ['user', 'org'],
          description: 'Type de propriétaire (utilisateur ou organisation)',
          default: 'user'
        },
        state: {
          type: 'string',
          enum: ['open', 'closed', 'all'],
          description: 'État des projets à récupérer',
          default: 'open'
        }
      },
      required: ['owner']
    },
    execute: async ({ owner, type = 'user', state = 'open' }) => {
      try {
        const query = `
          query($owner: String!, $type: String!) {
            ${type === 'user' ? 'user' : 'organization'}(login: $owner) {
              projectsV2(first: 20, states: ${state === 'all' ? '[OPEN, CLOSED]' : state === 'closed' ? '[CLOSED]' : '[OPEN]'}) {
                nodes {
                  id
                  title
                  number
                  shortDescription
                  url
                  closed
                  createdAt
                  updatedAt
                }
              }
            }
          }
        `;

        const response = await octokit.graphql(query, {
          owner,
          type
        }) as unknown;

        let projects: GitHubProjectNode[] = [];
        if (type === 'user' && response && typeof response === 'object' && 'user' in response) {
          const userResponse = response as GraphQLProjectsResponseUser;
          if (userResponse.user?.projectsV2?.nodes) {
            projects = userResponse.user.projectsV2.nodes;
          }
        } else if (type === 'org' && response && typeof response === 'object' && 'organization' in response) {
          const orgResponse = response as GraphQLProjectsResponseOrg;
          if (orgResponse.organization?.projectsV2?.nodes) {
            projects = orgResponse.organization.projectsV2.nodes;
          }
        } else {
            console.warn('[list_projects] Réponse GraphQL inattendue:', response);
        }
        

        return {
          success: true,
          projects: projects.map((project: GitHubProjectNode) => ({
            id: project.id,
            title: project.title,
            number: project.number,
            description: project.shortDescription,
            url: project.url,
            closed: project.closed,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt
          }))
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message || 'Erreur lors de la récupération des projets'
        };
      }
    }
  },

  // Outil pour créer un nouveau projet
  {
    name: 'create_project',
    description: 'Crée un nouveau projet GitHub',
    inputSchema: {
      type: 'object',
      properties: {
        owner: {
          type: 'string',
          description: 'Nom d\'utilisateur ou d\'organisation'
        },
        title: {
          type: 'string',
          description: 'Titre du projet'
        },
        description: {
          type: 'string',
          description: 'Description du projet'
        },
        type: {
          type: 'string',
          enum: ['user', 'org'],
          description: 'Type de propriétaire (utilisateur ou organisation)',
          default: 'user'
        }
      },
      required: ['owner', 'title']
    },
    execute: async ({ owner, title, description = '', type = 'user' }) => {
      try {
        const ownerQuery = `
          query($login: String!) {
            ${type === 'user' ? 'user' : 'organization'}(login: $login) {
              id
            }
          }
        `;

        const ownerData = await octokit.graphql(ownerQuery, {
          login: owner
        }) as unknown as GraphQLOwnerIdResponse;

        const ownerId = type === 'user' ? ownerData.user?.id : ownerData.organization?.id;
        if (!ownerId) {
          throw new Error(`Impossible de récupérer l'ID pour ${type} ${owner}`);
        }
        
        const createQuery = `
          mutation($ownerId: ID!, $title: String!, $description: String) {
            createProjectV2(input: {
              ownerId: $ownerId,
              title: $title,
              description: $description
            }) {
              projectV2 {
                id
                title
                number
                shortDescription
                url
                closed
                createdAt
                updatedAt
              }
            }
          }
        `;

        const response = await octokit.graphql(createQuery, {
          ownerId,
          title,
          description
        }) as unknown as GraphQLCreateProjectResponse;

        const project = response.createProjectV2?.projectV2;
        if (!project) {
            throw new Error('La création du projet a échoué ou la réponse est invalide.');
        }

        return {
          success: true,
          project: {
            id: project.id,
            title: project.title,
            number: project.number,
            description: project.shortDescription,
            url: project.url,
            closed: project.closed,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt
          }
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message || 'Erreur lors de la création du projet'
        };
      }
    }
  },

  // Outil pour obtenir les détails d'un projet
  {
    name: 'get_project',
    description: 'Récupère les détails d\'un projet GitHub',
    inputSchema: {
      type: 'object',
      properties: {
        owner: {
          type: 'string',
          description: 'Nom d\'utilisateur ou d\'organisation'
        },
        project_number: {
          type: 'number',
          description: 'Numéro du projet'
        }
      },
      required: ['owner', 'project_number']
    },
    execute: async ({ owner, project_number }) => {
      try {
        // Note: La query originale suppose 'user'. Il faudrait déterminer le type d'owner.
        // Pour cet outil, on va supposer que l'API GitHub peut résoudre le projet via user OU org.
        // Une approche plus robuste serait de demander le type d'owner en input.
        // Pour l'instant, on essaie avec 'user', puis 'organization' si ça échoue ou si on a une indication.
        // Simplifions pour l'instant en gardant la logique de 'user' comme dans le fichier resources.ts
        const query = `
          query($owner: String!, $number: Int!) {
            user(login: $owner) { # Potentiellement adapter pour organization
              projectV2(number: $number) {
                id
                title
                number
                shortDescription
                url
                closed
                createdAt
                updatedAt
                items(first: 100) {
                  nodes {
                    id
                    type
                    content {
                      ... on Issue { title number state url }
                      ... on PullRequest { title number state url }
                      ... on DraftIssue { title body }
                    }
                    fieldValues(first: 20) {
                      nodes {
                        ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2FieldCommon { name } } }
                        ... on ProjectV2ItemFieldDateValue { date field { ... on ProjectV2FieldCommon { name } } }
                        ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2FieldCommon { name } } }
                      }
                    }
                  }
                }
                fields(first: 20) {
                  nodes {
                    ... on ProjectV2FieldCommon { id name }
                    ... on ProjectV2SingleSelectField { id name options { id name color } }
                  }
                }
              }
            }
          }
        `;

        const response = await octokit.graphql(query, {
          owner,
          number: project_number
        }) as unknown as GraphQLGetProjectResponse;

        const project = response.user?.projectV2; // Ou response.organization?.projectV2
        if (!project) {
            throw new Error(`Projet non trouvé pour ${owner}/${project_number} ou réponse invalide.`);
        }
        
        return {
          success: true,
          project: {
            id: project.id,
            title: project.title,
            number: project.number,
            description: project.shortDescription,
            url: project.url,
            closed: project.closed,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            items: project.items?.nodes.map((item: GitHubProjectItem) => {
              const itemData: Partial<GitHubProjectItem & { fields: any[] }> = {
                id: item.id,
                type: item.type
              };
              if (item.content) itemData.content = item.content;
              if (item.fieldValues?.nodes) {
                itemData.fields = item.fieldValues.nodes.map((fieldValue: GitHubProjectFieldValue) => {
                  if (fieldValue.field?.name) {
                    return {
                      name: fieldValue.field.name,
                      value: fieldValue.text || fieldValue.date || fieldValue.name
                    };
                  }
                  return null;
                }).filter(Boolean);
              }
              return itemData;
            }),
            fields: project.fields?.nodes.map((field: GitHubProjectField) => {
              const fieldData: Partial<GitHubProjectField> = {
                id: field.id,
                name: field.name
              };
              if (field.options) fieldData.options = field.options;
              return fieldData;
            })
          }
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message || 'Erreur lors de la récupération du projet'
        };
      }
    }
  },

  // Outil pour ajouter un élément à un projet
  {
    name: 'add_item_to_project',
    description: 'Ajoute un élément (issue, pull request ou note) à un projet GitHub',
    inputSchema: {
      type: 'object',
      properties: {
        project_id: { type: 'string', description: 'ID du projet' },
        content_id: { type: 'string', description: 'ID de l\'élément à ajouter (issue ou pull request)' },
        content_type: { type: 'string', enum: ['issue', 'pull_request', 'draft_issue'], default: 'issue' },
        draft_title: { type: 'string', description: 'Titre de la note (uniquement pour les notes)' },
        draft_body: { type: 'string', description: 'Corps de la note (uniquement pour les notes)' }
      },
      required: ['project_id']
    },
    execute: async ({ project_id, content_id, content_type = 'issue', draft_title = '', draft_body = '' }) => {
      try {
        let query;
        let variables: any = { projectId: project_id };

        if (content_type === 'draft_issue') {
          if (!draft_title) throw new Error("Le titre est requis pour une draft_issue.");
          query = `
            mutation($projectId: ID!, $title: String!, $body: String) {
              addProjectV2DraftIssue(input: { projectId: $projectId, title: $title, body: $body }) {
                projectItem { id }
              }
            }`;
          variables.title = draft_title;
          variables.body = draft_body;
        } else {
          if (!content_id) throw new Error("content_id est requis pour issue ou pull_request.");
          query = `
            mutation($projectId: ID!, $contentId: ID!) {
              addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
                item { id }
              }
            }`;
          variables.contentId = content_id;
        }

        const response = await octokit.graphql(query, variables) as unknown as GraphQLAddProjectItemResponse;

        const itemId = content_type === 'draft_issue'
          ? response.addProjectV2DraftIssue?.projectItem?.id
          : response.addProjectV2ItemById?.item?.id;

        if (!itemId) {
            throw new Error("Impossible d'ajouter l'élément ou réponse invalide.");
        }

        return { success: true, item_id: itemId };
      } catch (error: any) {
        return { success: false, error: error.message || 'Erreur lors de l\'ajout de l\'élément au projet' };
      }
    }
  },

  // Outil pour mettre à jour un champ d'un élément dans un projet
  {
    name: 'update_project_item_field',
    description: 'Met à jour la valeur d\'un champ pour un élément dans un projet GitHub',
    inputSchema: {
      type: 'object',
      properties: {
        project_id: { type: 'string', description: 'ID du projet' },
        item_id: { type: 'string', description: 'ID de l\'élément dans le projet' },
        field_id: { type: 'string', description: 'ID du champ à mettre à jour' },
        field_type: { type: 'string', enum: ['text', 'date', 'single_select', 'number'], default: 'text' },
        value: { type: 'string', description: 'Nouvelle valeur pour le champ (requis sauf pour single_select avec option_id)' },
        option_id: { type: 'string', description: 'ID de l\'option pour les champs de type single_select' }
      },
      required: ['project_id', 'item_id', 'field_id', 'field_type']
    },
    execute: async ({ project_id, item_id, field_id, field_type, value, option_id }) => {
      try {
        let query;
        let variables: any = { projectId: project_id, itemId: item_id, fieldId: field_id };

        switch (field_type) {
          case 'text':
            if (value === undefined) throw new Error("La valeur 'value' est requise pour le type 'text'.");
            query = `mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $text: String!) {
              updateProjectV2ItemFieldValue(input: { projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: { text: $text }}) {
                projectV2Item { id }
              }}`;
            variables.text = value;
            break;
          case 'date':
            if (value === undefined) throw new Error("La valeur 'value' est requise pour le type 'date'.");
            query = `mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $date: Date!) {
              updateProjectV2ItemFieldValue(input: { projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: { date: $date }}) {
                projectV2Item { id }
              }}`;
            variables.date = value; // Assurez-vous que le format est ISO 8601
            break;
          case 'single_select':
            if (!option_id) throw new Error("La valeur 'option_id' est requise pour le type 'single_select'.");
            query = `mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
              updateProjectV2ItemFieldValue(input: { projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: { singleSelectOptionId: $optionId }}) {
                projectV2Item { id }
              }}`;
            variables.optionId = option_id;
            break;
          case 'number':
            if (value === undefined) throw new Error("La valeur 'value' est requise pour le type 'number'.");
            const numValue = parseFloat(value);
            if (isNaN(numValue)) throw new Error("La valeur pour 'number' doit être un nombre valide.");
            query = `mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $number: Float!) {
              updateProjectV2ItemFieldValue(input: { projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: { number: $number }}) {
                projectV2Item { id }
              }}`;
            variables.number = numValue;
            break;
          default:
            return { success: false, error: `Type de champ non pris en charge: ${field_type}` };
        }

        const response = await octokit.graphql(query, variables) as unknown as GraphQLUpdateProjectItemFieldResponse;
        const updatedItemId = response.updateProjectV2ItemFieldValue?.projectV2Item?.id;

        if (!updatedItemId) {
            throw new Error("Impossible de mettre à jour le champ ou réponse invalide.");
        }
        return { success: true, item_id: updatedItemId };
      } catch (error: any) {
        return { success: false, error: error.message || 'Erreur lors de la mise à jour du champ' };
      }
    }
  }
    ]
  }));

  // Gérer les requêtes d'outils
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const tool = server.tools.find((t: Tool) => t.name === request.params.name);
    if (!tool || !tool.execute) {
        throw new McpError(
            ErrorCode.MethodNotFound,
            `Outil inconnu ou non exécutable: ${request.params.name}`
        );
    }
    try {
        const result = await tool.execute(request.params.arguments);
        return {
            content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
            isError: !result.success
        };
    } catch (error: any) {
        return {
            content: [{ type: 'text', text: JSON.stringify({ success: false, error: error.message }, null, 2) }],
            isError: true
        };
    }
  });

  // Les fonctions handleXXX ne sont plus nécessaires car la logique est dans execute de chaque outil
  // et le CallToolRequestSchema handler appelle directement tool.execute.
  // Si vous souhaitez les conserver pour une raison spécifique, assurez-vous qu'elles sont appelées correctement.
  // Pour l'instant, je les commente pour éviter la redondance et les erreurs potentielles.

  /*
  async function handleListProjects(args: any) {
    // ... (logique déplacée vers l'outil list_projects.execute) ...
  }

  async function handleCreateProject(args: any) {
    // ... (logique déplacée vers l'outil create_project.execute) ...
  }

  async function handleGetProject(args: any) {
    // Implémentation similaire à celle de l'outil get_project
    // ...
    return { content: [{ type: 'text', text: 'Non implémenté via handleGetProject' }] };
  }

  async function handleAddItemToProject(args: any) {
    // Implémentation similaire à celle de l'outil add_item_to_project
    // ...
    return { content: [{ type: 'text', text: 'Non implémenté via handleAddItemToProject' }] };
  }

  async function handleUpdateProjectItemField(args: any) {
    // Implémentation similaire à celle de l'outil update_project_item_field
    // ...
    return { content: [{ type: 'text', text: 'Non implémenté via handleUpdateProjectItemField' }] };
  }
  */
}