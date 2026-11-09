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
# Releves de plafonds (normalises) :
#   2026-11-04, lot 1 (#2368) : global 27174 -> 25915 ; regles 22 fichiers / 61879 (intactes)
#   2026-11-04, lot 1 update-branch : plafond global releve 25915 -> 26117. Justification :
#     base fusionnee, pas base de coupe — #4543 a ajoute ~202 o de pointeurs Q20 dans le meme
#     fichier APRES la coupe (verifie par po-2028, c.6633632807). La coupe elle-meme reste
#     27174 -> 25915 ; relever le plafond ici evite que le test rougisse sur le commit de merge.
#   2026-11-04, lot 2 (#2368) : agent-claim-discipline 6860 -> 6305 (deduplication — identite/depot
#     deja relocalises verbatim en claudish#445, la rule ne garde que les lignes dures ; nouveau
#     deport du recit #4221 dans la doc detaillee) ; regles 61879 -> 61324, 22 fichiers.
#   2026-11-09, volet 2 (#2368, PR #4619) : les deux sommaires projet de `harnais-tightening` et
#     `degraded-escalation` sont SUPPRIMES (double chargement : le canon `.claude/configs/rules/`
#     est deploye dans `~/.claude/rules/` et se chargeait EN PLUS de la copie projet). Plafonds
#     ABAISSES d'autant : regles 61324 -> 57734, 22 -> 20 fichiers ; global 26117 -> 26103 (le lien
#     vers le canon raccourcit, `rules/harnais-tightening.md` resout aussi dans la copie deployee).
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

    It "user-global-claude.md <= 26103 octets normalises (volet 2 : lien vers le canon raccourci)" {
        $bytes = Get-NormalizedByteCount -Path (Join-Path $projectRoot ".claude/configs/user-global-claude.md")
        $bytes | Should -BeLessOrEqual 26103
    }

    It "rules dir <= 57734 octets normalises (volet 2 : deux sommaires projet de 3590 o supprimes)" {
        $rulesDir = Join-Path $projectRoot ".claude/rules"
        $rules = Get-ChildItem -Path $rulesDir -Filter *.md -File
        $total = ($rules | ForEach-Object { Get-NormalizedByteCount -Path $_.FullName } | Measure-Object -Sum).Sum
        $total | Should -BeLessOrEqual 57734
    }

    It "rules dir compte 20 fichiers (chaque fichier auto-charge paie son contexte ; volet 2 : 22 -> 20)" {
        $rulesDir = Join-Path $projectRoot ".claude/rules"
        (Get-ChildItem -Path $rulesDir -Filter *.md -File).Count | Should -Be 20
    }
}
