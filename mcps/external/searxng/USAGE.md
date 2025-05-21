# Utilisation du MCP SearXNG

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille comment utiliser le MCP SearXNG avec Roo. Le MCP SearXNG permet à Roo d'effectuer des recherches web et d'accéder au contenu des pages directement depuis l'interface de conversation, offrant ainsi un accès rapide à l'information en ligne tout en respectant la vie privée des utilisateurs.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: available_tools -->
## Outils disponibles

Le MCP SearXNG expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `searxng_web_search` | Effectue une recherche web et renvoie les résultats |
| `web_url_read` | Lit le contenu d'une URL spécifique |
<!-- END_SECTION: available_tools -->

<!-- START_SECTION: basic_usage -->
## Utilisation de base

### Recherche web simple

Pour effectuer une recherche web simple:

```
Outil: searxng_web_search
Arguments:
{
  "query": "intelligence artificielle actualités"
}
```

Cette commande effectuera une recherche sur le terme "intelligence artificielle actualités" et renverra les résultats les plus pertinents.

### Lecture du contenu d'une URL

Une fois que vous avez trouvé une URL intéressante dans les résultats de recherche, vous pouvez lire son contenu:

```
Outil: web_url_read
Arguments:
{
  "url": "https://example.com/article-interessant"
}
```

Cette commande récupérera le contenu de la page à l'URL spécifiée et le renverra sous forme de texte.
<!-- END_SECTION: basic_usage -->

<!-- START_SECTION: advanced_search -->
## Recherche avancée

### Recherche avec filtres

Vous pouvez affiner votre recherche en utilisant des filtres supplémentaires:

```
Outil: searxng_web_search
Arguments:
{
  "query": "développement durable entreprises",
  "pageno": 1,
  "time_range": "month",
  "language": "fr",
  "safesearch": "0"
}
```

Cette commande recherchera des informations sur le "développement durable entreprises" avec les filtres suivants:
- Page 1 des résultats
- Contenu publié au cours du dernier mois
- Résultats en français
- SafeSearch désactivé

### Recherche technique avec opérateurs

Vous pouvez utiliser des opérateurs de recherche avancés dans vos requêtes:

```
Outil: searxng_web_search
Arguments:
{
  "query": "site:github.com python machine learning"
}
```

Cette commande recherchera "python machine learning" uniquement sur le site github.com.

### Recherche d'actualités récentes

Pour obtenir les actualités les plus récentes sur un sujet:

```
Outil: searxng_web_search
Arguments:
{
  "query": "nouvelles technologies",
  "time_range": "day"
}
```

Cette commande recherchera des informations sur les "nouvelles technologies" publiées au cours des dernières 24 heures.
<!-- END_SECTION: advanced_search -->

<!-- START_SECTION: search_parameters -->
## Paramètres de recherche

### Paramètres de l'outil searxng_web_search

| Paramètre | Description | Valeurs possibles | Par défaut |
|-----------|-------------|-------------------|------------|
| `query` | Termes de recherche | Chaîne de caractères | (Requis) |
| `pageno` | Numéro de page des résultats | Entier positif | `1` |
| `time_range` | Période de publication | `"day"`, `"week"`, `"month"`, `"year"` | `null` (aucune limite) |
| `language` | Langue des résultats | Code de langue ISO (`"fr"`, `"en"`, etc.) | `"all"` |
| `safesearch` | Niveau de filtrage du contenu | `"0"` (désactivé), `"1"` (modéré), `"2"` (strict) | `"0"` |
| `categories` | Catégories de moteurs de recherche | `"general"`, `"images"`, `"news"`, etc. | `"general"` |

### Paramètres de l'outil web_url_read

| Paramètre | Description | Valeurs possibles | Par défaut |
|-----------|-------------|-------------------|------------|
| `url` | URL de la page à lire | URL valide | (Requis) |
| `timeout` | Délai d'attente en millisecondes | Entier positif | `10000` |
<!-- END_SECTION: search_parameters -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

### Recherche et analyse d'informations

Voici un workflow complet pour rechercher et analyser des informations sur un sujet:

1. Effectuer une recherche initiale sur un sujet:

```
Outil: searxng_web_search
Arguments:
{
  "query": "impact intelligence artificielle société",
  "language": "fr",
  "time_range": "year"
}
```

2. Lire le contenu d'un des résultats pertinents:

```
Outil: web_url_read
Arguments:
{
  "url": "https://example.com/article-sur-ia"
}
```

3. Effectuer une recherche complémentaire basée sur les informations trouvées:

