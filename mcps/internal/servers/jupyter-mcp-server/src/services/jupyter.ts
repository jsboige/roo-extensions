import { KernelManager, ServerConnection, SessionManager } from '@jupyterlab/services';
import axios from 'axios';
import { v4 as uuidv4 } from 'uuid';

// Configuration par défaut pour la connexion au serveur Jupyter
let serverSettings: ServerConnection.ISettings = ServerConnection.makeSettings({
  baseUrl: 'http://localhost:8888',
  wsUrl: 'ws://localhost:8888',
  token: ''
});

// Gestionnaires pour les kernels et les sessions
let kernelManager: KernelManager;
let sessionManager: SessionManager;

// Map pour stocker les kernels actifs
const activeKernels = new Map<string, any>();

// Version de l'API Jupyter
let jupyterApiVersion: string | null = null;

// État de la connexion
let connectionState = {
  connected: false,
  offlineMode: false,
  lastError: null as Error | null,
  serverInfo: {
    baseUrl: '',
    version: null as string | null
  }
};

/**
 * Retourne l'état actuel de la connexion au serveur Jupyter
 */
export function getConnectionState() {
  return { ...connectionState };
}

/**
 * Options pour l'initialisation des services Jupyter
 */
export interface JupyterServiceOptions {
  baseUrl?: string;
  token?: string;
  skipConnectionCheck?: boolean;
  autoReconnect?: boolean;
  reconnectInterval?: number;
}

/**
 * Initialise les services Jupyter avec les paramètres fournis
 * @param options Options de configuration pour la connexion au serveur Jupyter
 */
export async function initializeJupyterServices(options?: JupyterServiceOptions) {
  try {
    // Vérifier si nous devons sauter la vérification de connexion
    const skipConnectionCheck = options?.skipConnectionCheck || false;
    
    if (skipConnectionCheck) {
      console.log('Mode hors ligne: les vérifications de connexion au serveur Jupyter sont désactivées');
      console.log('Les fonctionnalités nécessitant un serveur Jupyter ne seront pas disponibles');
      
      // Initialiser les gestionnaires avec les paramètres par défaut
      kernelManager = new KernelManager({ serverSettings });
      sessionManager = new SessionManager({ kernelManager, serverSettings });
      
      // Mettre à jour l'état de la connexion
      connectionState.offlineMode = true;
      connectionState.connected = false;
      
      console.log('Services Jupyter initialisés en mode hors ligne');
      return true;
    }
    
    // Mettre à jour les paramètres si fournis
    if (options) {
      // Normaliser l'URL de base
      let baseUrl = options.baseUrl || 'http://localhost:8888';
      baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
      
      let wsUrl = baseUrl.replace('http', 'ws');
      const token = options.token || '';
      
      serverSettings = ServerConnection.makeSettings({
        baseUrl: baseUrl,
        wsUrl: wsUrl,
        token: token,
        appendToken: true // Ajouter automatiquement le token aux requêtes
      });
      
      // Mettre à jour l'état de la connexion
      connectionState.serverInfo.baseUrl = baseUrl;
      
      console.log(`URL de base configurée: ${baseUrl}`);
      console.log('Paramètres de connexion configurés avec token');
    }

    // Initialiser les gestionnaires
    kernelManager = new KernelManager({ serverSettings });
    sessionManager = new SessionManager({ kernelManager, serverSettings });

    // Vérifier la connexion au serveur Jupyter et récupérer la version
    const version = await checkJupyterVersion();
    if (version) {
      connectionState.serverInfo.version = version;
    }
    
    // Vérifier la connexion au serveur Jupyter
    const connectionStatus = await testConnection();
    
    // Mettre à jour l'état de la connexion
    connectionState.connected = connectionStatus;
    connectionState.offlineMode = false;
    
    if (!connectionStatus) {
      console.error('Échec de la connexion au serveur Jupyter. Vérifiez que le serveur est en cours d\'exécution et que le token est correct.');
      // Nous continuons malgré l'erreur pour permettre une dégradation gracieuse
      return true;
    }

    console.log('Services Jupyter initialisés avec succès');
    return true;
  } catch (error: any) {
    console.error('Erreur lors de l\'initialisation des services Jupyter:', error);
    console.log('Tentative de continuer malgré l\'erreur...');
    
    // Mettre à jour l'état de la connexion
    connectionState.connected = false;
    connectionState.lastError = error;
    
    // NOTE: Nous continuons malgré l'erreur d'initialisation pour permettre
    // aux fonctionnalités qui ne nécessitent pas d'authentification de fonctionner
    // Cette approche permet une dégradation gracieuse plutôt qu'un échec complet
    return true;  // Continuer malgré l'erreur
  }
}

