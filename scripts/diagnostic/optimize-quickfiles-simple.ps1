# Audit QuickFiles simple et autonome

param(
    [switch]$AuditOnly = $false,
    [string]$OutputPath = ".\docs\diagnostics\QUICKFILES-AUDIT-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
)

# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "DEBUT AUDIT QUICKFILES" -ForegroundColor Cyan

if ($AuditOnly) {
    Write-Host "MODE AUDIT SEULEMENT" -ForegroundColor Green
    
    # Test 1: Verification du serveur QuickFiles
    $QuickFilesPath = ".\mcps\internal\servers\quickfiles-server"
    $ServerExists = Test-Path $QuickFilesPath
    Write-Host "Serveur QuickFiles: $(if ($ServerExists) { 'TROUVE' } else { 'NON TROUVE' })" -ForegroundColor $(if ($ServerExists) { 'Green' } else { 'Red' })
    
    # Test 2: Verification des fichiers de test
    $TestFiles = Get-ChildItem -Path ".\mcps\tests" -Filter "*quickfiles*" -Recurse -ErrorAction SilentlyContinue
    Write-Host "Fichiers de test: $($TestFiles.Count) trouves" -ForegroundColor White
    
    # Test 3: Verification de l'integration dans les modes
    $ModeFiles = Get-ChildItem -Path ".\roo-modes" -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    $IntegrationCount = 0
    foreach ($ModeFile in $ModeFiles) {
        try {
            $Content = Get-Content $ModeFile.FullName -Raw
            if ($Content -match "quickfiles" -or $Content -match "read_multiple_files") {
                $IntegrationCount++
            }
        } catch {
            # Ignorer les erreurs
        }
    }
    Write-Host "Integration modes: $IntegrationCount/$($ModeFiles.Count) modes" -ForegroundColor White
    
    # Test 4: Verification configuration MCP
    $McpConfigPath = ".\roo-config\mcp_settings.json"
    $McpConfigured = $false
    if (Test-Path $McpConfigPath) {
        try {
            $McpSettings = Get-Content $McpConfigPath -Raw | ConvertFrom-Json
            if ($McpSettings.PSObject.Properties.Name -contains "mcpServers") {
                foreach ($Server in $McpSettings.mcpServers.PSObject.Properties) {
                    if ($Server.Name -match "quickfiles" -or $Server.Value.command -match "quickfiles") {
                        $McpConfigured = $true
                        break
                    }
                }
            }
        } catch {
            # Ignorer les erreurs
        }
    }
    Write-Host "Configuration MCP: $(if ($McpConfigured) { 'CONFIGURE' } else { 'NON CONFIGURE' })" -ForegroundColor $(if ($McpConfigured) { 'Green' } else { 'Yellow' })
    
    # Calcul du score d'accessibilite
    $Score = 0
    if ($ServerExists) { $Score += 25 }
    if ($TestFiles.Count -gt 0) { $Score += 25 }
    if ($IntegrationCount -gt 0) { $Score += 25 }
    if ($McpConfigured) { $Score += 25 }
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "RESULTATS AUDIT QUICKFILES" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host "Score d'accessibilite: $Score/100" -ForegroundColor White
    Write-Host "Integration modes: $IntegrationCount modes" -ForegroundColor White
    Write-Host "Fichiers de test: $($TestFiles.Count)" -ForegroundColor White
    Write-Host "="*60 -ForegroundColor Cyan
    
    # Generation du rapport
    $Report = @"
# RAPPORT D'AUDIT QUICKFILES

**Genere le :** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Script :** optimize-quickfiles-simple.ps1

## RESULTATS

### Score d'Accessibilite
**$Score/100**

### Details des Tests
- **Serveur QuickFiles:** $(if ($ServerExists) { 'TROUVE' } else { 'NON TROUVE' })
- **Fichiers de test:** $($TestFiles.Count) trouves
- **Integration modes:** $IntegrationCount/$($ModeFiles.Count) modes
- **Configuration MCP:** $(if ($McpConfigured) { 'CONFIGURE' } else { 'NON CONFIGURE' })

### Recommandations
$(if ($Score -lt 80) { "- Ameliorer l'accessibilite (score < 80%)" } else { "- L'accessibilite est satisfaisante" })
$(if ($IntegrationCount -lt 2) { "- Augmenter l'integration dans les modes Roo" } else { "- L'integration dans les modes est correcte" })
$(if ($TestFiles.Count -lt 3) { "- Augmenter la couverture de test" } else { "- La couverture de test est adequate" })

---

*Rapport genere automatiquement*
"@
    
    # Creer le repertoire si necessaire
    $DirName = Split-Path $OutputPath -Parent
    if (-not (Test-Path $DirName)) {
        New-Item -ItemType Directory -Path $DirName -Force | Out-Null
    }
    
    $Report | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "Rapport genere: $OutputPath" -ForegroundColor Green
    
} else {
    Write-Host "Utilisez -AuditOnly pour l'audit uniquement" -ForegroundColor Yellow
}

Write-Host "AUDIT TERMINE" -ForegroundColor Green