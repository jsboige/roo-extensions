import { ListResourcesRequestSchema, ReadResourceRequestSchema, ErrorCode, McpError } from '@modelcontextprotocol/sdk/types.js';
import { getGitHubClient } from './utils/github';

// Interfaces pour les réponses GraphQL
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
  name?: string; // For single select
  field?: {
    name?: string;
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

interface GraphQLProjectResponse {
  user?: { // Peut être user ou organization selon la query, mais pour simplifier on garde user ici
    projectV2: GitHubProjectNode;
  };
  organization?: {
     projectV2: GitHubProjectNode;
  }
}


// Initialiser le client GitHub
const octokit = getGitHubClient();

/**
 * Configure les ressources MCP pour accéder aux données de GitHub Projects
 * @param server Instance du serveur MCP
 */
export function setupResources(server: any) {
  // Définir la liste des ressources disponibles
  server.setRequestHandler(ListResourcesRequestSchema, async () => ({
    resources: [
  // Ressource pour accéder aux projets d'un utilisateur ou d'une organisation
  {
    name: 'projects',
    description: 'Accès aux projets GitHub d\'un utilisateur ou d\'une organisation',
    uriSchema: 'github-projects://{owner}/{type}?state={state}',
    fetch: async (uri) => {
      try {
        // Extraire les paramètres de l'URI
        const url = new URL(uri);
        const pathParts = url.pathname.split('/').filter(Boolean);
        
        if (pathParts.length < 2) {
          throw new Error('URI invalide: format attendu github-projects://{owner}/{type}');
        }
        
        const owner = pathParts[0];
        const type = pathParts[1];
        const state = url.searchParams.get('state') || 'open';
        
        if (!['user', 'org'].includes(type)) {
          throw new Error('Type invalide: doit être "user" ou "org"');
        }
        
        if (!['open', 'closed', 'all'].includes(state)) {
          throw new Error('État invalide: doit être "open", "closed" ou "all"');
        }
        
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
        }) as unknown; // Cast to unknown first

        let projects: GitHubProjectNode[] = [];
        if (type === 'user' && response && typeof response === 'object' && 'user' in response) {
          const userResponse = response as GraphQLProjectsResponseUser;
          if (userResponse.user && userResponse.user.projectsV2 && userResponse.user.projectsV2.nodes) {
            projects = userResponse.user.projectsV2.nodes;
          }
        } else if (type === 'org' && response && typeof response === 'object' && 'organization' in response) {
          const orgResponse = response as GraphQLProjectsResponseOrg;
          if (orgResponse.organization && orgResponse.organization.projectsV2 && orgResponse.organization.projectsV2.nodes) {
            projects = orgResponse.organization.projectsV2.nodes;
          }
        } else {
          console.warn('Réponse GraphQL inattendue pour la liste des projets:', response);
        }
        

        return {
          format: 'json',
          content: JSON.stringify({
            owner,
            type,
            state,
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
          }, null, 2)
        };
      } catch (error: any) {
        return {
          format: 'json',
          content: JSON.stringify({
            error: error.message || 'Erreur lors de la récupération des projets'
          }, null, 2)
        };
      }
    }
  },
  
  // Ressource pour accéder à un projet spécifique
  {
    name: 'project',
    description: 'Accès à un projet GitHub spécifique',
    uriSchema: 'github-project://{owner}/{project_number}',
    fetch: async (uri) => {
      try {
        // Extraire les paramètres de l'URI
        const url = new URL(uri);
        const pathParts = url.pathname.split('/').filter(Boolean);
        
        if (pathParts.length < 2) {
          throw new Error('URI invalide: format attendu github-project://{owner}/{project_number}');
        }
        
        const owner = pathParts[0];
        const projectNumber = parseInt(pathParts[1], 10);
        
        if (isNaN(projectNumber)) {
          throw new Error('Numéro de projet invalide: doit être un nombre');
        }
        
        // Utiliser l'API GraphQL pour récupérer les détails d'un projet (v2)
        // Note: La query originale ne spécifie pas si owner est un user ou une org pour le projectV2.
        // Pour cet exemple, on assume que c'est un user. Il faudrait adapter si ce n'est pas le cas.
        const query = `
          query($owner: String!, $number: Int!) {
            user(login: $owner) { # Ou organization(login: $owner) si besoin
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
                          name # This is the option name for single select
                          field {
                            ... on ProjectV2FieldCommon {
                              name # This is the field name
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
          number: projectNumber
        }) as unknown;

        let project: GitHubProjectNode | null = null;
        if (response && typeof response === 'object') {
            if ('user' in response && (response as GraphQLProjectResponse).user?.projectV2) {
                 project = (response as GraphQLProjectResponse).user!.projectV2;
            } else if ('organization' in response && (response as GraphQLProjectResponse).organization?.projectV2) {
                 project = (response as GraphQLProjectResponse).organization!.projectV2;
            }
        }

        if (!project) {
          throw new Error('Projet non trouvé ou réponse GraphQL inattendue.');
        }


        return {
          format: 'json',
          content: JSON.stringify({
            id: project.id,
            title: project.title,
            number: project.number,
            description: project.shortDescription,
            url: project.url,
            closed: project.closed,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            items: project.items?.nodes.map((item: GitHubProjectItem) => {
              const itemData: Partial<GitHubProjectItem & { fields: any[] }> = { // Utilisation de Partial pour itemData
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
                itemData.fields = item.fieldValues.nodes.map((fieldValue: GitHubProjectFieldValue) => {
                  if (fieldValue.field && fieldValue.field.name) {
                    return {
                      name: fieldValue.field.name,
                      value: fieldValue.text || fieldValue.date || fieldValue.name // fieldValue.name for single select option
                    };
                  }
                  return null;
                }).filter(Boolean);
              }

              return itemData;
            }),
            fields: project.fields?.nodes.map((field: GitHubProjectField) => {
              const fieldData: Partial<GitHubProjectField> = { // Utilisation de Partial pour fieldData
                id: field.id,
                name: field.name
              };

              if (field.options) {
                fieldData.options = field.options.map((option: GitHubProjectFieldOption) => ({
                  id: option.id,
                  name: option.name,
                  color: option.color
                }));
              }

              return fieldData;
            })
          }, null, 2)
        };
      } catch (error: any) {
        return {
          format: 'json',
          content: JSON.stringify({
            error: error.message || 'Erreur lors de la récupération du projet'
          }, null, 2)
        };
      }
    }
  }
    ]
  }));

  // Gérer les requêtes de ressources
  server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
    const uri = request.params.uri;
    
    try {
      // Extraire le schéma de l'URI pour déterminer quelle ressource est demandée
      const url = new URL(uri);
      const schema = url.protocol;
      
      if (schema === 'github-projects:') {
        return handleProjectsResource(uri);
      } else if (schema === 'github-project:') {
        return handleProjectResource(uri);
      } else {
        throw new McpError(
          ErrorCode.InvalidRequest,
          `Schéma d'URI non pris en charge: ${schema}`
        );
      }
    } catch (error: any) {
      return {
        format: 'json',
        content: JSON.stringify({
          error: error.message || 'Erreur lors de l\'accès à la ressource'
        }, null, 2)
      };
    }
  });

  // Fonctions de gestion des ressources
  async function handleProjectsResource(uri: string) {
    try {
      // Extraire les paramètres de l'URI
      const url = new URL(uri);
      const pathParts = url.pathname.split('/').filter(Boolean);
      
      if (pathParts.length < 2) {
        throw new Error('URI invalide: format attendu github-projects://{owner}/{type}');
      }
      
      const owner = pathParts[0];
      const type = pathParts[1];
      const state = url.searchParams.get('state') || 'open';
      
      if (!['user', 'org'].includes(type)) {
        throw new Error('Type invalide: doit être "user" ou "org"');
      }
      
      if (!['open', 'closed', 'all'].includes(state)) {
        throw new Error('État invalide: doit être "open", "closed" ou "all"');
      }
      
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
      }) as unknown;

      let projects: GitHubProjectNode[] = [];
      if (type === 'user' && response && typeof response === 'object' && 'user' in response) {
        const userResponse = response as GraphQLProjectsResponseUser;
        if (userResponse.user && userResponse.user.projectsV2 && userResponse.user.projectsV2.nodes) {
          projects = userResponse.user.projectsV2.nodes;
        }
      } else if (type === 'org' && response && typeof response === 'object' && 'organization' in response) {
        const orgResponse = response as GraphQLProjectsResponseOrg;
        if (orgResponse.organization && orgResponse.organization.projectsV2 && orgResponse.organization.projectsV2.nodes) {
          projects = orgResponse.organization.projectsV2.nodes;
        }
      } else {
        console.warn('Réponse GraphQL inattendue pour handleProjectsResource:', response);
      }


      return {
        format: 'json',
        content: JSON.stringify({
          owner,
          type,
          state,
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
        }, null, 2)
      };
    } catch (error: any) {
      return {
        format: 'json',
        content: JSON.stringify({
          error: error.message || 'Erreur lors de la récupération des projets'
        }, null, 2)
      };
    }
  }

  async function handleProjectResource(uri: string): Promise<{ format: string; content: string }> {
    try {
      const url = new URL(uri);
      const pathParts = url.pathname.split('/').filter(Boolean);

      if (pathParts.length < 2) {
        throw new Error('URI invalide: format attendu github-project://{owner}/{project_number}');
      }

      const owner = pathParts[0];
      const projectNumber = parseInt(pathParts[1], 10);

      if (isNaN(projectNumber)) {
        throw new Error('Numéro de projet invalide: doit être un nombre');
      }

      // La query doit être adaptée pour potentiellement requêter 'organization' au lieu de 'user'
      // Pour l'instant, on garde 'user' comme dans le fetch de la ressource 'project'
      const query = `
        query($owner: String!, $number: Int!) {
          user(login: $owner) { # Ou organization(login: $owner)
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
        number: projectNumber,
      }) as unknown;
      
      let project: GitHubProjectNode | null = null;
        if (response && typeof response === 'object') {
            if ('user' in response && (response as GraphQLProjectResponse).user?.projectV2) {
                 project = (response as GraphQLProjectResponse).user!.projectV2;
            } else if ('organization' in response && (response as GraphQLProjectResponse).organization?.projectV2) {
                 project = (response as GraphQLProjectResponse).organization!.projectV2;
            }
        }

      if (!project) {
        throw new Error('Projet non trouvé ou réponse GraphQL inattendue pour handleProjectResource.');
      }

      return {
        format: 'json',
        content: JSON.stringify({
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
              type: item.type,
            };
            if (item.content) {
              itemData.content = item.content;
            }
            if (item.fieldValues && item.fieldValues.nodes) {
              itemData.fields = item.fieldValues.nodes.map((fieldValue: GitHubProjectFieldValue) => {
                if (fieldValue.field && fieldValue.field.name) {
                  return {
                    name: fieldValue.field.name,
                    value: fieldValue.text || fieldValue.date || fieldValue.name,
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
              name: field.name,
            };
            if (field.options) {
              fieldData.options = field.options;
            }
            return fieldData;
          }),
        }, null, 2),
      };
    } catch (error: any) {
      return {
        format: 'json',
        content: JSON.stringify({
          error: error.message || 'Erreur lors de la récupération du projet via handleProjectResource',
        }, null, 2),
      };
    }
  }
}