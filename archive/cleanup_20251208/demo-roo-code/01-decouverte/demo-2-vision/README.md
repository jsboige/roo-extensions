# 👁️ Demo 2 - Vision avec Roo

## Objectif de la démo

Cette démo vous permet de découvrir les capacités de vision de Roo, qui lui permettent d'analyser des images et de répondre à des questions à leur sujet. Vous apprendrez comment soumettre des images à Roo et comment poser des questions efficaces pour obtenir des analyses pertinentes.

## Prérequis

- Avoir accès à Roo dans VSCode
- Disposer d'images à analyser (des exemples sont fournis dans le répertoire ressources)

## Instructions pas à pas

### 1. Préparation de l'environnement

1. Assurez-vous que le contenu du répertoire workspace est initialisé :
   ```
   ./prepare-workspaces.ps1   # Windows
   ./prepare-workspaces.sh    # Linux/Mac
   ```

2. Dans l'explorateur de fichiers VSCode, naviguez jusqu'au dossier `01-decouverte/demo-2-vision/workspace`

3. Ouvrez le panneau Roo en cliquant sur l'icône Roo dans la barre latérale

4. Sélectionnez le mode "Conversation" (💬 Ask)

### 2. Soumettre une image à Roo

Il existe plusieurs façons de soumettre une image à Roo :

- **Glisser-déposer** une image directement dans la zone de conversation
- **Copier-coller** une image depuis votre presse-papiers
- **Utiliser le bouton d'upload** pour sélectionner une image depuis votre système de fichiers
- **Faire une capture d'écran** et la partager directement avec Roo

Pour cette démo, vous pouvez utiliser les images fournies dans le répertoire `ressources`.

### 3. Poser des questions sur l'image

Accompagnez votre image d'une question ou d'une instruction claire pour obtenir les meilleurs résultats :

✅ **Efficace** : "Que représente ce diagramme d'architecture ?"  
✅ **Efficace** : "Explique ce qui pourrait causer l'erreur visible sur cette capture d'écran."  
✅ **Efficace** : "Analyse cette maquette d'interface et suggère des améliorations d'UX."

❌ **Moins efficace** : "Que vois-tu ?" (trop vague)  
❌ **Moins efficace** : "Aide-moi avec cette image." (manque de direction)

### 4. Explorer différents types d'analyses visuelles

Essayez ces différents types d'analyses avec les images appropriées :

#### Analyse de code
- Soumettez une capture d'écran de code et demandez : "Identifie les bugs potentiels dans ce code."
- Ou : "Comment pourrais-je optimiser ce code ?"

#### Analyse de diagrammes techniques
- Soumettez un diagramme d'architecture et demandez : "Explique ce que représente ce diagramme."
- Ou : "Quels sont les composants clés de cette architecture ?"

#### Analyse d'interfaces utilisateur
- Soumettez une capture d'écran d'interface et demandez : "Quels problèmes d'UX identifies-tu dans cette interface ?"
- Ou : "Comment pourrais-je améliorer cette interface utilisateur ?"

#### Analyse de données visuelles
- Soumettez un graphique ou un tableau et demandez : "Que montrent ces données ?"
- Ou : "Quelles conclusions peut-on tirer de ce graphique ?"

### 5. Poser des questions de suivi

Vous pouvez approfondir l'analyse en posant des questions de suivi sur la même image :

- "Peux-tu me donner plus de détails sur la partie X de l'image ?"
- "Comment pourrais-je améliorer ce design ?"
- "Y a-t-il des problèmes potentiels dans ce code que tu peux identifier ?"

## Exercice pratique

1. Choisissez une image du répertoire ressources ou utilisez votre propre image
2. Soumettez-la à Roo avec une question initiale
3. Posez au moins deux questions de suivi pour approfondir l'analyse
4. Notez vos observations sur la qualité et la pertinence des réponses

## Bonnes pratiques

- **Utilisez des images claires et nettes** pour de meilleurs résultats
- **Cadrez bien le sujet principal** de votre image
- **Posez des questions spécifiques** plutôt que générales
- **Fournissez du contexte** lorsque nécessaire
- **Combinez texte et image** pour une communication plus efficace

## Limites actuelles

- Roo ne peut pas analyser de vidéos, seulement des images statiques
- La résolution et la qualité de l'image affectent la précision de l'analyse
- Certains détails très fins ou textes très petits peuvent être difficiles à interpréter
- Roo ne peut pas exécuter le code visible dans une image

## Ressources supplémentaires

Dans le répertoire `ressources`, vous trouverez :
- Des exemples d'images à utiliser pour vos tests
- Un guide détaillé sur les capacités de vision de Roo
- Des exemples de questions efficaces pour différents types d'images

## Documentation pour les agents

Dans le répertoire `docs`, vous trouverez :
- Des explications détaillées sur le fonctionnement des capacités de vision
- Des conseils pour guider les utilisateurs dans leur découverte de cette fonctionnalité
- Des réponses aux questions fréquemment posées

## Prochaines étapes

Après avoir exploré cette démo, vous pouvez :
- Revenir à la [Demo 1 - Conversation avec Roo](../demo-1-conversation/README.md) pour approfondir vos connaissances sur les interactions textuelles
- Passer à la [Demo 3 - Organisation et productivité](../demo-3-organisation/README.md) pour des cas d'usage plus spécifiques
- Explorer la [Demo 4 - Questions techniques et conceptuelles](../demo-4-questions/README.md) pour des sujets plus complexes