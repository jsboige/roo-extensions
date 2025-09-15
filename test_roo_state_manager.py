#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🔧 VALIDATION ROO-STATE-MANAGER - ARCHITECTURE 2-NIVEAUX
========================================================
Script de validation pour les évolutions critiques du roo-state-manager :
- Architecture 2-niveaux avec services background
- Queue d'indexation Qdrant asynchrone  
- Nouveaux outils d'export (XML, traces, CSV, JSON)
- Intervalles d'indexation et gestion mémoire

Partie de la Mission SDDD - Phase 6: Tests de Validation
"""

import os
import sys
import json
from pathlib import Path

def test_architecture_structure():
    """Test 1: Validation structure architecture 2-niveaux"""
    print("=== TEST 1: STRUCTURE ARCHITECTURE 2-NIVEAUX ===")
    
    base_path = Path("mcps/internal/servers/roo-state-manager")
    src_path = base_path / "src"
    
    # Fichiers critiques architecture 2-niveaux
    critical_files = {
        "index.ts": "Point d'entrée principal",
        "services/background-service.ts": "Services background",
        "core/qdrant-manager.ts": "Gestionnaire Qdrant", 
        "tools/export-tools.ts": "Nouveaux outils export",
        "utils/queue-manager.ts": "Gestionnaire de queue"
    }
    
    results = {}
    for file_path, description in critical_files.items():
        full_path = src_path / file_path
        exists = full_path.exists()
        results[file_path] = {"exists": exists, "description": description}
        status = "✅" if exists else "❌"
        print(f"  {status} {file_path}: {description}")
    
    return all(r["exists"] for r in results.values())

def test_main_architecture_code():
    """Test 2: Code architecture principal (index.ts)"""
    print("\n=== TEST 2: CODE ARCHITECTURE PRINCIPALE ===")
    
    index_file = Path("mcps/internal/servers/roo-state-manager/src/index.ts")
    if not index_file.exists():
        print("❌ index.ts introuvable")
        return False
    
    content = index_file.read_text(encoding='utf-8')
    
    # Patterns critiques architecture 2-niveaux
    critical_patterns = {
        "qdrantIndexQueue": "Queue d'indexation Qdrant",
        "qdrantIndexInterval": "Intervalle d'indexation", 
        "startBackgroundServices": "Services background",
        "stopBackgroundServices": "Arrêt services background",
        "processQdrantIndexQueue": "Traitement queue Qdrant",
        "export_tasks_xml": "Export XML",
        "export_conversation_xml": "Export conversation XML", 
        "generate_trace_summary": "Génération résumé traces",
        "export_conversation_json": "Export JSON",
        "export_conversation_csv": "Export CSV"
    }
    
    results = {}
    for pattern, description in critical_patterns.items():
        found = pattern in content
        results[pattern] = {"found": found, "description": description}
        status = "✅" if found else "❌"
        print(f"  {status} {pattern}: {description}")
    
    found_count = sum(1 for r in results.values() if r["found"])
    total_count = len(results)
    print(f"\n📊 Patterns trouvés: {found_count}/{total_count}")
    
    return found_count >= (total_count * 0.8)  # Au moins 80% des patterns

def test_export_tools_structure():
    """Test 3: Nouveaux outils d'export"""
    print("\n=== TEST 3: NOUVEAUX OUTILS D'EXPORT ===")
    
    # Vérifions les nouvelles capacités d'export mentionnées dans le CHANGELOG
    export_capabilities = {
        "XML": "Export conversations au format XML",
        "JSON": "Export conversations au format JSON (light/full)", 
        "CSV": "Export conversations au format CSV (conversations/messages/tools)",
        "Traces": "Génération résumés intelligents de traces",
        "Cluster": "Analyse grappes de tâches liées"
    }
    
    index_file = Path("mcps/internal/servers/roo-state-manager/src/index.ts")
    if not index_file.exists():
        print("❌ Impossible de vérifier les outils d'export")
        return False
        
    content = index_file.read_text(encoding='utf-8')
    
    # Patterns pour chaque capacité
    export_patterns = {
        "XML": ["export_tasks_xml", "export_conversation_xml", "export_project_xml"],
        "JSON": ["export_conversation_json", "jsonVariant"],
        "CSV": ["export_conversation_csv", "csvVariant"],
        "Traces": ["generate_trace_summary", "generate_cluster_summary"],
        "Cluster": ["generate_cluster_summary", "clusterMode"]
    }
    
    results = {}
    for capability, patterns in export_patterns.items():
        found_patterns = [p for p in patterns if p in content]
        has_capability = len(found_patterns) > 0
        results[capability] = {
            "found": has_capability,
            "patterns": found_patterns,
            "description": export_capabilities[capability]
        }
        
        status = "✅" if has_capability else "❌"
        pattern_list = ", ".join(found_patterns) if found_patterns else "Aucun"
        print(f"  {status} {capability}: {pattern_list}")
    
    capabilities_found = sum(1 for r in results.values() if r["found"])
    total_capabilities = len(results)
    print(f"\n📊 Capacités d'export: {capabilities_found}/{total_capabilities}")
    
    return capabilities_found >= 4  # Au moins 4/5 capacités

