#!/usr/bin/env python3
"""
Script pour tester spécifiquement le mécanisme d'escalade des modes simples vers les modes complexes.
Ce script se concentre sur le test du mode Architect Simple avec une tâche complexe.
"""

import os
import json
import time
import argparse
from datetime import datetime
from typing import Dict, Any, Optional

class EscalationTestResult:
    def __init__(self, mode: str, task: str):
        self.mode = mode
        self.task = task
        self.start_time = time.time()
        self.end_time: Optional[float] = None
        self.duration: Optional[float] = None
        self.tokens_used: Optional[int] = None
        self.cost: Optional[float] = None
        self.escalated: bool = False
        self.escalation_format_correct: bool = False
        self.reason_relevant: bool = False
        self.attempted_partial_solution: bool = False
        self.requested_more_info: bool = False
        self.response: str = ""
        self.notes: str = ""

    def complete(self, tokens_used: int, cost: float, escalated: bool, 
                 escalation_format_correct: bool, reason_relevant: bool,
                 attempted_partial_solution: bool, requested_more_info: bool,
                 response: str, notes: str = ""):
        self.end_time = time.time()
        self.duration = self.end_time - self.start_time
        self.tokens_used = tokens_used
        self.cost = cost
        self.escalated = escalated
        self.escalation_format_correct = escalation_format_correct
        self.reason_relevant = reason_relevant
        self.attempted_partial_solution = attempted_partial_solution
        self.requested_more_info = requested_more_info
        self.response = response
        self.notes = notes

    def to_dict(self) -> Dict[str, Any]:
        return {
            "mode": self.mode,
            "task": self.task,
            "duration": self.duration,
            "tokens_used": self.tokens_used,
            "cost": self.cost,
            "escalated": self.escalated,
            "escalation_format_correct": self.escalation_format_correct,
            "reason_relevant": self.reason_relevant,
            "attempted_partial_solution": self.attempted_partial_solution,
            "requested_more_info": self.requested_more_info,
            "response": self.response,
            "notes": self.notes,
            "success": self.escalated and self.escalation_format_correct and 
                      self.reason_relevant and not self.attempted_partial_solution and 
                      not self.requested_more_info
        }


