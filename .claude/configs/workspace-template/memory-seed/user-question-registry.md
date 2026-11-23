# Registre des questions user — {{WORKSPACE}}

Questions **agent → user** uniquement ; quand le user engage la conversation, on répond
dans le fil. Une entrée ne sort des ouvertes QUE sur réponse user — jamais auto-expirée,
jamais retirée silencieusement. Représenté en bloc à chaque fin de session ; re-posée au
cycle suivant tant que sans réponse (via `MEMORY.md`, jamais re-postée dans le fil).

## Format d'une entrée — 5 champs, phrases simples, jamais un mot plus fort que ce qui a été mesuré

1. **Ce qui se passe** :
2. **Ce qui est demandé du user** (oui/non, ou un choix a/b/c) :
3. **Ce qui arrive sans réponse** :
4. **Ce que la lane recommande** :
5. **Échéance** (s'il y en a une) :

Champ obligatoire par entrée : **comment vérifier qu'elle est morte** — sans critère de
mort, une question répondue se re-pose indéfiniment.

## Ouvertes

_(aucune)_

## Répondues

_(aucune — une entrée répondue déménage ici, elle ne se supprime pas)_
