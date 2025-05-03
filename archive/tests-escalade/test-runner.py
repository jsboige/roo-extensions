#!/usr/bin/env python3
"""
Script pour exécuter les tests des modes Simples/Complexes de Roo et collecter les résultats.
"""

import os
import json
import time
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional

# Structure pour stocker les résultats des tests
class TestResult:
    def __init__(self, scenario: str, agent_type: str, complexity: str, model: str):
        self.scenario = scenario
        self.agent_type = agent_type
        self.complexity = complexity
        self.model = model
        self.start_time = time.time()
        self.end_time: Optional[float] = None
        self.duration: Optional[float] = None
        self.tokens_used: Optional[int] = None
        self.cost: Optional[float] = None
        self.escalated: bool = False
        self.completed: bool = False
        self.quality_score: Optional[int] = None
        self.notes: str = ""

    def complete(self, tokens_used: int, cost: float, escalated: bool, quality_score: int, notes: str = ""):
        self.end_time = time.time()
        self.duration = self.end_time - self.start_time
        self.tokens_used = tokens_used
        self.cost = cost
        self.escalated = escalated
        self.completed = True
        self.quality_score = quality_score
        self.notes = notes

    def to_dict(self) -> Dict[str, Any]:
        return {
            "scenario": self.scenario,
            "agent_type": self.agent_type,
            "complexity": self.complexity,
            "model": self.model,
            "duration": self.duration,
            "tokens_used": self.tokens_used,
            "cost": self.cost,
            "escalated": self.escalated,
            "completed": self.completed,
            "quality_score": self.quality_score,
            "notes": self.notes
        }


class TestRunner:
    def __init__(self, output_dir: str = "test-results"):
        self.output_dir = output_dir
        self.results: List[TestResult] = []
        
        # Créer le répertoire de sortie s'il n'existe pas
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

    def run_test(self, scenario: str, agent_type: str, complexity: str, model: str) -> TestResult:
        """
        Exécute un test et retourne le résultat.
        
        Note: Cette fonction est un placeholder. Dans une implémentation réelle,
        elle interagirait avec l'API Roo pour exécuter le test.
        """
        print(f"Exécution du test: {scenario} avec {agent_type}-{complexity} ({model})")
        
        # Créer un résultat de test
        result = TestResult(scenario, agent_type, complexity, model)
        
        # Dans une implémentation réelle, vous exécuteriez le test ici
        # et collecteriez les résultats
        
        # Pour l'instant, demandez à l'utilisateur d'entrer manuellement les résultats
        print("\nUne fois le test terminé, veuillez entrer les résultats:")
        
        tokens_used = int(input("Tokens utilisés: "))
        cost = float(input("Coût ($): "))
        escalated = input("Escalade vers mode complexe (o/n): ").lower() == 'o'
        quality_score = int(input("Score de qualité (1-10): "))
        notes = input("Notes: ")
        
        # Compléter le résultat
        result.complete(tokens_used, cost, escalated, quality_score, notes)
        
        # Ajouter le résultat à la liste
        self.results.append(result)
        
        return result

    def save_results(self) -> str:
        """
        Sauvegarde les résultats des tests dans un fichier JSON.
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{self.output_dir}/results_{timestamp}.json"
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump([r.to_dict() for r in self.results], f, indent=2)
        
        print(f"Résultats sauvegardés dans {filename}")
        return filename

    def compare_results(self, model1: str, model2: str) -> Dict[str, Any]:
        """
        Compare les résultats entre deux modèles différents.
        """
        results1 = [r for r in self.results if r.model == model1]
        results2 = [r for r in self.results if r.model == model2]
        
        if not results1 or not results2:
            return {"error": "Pas assez de résultats pour comparer"}
        
        # Calculer les moyennes
        avg_tokens1 = sum(r.tokens_used for r in results1 if r.tokens_used) / len(results1)
        avg_tokens2 = sum(r.tokens_used for r in results2 if r.tokens_used) / len(results2)
        
        avg_cost1 = sum(r.cost for r in results1 if r.cost) / len(results1)
        avg_cost2 = sum(r.cost for r in results2 if r.cost) / len(results2)
        
        avg_quality1 = sum(r.quality_score for r in results1 if r.quality_score) / len(results1)
        avg_quality2 = sum(r.quality_score for r in results2 if r.quality_score) / len(results2)
        
        escalation_rate1 = sum(1 for r in results1 if r.escalated) / len(results1)
        escalation_rate2 = sum(1 for r in results2 if r.escalated) / len(results2)
        
        return {
            "model1": model1,
            "model2": model2,
            "avg_tokens": {model1: avg_tokens1, model2: avg_tokens2, "diff_percent": (avg_tokens2 - avg_tokens1) / avg_tokens1 * 100},
            "avg_cost": {model1: avg_cost1, model2: avg_cost2, "diff_percent": (avg_cost2 - avg_cost1) / avg_cost1 * 100},
            "avg_quality": {model1: avg_quality1, model2: avg_quality2, "diff_percent": (avg_quality2 - avg_quality1) / avg_quality1 * 100},
            "escalation_rate": {model1: escalation_rate1, model2: escalation_rate2}
        }


def main():
    parser = argparse.ArgumentParser(description="Exécuter des tests pour les modes Roo")
    parser.add_argument("--output", default="test-results", help="Répertoire de sortie pour les résultats")
    args = parser.parse_args()
    
    runner = TestRunner(output_dir=args.output)
    
    # Charger les scénarios de test depuis le fichier test-scenarios.md
    # Dans une implémentation réelle, vous pourriez parser le fichier markdown
    # Pour l'instant, nous allons juste utiliser quelques exemples
    
    scenarios = [
        # Format: (scenario, agent_type, complexity)
        ("Correction de bug simple", "code", "simple"),
        ("Refactoring majeur", "code", "complex"),
        ("Erreur de syntaxe", "debug", "simple"),
        ("Bug concurrent", "debug", "complex"),
        ("Documentation technique", "architect", "simple"),
        ("Conception système", "architect", "complex"),
        ("Question factuelle", "ask", "simple"),
        ("Analyse approfondie", "ask", "complex"),
        ("Décomposition simple", "orchestrator", "simple"),
        ("Projet complet", "orchestrator", "complex")
    ]
    
    # Modèles à tester
    models = ["anthropic/claude-3.5-sonnet", "qwen/qwen-3-235b-a22b"]
    
    # Exécuter les tests
    for scenario, agent_type, complexity in scenarios:
        for model in models:
            runner.run_test(scenario, agent_type, complexity, model)
    
    # Sauvegarder les résultats
    results_file = runner.save_results()
    
    # Comparer les résultats
    comparison = runner.compare_results(models[0], models[1])
    
    # Afficher la comparaison
    print("\nComparaison des modèles:")
    print(json.dumps(comparison, indent=2))
    
    # Sauvegarder la comparaison
    comparison_file = f"{args.output}/comparison_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(comparison_file, 'w', encoding='utf-8') as f:
        json.dump(comparison, f, indent=2)
    
    print(f"Comparaison sauvegardée dans {comparison_file}")


if __name__ == "__main__":
    main()