#!/usr/bin/env python3
"""
Script pour vérifier que les modifications des mécanismes d'escalade ont été correctement appliquées.
Ce script est une version simplifiée de test-escalade.py, conçu pour vérifier rapidement le comportement
d'escalade après les modifications.
"""

import os
import json
import time
import argparse
from datetime import datetime

def main():
    parser = argparse.ArgumentParser(description="Vérifier les mécanismes d'escalade après modifications")
    parser.add_argument("--mode", default="architect-simple", 
                        choices=["architect-simple", "code-simple", "debug-simple", "ask-simple", "orchestrator-simple"],
                        help="Mode à tester")
    args = parser.parse_args()
    
    # Tâche de test pour l'escalade (architecture de microservices)
    if args.mode == "architect-simple":
        task = """Concevoir l'architecture complète d'un système de microservices pour une plateforme e-commerce.
L'architecture doit inclure:
- Une stratégie de déploiement multi-région
- Un système de gestion des pannes et de résilience
- Une architecture de sécurité conforme aux normes PCI-DSS"""
    elif args.mode == "code-simple":
        task = """Refactoriser le système de gestion des utilisateurs pour améliorer les performances.
Le refactoring doit inclure:
- Optimisation des requêtes de base de données
- Mise en place d'un système de cache
- Restructuration complète du modèle de données"""
    elif args.mode == "debug-simple":
        task = """Résoudre un problème de concurrence dans le système de paiement qui cause des deadlocks
sous forte charge. Le problème implique plusieurs microservices et nécessite une analyse
approfondie des logs et des transactions."""
    elif args.mode == "ask-simple":
        task = """Expliquer en détail les avantages et inconvénients des différentes architectures de microservices
pour un système bancaire à haute disponibilité, en incluant une analyse comparative des patterns
de communication synchrone vs asynchrone et leurs impacts sur la résilience du système."""
    else:  # orchestrator-simple
        task = """Coordonner la migration d'un système monolithique vers une architecture de microservices,
en planifiant les différentes phases, les équipes impliquées, et les stratégies de test et de déploiement.
Cette migration implique plus de 20 composants interdépendants."""
    
    print("\n" + "="*80)
    print(f"TEST DE VÉRIFICATION D'ESCALADE - MODE {args.mode.upper()}")
    print("="*80)
    
    print("\nTÂCHE DE TEST:")
    print(f"{task}")
    
    print("\nINSTRUCTIONS:")
    print("1. Copiez cette tâche et soumettez-la à un nouvel agent dans le mode spécifié")
    print("2. Observez si l'agent escalade correctement la tâche")
    print("3. Vérifiez que l'escalade respecte les critères suivants:")
    print("   - L'agent identifie immédiatement la complexité de la tâche")
    print("   - L'agent utilise le format exact: [ESCALADE REQUISE] Cette tâche nécessite...")
    print("   - L'agent fournit une raison pertinente pour l'escalade")
    print("   - L'agent ne tente pas de résoudre partiellement la tâche")
    print("   - L'agent ne demande pas d'informations supplémentaires")
    
    print("\nRÉSULTATS ATTENDUS:")
    print("L'agent devrait immédiatement escalader cette tâche vers sa version complexe")
    print("sans tenter de la résoudre ou de demander plus d'informations.")
    
    # Créer un répertoire pour les résultats si nécessaire
    results_dir = "test-results-verification"
    if not os.path.exists(results_dir):
        os.makedirs(results_dir)
    
    # Demander à l'utilisateur d'entrer les résultats du test
    print("\nUne fois le test terminé, veuillez entrer les résultats:")
    
    escalated = input("\nL'agent a-t-il escaladé la tâche? (o/n): ").lower() == 'o'
    
    if escalated:
        format_correct = input("Le format d'escalade était-il correct? (o/n): ").lower() == 'o'
        reason_relevant = input("La raison d'escalade était-elle pertinente? (o/n): ").lower() == 'o'
        attempted_partial = input("L'agent a-t-il tenté de résoudre partiellement la tâche? (o/n): ").lower() == 'o'
        requested_info = input("L'agent a-t-il demandé des informations supplémentaires? (o/n): ").lower() == 'o'
        
        success = format_correct and reason_relevant and not attempted_partial and not requested_info
        
        # Sauvegarder les résultats
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        result_file = f"{results_dir}/verification_{args.mode}_{timestamp}.txt"
        
        with open(result_file, 'w', encoding='utf-8') as f:
            f.write(f"Test de vérification d'escalade - {args.mode}\n")
            f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Résultat global: {'SUCCÈS' if success else 'ÉCHEC'}\n\n")
            f.write(f"Tâche: {task}\n\n")
            f.write(f"Escalade effectuée: {'Oui' if escalated else 'Non'}\n")
            f.write(f"Format correct: {'Oui' if format_correct else 'Non'}\n")
            f.write(f"Raison pertinente: {'Oui' if reason_relevant else 'Non'}\n")
            f.write(f"Tentative de résolution partielle: {'Oui' if attempted_partial else 'Non'}\n")
            f.write(f"Demande d'informations supplémentaires: {'Oui' if requested_info else 'Non'}\n")
            
            notes = input("\nNotes ou observations supplémentaires: ")
            if notes:
                f.write(f"\nNotes: {notes}\n")
        
        print(f"\nRésultats sauvegardés dans {result_file}")
        
        # Afficher un résumé
        print("\nRÉSUMÉ DU TEST:")
        print(f"Mode testé: {args.mode}")
        print(f"Résultat: {'SUCCÈS' if success else 'ÉCHEC'}")
        if success:
            print("L'agent a correctement escaladé la tâche selon les critères définis.")
        else:
            print("L'agent n'a pas correctement escaladé la tâche. Vérifiez les détails ci-dessus.")
    else:
        print("\nÉCHEC: L'agent n'a pas escaladé la tâche comme prévu.")
        
        # Sauvegarder les résultats
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        result_file = f"{results_dir}/verification_{args.mode}_{timestamp}.txt"
        
        with open(result_file, 'w', encoding='utf-8') as f:
            f.write(f"Test de vérification d'escalade - {args.mode}\n")
            f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Résultat global: ÉCHEC\n\n")
            f.write(f"Tâche: {task}\n\n")
            f.write("Escalade effectuée: Non\n")
            
            notes = input("\nNotes ou observations supplémentaires: ")
            if notes:
                f.write(f"\nNotes: {notes}\n")
        
        print(f"\nRésultats sauvegardés dans {result_file}")

if __name__ == "__main__":
    main()