# 👁️ Découverte des capacités de vision de Claude

Ce guide vous présente comment utiliser les capacités de vision de Claude dans Roo, vous permettant d'interagir avec des images et d'obtenir des analyses pertinentes.

## Introduction aux capacités de vision

Claude, le modèle qui alimente Roo, possède des capacités multimodales qui lui permettent de "voir" et d'analyser des images. Cette fonctionnalité est particulièrement utile pour :

- Analyser des captures d'écran de code ou d'interfaces
- Comprendre des diagrammes techniques
- Interpréter des graphiques et des visualisations de données
- Examiner des maquettes ou des designs d'interface
- Analyser des erreurs visuelles dans des applications

## Comment utiliser la vision avec Roo

### 1. Soumettre une image

Pour utiliser les capacités de vision de Claude, vous devez soumettre une image à Roo de l'une des façons suivantes :

- **Glisser-déposer** une image directement dans la zone de conversation
- **Copier-coller** une image depuis votre presse-papiers
- **Utiliser le bouton d'upload** pour sélectionner une image depuis votre système de fichiers
- **Faire une capture d'écran** et la partager directement avec Roo

### 2. Poser une question sur l'image

Accompagnez votre image d'une question ou d'une instruction claire pour obtenir les meilleurs résultats :

✅ **Efficace** : "Que représente ce diagramme d'architecture ?"  
✅ **Efficace** : "Explique ce qui pourrait causer l'erreur visible sur cette capture d'écran."  
✅ **Efficace** : "Analyse cette maquette d'interface et suggère des améliorations d'UX."

❌ **Moins efficace** : "Que vois-tu ?" (trop vague)  
❌ **Moins efficace** : "Aide-moi avec cette image." (manque de direction)

### 3. Poser des questions de suivi

Vous pouvez approfondir l'analyse en posant des questions de suivi sur la même image :

- "Peux-tu me donner plus de détails sur la partie X de l'image ?"
- "Comment pourrais-je améliorer ce design ?"
- "Y a-t-il des problèmes potentiels dans ce code que tu peux identifier ?"

## Types d'analyses visuelles

### Analyse de code

Claude peut analyser des captures d'écran de code pour :
- Identifier des bugs ou des erreurs
- Suggérer des optimisations
- Expliquer la logique du code
- Proposer des refactorisations

### Analyse de diagrammes techniques

Claude peut interpréter :
- Diagrammes d'architecture
- Diagrammes UML
- Diagrammes entité-relation
- Organigrammes
- Diagrammes de flux de données

### Analyse d'interfaces utilisateur

Claude peut examiner des interfaces pour :
- Évaluer l'expérience utilisateur
- Identifier des problèmes d'accessibilité
- Suggérer des améliorations de design
- Analyser la cohérence visuelle

### Analyse de données visuelles

Claude peut interpréter :
- Graphiques et visualisations
- Tableaux de données
- Dashboards
- Rapports visuels

## Exemple pratique

Dans ce répertoire, vous trouverez :

1. Un [exemple d'image](./exemple-image.txt) que vous pouvez utiliser pour tester les capacités de vision
2. Un fichier d'[instructions d'analyse](./instructions-analyse.md) avec des exemples de questions à poser

## Bonnes pratiques

- **Utilisez des images claires et nettes** pour de meilleurs résultats
- **Cadrez bien le sujet principal** de votre image
- **Posez des questions spécifiques** plutôt que générales
- **Fournissez du contexte** lorsque nécessaire
- **Combinez texte et image** pour une communication plus efficace

## Limites actuelles

- Claude ne peut pas analyser de vidéos, seulement des images statiques
- La résolution et la qualité de l'image affectent la précision de l'analyse
- Certains détails très fins ou textes très petits peuvent être difficiles à interpréter
- Claude ne peut pas exécuter le code visible dans une image

## Prochaines étapes

Après avoir exploré les capacités de vision de base, vous pourriez être intéressé par :

- Utiliser la vision pour déboguer des problèmes complexes
- Combiner l'analyse d'images avec la génération de code
- Explorer les capacités de vision dans d'autres modes de Roo

---

N'hésitez pas à expérimenter avec vos propres images et à découvrir comment les capacités de vision de Claude peuvent améliorer votre flux de travail de développement !