/**
 * Vérifie la version de l'API Jupyter
 */
async function checkJupyterVersion() {
  // Vérifier si le mode hors ligne est activé
  if (connectionState.offlineMode) {
    console.log('Mode hors ligne: pas de vérification de la version de l\'API Jupyter');
    return null;
  }

  try {
    // Normaliser l'URL de base pour éviter les doubles slashes
    const baseUrl = serverSettings.baseUrl.endsWith('/')
      ? serverSettings.baseUrl.slice(0, -1)
      : serverSettings.baseUrl;
    
    const token = serverSettings.token;
    const apiUrl = `${baseUrl}/api`;
    
    console.log(`Vérification de la version de l'API Jupyter à: ${apiUrl}`);
    
    // Utiliser à la fois le token dans l'URL et dans l'en-tête pour une sécurité maximale
    const response = await axios.get(`${apiUrl}?token=${token}`, {
      headers: {
        'Authorization': `token ${token}`
      }
    });
    
    if (response.status === 200 && response.data && response.data.version) {
      jupyterApiVersion = response.data.version;
      console.log(`Version de l'API Jupyter: ${jupyterApiVersion}`);
      return jupyterApiVersion;
    }
    
    console.warn('Version de l\'API Jupyter non disponible');
    return null;
  } catch (error) {
    console.warn('Erreur lors de la vérification de la version de l\'API Jupyter:', error);
    return null;
  }
}

/**
 * Teste la connexion au serveur Jupyter en utilisant la méthode recommandée:
 * token dans l'URL et dans l'en-tête d'autorisation
 */
async function testConnection() {
  // Vérifier si le mode hors ligne est activé
  if (connectionState.offlineMode) {
    console.log('Mode hors ligne: pas de test de connexion au serveur Jupyter');
    return false;
  }

  try {
    // Normaliser l'URL de base pour éviter les doubles slashes
    const baseUrl = serverSettings.baseUrl.endsWith('/')
      ? serverSettings.baseUrl.slice(0, -1)
      : serverSettings.baseUrl;
    
    const token = serverSettings.token;
    const apiUrl = `${baseUrl}/api/kernels`;
    
    console.log(`Test de connexion à: ${apiUrl}`);
    
    // Utiliser à la fois le token dans l'URL et dans l'en-tête pour une sécurité maximale
    const response = await axios.get(`${apiUrl}?token=${token}`, {
      headers: {
        'Authorization': `token ${token}`
      }
    });
    
    if (response.status === 200) {
      console.log('Connexion au serveur Jupyter établie avec succès (token dans l\'URL et en-tête)');
      return true;
    }
    
    console.warn(`Avertissement: Réponse du serveur Jupyter avec code ${response.status}`);
    return false;
  } catch (error) {
    console.error('Erreur lors du test de connexion au serveur Jupyter:', error);
    return false;
  }
}

/**
 * Démarre un nouveau kernel Jupyter
 * @param kernelName Nom du kernel à démarrer (ex: 'python3')
 * @returns ID du kernel démarré
 */
export async function startKernel(kernelName: string = 'python3'): Promise<string> {
  try {
    // Vérifier si le mode hors ligne est activé
    if (connectionState.offlineMode) {
      console.log('Mode hors ligne: simulation de démarrage du kernel');
      const kernelId = uuidv4();
      // Créer un objet simulant un kernel pour le mode hors ligne
      const mockKernel = {
        name: kernelName,
        id: kernelId,
        status: 'offline',
        // Fonctions simulées pour le mode hors ligne
        requestExecute: () => {
          return {
            onIOPub: () => {},
            onReply: (callback: any) => {
              callback({
                content: {
                  status: 'ok',
                  execution_count: 0
                }
              });
            },
            onStderr: () => {},
            done: Promise.resolve()
          };
        },
        shutdown: async () => Promise.resolve(),
        interrupt: async () => Promise.resolve(),
        restart: async () => Promise.resolve()
      };
      
      activeKernels.set(kernelId, mockKernel);
      console.log(`Kernel simulé démarré en mode hors ligne: ${kernelId} (${kernelName})`);
      
      return kernelId;
    }

    const kernel = await kernelManager.startNew({ name: kernelName });
    const kernelId = uuidv4();
    
    activeKernels.set(kernelId, kernel);
    console.log(`Kernel démarré: ${kernelId} (${kernelName})`);
    
    return kernelId;
  } catch (error) {
    console.error('Erreur lors du démarrage du kernel:', error);
    throw error;
  }
}

