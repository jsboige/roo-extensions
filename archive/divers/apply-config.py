#!/usr/bin/env python3
"""
Script pour appliquer une configuration de modèles aux modes Roo.
Ce script modifie le fichier .roomodes pour changer les modèles utilisés par les différents modes.
"""

import os
import json
import argparse
import shutil
from datetime import datetime


def load_roomodes(file_path: str) -> dict:
    """Charge le fichier .roomodes"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def load_config(file_path: str) -> dict:
    """Charge le fichier de configuration des modèles"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def backup_file(file_path: str) -> str:
    """Crée une sauvegarde du fichier"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = f"{file_path}.backup_{timestamp}"
    shutil.copy2(file_path, backup_path)
    print(f"Sauvegarde créée: {backup_path}")
    return backup_path


def apply_config(roomodes_data: dict, config_data: dict, config_name: str) -> dict:
    """Applique la configuration spécifiée au fichier .roomodes"""
    # Trouver la configuration par son nom
    selected_config = None
    for config in config_data["configurations"]:
        if config["name"] == config_name:
            selected_config = config
            break
    
    if not selected_config:
        raise ValueError(f"Configuration '{config_name}' non trouvée")
    
    # Appliquer les modèles de la configuration aux modes correspondants
    for mode in roomodes_data["customModes"]:
        slug = mode["slug"]
        if slug in selected_config["modes"]:
            old_model = mode["model"]
            new_model = selected_config["modes"][slug]
            mode["model"] = new_model
            print(f"Mode {slug}: {old_model} -> {new_model}")
    
    return roomodes_data


def save_roomodes(file_path: str, data: dict):
    """Sauvegarde les données dans le fichier .roomodes"""
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
    print(f"Fichier {file_path} mis à jour")


def list_configs(config_data: dict):
    """Affiche la liste des configurations disponibles"""
    print("\nConfigurations disponibles:")
    for i, config in enumerate(config_data["configurations"], 1):
        print(f"{i}. {config['name']}")
        print(f"   {config['description']}")
        print()


def main():
    parser = argparse.ArgumentParser(description="Appliquer une configuration de modèles aux modes Roo")
    parser.add_argument("--roomodes", default=".roomodes", help="Chemin vers le fichier .roomodes")
    parser.add_argument("--config", default="model-configs.json", help="Chemin vers le fichier de configuration des modèles")
    parser.add_argument("--list", action="store_true", help="Lister les configurations disponibles")
    parser.add_argument("--apply", help="Nom de la configuration à appliquer")
    parser.add_argument("--no-backup", action="store_true", help="Ne pas créer de sauvegarde du fichier .roomodes")
    args = parser.parse_args()
    
    # Vérifier que les fichiers existent
    if not os.path.exists(args.roomodes):
        print(f"Erreur: Le fichier {args.roomodes} n'existe pas")
        return
    
    if not os.path.exists(args.config):
        print(f"Erreur: Le fichier {args.config} n'existe pas")
        return
    
    # Charger les fichiers
    config_data = load_config(args.config)
    
    # Lister les configurations
    if args.list:
        list_configs(config_data)
        return
    
    # Appliquer une configuration
    if args.apply:
        roomodes_data = load_roomodes(args.roomodes)
        
        # Créer une sauvegarde
        if not args.no_backup:
            backup_file(args.roomodes)
        
        # Appliquer la configuration
        try:
            updated_data = apply_config(roomodes_data, config_data, args.apply)
            save_roomodes(args.roomodes, updated_data)
            print(f"\nConfiguration '{args.apply}' appliquée avec succès")
            print("Redémarrez Roo pour appliquer les changements")
        except ValueError as e:
            print(f"Erreur: {e}")
            return
    else:
        parser.print_help()


if __name__ == "__main__":
    main()