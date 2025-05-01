#!/usr/bin/env python3
"""
Script pour tester de manière complète les mécanismes d'escalade et de rétrogradation
pour tous les modes (Code, Debug, Architect, Ask, Orchestrator).

Ce script permet de tester:
1. L'escalade externe pour les modes simples
2. L'escalade interne pour les modes simples
3. La notification d'escalade pour les modes complexes
4. La suggestion de rétrogradation pour les modes complexes

Les résultats sont documentés dans un fichier markdown.
"""

import os
import json
import time
import argparse
from datetime import datetime
from typing import Dict, Any, Optional, List, Tuple

# Définition des tâches de test pour chaque mode
TASKS = {
    # Tâches complexes pour tester l'escalade externe des modes simples
    "escalade_externe": {
        "code-simple": """Refactoriser le système de gestion des utilisateurs pour améliorer les performances.
Le refactoring doit inclure:
- Optimisation des requêtes de base de données
- Mise en place d'un système de cache
- Restructuration complète du modèle de données""",
        
        "debug-simple": """Résoudre un problème de concurrence dans le système de paiement qui cause des deadlocks
sous forte charge. Le problème implique plusieurs microservices et nécessite une analyse
approfondie des logs et des transactions.""",
        
        "architect-simple": """Concevoir l'architecture complète d'un système de microservices pour une plateforme e-commerce.
L'architecture doit inclure:
- Une stratégie de déploiement multi-région
- Un système de gestion des pannes et de résilience
- Une architecture de sécurité conforme aux normes PCI-DSS""",
        
        "ask-simple": """Expliquer en détail les avantages et inconvénients des différentes architectures de microservices
pour un système bancaire à haute disponibilité, en incluant une analyse comparative des patterns
de communication synchrone vs asynchrone et leurs impacts sur la résilience du système.""",
        
        "orchestrator-simple": """Coordonner la migration d'un système monolithique vers une architecture de microservices,
en planifiant les différentes phases, les équipes impliquées, et les stratégies de test et de déploiement.
Cette migration implique plus de 20 composants interdépendants."""
    },
    
    # Tâches modérément complexes pour tester l'escalade interne des modes simples
    "escalade_interne": {
        "code-simple": """Implémenter une fonctionnalité de validation de formulaire qui vérifie:
- La validité des emails avec une expression régulière
- La force des mots de passe (au moins 8 caractères, majuscules, minuscules, chiffres)
- La correspondance entre le mot de passe et sa confirmation""",
        
        "debug-simple": """Corriger un bug où les données du formulaire ne sont pas correctement validées avant d'être 
envoyées au serveur, ce qui cause des erreurs 400 Bad Request. Le problème semble lié à la 
conversion des dates.""",
        
        "architect-simple": """Créer un diagramme de flux pour le processus d'authentification d'une application web,
incluant l'inscription, la connexion, la récupération de mot de passe et la déconnexion.""",
        
        "ask-simple": """Expliquer le concept de programmation orientée objet, ses principes fondamentaux
(encapsulation, héritage, polymorphisme) et comment ils sont implémentés en Java.""",
        
        "orchestrator-simple": """Planifier l'implémentation d'une fonctionnalité de recherche avancée pour un site
e-commerce, en décomposant la tâche en étapes et en identifiant les compétences nécessaires."""
    },
    
    # Tâches complexes pour tester la notification d'escalade des modes complexes
    "notification_escalade": {
        "code-complex": """Refactoriser le système de gestion des utilisateurs pour améliorer les performances.
Le refactoring doit inclure:
- Optimisation des requêtes de base de données
- Mise en place d'un système de cache
- Restructuration complète du modèle de données

Note: Cette tâche a été escaladée depuis le mode code-simple.""",
        
        "debug-complex": """Résoudre un problème de concurrence dans le système de paiement qui cause des deadlocks
sous forte charge. Le problème implique plusieurs microservices et nécessite une analyse
approfondie des logs et des transactions.

Note: Cette tâche a été escaladée depuis le mode debug-simple.""",
        
        "architect-complex": """Concevoir l'architecture complète d'un système de microservices pour une plateforme e-commerce.
L'architecture doit inclure:
- Une stratégie de déploiement multi-région
- Un système de gestion des pannes et de résilience
- Une architecture de sécurité conforme aux normes PCI-DSS

Note: Cette tâche a été escaladée depuis le mode architect-simple.""",
        
        "ask-complex": """Expliquer en détail les avantages et inconvénients des différentes architectures de microservices
pour un système bancaire à haute disponibilité, en incluant une analyse comparative des patterns
de communication synchrone vs asynchrone et leurs impacts sur la résilience du système.

Note: Cette tâche a été escaladée depuis le mode ask-simple.""",
        
        "orchestrator-complex": """Coordonner la migration d'un système monolithique vers une architecture de microservices,
en planifiant les différentes phases, les équipes impliquées, et les stratégies de test et de déploiement.
Cette migration implique plus de 20 composants interdépendants.

Note: Cette tâche a été escaladée depuis le mode orchestrator-simple."""
    },
    
    # Tâches simples pour tester la suggestion de rétrogradation des modes complexes
    "retrogradation": {
        "code-complex": """Ajouter une validation d'entrée à la fonction suivante pour s'assurer que le paramètre 'name' 
n'est pas vide et contient uniquement des lettres et des espaces:

function greetUser(name) {
  return `Hello, ${name}!`;
}""",
        
        "debug-complex": """Le code suivant génère une erreur. Pouvez-vous identifier et corriger le problème?

function calculateTotal(items) {
  let total = 0;
  for (let i = 0; i < items.lenght; i++) {
    total += items[i];
  }
  return total;
}""",
        
        "architect-complex": """Créer un README pour le composant d'authentification qui explique:
- Son objectif
- Comment l'utiliser
- Les dépendances requises
- Les configurations possibles""",
        
        "ask-complex": """Qu'est-ce que le pattern MVC en développement web?""",
        
        "orchestrator-complex": """Créer une page web statique avec un formulaire de contact qui inclut:
- Champs pour le nom, email et message
- Validation côté client
- Un message de confirmation après soumission"""
    }
}