/**
 * Arrête un kernel actif
 * @param kernelId ID du kernel à arrêter
 */
export async function stopKernel(kernelId: string): Promise<boolean> {
  try {
    const kernel = activeKernels.get(kernelId);
    
    if (!kernel) {
      throw new Error(`Kernel non trouvé: ${kernelId}`);
    }
    
    await kernel.shutdown();
    activeKernels.delete(kernelId);
    console.log(`Kernel arrêté: ${kernelId}`);
    
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'arrêt du kernel:', error);
    throw error;
  }
}

/**
 * Exécute du code sur un kernel spécifique
 * @param kernelId ID du kernel sur lequel exécuter le code
 * @param code Code à exécuter
 * @returns Résultat de l'exécution
 */
export async function executeCode(kernelId: string, code: string): Promise<any> {
  try {
    const kernel = activeKernels.get(kernelId);
    
    if (!kernel) {
      throw new Error(`Kernel non trouvé: ${kernelId}`);
    }
    
    // Vérifier si le mode hors ligne est activé
    if (connectionState.offlineMode) {
      console.log('Mode hors ligne: simulation d\'exécution de code');
      
      // Simuler une exécution de code en mode hors ligne
      return {
        status: 'ok',
        execution_count: 0,
        outputs: [
          {
            type: 'stream',
            name: 'stdout',
            text: `Mode hors ligne: le code suivant n'a pas été exécuté:\n\n${code}\n\nActivez un serveur Jupyter pour exécuter du code.`
          }
        ]
      };
    }
    
    const future = kernel.requestExecute({ code });
    
    return new Promise((resolve, reject) => {
      const outputs: any[] = [];
      
      future.onIOPub = (msg: any) => {
        if (msg.content && msg.header) {
          if (msg.header.msg_type === 'error') {
            outputs.push({
              type: 'error',
              name: msg.content.ename,
              value: msg.content.evalue,
              traceback: msg.content.traceback
            });
          } else if (msg.header.msg_type === 'stream') {
            outputs.push({
              type: 'stream',
              name: msg.content.name,
              text: msg.content.text
            });
          } else if (msg.header.msg_type === 'execute_result' ||
                    msg.header.msg_type === 'display_data') {
            outputs.push({
              type: msg.header.msg_type,
              data: msg.content.data,
              metadata: msg.content.metadata
            });
          }
        }
      };
      
      future.onReply = (msg: any) => {
        resolve({
          status: msg.content.status,
          execution_count: msg.content.execution_count,
          outputs
        });
      };
      
      future.onStderr = (msg: string) => {
        outputs.push({
          type: 'stderr',
          text: msg
        });
      };
      
      future.done.catch(reject);
    });
  } catch (error) {
    console.error('Erreur lors de l\'exécution du code:', error);
    throw error;
  }
}

/**
 * Liste les kernels disponibles sur le serveur Jupyter
 * @returns Liste des spécifications de kernels disponibles
 */
export async function listAvailableKernels(): Promise<any[]> {
  // Vérifier si le mode hors ligne est activé
  if (connectionState.offlineMode) {
    console.log('Mode hors ligne: impossible de récupérer les kernels disponibles');
    return [
      {
        name: 'python3',
        spec: {
          display_name: 'Python 3 (Offline)',
          language: 'python',
          argv: [],
          env: {}
        }
      }
    ];
  }

  try {
    // Utiliser axios pour récupérer les spécifications des kernels
    // Normaliser l'URL de base pour éviter les doubles slashes
    const baseUrl = serverSettings.baseUrl.endsWith('/')
      ? serverSettings.baseUrl.slice(0, -1)
      : serverSettings.baseUrl;
    
    const token = serverSettings.token;
    const apiUrl = `${baseUrl}/api/kernelspecs`;
    
    console.log(`Récupération des kernels depuis: ${apiUrl}`);
    
    // Utiliser à la fois le token dans l'URL et dans l'en-tête
    const response = await axios.get(`${apiUrl}?token=${token}`, {
      headers: {
        'Authorization': `token ${token}`
      }
    });
    
    if (response.status === 200) {
      console.log('Récupération des kernels réussie via API REST');
      return Object.values(response.data.kernelspecs);
    }
    
    throw new Error(`Erreur lors de la récupération des kernels: ${response.status}`);
  } catch (error) {
    console.error('Erreur lors de la récupération des kernels:', error);
    throw new Error(`Erreur lors de la récupération des kernels: ${error}`);
  }
}