```
Outil: searxng_web_search
Arguments:
{
  "query": "régulation intelligence artificielle Europe",
  "language": "fr"
}
```

### Veille technologique

Pour effectuer une veille technologique régulière:

1. Rechercher les dernières actualités sur un sujet:

```
Outil: searxng_web_search
Arguments:
{
  "query": "innovations blockchain",
  "time_range": "week",
  "language": "fr"
}
```

2. Approfondir un sujet spécifique mentionné dans les actualités:

```
Outil: searxng_web_search
Arguments:
{
  "query": "blockchain énergie renouvelable",
  "language": "fr"
}
```

3. Lire les articles pertinents:

```
Outil: web_url_read
Arguments:
{
  "url": "https://example.com/article-blockchain-energie"
}
```

### Recherche académique

Pour effectuer une recherche académique:

1. Rechercher des articles scientifiques:

```
Outil: searxng_web_search
Arguments:
{
  "query": "site:arxiv.org quantum computing algorithms",
  "time_range": "year"
}
```

2. Lire les abstracts des articles:

```
Outil: web_url_read
Arguments:
{
  "url": "https://arxiv.org/abs/example"
}
```
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques

### Optimisation des requêtes

1. **Soyez spécifique** dans vos requêtes pour obtenir des résultats plus pertinents
   - Utilisez des termes précis et descriptifs
   - Incluez des mots-clés importants

2. **Utilisez les opérateurs de recherche** pour affiner vos résultats:
   - `site:example.com` pour limiter la recherche à un site spécifique
   - `"phrase exacte"` pour rechercher une expression exacte
   - `filetype:pdf` pour rechercher des fichiers d'un type spécifique
   - `intitle:mot` pour rechercher des pages avec un mot dans le titre

3. **Utilisez les filtres** pour cibler vos résultats:
   - Filtrez par langue pour obtenir des résultats dans votre langue préférée
   - Filtrez par période pour obtenir des informations récentes
   - Utilisez SafeSearch selon vos besoins

### Utilisation responsable

1. **Respectez les limites** des instances SearXNG:
   - Évitez les requêtes excessives ou répétitives
   - Espacez vos requêtes pour ne pas surcharger les instances

2. **Variez les instances** si vous effectuez de nombreuses recherches:
   - Configurez plusieurs instances dans votre configuration
   - Utilisez la rotation d'instances

3. **Respectez la vie privée**:
   - N'utilisez pas le MCP SearXNG pour collecter des informations personnelles
   - Soyez conscient que certains sites peuvent bloquer les requêtes automatisées
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes courants

### Résultats non pertinents

Si les résultats ne sont pas pertinents:
- Ajoutez plus de mots-clés spécifiques
- Utilisez des guillemets pour les expressions exactes: `"expression exacte"`
- Utilisez des opérateurs comme `site:`, `intitle:`, etc.

### Pas de résultats

Si vous ne recevez aucun résultat:
- Vérifiez que l'instance SearXNG est accessible
- Simplifiez votre requête
- Essayez une autre instance SearXNG
- Vérifiez votre connexion Internet

### Erreurs de lecture d'URL

Si la lecture d'URL échoue:
- Vérifiez que l'URL est accessible dans un navigateur
- Certains sites peuvent bloquer les requêtes automatisées
- Essayez une autre URL du même sujet

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

Le MCP SearXNG s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Recherche des informations sur l'intelligence artificielle"
- "Trouve des articles récents sur le changement climatique"
- "Cherche des tutoriels Python sur GitHub"
- "Lis le contenu de cette page web: https://example.com/article"
- "Trouve des articles scientifiques sur la fusion nucléaire publiés cette année"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP SearXNG.
<!-- END_SECTION: integration_with_roo -->

<!-- START_SECTION: privacy_considerations -->
## Considérations de confidentialité

Le MCP SearXNG est conçu pour respecter la vie privée des utilisateurs:

1. **Métamoteur de recherche privé**:
   - SearXNG ne stocke pas d'informations personnelles
   - Les requêtes ne sont pas partagées avec les moteurs de recherche tiers

2. **Instances publiques vs privées**:
   - Les instances publiques peuvent avoir différentes politiques de confidentialité
   - Pour une confidentialité maximale, envisagez d'héberger votre propre instance

3. **Limites de la confidentialité**:
   - Bien que SearXNG ne trace pas les utilisateurs, les sites web visités peuvent le faire
   - Soyez conscient que la lecture du contenu d'une URL peut révéler votre adresse IP au site web
<!-- END_SECTION: privacy_considerations -->