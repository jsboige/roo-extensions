import { Tool } from '@modelcontextprotocol/sdk/types.js';
import { CallToolRequestSchema, ListToolsRequestSchema, ErrorCode, McpError } from '@modelcontextprotocol/sdk/types.js';
import { Octokit } from '@octokit/rest';
import { getGitHubClient } from './utils/github';

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
        // Utiliser l'API GraphQL pour récupérer les projets (v2)
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
        });

        const projects = type === 'user' 
          ? response.user.projectsV2.nodes 
          : response.organization.projectsV2.nodes;

        return {
          success: true,
          projects: projects.map((project: any) => ({
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
        // Utiliser l'API GraphQL pour créer un projet (v2)
        const query = `
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

        // D'abord, obtenir l'ID du propriétaire
        const ownerQuery = `
          query($login: String!) {
            ${type === 'user' ? 'user' : 'organization'}(login: $login) {
              id
            }
          }
        `;

        const ownerData = await octokit.graphql(ownerQuery, {
          login: owner
        });

        const ownerId = type === 'user' 
          ? ownerData.user.id 
          : ownerData.organization.id;

        const response = await octokit.graphql(query, {
          ownerId,
          title,
          description
        });

        const project = response.createProjectV2.projectV2;

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
        // Utiliser l'API GraphQL pour récupérer les détails d'un projet (v2)
        const query = `
          query($owner: String!, $number: Int!) {
            user(login: $owner) {
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
                      ... on Issue {
                        title
                        number
                        state
                        url
                      }
                      ... on PullRequest {
                        title
                        number
                        state
                        url
                      }
                      ... on DraftIssue {
                        title
                        body
                      }
                    }
                    fieldValues(first: 20) {
                      nodes {
                        ... on ProjectV2ItemFieldTextValue {
                          text
                          field {
                            ... on ProjectV2FieldCommon {
                              name
                            }
                          }
                        }
                        ... on ProjectV2ItemFieldDateValue {
                          date
                          field {
                            ... on ProjectV2FieldCommon {
                              name
                            }
                          }
                        }
                        ... on ProjectV2ItemFieldSingleSelectValue {
                          name
                          field {
                            ... on ProjectV2FieldCommon {
                              name
                            }
                          }
                        }
                      }
                    }
                  }
                }
                fields(first: 20) {
                  nodes {
                    ... on ProjectV2FieldCommon {
                      id
                      name
                    }
                    ... on ProjectV2SingleSelectField {
                      id
                      name
                      options {
                        id
                        name
                        color
                      }
                    }
                  }
                }
              }
            }
          }
        `;

        const response = await octokit.graphql(query, {
          owner,
          number: project_number
        });

        const project = response.user.projectV2;

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
            items: project.items.nodes.map((item: any) => {
              const itemData: any = {
                id: item.id,
                type: item.type
              };

              if (item.content) {
                itemData.content = {
                  title: item.content.title,
                  number: item.content.number,
                  state: item.content.state,
                  url: item.content.url,
                  body: item.content.body
                };
              }

              if (item.fieldValues && item.fieldValues.nodes) {
                itemData.fields = item.fieldValues.nodes.map((fieldValue: any) => {
                  if (fieldValue.field && fieldValue.field.name) {
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
            fields: project.fields.nodes.map((field: any) => {
              const fieldData: any = {
                id: field.id,
                name: field.name
              };

              if (field.options) {
                fieldData.options = field.options.map((option: any) => ({
                  id: option.id,
                  name: option.name,
                  color: option.color
                }));
              }

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
        project_id: {
          type: 'string',
          description: 'ID du projet'
        },
        content_id: {
          type: 'string',
          description: 'ID de l\'élément à ajouter (issue ou pull request)'
        },
        content_type: {
          type: 'string',
          enum: ['issue', 'pull_request', 'draft_issue'],
          description: 'Type de contenu à ajouter',
          default: 'issue'
        },
        draft_title: {
          type: 'string',
          description: 'Titre de la note (uniquement pour les notes)'
        },
        draft_body: {
          type: 'string',
          description: 'Corps de la note (uniquement pour les notes)'
        }
      },
      required: ['project_id']
    },
    execute: async ({ project_id, content_id, content_type = 'issue', draft_title = '', draft_body = '' }) => {
      try {
        let query;
        let variables: any = { projectId: project_id };

        if (content_type === 'draft_issue') {
          // Ajouter une note au projet
          query = `
            mutation($projectId: ID!, $title: String!, $body: String!) {
              addProjectV2DraftIssue(input: {
                projectId: $projectId,
                title: $title,
                body: $body
              }) {
                projectItem {
                  id
                }
              }
            }
          `;
          variables.title = draft_title;
          variables.body = draft_body;
        } else {
          // Ajouter une issue ou une pull request au projet
          query = `
            mutation($projectId: ID!, $contentId: ID!) {
              addProjectV2ItemById(input: {
                projectId: $projectId,
                contentId: $contentId
              }) {
                item {
                  id
                }
              }
            }
          `;
          variables.contentId = content_id;
        }

        const response = await octokit.graphql(query, variables);

        const itemId = content_type === 'draft_issue'
          ? response.addProjectV2DraftIssue.projectItem.id
          : response.addProjectV2ItemById.item.id;

        return {
          success: true,
          item_id: itemId
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message || 'Erreur lors de l\'ajout de l\'élément au projet'
        };
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
        project_id: {
          type: 'string',
          description: 'ID du projet'
        },
        item_id: {
          type: 'string',
          description: 'ID de l\'élément dans le projet'
        },
        field_id: {
          type: 'string',
          description: 'ID du champ à mettre à jour'
        },
        field_type: {
          type: 'string',
          enum: ['text', 'date', 'single_select', 'number'],
          description: 'Type de champ',
          default: 'text'
        },
        value: {
          type: 'string',
          description: 'Nouvelle valeur pour le champ'
        },
        option_id: {
          type: 'string',
          description: 'ID de l\'option pour les champs de type single_select'
        }
      },
      required: ['project_id', 'item_id', 'field_id', 'field_type']
    },
    execute: async ({ project_id, item_id, field_id, field_type, value, option_id }) => {
      try {
        let query;
        let variables: any = {
          projectId: project_id,
          itemId: item_id,
          fieldId: field_id
        };

        switch (field_type) {
          case 'text':
            query = `
              mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $text: String!) {
                updateProjectV2ItemFieldValue(input: {
                  projectId: $projectId,
                  itemId: $itemId,
                  fieldId: $fieldId,
                  value: { text: $text }
                }) {
                  projectV2Item {
                    id
                  }
                }
              }
            `;
            variables.text = value;
            break;

          case 'date':
            query = `
              mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $date: Date!) {
                updateProjectV2ItemFieldValue(input: {
                  projectId: $projectId,
                  itemId: $itemId,
                  fieldId: $fieldId,
                  value: { date: $date }
                }) {
                  projectV2Item {
                    id
                  }
                }
              }
            `;
            variables.date = value;
            break;

          case 'single_select':
            query = `
              mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
                updateProjectV2ItemFieldValue(input: {
                  projectId: $projectId,
                  itemId: $itemId,
                  fieldId: $fieldId,
                  value: { singleSelectOptionId: $optionId }
                }) {
                  projectV2Item {
                    id
                  }
                }
              }
            `;
            variables.optionId = option_id;
            break;

          case 'number':
            query = `
              mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $number: Float!) {
                updateProjectV2ItemFieldValue(input: {
                  projectId: $projectId,
                  itemId: $itemId,
                  fieldId: $fieldId,
                  value: { number: $number }
                }) {
                  projectV2Item {
                    id
                  }
                }
              }
            `;
            variables.number = parseFloat(value);
            break;

          default:
            return {
              success: false,
              error: `Type de champ non pris en charge: ${field_type}`
            };
        }

        const response = await octokit.graphql(query, variables);

        return {
          success: true,
          item_id: response.updateProjectV2ItemFieldValue.projectV2Item.id
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message || 'Erreur lors de la mise à jour du champ'
        };
      }
    }
  }
    ]
  }));

  // Gérer les requêtes d'outils
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    switch (request.params.name) {
      case 'list_projects':
        return handleListProjects(request.params.arguments);
      case 'create_project':
        return handleCreateProject(request.params.arguments);
      case 'get_project':
        return handleGetProject(request.params.arguments);
      case 'add_item_to_project':
        return handleAddItemToProject(request.params.arguments);
      case 'update_project_item_field':
        return handleUpdateProjectItemField(request.params.arguments);
      default:
        throw new McpError(
          ErrorCode.MethodNotFound,
          `Outil inconnu: ${request.params.name}`
        );
    }
  });

  // Fonctions de gestion des outils
  async function handleListProjects(args: any) {
    try {
      const { owner, type = 'user', state = 'open' } = args;
      
      // Utiliser l'API GraphQL pour récupérer les projets (v2)
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
      });

      const projects = type === 'user'
        ? response.user.projectsV2.nodes
        : response.organization.projectsV2.nodes;

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              projects: projects.map((project: any) => ({
                id: project.id,
                title: project.title,
                number: project.number,
                description: project.shortDescription,
                url: project.url,
                closed: project.closed,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt
              }))
            }, null, 2)
          }
        ]
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: false,
              error: error.message || 'Erreur lors de la récupération des projets'
            }, null, 2)
          }
        ],
        isError: true
      };
    }
  }

  async function handleCreateProject(args: any) {
    // Implémentation similaire à celle de l'outil create_project
    try {
      const { owner, title, description = '', type = 'user' } = args;
      
      // Code existant...
      // Utiliser l'API GraphQL pour créer un projet (v2)
      const query = `
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

      // D'abord, obtenir l'ID du propriétaire
      const ownerQuery = `
        query($login: String!) {
          ${type === 'user' ? 'user' : 'organization'}(login: $login) {
            id
          }
        }
      `;

      const ownerData = await octokit.graphql(ownerQuery, {
        login: owner
      });

      const ownerId = type === 'user'
        ? ownerData.user.id
        : ownerData.organization.id;

      const response = await octokit.graphql(query, {
        ownerId,
        title,
        description
      });

      const project = response.createProjectV2.projectV2;

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
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
            }, null, 2)
          }
        ]
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: false,
              error: error.message || 'Erreur lors de la création du projet'
            }, null, 2)
          }
        ],
        isError: true
      };
    }
  }

  async function handleGetProject(args: any) {
    // Implémentation similaire à celle de l'outil get_project
    // ...
    return { content: [{ type: 'text', text: 'Non implémenté' }] };
  }

  async function handleAddItemToProject(args: any) {
    // Implémentation similaire à celle de l'outil add_item_to_project
    // ...
    return { content: [{ type: 'text', text: 'Non implémenté' }] };
  }

  async function handleUpdateProjectItemField(args: any) {
    // Implémentation similaire à celle de l'outil update_project_item_field
    // ...
    return { content: [{ type: 'text', text: 'Non implémenté' }] };
  }
}