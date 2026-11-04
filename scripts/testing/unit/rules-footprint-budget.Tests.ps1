# Budget d'octets du harnais auto-chargé — campagne d'amincissement #2368
#
# Invariant testé : la surface payée à CHAQUE conversation (les règles auto-chargées
# `.claude/rules/*.md` + la source du harnais global `.claude/configs/user-global-claude.md`)
# tient sous un plafond d'octets. Chaque lot de #2368 ABAISSE ces plafonds dans la même
# PR que son amincissement ; les relever exige une justification explicite — un plafond
# qui monte signifie que le harnais a grossi, ce que la campagne cherche précisément
# à empêcher (décision ai-01 04/11 12:50Z, porteur po-2025, vérificateur po-2028).
#
# Les octets sont comptés en LF-normalisé (CRLF -> LF) : le test est agnostique au
# line-ending du checkout (autocrlf local vs checkout LF en CI) et ne mesure que le
# contenu. Le snapshot humain vit dans docs/harness/reference/rules-footprint.md
# (régénéré par scripts/audit-rules-footprint.ps1, octets bruts).
#
# Relevés de plafonds (normalisés) :
#   2026-11-04, lot 1 (#2368) : global 27174 -> 25915 ; règles 22 fichiers / 61879 (intactes)
#
# Syntaxe Pester v5 — exécuté en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Fonctionne sur pwsh Windows ET Linux.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/rules-footprint-budget.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path

    function Get-NormalizedByteCount {
        param([string]$Path)
        $raw = [System.IO.File]::ReadAllBytes($Path)
        $text = [System.Text.Encoding]::UTF8.GetString($raw)
        # Retire un éventuel BOM (sinon il compterait 3 octets selon le checkout)
        $text = $text.TrimStart([char]0xFEFF)
        # Normalise CRLF -> LF : le plafond mesure le contenu, pas la configuration git
        $text = $text.Replace("`r`n", "`n")
        return [System.Text.Encoding]::UTF8.GetByteCount($text)
    }
}

Describe "Rules footprint budget (#2368)" {

    It "user-global-claude.md <= 25915 octets normalises (plafond pose au lot 1)" {
        $bytes = Get-NormalizedByteCount -Path (Join-Path $projectRoot ".claude/configs/user-global-claude.md")
        $bytes | Should -BeLessOrEqual 25915
    }

    It "rules dir <= 61879 octets normalises (baseline du 04/11, intacte au lot 1)" {
        $rulesDir = Join-Path $projectRoot ".claude/rules"
        $rules = Get-ChildItem -Path $rulesDir -Filter *.md -File
        $total = ($rules | ForEach-Object { Get-NormalizedByteCount -Path $_.FullName } | Measure-Object -Sum).Sum
        $total | Should -BeLessOrEqual 61879
    }

    It "rules dir compte 22 fichiers (chaque fichier auto-charge paie son contexte)" {
        $rulesDir = Join-Path $projectRoot ".claude/rules"
        (Get-ChildItem -Path $rulesDir -Filter *.md -File).Count | Should -Be 22
    }
}
