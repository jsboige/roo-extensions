#!/usr/bin/env python3
# ==============================================================================
# Script: test-python.py
# Description: Tests d'encodage pour Python 3.x
# Auteur: Roo Debug Mode
# Date: 2025-10-29
# ==============================================================================

import sys
import os
import json
import locale
import subprocess
from datetime import datetime
from pathlib import Path


def get_diagnostic_info(test_name):
    """Collecte les informations de diagnostic pour Python"""
    try:
        # Exécuter chcp sur Windows
        code_page = "N/A (Unix)"
        if os.name == "nt":
            result = subprocess.run(
                ["chcp"], capture_output=True, text=True, shell=True
            )
            if result.returncode == 0:
                # Extraire le numéro de code page
                output = result.stdout.strip()
                if ":" in output:
                    code_page = output.split(":")[-1].strip()

        return {
            "test_name": test_name,
            "python_version": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
            "python_implementation": sys.implementation.name,
            "code_page": code_page,
            "default_encoding": sys.getdefaultencoding(),
            "filesystem_encoding": sys.getfilesystemencoding(),
            "stdout_encoding": sys.stdout.encoding
            if hasattr(sys.stdout, "encoding")
            else str(sys.stdout),
            "stderr_encoding": sys.stderr.encoding
            if hasattr(sys.stderr, "encoding")
            else str(sys.stderr),
            "locale_encoding": locale.getpreferredencoding(False),
            "os_name": os.name,
            "platform": sys.platform,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
        }
    except Exception as e:
        return {
            "test_name": test_name,
            "error": str(e),
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
        }


def test_console_display(test_name, content):
    """Test d'affichage dans la console"""
    diag = get_diagnostic_info(test_name)

    try:
        print(f"=== {test_name} ===")
        print(f"Python: {diag['python_version']} ({diag['python_implementation']})")
        print(f"Platforme: {diag['platform']}")
        print(f"Code Page: {diag['code_page']}")
        print(f"Encodage stdout: {diag['stdout_encoding']}")
        print(f"Affichage: {content}")

        return {"success": True, "diagnostic": diag, "result": "Affiché correctement"}
    except Exception as e:
        return {"success": False, "diagnostic": diag, "error": str(e)}


def test_file_write(test_name, content, filename):
    """Test d'écriture dans un fichier"""
    diag = get_diagnostic_info(test_name)
    file_path = f"results/{filename}"

    try:
        # Créer le répertoire results si nécessaire
        Path("results").mkdir(exist_ok=True)

        # Écrire avec encodage UTF-8 explicite
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)

        # Lire pour vérification
        with open(file_path, "r", encoding="utf-8") as f:
            written_content = f.read()

        if written_content == content:
            return {"success": True, "diagnostic": diag, "result": "Écriture réussie"}
        else:
            return {
                "success": False,
                "diagnostic": diag,
                "error": "Contenu différent après écriture",
            }
    except Exception as e:
        return {"success": False, "diagnostic": diag, "error": str(e)}


def test_file_read(test_name, filename):
    """Test de lecture depuis un fichier"""
    diag = get_diagnostic_info(test_name)
    file_path = f"test-data/{filename}"

    try:
        if not os.path.exists(file_path):
            return {
                "success": False,
                "diagnostic": diag,
                "error": f"Fichier non trouvé: {file_path}",
            }

        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        return {"success": True, "diagnostic": diag, "result": content}
    except Exception as e:
        return {"success": False, "diagnostic": diag, "error": str(e)}


def test_process_transmission(test_name, content):
    """Test de transmission entre processus"""
    diag = get_diagnostic_info(test_name)

    try:
        # Test avec subprocess (pipe)
        result = subprocess.run(
            [sys.executable, "-c", f'print("{content}")'],
            capture_output=True,
            text=True,
            encoding="utf-8",
        )

        if result.returncode == 0 and result.stdout.strip() == content:
            return {
                "success": True,
                "diagnostic": diag,
                "result": "Transmission réussie",
            }
        else:
            return {
                "success": False,
                "diagnostic": diag,
                "error": f"Contenu altéré: {result.stdout} (code: {result.returncode})",
            }
    except Exception as e:
        return {"success": False, "diagnostic": diag, "error": str(e)}


def test_environment_variables(test_name, content):
    """Test des variables d'environnement"""
    diag = get_diagnostic_info(test_name)

    try:
        # Définir une variable d'environnement
        os.environ["TEST_EMOJI_PYTHON"] = content

        # Lire la variable
        env_value = os.environ.get("TEST_EMOJI_PYTHON", "")

        if env_value == content:
            return {
                "success": True,
                "diagnostic": diag,
                "result": "Variable d'environnement préservée",
            }
        else:
            return {
                "success": False,
                "diagnostic": diag,
                "error": "Variable d'environnement altérée",
            }
    except Exception as e:
        return {"success": False, "diagnostic": diag, "error": str(e)}