/**
 * Liste les kernels actifs
 * @returns Liste des kernels actifs
 */
export function listActiveKernels(): { id: string, name: string }[] {
  const kernels: { id: string, name: string }[] = [];
  
  activeKernels.forEach((kernel, id) => {
    kernels.push({
      id,
      name: kernel.name
    });
  });
  
  return kernels;
}

/**
 * Liste les sessions actives sur le serveur Jupyter
 * @returns Liste des sessions actives
 */
export async function listActiveSessions(): Promise<any[]> {
  // Vérifier si le mode hors ligne est activé
  if (connectionState.offlineMode) {
    console.log('Mode hors ligne: impossible de récupérer les sessions actives');
    return [];
  }

  try {
    // Utiliser axios pour récupérer les sessions
    // Normaliser l'URL de base pour éviter les doubles slashes
    const baseUrl = serverSettings.baseUrl.endsWith('/')
      ? serverSettings.baseUrl.slice(0, -1)
      : serverSettings.baseUrl;
    
    const token = serverSettings.token;
    const apiUrl = `${baseUrl}/api/sessions`;
    
    console.log(`Récupération des sessions depuis: ${apiUrl}`);
    
    // Utiliser à la fois le token dans l'URL et dans l'en-tête
    const response = await axios.get(`${apiUrl}?token=${token}`, {
      headers: {
        'Authorization': `token ${token}`
      }
    });
    
    if (response.status === 200) {
      console.log('Récupération des sessions réussie via API REST');
      return response.data;
    }
    
    throw new Error(`Erreur lors de la récupération des sessions: ${response.status}`);
  } catch (error) {
    console.error('Erreur lors de la récupération des sessions:', error);
    throw new Error(`Erreur lors de la récupération des sessions: ${error}`);
  }
}

/**
 * Récupère un kernel actif par son ID
 * @param kernelId ID du kernel à récupérer
 * @returns Instance du kernel
 */
export function getKernel(kernelId: string): any {
  const kernel = activeKernels.get(kernelId);
  
  if (!kernel) {
    throw new Error(`Kernel non trouvé: ${kernelId}`);
  }
  
  return kernel;
}

/**
 * Interrompt l'exécution d'un kernel
 * @param kernelId ID du kernel à interrompre
 */
export async function interruptKernel(kernelId: string): Promise<boolean> {
  try {
    const kernel = activeKernels.get(kernelId);
    
    if (!kernel) {
      throw new Error(`Kernel non trouvé: ${kernelId}`);
    }
    
    await kernel.interrupt();
    console.log(`Kernel interrompu: ${kernelId}`);
    
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'interruption du kernel:', error);
    throw error;
  }
}

/**
 * Redémarre un kernel
 * @param kernelId ID du kernel à redémarrer
 */
export async function restartKernel(kernelId: string): Promise<boolean> {
  try {
    const kernel = activeKernels.get(kernelId);
    
    if (!kernel) {
      throw new Error(`Kernel non trouvé: ${kernelId}`);
    }
    
    await kernel.restart();
    console.log(`Kernel redémarré: ${kernelId}`);
    
    return true;
  } catch (error) {
    console.error('Erreur lors du redémarrage du kernel:', error);
    throw error;
  }
}

/**
 * Obtient des informations sur le serveur Jupyter
 * @returns Informations sur le serveur Jupyter
 */
export function getJupyterInfo(): { version: string | null, baseUrl: string, connected: boolean, offlineMode: boolean } {
  return {
    version: jupyterApiVersion,
    baseUrl: serverSettings.baseUrl,
    connected: !!jupyterApiVersion && !connectionState.offlineMode,
    offlineMode: connectionState.offlineMode
  };
}