class TestResult:
    def __init__(self, mode: str, test_type: str, task: str):
        self.mode = mode
        self.test_type = test_type
        self.task = task
        self.start_time = time.time()
        self.end_time: Optional[float] = None
        self.duration: Optional[float] = None
        self.success: bool = False
        self.response: str = ""
        self.notes: str = ""
        
        # Critères spécifiques selon le type de test
        if test_type == "escalade_externe":
            self.criteria = {
                "escalade_effectuee": False,
                "format_correct": False,
                "raison_pertinente": False,
                "pas_resolution_partielle": False,
                "pas_demande_info": False
            }
        elif test_type == "escalade_interne":
            self.criteria = {
                "tache_traitee": False,
                "escalade_signalee": False,
                "format_correct": False
            }
        elif test_type == "notification_escalade":
            self.criteria = {
                "tache_traitee": False,
                "notification_presente": False,
                "format_correct": False
            }
        elif test_type == "retrogradation":
            self.criteria = {
                "retrogradation_suggeree": False,
                "format_correct": False,
                "raison_pertinente": False,
                "tache_traitee": False
            }
    
    def complete(self, criteria_results: Dict[str, bool], response: str, notes: str = ""):
        self.end_time = time.time()
        self.duration = self.end_time - self.start_time
        
        # Mettre à jour les critères
        for key, value in criteria_results.items():
            if key in self.criteria:
                self.criteria[key] = value
        
        self.response = response
        self.notes = notes
        
        # Déterminer si le test est réussi en fonction des critères
        if self.test_type == "escalade_externe":
            self.success = (self.criteria["escalade_effectuee"] and 
                           self.criteria["format_correct"] and 
                           self.criteria["raison_pertinente"] and 
                           self.criteria["pas_resolution_partielle"] and 
                           self.criteria["pas_demande_info"])
        elif self.test_type == "escalade_interne":
            self.success = (self.criteria["tache_traitee"] and 
                           self.criteria["escalade_signalee"] and 
                           self.criteria["format_correct"])
        elif self.test_type == "notification_escalade":
            self.success = (self.criteria["tache_traitee"] and 
                           self.criteria["notification_presente"] and 
                           self.criteria["format_correct"])
        elif self.test_type == "retrogradation":
            self.success = (self.criteria["retrogradation_suggeree"] and 
                           self.criteria["format_correct"] and 
                           self.criteria["raison_pertinente"] and 
                           self.criteria["tache_traitee"])