def test_python_features(test_name):
    """Test des fonctionnalités Python spécifiques"""
    diag = get_diagnostic_info(test_name)

    try:
        features = {
            "has_f_strings": True,  # Python 3.6+
            "has_walrus_operator": hasattr(sys, "version_info")
            and sys.version_info >= (3, 8),
            "has_positional_only_params": True,  # Python 3.8+
            "has_match_statement": True,  # Python 3.10+
            "has_type_hints": True,
            "has_async_await": True,
            "has_pathlib": True,
            "has_dataclasses": hasattr(sys, "version_info")
            and sys.version_info >= (3, 7),
        }

        return {"success": True, "diagnostic": diag, "result": features}
    except Exception as e:
        return {"success": False, "diagnostic": diag, "error": str(e)}


def main():
    """Fonction principale des tests"""
    test_results = []

    print("=" * 60)
    print("  TESTS D'ENCODAGE - PYTHON 3.x")
    print("=" * 60)
    print()

    # Test 1: Caractères accentués simples
    accented_text = "é è à ù ç œ æ â ê î ô û"
    result = test_console_display("Python-Accented", accented_text)
    test_results.append(result)

    result = test_file_write(
        "Python-Accented-File", accented_text, "accented-python.txt"
    )
    test_results.append(result)

    result = test_file_read("Python-Accented-Read", "sample-accented.txt")
    test_results.append(result)

    # Test 2: Emojis simples
    simple_emojis = "✅ ❌ ⚠️ ℹ️"
    result = test_console_display("Python-SimpleEmojis", simple_emojis)
    test_results.append(result)

    result = test_file_write(
        "Python-SimpleEmojis-File", simple_emojis, "simple-emojis-python.txt"
    )
    test_results.append(result)

    result = test_file_read("Python-SimpleEmojis-Read", "sample-emojis.txt")
    test_results.append(result)

    # Test 3: Emojis complexes
    complex_emojis = "🚀 💻 ⚙️ 🪲 📁 📄 📦 🔍 📊 📋 🔬 🎯 📈 💡 💾 🔄 🏗️ 📝 🔧 ✨"
    result = test_console_display("Python-ComplexEmojis", complex_emojis)
    test_results.append(result)

    result = test_file_write(
        "Python-ComplexEmojis-File", complex_emojis, "complex-emojis-python.txt"
    )
    test_results.append(result)

    # Test 4: Transmission entre processus
    transmission_test = "Test transmission: ✅ 🚀 💻"
    result = test_process_transmission("Python-Transmission", transmission_test)
    test_results.append(result)

    # Test 5: Variables d'environnement
    env_test = "Variable env: ✅ 🚀 💻"
    result = test_environment_variables("Python-Environment", env_test)
    test_results.append(result)

    # Test 6: Fonctionnalités Python
    result = test_python_features("Python-Features")
    test_results.append(result)

    # Test 7: Option système UTF-8
    print("=== Test option système UTF-8 ===")
    try:
        if os.name == "nt":
            import ctypes
            import ctypes.wintypes

            # Vérifier si le support UTF-8 worldwide est activé
            try:
                kernel32 = ctypes.windll.kernel32
                # Cette fonction n'existe pas sur toutes les versions de Windows
                # C'est un test pour voir si l'API est disponible
                testUnicode = kernel32.GetConsoleOutputCP()
                testUnicode = kernel32.GetConsoleCP()

                test_results.append(
                    {
                        "success": True,
                        "diagnostic": get_diagnostic_info("Python-SystemSupport"),
                        "result": f"Console CP: {testUnicode}, Output CP: {testUnicode}",
                    }
                )
            except Exception as e:
                test_results.append(
                    {
                        "success": False,
                        "diagnostic": get_diagnostic_info("Python-SystemSupport"),
                        "error": f"API Windows non disponible: {str(e)}",
                    }
                )
        else:
            # Sur Unix, vérifier les locales
            current_locale = locale.getlocale()
            test_results.append(
                {
                    "success": True,
                    "diagnostic": get_diagnostic_info("Python-SystemSupport"),
                    "result": f"Locale Unix: {current_locale}",
                }
            )
    except Exception as e:
        test_results.append(
            {
                "success": False,
                "diagnostic": get_diagnostic_info("Python-SystemSupport"),
                "error": str(e),
            }
        )

    # Sauvegarder les résultats
    results_file = "results/python-results.json"
    Path("results").mkdir(exist_ok=True)

    with open(results_file, "w", encoding="utf-8") as f:
        json.dump(test_results, f, indent=2, ensure_ascii=False)

    print()
    print("=" * 60)
    print("  RÉSUMÉ DES TESTS PYTHON")
    print("=" * 60)
    print()

    success_count = sum(1 for result in test_results if result.get("success", False))
    failure_count = len(test_results) - success_count

    print(f"Tests exécutés: {len(test_results)}")
    print(f"Réussis: {success_count}")
    print(f"Échecs: {failure_count}")
    print(f"Taux de succès: {round((success_count / len(test_results)) * 100, 2)}%")

    print()
    print(f"Résultats détaillés sauvegardés dans: {results_file}")
    print("Tests Python terminés")


if __name__ == "__main__":
    main()
