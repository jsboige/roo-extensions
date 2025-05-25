#!/usr/bin/env python3
"""
Script de test pour reproduire l'erreur "Invalid arguments" du serveur MCP Git.
Ce script simule les appels MCP pour identifier les problèmes.
"""

import sys
import os
import logging
from pathlib import Path

# Ajouter le chemin vers le module mcp_server_git
sys.path.insert(0, str(Path(__file__).parent.parent / "mcps/forked/modelcontextprotocol-servers/src/git/src"))

try:
    from mcp_server_git.server import git_init, git_add, GitInit, GitAdd
    import git
    from pydantic import ValidationError
except ImportError as e:
    print(f"Erreur d'import: {e}")
    print("Assurez-vous que les dépendances sont installées:")
    print("pip install click gitpython mcp pydantic")
    sys.exit(1)

# Configuration du logging pour capturer les logs détaillés
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('git_mcp_debug.log')
    ]
)

logger = logging.getLogger(__name__)

def test_git_init():
    """Test de l'opération git init avec différents formats de chemin."""
    print("\n=== TEST GIT INIT ===")
    
    test_paths = [
        "d:/roo-extensions/git-mcp-debug-test",
        "d:\\roo-extensions\\git-mcp-debug-test",
        str(Path("d:/roo-extensions/git-mcp-debug-test")),
        "./git-mcp-debug-test",
    ]
    
    for test_path in test_paths:
        print(f"\n--- Test avec le chemin: {test_path} ---")
        
        # Test de validation Pydantic
        try:
            print(f"1. Test validation Pydantic pour: {test_path}")
            git_init_args = GitInit(repo_path=test_path)
            print(f"   ✓ Validation réussie: {git_init_args}")
        except ValidationError as e:
            print(f"   ✗ Erreur de validation Pydantic: {e}")
            continue
        except Exception as e:
            print(f"   ✗ Erreur inattendue lors de la validation: {e}")
            continue
        
        # Test de l'appel git_init
        try:
            print(f"2. Test appel git_init pour: {test_path}")
            result = git_init(test_path)
            print(f"   ✓ git_init réussi: {result}")
        except Exception as e:
            print(f"   ✗ Erreur lors de git_init: {e}")
            print(f"   Type d'erreur: {type(e).__name__}")
            import traceback
            traceback.print_exc()

def test_git_add():
    """Test de l'opération git add avec différents formats de fichiers."""
    print("\n=== TEST GIT ADD ===")
    
    # D'abord, créer un repo de test
    test_repo_path = "d:/roo-extensions/git-mcp-debug-test"
    
    try:
        # Initialiser le repo s'il n'existe pas
        if not os.path.exists(os.path.join(test_repo_path, ".git")):
            print(f"Initialisation du repo de test: {test_repo_path}")
            git.Repo.init(test_repo_path)
        
        # Créer un fichier de test
        test_file = os.path.join(test_repo_path, "test.txt")
        with open(test_file, "w") as f:
            f.write("Test file for git add")
        
        repo = git.Repo(test_repo_path)
        
        test_files_list = [
            ["test.txt"],
            ["./test.txt"],
            [str(Path(test_repo_path) / "test.txt")],
            ["test.txt", "nonexistent.txt"],  # Test avec fichier inexistant
        ]
        
        for test_files in test_files_list:
            print(f"\n--- Test avec les fichiers: {test_files} ---")
            
            # Test de validation Pydantic
            try:
                print(f"1. Test validation Pydantic pour: {test_files}")
                git_add_args = GitAdd(repo_path=test_repo_path, files=test_files)
                print(f"   ✓ Validation réussie: {git_add_args}")
            except ValidationError as e:
                print(f"   ✗ Erreur de validation Pydantic: {e}")
                continue
            except Exception as e:
                print(f"   ✗ Erreur inattendue lors de la validation: {e}")
                continue
            
            # Test de l'appel git_add
            try:
                print(f"2. Test appel git_add pour: {test_files}")
                result = git_add(repo, test_files)
                print(f"   ✓ git_add réussi: {result}")
            except Exception as e:
                print(f"   ✗ Erreur lors de git_add: {e}")
                print(f"   Type d'erreur: {type(e).__name__}")
                import traceback
                traceback.print_exc()
                
    except Exception as e:
        print(f"Erreur lors de la préparation du test git_add: {e}")
        import traceback
        traceback.print_exc()

def test_call_tool_simulation():
    """Simulation de l'appel call_tool pour identifier les problèmes."""
    print("\n=== SIMULATION CALL_TOOL ===")
    
    # Simulation des arguments comme ils seraient reçus via MCP
    test_cases = [
        {
            "name": "git_init",
            "arguments": {"repo_path": "d:/roo-extensions/git-mcp-debug-test"}
        },
        {
            "name": "git_add", 
            "arguments": {
                "repo_path": "d:/roo-extensions/git-mcp-debug-test",
                "files": ["test.txt"]
            }
        }
    ]
    
    for test_case in test_cases:
        print(f"\n--- Simulation {test_case['name']} ---")
        print(f"Arguments: {test_case['arguments']}")
        
        try:
            # Simulation de la logique de call_tool
            arguments = test_case["arguments"]
            repo_path = Path(arguments["repo_path"])
            print(f"repo_path converti en Path: {repo_path}")
            
            if test_case["name"] == "git_init":
                # Test GitInit validation
                git_init_args = GitInit(**arguments)
                print(f"GitInit args validés: {git_init_args}")
                result = git_init(git_init_args.repo_path)
                print(f"Résultat git_init: {result}")
                
            elif test_case["name"] == "git_add":
                # D'abord vérifier que le repo existe
                repo = git.Repo(repo_path)
                print(f"Repo git créé: {repo}")
                
                # Test GitAdd validation
                git_add_args = GitAdd(**arguments)
                print(f"GitAdd args validés: {git_add_args}")
                result = git_add(repo, git_add_args.files)
                print(f"Résultat git_add: {result}")
                
        except Exception as e:
            print(f"   ✗ Erreur lors de la simulation: {e}")
            print(f"   Type d'erreur: {type(e).__name__}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    print("=== DÉBUT DES TESTS DE DÉBOGAGE MCP GIT ===")
    print(f"Python version: {sys.version}")
    print(f"Working directory: {os.getcwd()}")
    
    # Vérifier les imports
    try:
        import git
        print(f"GitPython version: {git.__version__}")
    except:
        print("GitPython non disponible")
    
    try:
        import pydantic
        print(f"Pydantic version: {pydantic.__version__}")
    except:
        print("Pydantic non disponible")
    
    # Exécuter les tests
    test_git_init()
    test_git_add()
    test_call_tool_simulation()
    
    print("\n=== FIN DES TESTS ===")
    print("Consultez le fichier 'git_mcp_debug.log' pour les logs détaillés.")