class EscalationTester:
    def __init__(self, output_file: str = "resultats-tests-escalade.md"):
        self.output_file = output_file
        self.results: List[TestResult] = []
    
    def run_test(self, mode: str, test_type: str) -> TestResult:
        """
        Exécute un test d'escalade ou de rétrogradation et retourne le résultat.
        """
        task = TASKS[test_type].get(mode, "Tâche non définie pour ce mode")
        
        print(f"\n{'='*80}")
        print(f"TEST DE {test_type.upper()} - MODE {mode.upper()}")
        print(f"{'='*80}")
        
        print("\nTÂCHE DE TEST:")
        print(f"{task}")
        
        # Instructions spécifiques selon le type de test
        if test_type == "escalade_externe":
            print("\nINSTRUCTIONS:")
            print("1. Copiez cette tâche et soumettez-la à un nouvel agent dans le mode spécifié")
            print("2. Observez si l'agent escalade correctement la tâche")
            print("3. Vérifiez que l'escalade respecte les critères suivants:")
            print("   - L'agent identifie immédiatement la complexité de la tâche")
            print("   - L'agent utilise le format exact: [ESCALADE REQUISE] Cette tâche nécessite...")
            print("   - L'agent fournit une raison pertinente pour l'escalade")
            print("   - L'agent ne tente pas de résoudre partiellement la tâche")
            print("   - L'agent ne demande pas d'informations supplémentaires")
        elif test_type == "escalade_interne":
            print("\nINSTRUCTIONS:")
            print("1. Copiez cette tâche et soumettez-la à un nouvel agent dans le mode spécifié")
            print("2. Observez si l'agent traite la tâche mais signale une escalade interne")
            print("3. Vérifiez que l'escalade interne respecte les critères suivants:")
            print("   - L'agent traite la tâche")
            print("   - L'agent signale une escalade interne avec le format: [ESCALADE INTERNE]")
        elif test_type == "notification_escalade":
            print("\nINSTRUCTIONS:")
            print("1. Copiez cette tâche et soumettez-la à un nouvel agent dans le mode spécifié")
            print("2. Précisez que cette tâche provient d'une escalade depuis un mode simple")
            print("3. Vérifiez que l'agent traite la tâche et inclut la notification d'escalade:")
            print("   - L'agent traite complètement la tâche")
            print("   - L'agent inclut à la fin: [ISSU D'ESCALADE] Cette tâche a été traitée...")
        elif test_type == "retrogradation":
            print("\nINSTRUCTIONS:")
            print("1. Copiez cette tâche et soumettez-la à un nouvel agent dans le mode spécifié")
            print("2. Observez si l'agent suggère une rétrogradation")
            print("3. Vérifiez que la suggestion de rétrogradation respecte les critères suivants:")
            print("   - L'agent suggère une rétrogradation avec le format: [RÉTROGRADATION SUGGÉRÉE]")
            print("   - L'agent fournit une raison pertinente pour la rétrogradation")
            print("   - Malgré la suggestion, l'agent traite complètement la tâche")
        
        # Créer un résultat de test
        result = TestResult(mode, test_type, task)
        
        # Demander à l'utilisateur d'entrer manuellement les résultats
        print("\nUne fois le test terminé, veuillez entrer les résultats:")
        
        criteria_results = {}
        
        if test_type == "escalade_externe":
            criteria_results["escalade_effectuee"] = input("\nL'agent a-t-il escaladé la tâche? (o/n): ").lower() == 'o'
            
            if criteria_results["escalade_effectuee"]:
                criteria_results["format_correct"] = input("Le format d'escalade était-il correct? (o/n): ").lower() == 'o'
                criteria_results["raison_pertinente"] = input("La raison d'escalade était-elle pertinente? (o/n): ").lower() == 'o'
                criteria_results["pas_resolution_partielle"] = input("L'agent a-t-il évité de résoudre partiellement la tâche? (o/n): ").lower() == 'o'
                criteria_results["pas_demande_info"] = input("L'agent a-t-il évité de demander des informations supplémentaires? (o/n): ").lower() == 'o'
            else:
                criteria_results["format_correct"] = False
                criteria_results["raison_pertinente"] = False
                criteria_results["pas_resolution_partielle"] = False
                criteria_results["pas_demande_info"] = False
        
        elif test_type == "escalade_interne":
            criteria_results["tache_traitee"] = input("\nL'agent a-t-il traité la tâche? (o/n): ").lower() == 'o'
            criteria_results["escalade_signalee"] = input("L'agent a-t-il signalé une escalade interne? (o/n): ").lower() == 'o'
            
            if criteria_results["escalade_signalee"]:
                criteria_results["format_correct"] = input("Le format de l'escalade interne était-il correct? (o/n): ").lower() == 'o'
            else:
                criteria_results["format_correct"] = False
        
        elif test_type == "notification_escalade":
            criteria_results["tache_traitee"] = input("\nL'agent a-t-il traité complètement la tâche? (o/n): ").lower() == 'o'
            criteria_results["notification_presente"] = input("L'agent a-t-il inclus la notification d'escalade? (o/n): ").lower() == 'o'
            
            if criteria_results["notification_presente"]:
                criteria_results["format_correct"] = input("Le format de la notification était-il correct? (o/n): ").lower() == 'o'
            else:
                criteria_results["format_correct"] = False
        
        elif test_type == "retrogradation":
            criteria_results["retrogradation_suggeree"] = input("\nL'agent a-t-il suggéré une rétrogradation? (o/n): ").lower() == 'o'
            
            if criteria_results["retrogradation_suggeree"]:
                criteria_results["format_correct"] = input("Le format de la suggestion était-il correct? (o/n): ").lower() == 'o'
                criteria_results["raison_pertinente"] = input("La raison de la rétrogradation était-elle pertinente? (o/n): ").lower() == 'o'
            else:
                criteria_results["format_correct"] = False
                criteria_results["raison_pertinente"] = False
            
            criteria_results["tache_traitee"] = input("L'agent a-t-il traité complètement la tâche malgré la suggestion? (o/n): ").lower() == 'o'
        
        print("\nEntrez la réponse complète de l'agent (terminez par une ligne contenant uniquement 'END'):")
        response_lines = []
        while True:
            line = input()
            if line == "END":
                break
            response_lines.append(line)
        response = "\n".join(response_lines)
        
        notes = input("\nNotes ou observations supplémentaires: ")
        
        # Compléter le résultat
        result.complete(criteria_results, response, notes)
        
        # Ajouter le résultat à la liste
        self.results.append(result)
        
        return result
    
    def generate_report(self):
        """
        Génère un rapport markdown avec les résultats de tous les tests.
        """
        with open(self.output_file, 'w', encoding='utf-8') as f:
            f.write("# Résultats des Tests d'Escalade et de Rétrogradation\n\n")
            f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            # Tableau récapitulatif
            f.write("## Tableau Récapitulatif\n\n")
            f.write("| Mode | Type de Test | Résultat | Critères Réussis |\n")
            f.write("|------|-------------|----------|------------------|\n")
            
            for result in self.results:
                criteria_count = sum(1 for v in result.criteria.values() if v)
                total_criteria = len(result.criteria)
                f.write(f"| {result.mode} | {result.test_type.replace('_', ' ').title()} | {'✅ Réussi' if result.success else '❌ Échoué'} | {criteria_count}/{total_criteria} |\n")
            
            # Détails des tests
            f.write("\n## Détails des Tests\n\n")
            
            for result in self.results:
                f.write(f"### Test de {result.test_type.replace('_', ' ').title()} - {result.mode}\n\n")
                f.write(f"**Résultat:** {'✅ Réussi' if result.success else '❌ Échoué'}\n\n")
                f.write("**Tâche soumise:**\n```\n" + result.task + "\n```\n\n")
                
                f.write("**Critères évalués:**\n")
                for criterion, value in result.criteria.items():
                    f.write(f"- {criterion.replace('_', ' ').title()}: {'✅ Oui' if value else '❌ Non'}\n")
                
                f.write("\n**Durée du test:** {:.2f} secondes\n\n".format(result.duration))
                
                if result.notes:
                    f.write("**Notes:**\n" + result.notes + "\n\n")
                
                f.write("**Réponse de l'agent:**\n```\n" + result.response + "\n```\n\n")
                
                f.write("---\n\n")
            
            # Conclusion
            success_count = sum(1 for r in self.results if r.success)
            total_tests = len(self.results)
            
            f.write("## Conclusion\n\n")
            f.write(f"Sur un total de {total_tests} tests, {success_count} ont réussi ({success_count/total_tests*100:.1f}%).\n\n")
            
            if success_count == total_tests:
                f.write("✅ Tous les tests ont réussi. Les mécanismes d'escalade et de rétrogradation fonctionnent correctement.\n")
            else:
                f.write("⚠️ Certains tests ont échoué. Des ajustements sont nécessaires pour assurer le bon fonctionnement des mécanismes d'escalade et de rétrogradation.\n")
                
                # Recommandations
                f.write("\n### Recommandations\n\n")
                
                # Analyser les échecs par type de test
                escalade_externe_fails = [r for r in self.results if r.test_type == "escalade_externe" and not r.success]
                escalade_interne_fails = [r for r in self.results if r.test_type == "escalade_interne" and not r.success]
                notification_escalade_fails = [r for r in self.results if r.test_type == "notification_escalade" and not r.success]
                retrogradation_fails = [r for r in self.results if r.test_type == "retrogradation" and not r.success]
                
                if escalade_externe_fails:
                    f.write("**Problèmes d'escalade externe:**\n")
                    for r in escalade_externe_fails:
                        f.write(f"- Mode {r.mode}: ")
                        issues = []
                        if not r.criteria["escalade_effectuee"]:
                            issues.append("n'a pas escaladé la tâche")
                        if not r.criteria["format_correct"]:
                            issues.append("format d'escalade incorrect")
                        if not r.criteria["raison_pertinente"]:
                            issues.append("raison d'escalade non pertinente")
                        if not r.criteria["pas_resolution_partielle"]:
                            issues.append("a tenté de résoudre partiellement la tâche")
                        if not r.criteria["pas_demande_info"]:
                            issues.append("a demandé des informations supplémentaires")
                        f.write(", ".join(issues) + "\n")
                    f.write("\n")
                
                if escalade_interne_fails:
                    f.write("**Problèmes d'escalade interne:**\n")
                    for r in escalade_interne_fails:
                        f.write(f"- Mode {r.mode}: ")
                        issues = []
                        if not r.criteria["tache_traitee"]:
                            issues.append("n'a pas traité la tâche")
                        if not r.criteria["escalade_signalee"]:
                            issues.append("n'a pas signalé d'escalade interne")
                        if not r.criteria["format_correct"]:
                            issues.append("format d'escalade incorrect")
                        f.write(", ".join(issues) + "\n")
                    f.write("\n")
                
                if notification_escalade_fails:
                    f.write("**Problèmes de notification d'escalade:**\n")
                    for r in notification_escalade_fails:
                        f.write(f"- Mode {r.mode}: ")
                        issues = []
                        if not r.criteria["tache_traitee"]:
                            issues.append("n'a pas traité la tâche")
                        if not r.criteria["notification_presente"]:
                            issues.append("n'a pas inclus la notification d'escalade")
                        if not r.criteria["format_correct"]:
                            issues.append("format de notification incorrect")
                        f.write(", ".join(issues) + "\n")
                    f.write("\n")
                
                if retrogradation_fails:
                    f.write("**Problèmes de rétrogradation:**\n")
                    for r in retrogradation_fails:
                        f.write(f"- Mode {r.mode}: ")
                        issues = []
                        if not r.criteria["retrogradation_suggeree"]:
                            issues.append("n'a pas suggéré de rétrogradation")
                        if not r.criteria["format_correct"]:
                            issues.append("format de suggestion incorrect")
                        if not r.criteria["raison_pertinente"]:
                            issues.append("raison de rétrogradation non pertinente")
                        if not r.criteria["tache_traitee"]:
                            issues.append("n'a pas traité la tâche malgré la suggestion")
                        f.write(", ".join(issues) + "\n")
                    f.write("\n")
                
                # Recommandations générales
                f.write("**Actions recommandées:**\n")
                f.write("1. Vérifier la synchronisation entre les fichiers `.roomodes` et `custom_modes.json`\n")
                f.write("2. S'assurer que les instructions d'escalade et de rétrogradation sont clairement visibles dans les configurations\n")
                f.write("3. Renforcer les critères d'identification des tâches complexes/simples\n")
                f.write("4. Ajouter des exemples concrets de formats d'escalade/rétrogradation dans les instructions\n")
        
        print(f"\nRapport généré avec succès dans {self.output_file}")


