# Rapport d'analyse des tests d'escalade

*Genere le 15/05/2025 a 23:31:24*

## Resume global

- **Nombre total de tests**: 5
- **Tests reussis**: 3 (60%)
- **Tests echoues**: 2
- **Temps moyen d'escalade**: 01:27

### Repartition des escalades

- **Escalades attendues**: 4
- **Escalades non attendues**: 
- **Escalades reelles**: 3
- **Absence d'escalade**: 2

### Types d'escalade

- **Escalades internes**: 
- **Escalades externes**: 2

## Statistiques par mode

| Mode | Tests | Reussis | Taux de reussite | Escalades attendues | Escalades reelles | Internes | Externes |
|------|-------|---------|------------------|---------------------|-------------------|----------|----------|
| architect-simple | 1 | 0 | 0% | 1 | 0 | 0 | 0 |
| ask-simple | 1 | 0 | 0% | 1 | 1 | 1 | 0 |
| code-simple | 1 | 1 | 100% | 1 | 1 | 0 | 1 |
| debug-simple | 1 | 1 | 100% | 1 | 1 | 0 | 1 |
| orchestrator-complex | 1 | 1 | 100% | 0 | 0 | 0 | 0 |

## Problemes identifies

Aucun probleme identifie dans les tests d'escalade.
## Liste complete des tests

| # | Test | De | Vers | Attendu | Reel | Type | Temps | Reussite |
|---|------|----|----|---------|------|------|-------|----------|
| 1 | Escalade Code Simple vers Complex | code-simple | code-complex | Oui | Oui | Externe | 00:01:23 | OK |
| 2 | Escalade Debug Simple vers Complex | debug-simple | debug-complex | Oui | Oui | Externe | 00:02:15 | OK |
| 3 | Escalade Architect Simple vers Complex | architect-simple | architect-complex | Oui | Non | N/A | N/A | NOK |
| 4 | Escalade Ask Simple vers Complex | ask-simple | ask-complex | Oui | Oui | Interne | 00:00:45 | NOK |
| 5 | Pas d'escalade Orchestrator Complex | orchestrator-complex |  | Non | Non | N/A | N/A | OK |
