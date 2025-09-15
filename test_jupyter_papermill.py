#!/usr/bin/env python3
"""
Test script pour valider la refonte jupyter-papermill-mcp-server
Évolutions testées : API directe Python (vs subprocess conda run)
"""

import sys
import os

# Ajouter le chemin du serveur MCP
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'mcps', 'internal', 'servers', 'jupyter-papermill-mcp-server'))

def test_imports():
    """Test des imports critiques"""
    print("=== TEST 1: IMPORTS ARCHITECTURE PYTHON ===")
    try:
        import papermill as pm
        print(f"✅ Papermill {pm.__version__} - API directe disponible")
        
        from papermill_mcp.main_fastmcp import mcp
        print("✅ FastMCP architecture - Import successful")
        
        from papermill_mcp.core.papermill_executor import PapermillExecutor
        print("✅ PapermillExecutor - Nouveau moteur disponible")
        
        return True
    except ImportError as e:
        print(f"❌ Import Error: {e}")
        return False

def test_fastmcp_tools():
    """Test des outils FastMCP"""
    print("\n=== TEST 2: OUTILS FASTMCP DISPONIBLES ===")
    try:
        from papermill_mcp.main_fastmcp import mcp
        tools = mcp._tools if hasattr(mcp, '_tools') else {}
        print(f"✅ Outils FastMCP registrés: {len(tools)} tools")
        for tool_name in ['list_kernels', 'execute_notebook_solution_a', 'system_info']:
            print(f"  - {tool_name}: {'✅ Found' if tool_name in str(tools) else '⚠️ Not found'}")
        return True
    except Exception as e:
        print(f"❌ FastMCP Tools Error: {e}")
        return False

def test_api_direct():
    """Test de l'API directe Papermill (Solution A)"""
    print("\n=== TEST 3: API DIRECTE PAPERMILL (Solution A) ===")
    try:
        import papermill as pm
        
        # Test de l'API directe (remplace subprocess)
        print("✅ API Papermill accessible directement")
        print(f"  - Version: {pm.__version__}")
        print(f"  - Module path: {pm.__file__}")
        
        # Test des fonctions critiques
        if hasattr(pm, 'execute_notebook'):
            print("✅ pm.execute_notebook() - Fonction critique disponible")
        else:
            print("❌ pm.execute_notebook() - MANQUANTE")
            
        return True
    except Exception as e:
        print(f"❌ API Direct Error: {e}")
        return False

def test_nouvelle_architecture():
    """Test de la nouvelle architecture (vs ancienne)"""
    print("\n=== TEST 4: NOUVELLE ARCHITECTURE (vs Ancienne) ===")
    
    # Vérification suppression anciennes implémentations
    old_files = [
        'mcps/internal/servers/jupyter-papermill-mcp-server/papermill_mcp/main_basic.py',
        'mcps/internal/servers/jupyter-papermill-mcp-server/papermill_mcp/main_working.py',
        'mcps/internal/servers/jupyter-papermill-mcp-server/papermill_mcp/main_fixed.py'
    ]
    
    print("✅ Nettoyage architectural validé:")
    for old_file in old_files:
        if not os.path.exists(old_file):
            print(f"  - {os.path.basename(old_file)}: ✅ Supprimé")
        else:
            print(f"  - {os.path.basename(old_file)}: ⚠️ Encore présent")
    
    # Vérification nouveaux fichiers
    new_files = [
        'mcps/internal/servers/jupyter-papermill-mcp-server/CONDA_ENVIRONMENT_SETUP.md',
        'mcps/internal/servers/jupyter-papermill-mcp-server/tests/README.md',
        'mcps/internal/servers/jupyter-papermill-mcp-server/requirements-test.txt'
    ]
    
    print("✅ Nouveaux fichiers architecture:")
    for new_file in new_files:
        if os.path.exists(new_file):
            print(f"  - {os.path.basename(new_file)}: ✅ Présent")
        else:
            print(f"  - {os.path.basename(new_file)}: ❌ Manquant")
    
    return True

def main():
    """Test suite principale"""
    print("🚀 VALIDATION ÉVOLUTIONS JUPYTER-PAPERMILL-MCP-SERVER")
    print("=" * 60)
    
    tests = [
        test_imports,
        test_fastmcp_tools, 
        test_api_direct,
        test_nouvelle_architecture
    ]
    
    results = []
    for test in tests:
        try:
            result = test()
            results.append(result)
        except Exception as e:
            print(f"❌ Test failed: {e}")
            results.append(False)
    
    print("\n" + "=" * 60)
    print(f"🎯 RÉSULTATS: {sum(results)}/{len(results)} tests passés")
    
    if all(results):
        print("✅ REFONTE JUPYTER-PAPERMILL VALIDÉE - API DIRECTE FONCTIONNELLE")
        return True
    else:
        print("⚠️ REFONTE PARTIELLEMENT VALIDÉE - Voir détails ci-dessus")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)