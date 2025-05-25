"""
PATCH POUR CORRIGER L'ERREUR "Invalid arguments" DU SERVEUR MCP GIT

PROBLÈME IDENTIFIÉ:
Le logger utilisé dans les fonctions git_add() et git_init() n'est pas défini dans leur portée,
ce qui cause une NameError qui est probablement capturée et transformée en "Invalid arguments".

SOLUTION:
1. Définir le logger au niveau du module
2. Ou passer le logger en paramètre aux fonctions
3. Ou utiliser logging.getLogger(__name__) dans chaque fonction

PATCH RECOMMANDÉ:
"""

# AVANT (lignes problématiques dans server.py):
"""
def git_add(repo: git.Repo, files: list[str]) -> str:
    logger.info(f"[git_add] Called with repo: {repo}, files: {files}")  # NameError: logger not defined
    # ...

def git_init(repo_path: str) -> str:
    logger.info(f"[git_init] Called with repo_path: {repo_path}")  # NameError: logger not defined
    # ...
"""

# APRÈS (correction proposée):
"""
import logging

# Définir le logger au niveau du module
logger = logging.getLogger(__name__)

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
"""

# CHANGEMENTS SPÉCIFIQUES À APPLIQUER:

# 1. Ajouter cette ligne après les imports (vers ligne 17):
PATCH_LINE_17 = "logger = logging.getLogger(__name__)"

# 2. Ou alternativement, modifier chaque fonction pour utiliser:
ALTERNATIVE_SOLUTION = """
def git_add(repo: git.Repo, files: list[str]) -> str:
    logger = logging.getLogger(__name__)  # Définir localement
    logger.info(f"[git_add] Called with repo: {repo}, files: {files}")
    # ... reste du code
"""

print("Patch identifié pour corriger l'erreur 'Invalid arguments' du serveur MCP Git")
print("Le problème principal est que 'logger' n'est pas défini dans la portée des fonctions git_add et git_init")