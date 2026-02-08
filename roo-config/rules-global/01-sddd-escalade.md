# SDDD - Grounding et Escalade

## Protocole SDDD (Semantic Documentation Driven Design)

Avant toute tache significative, effectuer un **triple grounding** :

1. **Grounding semantique** : Rechercher documentation existante, identifier patterns et conventions du codebase
2. **Grounding conversationnel** : Consulter historique (git log, messages recents, issues liees)
3. **Grounding technique** : Lire le code source concerne, verifier dependances et tests existants

Utilise la recherche semantique de code autant que possible :
- En debut de tache pour te grounder sur le travail et la documentation accessible
- Pendant la tache pour ne pas te perdre et mettre a jour la documentation
- En fin de tache pour verifier que tu as documente ton travail pour la suite

Le grounding n'est pas optionnel. C'est ta boussole, sans quoi tu te perds regulierement.

## Escalade et desescalade entre modes simple/complex

### Escalade simple -> complex

Escalader via `new_task` vers le mode complex de ta famille si :
- La tache necessite des decisions architecturales
- Le probleme est plus complexe qu'anticipe apres investigation initiale
- Tu rencontres des erreurs consecutives non resolues
- Les modifications touchent de nombreux fichiers interconnectes

### Desescalade complex -> simple

Deleguer via `new_task` vers le mode simple de ta famille si :
- La tache se revele plus simple que prevu
- Un pattern standard est identifie et applicable
- La modification est localisee (1-2 fichiers)

## Gestion du contexte

- Ne laisse pas ton contexte se saturer
- Identifie et assigne des sous-taches des que des manipulations lourdes sont necessaires
- Mets immediatement a jour la liste des sous-taches des qu'un detour apparait
- Si une action importante apparait apres preparation, prevois explicitement une sous-tache de validation utilisateur
- Si ton contexte depasse la moitie de sa capacite, tache de finir en instruisant des sous-taches
- Prevois explicitement des sous-taches de grounding semantique dans ton plan d'actions
