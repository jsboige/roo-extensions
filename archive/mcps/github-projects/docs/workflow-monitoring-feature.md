# Plan d'Implémentation : Monitoring des Workflows GitHub Actions

## 1. Architecture

La nouvelle fonctionnalité de monitoring sera intégrée au MCP `github-projects-mcp` existant. Elle suivra le même modèle que les outils actuels, en utilisant le client Octokit configuré dans `src/utils/github.ts` pour interagir avec l'API REST de GitHub.

Les nouveaux outils seront ajoutés dans le fichier `src/tools.ts`, et les types de données correspondants seront définis dans `src/types/`.

## 2. Nouveaux Outils

### 2.1. `list_repository_workflows`

*   **Description :** Liste tous les workflows d'un dépôt GitHub.
*   **Signature TypeScript :**
    ```typescript
    interface ListRepositoryWorkflowsParams {
        owner: string;
        repo: string;
    }

    interface Workflow {
        id: number;
        node_id: string;
        name: string;
        path: string;
        state: 'active' | 'deleted' | 'disabled_fork' | 'disabled_inactivity' | 'disabled_manually';
        created_at: string;
        updated_at: string;
        url: string;
        html_url: string;
        badge_url: string;
    }

    interface ListRepositoryWorkflowsResult {
        success: boolean;
        workflows?: Workflow[];
        error?: string;
    }
    ```
*   **Endpoint API GitHub :** `GET /repos/{owner}/{repo}/actions/workflows`

### 2.2. `get_workflow_runs`

*   **Description :** Récupère les exécutions (runs) d'un workflow spécifique.
*   **Signature TypeScript :**
    ```typescript
    interface GetWorkflowRunsParams {
        owner: string;
        repo: string;
        workflow_id: number; // ou string pour le nom du fichier .yml
    }

    interface WorkflowRun {
        id: number;
        name: string;
        node_id: string;
        head_branch: string;
        head_sha: string;
        run_number: number;
        event: string;
        status: 'completed' | 'action_required' | 'cancelled' | 'failure' | 'neutral' | 'skipped' | 'stale' | 'success' | 'timed_out' | 'in_progress' | 'queued' | 'requested' | 'waiting' | 'pending';
        conclusion: 'success' | 'failure' | 'neutral' | 'cancelled' | 'skipped' | 'timed_out' | 'action_required' | null;
        workflow_id: number;
        created_at: string;
        updated_at: string;
        url: string;
        html_url: string;
    }

    interface GetWorkflowRunsResult {
        success: boolean;
        workflow_runs?: WorkflowRun[];
        error?: string;
    }
    ```
*   **Endpoint API GitHub :** `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs`

### 2.3. `get_workflow_run_status`

*   **Description :** Obtient le statut d'une exécution de workflow spécifique.
*   **Signature TypeScript :**
    ```typescript
    interface GetWorkflowRunStatusParams {
        owner: string;
        repo: string;
        run_id: number;
    }

    // Utilise la même interface WorkflowRun que get_workflow_runs

    interface GetWorkflowRunStatusResult {
        success: boolean;
        workflow_run?: WorkflowRun;
        error?: string;
    }
    ```
*   **Endpoint API GitHub :** `GET /repos/{owner}/{repo}/actions/runs/{run_id}`

## 3. Modifications des Fichiers

*   **`src/tools.ts` :**
    *   Ajouter les définitions des trois nouveaux outils (`list_repository_workflows`, `get_workflow_runs`, `get_workflow_run_status`).
    *   Implémenter la logique `execute` pour chaque outil, en appelant l'API GitHub via `octokit.rest.actions.<endpoint>`.
    *   Gérer les erreurs et retourner une réponse au format `{ success: boolean, ... }`.

*   **`src/types/` :**
    *   Créer un nouveau fichier `src/types/workflows.ts` (ou ajouter au `global.d.ts` existant) pour définir les interfaces TypeScript (`ListRepositoryWorkflowsParams`, `Workflow`, `GetWorkflowRunsParams`, `WorkflowRun`, etc.).

*   **`src/index.ts` :**
    *   Aucune modification directe nécessaire si `setupTools` charge dynamiquement tous les outils définis dans `tools.ts`.