def main():
    parser = argparse.ArgumentParser(description="Tester les mécanismes d'escalade et de rétrogradation")
    parser.add_argument("--output", default="resultats-tests-escalade.md", help="Fichier de sortie pour les résultats")
    args = parser.parse_args()
    
    tester = EscalationTester(output_file=args.output)
    
    # Liste des modes à tester
    modes_simples = ["code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple"]
    modes_complexes = ["code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex"]
    
    # Tests pour les modes simples
    print("\n=== TESTS D'ESCALADE EXTERNE POUR LES MODES SIMPLES ===\n")
    for mode in modes_simples:
        input(f"\nAppuyez sur Entrée pour commencer le test d'escalade externe pour {mode}...")
        tester.run_test(mode, "escalade_externe")
    
    print("\n=== TESTS D'ESCALADE INTERNE POUR LES MODES SIMPLES ===\n")
    for mode in modes_simples:
        input(f"\nAppuyez sur Entrée pour commencer le test d'escalade interne pour {mode}...")
        tester.run_test(mode, "escalade_interne")
    
    # Tests pour les modes complexes
    print("\n=== TESTS DE NOTIFICATION D'ESCALADE POUR LES MODES COMPLEXES ===\n")
    for mode in modes_complexes:
        input(f"\nAppuyez sur Entrée pour commencer le test de notification d'escalade pour {mode}...")
        tester.run_test(mode, "notification_escalade")
    
    print("\n=== TESTS DE RÉTROGRADATION POUR LES MODES COMPLEXES ===\n")
    for mode in modes_complexes:
        input(f"\nAppuyez sur Entrée pour commencer le test de rétrogradation pour {mode}...")
        tester.run_test(mode, "retrogradation")
    
    # Générer le rapport
    tester.generate_report()
    
    print("\nTous les tests sont terminés. Consultez le rapport pour les résultats détaillés.")


if __name__ == "__main__":
    main()