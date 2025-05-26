import logging
from pathlib import Path
from typing import Sequence
from mcp.server import Server
from mcp.server.session import ServerSession
from mcp.server.stdio import stdio_server
from mcp.types import (
    ClientCapabilities,
    TextContent,
    Tool,
    ListRootsResult,
    RootsCapability,
)
from enum import Enum
import git
from pydantic import BaseModel, ValidationError

# CORRECTION: Définir le logger au niveau du module
logger = logging.getLogger(__name__)

class GitStatus(BaseModel):
    repo_path: str

class GitDiffUnstaged(BaseModel):
    repo_path: str

class GitDiffStaged(BaseModel):
    repo_path: str

class GitDiff(BaseModel):
    repo_path: str
    target: str

class GitCommit(BaseModel):
    repo_path: str
    message: str

# Modèle Pydantic pour les arguments de l'outil git_add
class GitAdd(BaseModel):
    repo_path: str
    files: list[str]

class GitReset(BaseModel):
    repo_path: str

class GitLog(BaseModel):
    repo_path: str
    max_count: int = 10

class GitCreateBranch(BaseModel):
    repo_path: str
    branch_name: str
    base_branch: str | None = None

class GitCheckout(BaseModel):
    repo_path: str
    branch_name: str

class GitShow(BaseModel):
    repo_path: str
    revision: str

# Modèle Pydantic pour les arguments de l'outil git_init
class GitInit(BaseModel):
    repo_path: str

# Énumération des noms d'outils Git disponibles via MCP
class GitTools(str, Enum):
    STATUS = "git_status"
    DIFF_UNSTAGED = "git_diff_unstaged"
    DIFF_STAGED = "git_diff_staged"
    DIFF = "git_diff"
    COMMIT = "git_commit"
    ADD = "git_add"
    RESET = "git_reset"
    LOG = "git_log"
    CREATE_BRANCH = "git_create_branch"
    CHECKOUT = "git_checkout"
    SHOW = "git_show"
    INIT = "git_init"

def git_status(repo: git.Repo) -> str:
    return repo.git.status()

def git_diff_unstaged(repo: git.Repo) -> str:
    return repo.git.diff()

def git_diff_staged(repo: git.Repo) -> str:
    return repo.git.diff("--cached")

def git_diff(repo: git.Repo, target: str) -> str:
    return repo.git.diff(target)

def git_commit(repo: git.Repo, message: str) -> str:
    commit = repo.index.commit(message)
    return f"Changes committed successfully with hash {commit.hexsha}"

def git_add(repo: git.Repo, files: list[str]) -> str:
    logger.info(f"[git_add] Called with repo: {repo}, files: {files}")
    try:
        logger.info(f"[git_add] Attempting to call repo.index.add(files={files})")
        repo.index.add(files)
        logger.info(f"[git_add] repo.index.add() successful for files: {files}")
    except git.exc.GitCommandError as e:
        logger.error(f"[git_add] GitCommandError during repo.index.add(): {e}")
        raise
    except Exception as e:
        logger.error(f"[git_add] Unexpected error during repo.index.add(): {e}")
        raise
    return "Files staged successfully"

def git_reset(repo: git.Repo) -> str:
    repo.index.reset()
    return "All staged changes reset"

def git_log(repo: git.Repo, max_count: int = 10) -> list[str]:
    commits = list(repo.iter_commits(max_count=max_count))
    log = []
    for commit in commits:
        log.append(
            f"Commit: {commit.hexsha}\n"
            f"Author: {commit.author}\n"
            f"Date: {commit.authored_datetime}\n"
            f"Message: {commit.message}\n"
        )
    return log

def git_create_branch(repo: git.Repo, branch_name: str, base_branch: str | None = None) -> str:
    if base_branch:
        base = repo.refs[base_branch]
    else:
        base = repo.active_branch

    repo.create_head(branch_name, base)
    return f"Created branch '{branch_name}' from '{base.name}'"

def git_checkout(repo: git.Repo, branch_name: str) -> str:
    repo.git.checkout(branch_name)
    return f"Switched to branch '{branch_name}'"

def git_init(repo_path: str) -> str:
    logger.info(f"[git_init] Called with repo_path: {repo_path}")
    try:
        logger.info(f"[git_init] Attempting to call git.Repo.init(path='{repo_path}', mkdir=True)")
        repo = git.Repo.init(path=repo_path, mkdir=True)
        logger.info(f"[git_init] git.Repo.init() successful. Repo git_dir: {repo.git_dir}")
        return f"Initialized empty Git repository in {repo.git_dir}"
    except git.exc.GitCommandError as e:
        logger.error(f"[git_init] GitCommandError during git.Repo.init(): {e}")
        return f"Error initializing repository: {str(e)}"
    except Exception as e:
        logger.error(f"[git_init] Unexpected error during git.Repo.init(): {e}")
        return f"Error initializing repository: {str(e)}"

