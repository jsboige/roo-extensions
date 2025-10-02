# Rapport d'investigation : Bug du message "avalé" lors d'un envoi concurrent

## 1. Contexte

Depuis une mise à jour en mai 2025, les utilisateurs peuvent saisir du texte pendant l'exécution d'un outil. Cependant, cela a introduit un bug où un message utilisateur peut être "avalé" (disparaître de l'input) s'il est envoyé juste au moment où une réponse d'outil arrive. Ce rapport détaille la cause de ce problème et évalue l'efficacité des mécanismes de mitigation actuels.

## 2. Identification du changement

L'analyse du fichier `CHANGELOG.md` a permis d'identifier une entrée de version qui correspond au comportement observé.

- **Version** : `[3.19.0] - 2025-05-29`
- **Ligne de code pertinente** : 
  ```
  - Fix: chat input clearing during running tasks (thanks @xyOz-dev!)
  ```

Bien que formulée comme un "fix", cette modification (ou une modification associée) a vraisemblablement altéré la gestion de l'état de l'input, permettant la saisie concurrente et introduisant par inadvertance cette race condition.

## 3. Analyse de la Race Condition

Le bug est une **race condition classique** dont la cause se situe dans la gestion de l'état du composant `ChatView.tsx`. Voici le déroulement détaillé :

1.  **Saisie utilisateur** : L'utilisateur tape un message. L'état de l'interface est `sendingDisabled: false`. Le texte est stocké dans l'état `inputValue` du hook `useAutosaveDraft`.

2.  **Arrivée d'un message concurrent** : Un message de l'extension (ex: une réponse d'outil, le début d'une nouvelle tâche) arrive. Cet événement déclenche une mise à jour de l'état `messages` dans `ChatView.tsx`.

3.  **Mise à jour de l'état interne** : Le `useEffect` qui observe les `messages` s'exécute. Il détecte que l'application est maintenant en cours de traitement et met l'état `sendingDisabled` à `true`. À ce stade, l'interface utilisateur n'a pas encore été re-rendue pour refléter ce changement (par exemple, en désactivant le bouton "Send").

4.  **Envoi par l'utilisateur** : L'utilisateur clique sur le bouton "Send" alors qu'il est encore visiblement actif. La fonction `handleSendMessage` est appelée.

5.  **Exécution de la logique erronée** :
    - `handleSendMessage` lit la valeur la plus récente de `sendingDisabled`, qui est maintenant `true`.
    - La condition `if (sendingDisabled)` est donc satisfaite.
    - Le code à l'intérieur de cette condition s'exécute, ce qui entraîne deux actions :
        1. Le message est placé dans une file d'attente (`queueMessage`).
        2. La fonction `clearDraft()` est appelée, **ce qui vide immédiatement le contenu de l'input**.

Le message disparaît parce que l'état local de l'input est effacé avant que l'utilisateur ne reçoive une confirmation visuelle que son message a bien été pris en compte.

## 4. Évaluation de la fonctionnalité "Autosave Draft"

La fonctionnalité `useAutosaveDraft` a été analysée pour déterminer si elle corrige ce problème.

- **Fonctionnement** : Le hook sauvegarde le contenu de l'input dans le `localStorage` après un `debounce` de 300ms. Cela signifie que la sauvegarde n'est pas instantanée.

- **Conclusion** : L'autosave **ne résout pas la cause racine du bug**, mais agit comme un **filet de sécurité partiel**.
    - **Cas où ça fonctionne** : Si l'utilisateur attend plus de 300ms après avoir tapé, le brouillon est sauvegardé. Même si l'input est effacé, le texte peut être restauré plus tard.
    - **Cas où ça échoue** : Si l'utilisateur tape rapidement et envoie son message en moins de 300ms, le `debounce` n'a pas eu le temps de s'exécuter. La race condition efface l'input, et comme le brouillon n'a pas été sauvegardé, **le message est définitivement perdu**.

## 5. Recommandation

La fonctionnalité "autosave draft" est insuffisante pour corriger entièrement ce bug de concurrence.

**Il est recommandé d'implémenter une correction plus robuste** qui s'attaque directement à la race condition. Plusieurs approches sont possibles :

1.  **Synchronisation de l'état et de l'UI** : S'assurer que l'interface utilisateur (le bouton "Send" et l'input) est désactivée de manière synchrone avec la mise à jour de l'état `sendingDisabled`.
2.  **Gestion optimiste de l'envoi** : Plutôt que de mettre en file d'attente et d'effacer, la fonction `handleSendMessage` pourrait ajouter le message à l'UI avec un état "en attente", même si `sendingDisabled` est `true`, et le traiter lorsque l'application redevient disponible.
3.  **Verrouillage de l'état** : Mettre en place un mécanisme de verrou (lock) pour empêcher `handleSendMessage` de vider l'input si un message est sur le point d'être envoyé dans ce court intervalle de temps.

L'approche 1 est la plus simple et la plus directe pour garantir une expérience utilisateur cohérente.