class EscalationTester:
    def __init__(self, output_dir: str = "test-results-escalade"):
        self.output_dir = output_dir
        
        # Créer le répertoire de sortie s'il n'existe pas
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

    def run_test(self, mode: str, task: str) -> EscalationTestResult:
        """
        Exécute un test d'escalade et retourne le résultat.
        """
        print(f"Test d'escalade pour le mode {mode}")
        print(f"Tâche: {task}")
        
        # Créer un résultat de test
        result = EscalationTestResult(mode, task)
        
        # Demander à l'utilisateur d'entrer manuellement les résultats
        print("\nUne fois le test terminé, veuillez entrer les résultats:")
        
        tokens_used = int(input("Tokens utilisés: "))
        cost = float(input("Coût ($): "))
        escalated = input("Escalade effectuée (o/n): ").lower() == 'o'
        
        if escalated:
            escalation_format_correct = input("Format d'escalade correct '[ESCALADE REQUISE]...' (o/n): ").lower() == 'o'
            reason_relevant = input("Raison d'escalade pertinente (o/n): ").lower() == 'o'
        else:
            escalation_format_correct = False
            reason_relevant = False
        
        attempted_partial_solution = input("Tentative de résolution partielle (o/n): ").lower() == 'o'
        requested_more_info = input("Demande d'informations supplémentaires (o/n): ").lower() == 'o'
        
        print("Entrez la réponse complète du mode (terminez par une ligne contenant uniquement 'END'):")
        response_lines = []
        while True:
            line = input()
            if line == "END":
                break
            response_lines.append(line)
        response = "\n".join(response_lines)
        
        notes = input("Notes supplémentaires: ")
        
        # Compléter le résultat
        result.complete(
            tokens_used, cost, escalated, escalation_format_correct, reason_relevant,
            attempted_partial_solution, requested_more_info, response, notes
        )
        
        return result

    def save_result(self, result: EscalationTestResult) -> str:
        """
        Sauvegarde le résultat du test dans un fichier JSON.
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{self.output_dir}/escalation_test_{result.mode}_{timestamp}.json"
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(result.to_dict(), f, indent=2)
        
        print(f"Résultat sauvegardé dans {filename}")
        
        # Générer également un rapport en markdown
        report_filename = f"{self.output_dir}/escalation_test_{result.mode}_{timestamp}.md"
        self.generate_report(result, report_filename)
        
        return filename

    def generate_report(self, result: EscalationTestResult, filename: str):
        """
        Génère un rapport en markdown pour le test d'escalade.
        """
        success = result.escalated and result.escalation_format_correct and \
                 result.reason_relevant and not result.attempted_partial_solution and \
                 not result.requested_more_info
        
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(f"# Rapport de Test d'Escalade - {result.mode}\n\n")
            f.write(f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"**Résultat global:** {'✅ SUCCÈS' if success else '❌ ÉCHEC'}\n\n")
            
            f.write("## Détails du Test\n\n")
            f.write(f"**Mode testé:** {result.mode}\n")
            f.write(f"**Tâche soumise:**\n```\n{result.task}\n```\n\n")
            
            f.write("## Critères d'Évaluation\n\n")
            f.write(f"1. **Escalade effectuée:** {'✅ Oui' if result.escalated else '❌ Non'}\n")
            f.write(f"2. **Format d'escalade correct:** {'✅ Oui' if result.escalation_format_correct else '❌ Non'}\n")
            f.write(f"3. **Raison d'escalade pertinente:** {'✅ Oui' if result.reason_relevant else '❌ Non'}\n")
            f.write(f"4. **Pas de tentative de résolution partielle:** {'✅ Oui' if not result.attempted_partial_solution else '❌ Non'}\n")
            f.write(f"5. **Pas de demande d'informations supplémentaires:** {'✅ Oui' if not result.requested_more_info else '❌ Non'}\n\n")
            
            f.write("## Métriques\n\n")
            f.write(f"- **Tokens utilisés:** {result.tokens_used}\n")
            f.write(f"- **Coût ($):** {result.cost}\n")
            f.write(f"- **Durée (secondes):** {result.duration:.2f}\n\n")
            
            f.write("## Réponse Complète\n\n")
            f.write(f"```\n{result.response}\n```\n\n")
            
            if result.notes:
                f.write("## Notes Supplémentaires\n\n")
                f.write(f"{result.notes}\n")
        
        print(f"Rapport généré dans {filename}")


def main():
    parser = argparse.ArgumentParser(description="Tester le mécanisme d'escalade des modes simples")
    parser.add_argument("--output", default="test-results-escalade", help="Répertoire de sortie pour les résultats")
    parser.add_argument("--mode", default="architect-simple", help="Mode à tester")
    args = parser.parse_args()
    
    tester = EscalationTester(output_dir=args.output)
    
    # Tâche de test pour l'escalade (architecture de microservices)
    task = """Concevoir l'architecture complète d'un système de microservices pour une plateforme e-commerce à haute disponibilité capable de gérer des millions d'utilisateurs simultanés. L'architecture doit inclure:
- Une stratégie de déploiement multi-région
- Un système de gestion des pannes et de résilience
- Une architecture de sécurité conforme aux normes PCI-DSS
- Une stratégie de mise à l'échelle automatique
- Un plan de migration depuis le système monolithique existant"""
    
    # Exécuter le test
    result = tester.run_test(args.mode, task)
    
    # Sauvegarder le résultat
    tester.save_result(result)
    
    # Afficher un résumé
    success = result.escalated and result.escalation_format_correct and \
             result.reason_relevant and not result.attempted_partial_solution and \
             not result.requested_more_info
    
    print("\nRésumé du test d'escalade:")
    print(f"Mode: {result.mode}")
    print(f"Résultat: {'SUCCÈS' if success else 'ÉCHEC'}")
    print(f"Escalade effectuée: {'Oui' if result.escalated else 'Non'}")
    print(f"Format correct: {'Oui' if result.escalation_format_correct else 'Non'}")
    print(f"Raison pertinente: {'Oui' if result.reason_relevant else 'Non'}")
    print(f"Tentative de résolution partielle: {'Oui' if result.attempted_partial_solution else 'Non'}")
    print(f"Demande d'informations supplémentaires: {'Oui' if result.requested_more_info else 'Non'}")


if __name__ == "__main__":
    main()