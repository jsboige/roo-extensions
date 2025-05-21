import { Tool } from '@modelcontextprotocol/sdk/types.js';

// Définir ToolSchema comme un type
type ToolSchema = {
  type: string;
  properties: Record<string, any>;
  required?: string[];
};
import {
  startKernel,
  stopKernel,
  listAvailableKernels,
  listActiveKernels,
  interruptKernel,
  restartKernel
} from '../services/jupyter.js';

// Schéma pour l'outil list_kernels
const listKernelsSchema: ToolSchema = {
  type: 'object',
  properties: {},
  required: []
};

// Schéma pour l'outil start_kernel
const startKernelSchema: ToolSchema = {
  type: 'object',
  properties: {
    kernel_name: {
      type: 'string',
      description: 'Nom du kernel à démarrer (ex: python3)',
      default: 'python3'
    }
  },
  required: []
};

// Schéma pour l'outil stop_kernel
const stopKernelSchema: ToolSchema = {
  type: 'object',
  properties: {
    kernel_id: {
      type: 'string',
      description: 'ID du kernel à arrêter'
    }
  },
  required: ['kernel_id']
};

// Schéma pour l'outil interrupt_kernel
const interruptKernelSchema: ToolSchema = {
  type: 'object',
  properties: {
    kernel_id: {
      type: 'string',
      description: 'ID du kernel à interrompre'
    }
  },
  required: ['kernel_id']
};

// Schéma pour l'outil restart_kernel
const restartKernelSchema: ToolSchema = {
  type: 'object',
  properties: {
    kernel_id: {
      type: 'string',
      description: 'ID du kernel à redémarrer'
    }
  },
  required: ['kernel_id']
};

// Définition des outils MCP pour la gestion des kernels
export const kernelTools: Tool[] = [
  {
    name: 'list_kernels',
    description: 'Liste les kernels disponibles et actifs',
    schema: listKernelsSchema,
    handler: async () => {
      try {
        const availableKernels = await listAvailableKernels();
        const activeKernels = listActiveKernels();
        
        return {
          available_kernels: availableKernels,
          active_kernels: activeKernels
        };
      } catch (error) {
        throw new Error(`Erreur lors de la récupération des kernels: ${error}`);
      }
    }
  },
  {
    name: 'start_kernel',
    description: 'Démarre un nouveau kernel',
    schema: startKernelSchema,
    handler: async ({ kernel_name = 'python3' }) => {
      try {
        const kernelId = await startKernel(kernel_name);
        
        return {
          kernel_id: kernelId,
          kernel_name,
          message: `Kernel démarré avec succès: ${kernelId}`
        };
      } catch (error) {
        throw new Error(`Erreur lors du démarrage du kernel: ${error}`);
      }
    }
  },
  {
    name: 'stop_kernel',
    description: 'Arrête un kernel actif',
    schema: stopKernelSchema,
    handler: async ({ kernel_id }) => {
      try {
        await stopKernel(kernel_id);
        
        return {
          success: true,
          message: `Kernel arrêté avec succès: ${kernel_id}`
        };
      } catch (error) {
        throw new Error(`Erreur lors de l'arrêt du kernel: ${error}`);
      }
    }
  },
  {
    name: 'interrupt_kernel',
    description: 'Interrompt l\'exécution d\'un kernel',
    schema: interruptKernelSchema,
    handler: async ({ kernel_id }) => {
      try {
        await interruptKernel(kernel_id);
        
        return {
          success: true,
          message: `Kernel interrompu avec succès: ${kernel_id}`
        };
      } catch (error) {
        throw new Error(`Erreur lors de l'interruption du kernel: ${error}`);
      }
    }
  },
  {
    name: 'restart_kernel',
    description: 'Redémarre un kernel',
    schema: restartKernelSchema,
    handler: async ({ kernel_id }) => {
      try {
        await restartKernel(kernel_id);
        
        return {
          success: true,
          message: `Kernel redémarré avec succès: ${kernel_id}`
        };
      } catch (error) {
        throw new Error(`Erreur lors du redémarrage du kernel: ${error}`);
      }
    }
  }
];