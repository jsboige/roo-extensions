#!/usr/bin/env python3
"""
🎯 TEST COMPLET 11/11 OUTILS MCP JUPYTER-PAPERMILL
Mission SDDD : Validation finale après corrections des 2 bugs restants
"""

import json
import os
import sys
import time
import datetime
from pathlib import Path
import tempfile

def test_mcp_jupyter_complete():
    """Test complet des 11 outils MCP Jupyter-Papermill"""
    print("🎯 MISSION SDDD : VALIDATION 11/11 OUTILS MCP JUPYTER-PAPERMILL")
    print("=" * 70)
    
    # Résultats de test
    results = {}
    
    try:
        # Import des fonctions d'outils directement
        from papermill_mcp.main_fastmcp import (
            list_kernels, create_notebook, add_cell_to_notebook,
            execute_notebook, execute_notebook_solution_a, parameterize_notebook,
            list_notebook_cells, get_notebook_metadata, inspect_notebook_outputs,
            validate_notebook, system_info
        )
        print("✅ Import serveur MCP : Succès")
        print("📊 Toutes les fonctions d'outils importées")
        
        # Liste des 11 outils attendus
        expected_tools = [
            'list_kernels',           # 1
            'create_notebook',        # 2  
            'add_cell_to_notebook',   # 3
            'execute_notebook',       # 4
            'execute_notebook_solution_a',  # 5 - BUG CORRIGÉ
            'parameterize_notebook',  # 6 - BUG CORRIGÉ
            'list_notebook_cells',    # 7
            'get_notebook_metadata',  # 8
            'inspect_notebook_outputs', # 9
            'validate_notebook',      # 10
            'system_info'             # 11
        ]
        
        print(f"\n🎯 VALIDATION : {len(expected_tools)} outils attendus")
        
        # Test 1: list_kernels (toujours fonctionnel)
        print(f"\n1️⃣ TEST list_kernels")
        try:
            kernels = list_kernels()
            if isinstance(kernels, list) and len(kernels) > 0:
                print(f"   ✅ {len(kernels)} kernels détectés")
                results['list_kernels'] = 'SUCCESS'
            else:
                print(f"   ❌ Aucun kernel détecté")
                results['list_kernels'] = 'FAILED'
        except Exception as e:
            print(f"   ❌ Erreur: {e}")
            results['list_kernels'] = 'ERROR'
        
        # Test 2: system_info (toujours fonctionnel)
        print(f"\n2️⃣ TEST system_info")
        try:
            info = system_info()
            if info.get('status') == 'success':
                print(f"   ✅ Python {info['python']['version']}")
                results['system_info'] = 'SUCCESS'
            else:
                print(f"   ❌ Status non-success")
                results['system_info'] = 'FAILED'
        except Exception as e:
            print(f"   ❌ Erreur: {e}")
            results['system_info'] = 'ERROR'
        
        # Test 3: create_notebook + validation complète
        print(f"\n3️⃣ TEST create_notebook")
        test_notebook = "test_sddd_mission_complete.ipynb"
        try:
            result = create_notebook(
                notebook_path=test_notebook,
                kernel_name="python3"
            )
            if result.get('status') == 'success':
                print(f"   ✅ Notebook créé: {test_notebook}")
                results['create_notebook'] = 'SUCCESS'
                
                # Test 4: add_cell_to_notebook (corrigé précédemment)
                print(f"\n4️⃣ TEST add_cell_to_notebook")
                cell_result = add_cell_to_notebook(
                    notebook_path=test_notebook,
                    cell_type="code",
                    content="# TEST SDDD MISSION\nprint('Finalisation 11/11 outils réussie!')"
                )
                if cell_result.get('status') == 'success':
                    print(f"   ✅ Cellule ajoutée avec succès")
                    results['add_cell_to_notebook'] = 'SUCCESS'
                else:
                    print(f"   ❌ Échec ajout cellule")
                    results['add_cell_to_notebook'] = 'FAILED'
                    
                # Test 5: Autres outils de lecture
                test_functions = [
                    ('list_notebook_cells', list_notebook_cells),
                    ('get_notebook_metadata', get_notebook_metadata),
                    ('validate_notebook', validate_notebook)
                ]
                
                for tool_name, tool_func in test_functions:
                    print(f"\n5️⃣ TEST {tool_name}")
                    try:
                        tool_result = tool_func(notebook_path=test_notebook)
                        if tool_result.get('status') == 'success':
                            print(f"   ✅ {tool_name}: Succès")
                            results[tool_name] = 'SUCCESS'
                        else:
                            print(f"   ❌ {tool_name}: Échec")
                            results[tool_name] = 'FAILED'
                    except Exception as e:
                        print(f"   ❌ {tool_name}: Erreur {e}")
                        results[tool_name] = 'ERROR'
                        
            else:
                print(f"   ❌ Échec création notebook")
                results['create_notebook'] = 'FAILED'
        except Exception as e:
            print(f"   ❌ Erreur: {e}")
            results['create_notebook'] = 'ERROR'
        
        # 🎯 TESTS CRITIQUES : 2 outils corrigés
        print(f"\n🎯 TESTS CRITIQUES : OUTILS CORRIGÉS")
        print("=" * 50)
        
        # Test CRITIQUE 6: parameterize_notebook (BUG CORRIGÉ)
        print(f"\n6️⃣ TEST CRITIQUE parameterize_notebook (BUG Pydantic CORRIGÉ)")
        try:
            # Test avec dictionnaire direct (cas normal)
            params_dict = {"test_param": "valeur_test", "number": 42}
            param_result = parameterize_notebook(
                notebook_path=test_notebook,
                parameters=params_dict,
                output_path=""
            )
            
            # Test avec string JSON (cas problématique corrigé)
            params_json = '{"test_param": "valeur_json", "number": 123}'
            param_result_json = parameterize_notebook(
                notebook_path=test_notebook,
                parameters=params_json,
                output_path=""
            )
            
            success_count = 0
            if param_result.get('status') == 'success':
                print(f"   ✅ Paramètres dictionnaire: Succès")
                success_count += 1
            else:
                print(f"   ❌ Paramètres dictionnaire: {param_result.get('error', 'Échec')}")
                
            if param_result_json.get('status') == 'success':
                print(f"   ✅ Paramètres JSON string: Succès")
                success_count += 1
            else:
                print(f"   ❌ Paramètres JSON string: {param_result_json.get('error', 'Échec')}")
            
            if success_count == 2:
                print(f"   🎯 CORRECTION VALIDÉE: Bug Pydantic résolu!")
                results['parameterize_notebook'] = 'SUCCESS'
            else:
                print(f"   ⚠️ CORRECTION PARTIELLE: {success_count}/2 tests réussis")
                results['parameterize_notebook'] = 'PARTIAL'
                
        except Exception as e:
            print(f"   ❌ Erreur critique: {e}")
            results['parameterize_notebook'] = 'ERROR'
        
        # Test CRITIQUE 7: execute_notebook_solution_a (BUG CORRIGÉ)
        print(f"\n7️⃣ TEST CRITIQUE execute_notebook_solution_a (BUG Instabilité CORRIGÉ)")
        try:
            exec_result = execute_notebook_solution_a(
                notebook_path=test_notebook,
                output_path=""
            )
            if exec_result.get('status') == 'success':
                print(f"   ✅ Exécution réussie avec timestamp unique")
                print(f"   📁 Fichier: {exec_result.get('output_path', 'N/A')}")
                print(f"   ⏱️ Temps: {exec_result.get('execution_time_seconds', 'N/A')}s")
                results['execute_notebook_solution_a'] = 'SUCCESS'
            else:
                print(f"   ❌ Échec exécution: {exec_result.get('error', 'Inconnu')}")
                results['execute_notebook_solution_a'] = 'FAILED'
        except Exception as e:
            print(f"   ❌ Erreur critique: {e}")
            results['execute_notebook_solution_a'] = 'ERROR'
        
        # Test 8: execute_notebook (témoin - déjà fonctionnel)
        print(f"\n8️⃣ TEST execute_notebook (témoin)")
        try:
            exec_std_result = execute_notebook(
                notebook_path=test_notebook,
                output_path=""
            )
            if exec_std_result.get('status') == 'success':
                print(f"   ✅ Exécution standard réussie (témoin)")
                results['execute_notebook'] = 'SUCCESS'
            else:
                print(f"   ❌ Échec exécution standard")
                results['execute_notebook'] = 'FAILED'
        except Exception as e:
            print(f"   ❌ Erreur: {e}")
            results['execute_notebook'] = 'ERROR'
            
        # Test 9: inspect_notebook_outputs
        print(f"\n9️⃣ TEST inspect_notebook_outputs")
        try:
            inspect_result = inspect_notebook_outputs(notebook_path=test_notebook)
            if inspect_result.get('status') == 'success':
                print(f"   ✅ Inspection réussie")
                results['inspect_notebook_outputs'] = 'SUCCESS'
            else:
                print(f"   ❌ Échec inspection")
                results['inspect_notebook_outputs'] = 'FAILED'
        except Exception as e:
            print(f"   ❌ Erreur: {e}")
            results['inspect_notebook_outputs'] = 'ERROR'
        
    except ImportError as e:
        print(f"❌ Erreur import serveur MCP: {e}")
        return False
    except Exception as e:
        print(f"❌ Erreur générale: {e}")
        return False
    
    # 📊 RAPPORT FINAL
    print(f"\n📊 RAPPORT FINAL MISSION SDDD")
    print("=" * 70)
    
    success_count = sum(1 for v in results.values() if v == 'SUCCESS')
    total_tools = len(expected_tools)
    success_rate = (success_count / total_tools) * 100
    
    print(f"🎯 RÉSULTAT MISSION : {success_count}/{total_tools} outils fonctionnels ({success_rate:.1f}%)")
    
    # Détail par outil
    for tool in expected_tools:
        status = results.get(tool, 'NOT_TESTED')
        icon = "✅" if status == 'SUCCESS' else "⚠️" if status == 'PARTIAL' else "❌"
        print(f"   {icon} {tool}: {status}")
    
    # Validation mission
    if success_count == total_tools:
        print(f"\n🎉 MISSION SDDD ACCOMPLIE : 100% FONCTIONNALITÉ (11/11)")
        print(f"✅ Corrections bugs appliquées avec succès")
        print(f"✅ Serveur MCP Jupyter-Papermill complètement opérationnel")
        return True
    else:
        failed_count = total_tools - success_count
        print(f"\n⚠️ MISSION PARTIELLE : {failed_count} outils nécessitent attention")
        
    # Nettoyage
    try:
        if 'test_notebook' in locals() and os.path.exists(test_notebook):
            os.remove(test_notebook)
            print(f"\n🧹 Nettoyage: {test_notebook} supprimé")
    except:
        pass
        
    return success_count == total_tools

if __name__ == "__main__":
    print("🚀 Démarrage validation complète...")
    success = test_mcp_jupyter_complete()
    sys.exit(0 if success else 1)