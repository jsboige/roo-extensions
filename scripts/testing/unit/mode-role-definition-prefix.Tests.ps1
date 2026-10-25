# Garde : roleDefinition commune a tous les modes generes (#4334)
#
# PROPRIETE GARDEE
# ----------------
# Zoo/Roo place le `roleDefinition` d'un mode en PREMIER element du prompt
# systeme (zoo-code/src/core/prompts/system.ts). Tout texte propre a un mode
# place ici fait diverger le prefixe des le premier mode, et le prefix-cache
# (blocs KV vLLM, prompt-cache Anthropic facture 0.1x, cache automatique
# OpenAI >= 1024 tokens) ne peut plus servir un mode depuis les blocs d'un
# autre : le socle commun (outils, regles, instructions globales) est
# re-prefixe pour chaque mode.
#
# L'identite d'un mode vit donc dans `customInstructions`, rendu en FIN de
# prompt systeme par addCustomInstructions -- la ou une divergence ne coute
# rien. Ce test echoue si quelqu'un reintroduit du texte specifique dans
# `roleDefinition`, ou si le generateur cesse de deployer l'identite dans les
# instructions de mode (perte de comportement).
#
# Assertions STATIQUES sur fichiers JSON (aucune execution de node) : le job
# CI `unit-pester` tourne sur ubuntu-latest, dans la lignee de
# generate-modes-deploy-global.Tests.ps1.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/mode-role-definition-prefix.Tests.ps1 -Output Detailed"

BeforeDiscovery {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:Targets = @(
        @{
            Name       = "simple-complex"
            ConfigPath = Join-Path $projectRoot "roo-config/modes/modes-config.json"
            ModesPath  = Join-Path $projectRoot "roo-config/modes/generated/simple-complex.roomodes"
        }
    )
}

Describe "roleDefinition commune aux modes generes (#4334) <Name>" -ForEach $script:Targets {

    BeforeAll {
        $config = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $generated = Get-Content -Path $ModesPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:fleetRole = [string]$config.fleetRoleDefinition
        $script:modes = @($generated.customModes)
    }

    It "modes-config.json declare une fleetRoleDefinition non vide" {
        Test-Path $ConfigPath | Should -Be $true
        $fleetRole.Trim().Length | Should -BeGreaterThan 200
    }

    It "genere au moins deux modes (sinon le prefixe partage n'a pas d'objet)" {
        $modes.Count | Should -BeGreaterThan 1
    }

    It "chaque mode porte EXACTEMENT la fleetRoleDefinition" {
        foreach ($m in $modes) {
            $m.roleDefinition | Should -Be $fleetRole
        }
    }

    It "la fleetRoleDefinition ne cite AUCUN slug de mode (elle doit rester agnostique)" {
        foreach ($m in $modes) {
            $fleetRole.ToLower().Contains($m.slug.ToLower()) | Should -Be $false -Because "le slug '$($m.slug)' dans le prefixe partage recree la divergence que #4334 supprime"
        }
    }

    It "l'identite du mode est preservee, deplacee en tete de customInstructions" {
        foreach ($m in $modes) {
            $head = ([string]$m.customInstructions).Substring(0, [Math]::Min(200, ([string]$m.customInstructions).Length))
            $head.ToLower().Contains($m.slug.ToLower()) | Should -Be $true -Because "le texte identitaire de '$($m.slug)' doit survivre au deplacement (aucune suppression sans preuve de preservation)"
        }
    }

    It "l'identite source de modes-config.json n'est pas perdue (roleDefinition par famille/niveau)" {
        $familyNames = @($config.families.PSObject.Properties.Name)
        $levelNames = @($config.levels | ForEach-Object { $_.name })
        foreach ($fam in $familyNames) {
            foreach ($lvl in $levelNames) {
                $identity = [string]$config.families.$fam.$lvl.roleDefinition
                $identity.Trim().Length | Should -BeGreaterThan 0 -Because "$fam-$lvl doit garder son identite en source"
                ($modes | Where-Object { $_.slug -eq ($fam + '-' + $lvl) }) | Should -Not -BeNullOrEmpty
            }
        }
    }
}
