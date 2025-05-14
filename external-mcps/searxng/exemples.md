# Exemples d'utilisation du serveur MCP SearXNG

Ce document présente des exemples concrets d'utilisation du serveur MCP SearXNG avec Roo, montrant comment effectuer des recherches web et accéder au contenu des pages.

## Recherche web simple

Pour effectuer une recherche web simple, vous pouvez utiliser l'outil `searxng_web_search` avec un paramètre de requête de base :

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "intelligence artificielle actualités"
}
</arguments>
</use_mcp_tool>
```

Cette commande effectuera une recherche sur le terme "intelligence artificielle actualités" et renverra les résultats les plus pertinents.

## Recherche avec filtres

Vous pouvez affiner votre recherche en utilisant des filtres supplémentaires :

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "développement durable entreprises",
  "pageno": 1,
  "time_range": "month",
  "language": "fr",
  "safesearch": "0"
}
</arguments>
</use_mcp_tool>
```

Cette commande recherchera des informations sur le "développement durable entreprises" avec les filtres suivants :
- Page 1 des résultats
- Contenu publié au cours du dernier mois
- Résultats en français
- SafeSearch désactivé

## Lecture du contenu d'une URL

Une fois que vous avez trouvé une URL intéressante dans les résultats de recherche, vous pouvez utiliser l'outil `web_url_read` pour lire son contenu :

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>web_url_read</tool_name>
<arguments>
{
  "url": "https://example.com/article-interessant"
}
</arguments>
</use_mcp_tool>
```

Cette commande récupérera le contenu de la page à l'URL spécifiée et le renverra sous forme de texte.

## Recherche technique avec opérateurs

Vous pouvez utiliser des opérateurs de recherche avancés dans vos requêtes :

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "site:github.com python machine learning"
}
</arguments>
</use_mcp_tool>
```

Cette commande recherchera "python machine learning" uniquement sur le site github.com.

## Recherche d'actualités récentes

Pour obtenir les actualités les plus récentes sur un sujet :

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "nouvelles technologies",
  "time_range": "day"
}
</arguments>
</use_mcp_tool>
```

Cette commande recherchera des informations sur les "nouvelles technologies" publiées au cours des dernières 24 heures.

## Workflow complet : recherche et analyse

Voici un exemple de workflow complet combinant recherche et analyse de contenu :

1. Effectuer une recherche sur un sujet :

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "impact intelligence artificielle société",
  "language": "fr",
  "time_range": "year"
}
</arguments>
</use_mcp_tool>
```

2. Lire le contenu d'un des résultats :

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>web_url_read</tool_name>
<arguments>
{
  "url": "https://example.com/article-sur-ia"
}
</arguments>
</use_mcp_tool>
```

3. Effectuer une recherche complémentaire basée sur les informations trouvées :

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "régulation intelligence artificielle Europe",
  "language": "fr"
}
</arguments>
</use_mcp_tool>
```

## Bonnes pratiques

1. **Soyez spécifique** dans vos requêtes pour obtenir des résultats plus pertinents
2. **Utilisez les filtres** (langue, période) pour affiner les résultats
3. **Respectez les limites** des instances SearXNG en évitant les requêtes excessives
4. **Variez les instances** si vous rencontrez des limitations
5. **Combinez les recherches** avec d'autres outils pour une analyse complète

## Résolution des problèmes courants

### Résultats non pertinents

Si les résultats ne sont pas pertinents, essayez :
- D'ajouter plus de mots-clés spécifiques
- D'utiliser des guillemets pour les expressions exactes : `"expression exacte"`
- D'utiliser des opérateurs comme `site:`, `intitle:`, etc.

### Pas de résultats

Si vous ne recevez aucun résultat :
- Vérifiez que l'instance SearXNG est accessible
- Simplifiez votre requête
- Essayez une autre instance SearXNG
- Vérifiez votre connexion Internet

### Erreurs de lecture d'URL

Si la lecture d'URL échoue :
- Vérifiez que l'URL est accessible dans un navigateur
- Certains sites peuvent bloquer les requêtes automatisées
- Essayez une autre URL du même sujet