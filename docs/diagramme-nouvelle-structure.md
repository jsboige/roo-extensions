# Diagramme de la nouvelle structure du dépôt

Ce document présente un diagramme visuel de la nouvelle structure proposée pour le dépôt Roo Extensions.

## Structure générale

```mermaid
graph TD
    Root[roo-extensions] --> Docs[docs/]
    Root --> Modules[modules/]
    Root --> MCPs[mcps/]
    Root --> RooCode[roo-code/]
    Root --> RooConfig[roo-config/]
    Root --> RooModes[roo-modes/]
    Root --> Scripts[scripts/]
    Root --> Tests[tests/]
    Root --> Archive[archive/]
    
    %% Documentation
    Docs --> DocsArch[architecture/]
    Docs --> DocsGuides[guides/]
    Docs --> DocsRapports[rapports/]
    Docs --> DocsTests[tests/]
    
    %% Modules
    Modules --> ModFormValidator[form-validator/]
    
    %% MCPs
    MCPs --> MCPsInternal[internal/]
    MCPs --> MCPsExternal[external/]
    MCPs --> MCPsMonitoring[monitoring/]
    MCPs --> MCPsScripts[scripts/]
    
    %% MCPs Internal
    MCPsInternal --> MCPQuickfiles[quickfiles/]
    MCPsInternal --> MCPJinavigator[jinavigator/]
    MCPsInternal --> MCPJupyter[jupyter/]
    
    %% MCPs External
    MCPsExternal --> MCPSearxng[searxng/]
    MCPsExternal --> MCPWinCLI[win-cli/]
    MCPsExternal --> MCPFilesystem[filesystem/]
    MCPsExternal --> MCPGit[git/]
    MCPsExternal --> MCPGitHub[github/]
    
    %% Roo Code
    RooCode --> RooCodeAssets[assets/]
    RooCode --> RooCodeDocs[docs/]
    RooCode --> RooCodeSrc[src/]
    
    %% Roo Config
    RooConfig --> RooConfigBackups[backups/]
    RooConfig --> RooConfigTemplates[config-templates/]
    RooConfig --> RooConfigDiagnostic[diagnostic-scripts/]
    RooConfig --> RooConfigModes[modes/]
    RooConfig --> RooConfigQwen[qwen3-profiles/]
    RooConfig --> RooConfigScheduler[scheduler/]
    RooConfig --> RooConfigSettings[settings/]
    
    %% Roo Modes
    RooModes --> RooModesDocs[docs/]
    RooModes --> RooModesExamples[examples/]
    RooModes --> RooModesN5[n5/]
    RooModes --> RooModesOptimized[optimized/]
    
    %% Scripts
    Scripts --> ScriptsDeployment[deployment/]
    Scripts --> ScriptsMaintenance[maintenance/]
    Scripts --> ScriptsMigration[migration/]
    
    %% Tests
    Tests --> TestsData[data/]
    Tests --> TestsEscalation[escalation/]
    Tests --> TestsMCP[mcp/]
    Tests --> TestsResults[results/]
    Tests --> TestsScripts[scripts/]
    
    %% Archive
    Archive --> ArchiveLegacy[legacy/]
```

## Détail du module form-validator

```mermaid
graph TD
    FormValidator[modules/form-validator/] --> FormValidatorClient[form-validator-client.js]
    FormValidator --> FormValidatorReadme[README.md]
    FormValidator --> FormValidatorHTML[form-validator.html]
    FormValidator --> FormValidatorJS[form-validator.js]
    FormValidator --> FormValidatorTests[tests/]
    FormValidatorTests --> FormValidatorTest[form-validator-test.js]
```

## Détail des scripts

```mermaid
graph TD
    Scripts[scripts/] --> Deployment[deployment/]
    Scripts --> Maintenance[maintenance/]
    Scripts --> Migration[migration/]
    
    Maintenance --> UpdateModePrompts[update-mode-prompts.ps1]
    Maintenance --> UpdateModePromptsV2[update-mode-prompts-v2.ps1]
    Maintenance --> UpdateModePromptsFixed[update-mode-prompts-fixed.ps1]
    Maintenance --> UpdateScriptPaths[update-script-paths.ps1]
    Maintenance --> OrganizeRepo[organize-repo.ps1]
    
    Migration --> MigrateToProfiles[migrate-to-profiles.ps1]
```

## Détail des tests

```mermaid
graph TD
    Tests[tests/] --> Data[data/]
    Tests --> Escalation[escalation/]
    Tests --> MCP[mcp/]
    Tests --> Results[results/]
    Tests --> Scripts[scripts/]
    
    Results --> ResultsGeneral[general/]
    Results --> ResultsN5[n5/]
```

## Comparaison avant/après pour les MCPs

```mermaid
graph TD
    subgraph "Avant"
    MCPsOld[mcps/] --> MCPServers[mcp-servers/]
    MCPsOld --> ExternalMCPs[external-mcps/]
    end
    
    subgraph "Après"
    MCPsNew[mcps/] --> Internal[internal/]
    MCPsNew --> External[external/]
    MCPsNew --> Monitoring[monitoring/]
    MCPsNew --> MCPScripts[scripts/]
    end
```

## Comparaison avant/après pour les tests

```mermaid
graph TD
    subgraph "Avant"
    TestsOld[tests/]
    TestDataOld[test-data/]
    TestResultsOld[test-results/]
    RooModesTestResults[roo-modes/n5/test-results/]
    end
    
    subgraph "Après"
    TestsNew[tests/] --> DataNew[data/]
    TestsNew --> ResultsNew[results/]
    TestsNew --> EscalationNew[escalation/]
    TestsNew --> MCPNew[mcp/]
    TestsNew --> ScriptsNew[scripts/]
    ResultsNew --> N5Results[n5/]
    end
```

Ces diagrammes illustrent la nouvelle structure proposée pour le dépôt Roo Extensions, mettant en évidence l'organisation plus cohérente et intuitive des fichiers et répertoires.