def git_show(repo: git.Repo, revision: str) -> str:
    commit = repo.commit(revision)
    output = [
        f"Commit: {commit.hexsha}\n"
        f"Author: {commit.author}\n"
        f"Date: {commit.authored_datetime}\n"
        f"Message: {commit.message}\n"
    ]
    if commit.parents:
        parent = commit.parents[0]
        diff = parent.diff(commit, create_patch=True)
    else:
        diff = commit.diff(git.NULL_TREE, create_patch=True)
    for d in diff:
        output.append(f"\n--- {d.a_path}\n+++ {d.b_path}\n")
        output.append(d.diff.decode('utf-8'))
    return "".join(output)

# Fonction principale pour initialiser et démarrer le serveur MCP Git.
# Elle configure le logger, vérifie le dépôt Git optionnel,
# enregistre les outils et lance le serveur en attente de requêtes.
async def serve(repository: Path | None) -> None:
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

    # CORRECTION: Utiliser le logger défini au niveau du module
    # logger = logging.getLogger(__name__)  # Cette ligne était redondante

    if repository is not None:
        try:
            git.Repo(repository)
            logger.info(f"Using repository at {repository}")
        except git.InvalidGitRepositoryError:
            logger.error(f"{repository} is not a valid Git repository")
            return

    server = Server("mcp-git")

    # Décorateur pour enregistrer la fonction `list_tools` auprès du serveur MCP.
    # Cette fonction sera appelée par le client MCP pour découvrir les outils disponibles.
    @server.list_tools()
    async def list_tools() -> list[Tool]:
        # Retourne la liste des outils Git supportés par ce serveur MCP.
        # Chaque outil est défini avec son nom, sa description et son schéma d'entrée (via Pydantic).
        return [
            Tool(
                name=GitTools.STATUS,
                description="Shows the working tree status",
                inputSchema=GitStatus.schema(),
            ),
            Tool(
                name=GitTools.DIFF_UNSTAGED,
                description="Shows changes in the working directory that are not yet staged",
                inputSchema=GitDiffUnstaged.schema(),
            ),
            Tool(
                name=GitTools.DIFF_STAGED,
                description="Shows changes that are staged for commit",
                inputSchema=GitDiffStaged.schema(),
            ),
            Tool(
                name=GitTools.DIFF,
                description="Shows differences between branches or commits",
                inputSchema=GitDiff.schema(),
            ),
            Tool(
                name=GitTools.COMMIT,
                description="Records changes to the repository",
                inputSchema=GitCommit.schema(),
            ),
            Tool(
                name=GitTools.ADD, # Nom de l'outil pour ajouter des fichiers à l'index
                description="Adds file contents to the staging area",
                inputSchema=GitAdd.schema(), # Schéma Pydantic pour les arguments de git_add
            ),
            Tool(
                name=GitTools.RESET,
                description="Unstages all staged changes",
                inputSchema=GitReset.schema(),
            ),
            Tool(
                name=GitTools.LOG,
                description="Shows the commit logs",
                inputSchema=GitLog.schema(),
            ),
            Tool(
                name=GitTools.CREATE_BRANCH,
                description="Creates a new branch from an optional base branch",
                inputSchema=GitCreateBranch.schema(),
            ),
            Tool(
                name=GitTools.CHECKOUT,
                description="Switches branches",
                inputSchema=GitCheckout.schema(),
            ),
            Tool(
                name=GitTools.SHOW,
                description="Shows the contents of a commit",
                inputSchema=GitShow.schema(),
            ),
            Tool(
                name=GitTools.INIT, # Nom de l'outil pour initialiser un dépôt
                description="Initialize a new Git repository",
                inputSchema=GitInit.schema(), # Schéma Pydantic pour les arguments de git_init
            )
        ]

    async def list_repos() -> Sequence[str]:
        async def by_roots() -> Sequence[str]:
            if not isinstance(server.request_context.session, ServerSession):
                raise TypeError("server.request_context.session must be a ServerSession")

            if not server.request_context.session.check_client_capability(
                ClientCapabilities(roots=RootsCapability())
            ):
                return []

            roots_result: ListRootsResult = await server.request_context.session.list_roots()
            logger.debug(f"Roots result: {roots_result}")
            repo_paths = []
            for root in roots_result.roots:
                path = root.uri.path
                try:
                    git.Repo(path)
                    repo_paths.append(str(path))
                except git.InvalidGitRepositoryError:
                    pass
            return repo_paths

        def by_commandline() -> Sequence[str]:
            return [str(repository)] if repository is not None else []

        cmd_repos = by_commandline()
        root_repos = await by_roots()
        return [*root_repos, *cmd_repos]

    # Décorateur pour enregistrer la fonction `call_tool` auprès du serveur MCP.
    # Cette fonction est appelée lorsqu'un client MCP demande l'exécution d'un outil.
    @server.call_tool()
    async def call_tool(name: str, arguments: dict) -> list[TextContent]:
        logger.info(f"[call_tool] Called with tool name: {name}, arguments: {arguments}")
        # Gère l'invocation d'un outil spécifique demandé par le client MCP.
        # Valide le chemin du dépôt, puis utilise un 'match' sur le nom de l'outil
        # pour appeler la fonction GitPython correspondante avec les arguments fournis.
        repo_path = Path(arguments["repo_path"])
        
        # Handle git init separately since it doesn't require an existing repo
        # Cas spécial pour git_init: ne nécessite pas un dépôt existant et est traité en premier.
        if name == GitTools.INIT:
            logger.info(f"[call_tool] Attempting to validate arguments for GitInit: {arguments}")
            try:
                git_init_args = GitInit(**arguments)
                logger.info(f"[call_tool] GitInit arguments validated: {git_init_args}")
            except ValidationError as e:
                logger.error(f"[call_tool] GitInit argument validation error: {e}")
                raise
            logger.info(f"[call_tool] Calling git_init with repo_path: {git_init_args.repo_path}")
            result = git_init(git_init_args.repo_path)

            return [TextContent(
                type="text",
                text=result
            )]
            
        # For all other commands, we need an existing repo
        # Pour tous les autres outils, un objet git.Repo est instancié à partir du chemin fourni.
        repo = git.Repo(repo_path)
        logger.info(f"[call_tool] Successfully created git.Repo object for path: {repo_path}")

        # Utilise le 'pattern matching' pour déterminer quelle fonction Git appeler.
        match name:
            case GitTools.STATUS:
                status = git_status(repo)
                return [TextContent(
                    type="text",
                    text=f"Repository status:\n{status}"
                )]

            case GitTools.DIFF_UNSTAGED:
                diff = git_diff_unstaged(repo)
                return [TextContent(
                    type="text",
                    text=f"Unstaged changes:\n{diff}"
                )]

            case GitTools.DIFF_STAGED:
                diff = git_diff_staged(repo)
                return [TextContent(
                    type="text",
                    text=f"Staged changes:\n{diff}"
                )]

            case GitTools.DIFF:
                diff = git_diff(repo, arguments["target"])
                return [TextContent(
                    type="text",
                    text=f"Diff with {arguments['target']}:\n{diff}"
                )]

            case GitTools.COMMIT:
                result = git_commit(repo, arguments["message"])
                return [TextContent(
                    type="text",
                    text=result
                )]

            case GitTools.ADD:
                logger.info(f"[call_tool] Attempting to validate arguments for GitAdd: {arguments}")
                try:
                    git_add_args = GitAdd(**arguments)
                    logger.info(f"[call_tool] GitAdd arguments validated: {git_add_args}")
                except ValidationError as e:
                    logger.error(f"[call_tool] GitAdd argument validation error: {e}")
                    raise
                logger.info(f"[call_tool] Calling git_add with repo: {repo}, files: {git_add_args.files}")
                result = git_add(repo, git_add_args.files)

                return [TextContent(
                    type="text",
                    text=result
                )]

            case GitTools.RESET:
                result = git_reset(repo)
                return [TextContent(
                    type="text",
                    text=result
                )]

            case GitTools.LOG:
                log = git_log(repo, arguments.get("max_count", 10))
                return [TextContent(
                    type="text",
                    text="Commit history:\n" + "\n".join(log)
                )]

            case GitTools.CREATE_BRANCH:
                result = git_create_branch(
                    repo,
                    arguments["branch_name"],
                    arguments.get("base_branch")
                )
                return [TextContent(
                    type="text",
                    text=result
                )]

            case GitTools.CHECKOUT:
                result = git_checkout(repo, arguments["branch_name"])
                return [TextContent(
                    type="text",
                    text=result
                )]

            case GitTools.SHOW:
                result = git_show(repo, arguments["revision"])
                return [TextContent(
                    type="text",
                    text=result
                )]

            case _:
                raise ValueError(f"Unknown tool: {name}")

    options = server.create_initialization_options()
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, options, raise_exceptions=True)