def test_package_dependencies():
    """Test 4: Dépendances et package.json"""
    print("\n=== TEST 4: DÉPENDANCES ARCHITECTURE ===")
    
    package_file = Path("mcps/internal/servers/roo-state-manager/package.json")
    if not package_file.exists():
        print("❌ package.json introuvable")
        return False
    
    try:
        with open(package_file, 'r', encoding='utf-8') as f:
            package_data = json.load(f)
        
        # Dépendances critiques pour l'architecture 2-niveaux
        critical_deps = {
            "qdrant-js": "Client Qdrant pour indexation sémantique",
            "sqlite3": "Base de données SQLite",
            "xml2js": "Traitement XML pour exports",
            "csv-writer": "Génération CSV",
            "marked": "Traitement Markdown"
        }
        
        dependencies = {**package_data.get("dependencies", {}), 
                       **package_data.get("devDependencies", {})}
        
        results = {}
        for dep, description in critical_deps.items():
            found = any(dep in dep_name for dep_name in dependencies.keys())
            results[dep] = {"found": found, "description": description}
            status = "✅" if found else "⚠️"
            version = next((v for k, v in dependencies.items() if dep in k), "N/A")
            print(f"  {status} {dep} ({version}): {description}")
        
        deps_found = sum(1 for r in results.values() if r["found"])
        total_deps = len(results)
        print(f"\n📊 Dépendances critiques: {deps_found}/{total_deps}")
        
        return deps_found >= 3  # Au moins 3/5 dépendances critiques
        
    except Exception as e:
        print(f"❌ Erreur lecture package.json: {e}")
        return False

def main():
    """Fonction principale de validation"""
    print("🔧 VALIDATION ÉVOLUTIONS ROO-STATE-MANAGER")
    print("=" * 60)
    
    tests = [
        ("Structure Architecture", test_architecture_structure),
        ("Code Architecture Principal", test_main_architecture_code), 
        ("Outils d'Export", test_export_tools_structure),
        ("Dépendances Package", test_package_dependencies)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ ERREUR {test_name}: {e}")
            results.append((test_name, False))
    
    # Rapport final
    print("\n" + "=" * 60)
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    print(f"🎯 RÉSULTATS: {passed}/{total} tests passés")
    
    for test_name, result in results:
        status = "✅" if result else "❌"
        print(f"  {status} {test_name}")
    
    if passed == total:
        print("✅ ARCHITECTURE 2-NIVEAUX ROO-STATE-MANAGER VALIDÉE")
        return True
    else:
        print(f"⚠️ ARCHITECTURE PARTIELLEMENT VALIDÉE ({passed}/{total})")
        return passed >= (total * 0.75)  # 75% de réussite minimum

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)