<#
.SYNOPSIS
    Rotation des logs scheduling (outputs/scheduling/logs) — #3323 puis #3834.

.DESCRIPTION
    Applique la politique de retention de #3599/#3323 avec, depuis #3834, un mode
    ARCHIVE-PUIS-RETRAIT obligatoire avant toute suppression (decision user du
    13/09 : aucune purge, archivage GDrive ; reprise 24/09 « OK pour a) »).

    MODES :
    - Sans parametre d'action : REPORT-ONLY (aucune suppression, aucun fichier cree).
    - -ArchiveTo <dossier> sans -Execute : report + PREVIEW de l'archivage
      (destination, nom d'archive, 7z) — rien n'est ecrit.
    - -ArchiveTo <dossier> -Execute : les 4 ETAPES ci-dessous.
    - -Execute sans -ArchiveTo : REFUS (exit 2). La suppression nue est
      impossible par construction (decision user du 13/09, #3834).

    LES 4 ETAPES (modele : variante empaquetee des slices ai-01 et web1 du
    24/09, #3323) :
    1. INVENTAIRE : memes buckets que le report-only ; seuls WorkerIter /
       Regular / Meta sont archivables. Env, Lock et Unknown ne sont JAMAIS
       archives sur GDrive ni supprimes (secrets potentiels / verrous /
       patterns inconnus) — ils restent en place et sont comptes.
    2. EMPAQUETAGE : sources hashees AVANT packing ; une archive .7z (mx=7) +
       <archive>.MANIFEST.sha256 (sha256, taille, nom) + <archive>.INVENTORY.txt
       (bucket, age, taille, nom) + sidecar .7z.sha256, dans
       <ArchiveTo>\<machine>\<date>\. Idempotent : jamais d'ecrasement — si
       l'archive du jour existe deja, suffixe -HHmmss ; les artefacts portent
       le nom de leur archive ; collision sur le suffixe = refus explicite.
    3. INTEGRITE : l'archive est testee (7z t), extraite localement et chaque
       entree re-hashee contre le manifeste (concordants / discordants /
       manquants / en trop) ; les artefact copies sont RELUS depuis la
       destination et compares. Toute divergence => ARRET AVANT LE RETRAIT
       (exit 3, aucun fichier supprime).
    4. RETRAIT LOCAL : un fichier n'est supprime que s'il a ENCORE le hash de
       son entree de manifeste ; sinon il est saute et compte.

    Pourquoi empaqueter : la copie fichier par fichier sur DriveFS tournait a
    ~40 fichiers/min sur ai-01 et degradait toute la machine, et un listing de
    G: pris juste apres une ecriture massive n'est pas un compte (#3323). La
    relecture finale se fait donc par chemin direct (Get-Item / ReadAllText),
    jamais par listing.

    Buckets et retention :
    | Bucket     | Patterns                                                                                 | Retention      |
    |------------|------------------------------------------------------------------------------------------|----------------|
    | WorkerIter | worker-iter-*                                                                            | 14 jours       |
    | Regular    | worker-*, executor-*, coordinator-*, dashboard-watcher-*, listener-*, copilot-dispatcher* | 30 jours       |
    | Meta       | meta-audit-*, meta-*                                                                     | 7 jours        |
    | Env        | *.env                                                                                    | JAMAIS (secrets potentiels) |
    | Lock       | *.lock, *.lastrun                                                                        | JAMAIS (verrous) |
    | Unknown    | tout le reste                                                                            | JAMAIS         |

.PARAMETER RepoRoot
    Chemin du repo (defaut = resolution auto depuis l'emplacement du script).

.PARAMETER LogDir
    Repertoire des logs (defaut = <RepoRoot>\outputs\scheduling\logs).
    Aucune recursion : seul le contenu direct est examine.

.PARAMETER ArchiveTo
    Racine de destination des archives (production : la racine RooSync sur
    GDrive). L'archive du jour va dans <ArchiveTo>\<machine>\<yyyy-MM-dd>\.
    Avec -Execute : les 4 etapes. Sans -Execute : preview seule.

.PARAMETER Execute
    Requis pour TOUTE action de retrait. Sans -ArchiveTo : REFUS (exit 2).

.PARAMETER SevenZip
    Chemin de 7z.exe. Si fourni et introuvable : refus (pas de fallback
    silencieux). Sinon detection parmi : PATH, C:\ProgramData\chocolatey\tools\
    7z.exe, <Program Files>\Docker\Docker\7zr.exe, <Program Files>\7-Zip\7z.exe,
    D:\Apps\PortableApps\7-ZipPortable\App\7-Zip64\7z.exe. Absent : refus
    explicite — AUCUN repli sur la copie fichier par fichier.

.PARAMETER TestHook
    HOOK DE TEST — reserve a test-rotate-scheduling-logs.ps1 (#3834). Applique
    apres l'empaquetage, avant les controles :
    - 'corrupt-archive' : corrompt l'archive locale (l'etape 3 doit echouer).
    - 'mutate:<nom>'    : modifie <nom> dans LogDir (l'etape 4 doit le sauter).

.NOTES
    Issue : #3323 (rotation, #3599) puis #3834 (archive-puis-retrait).
    Decisions user : 13/09 (aucune purge, archivage GDrive), 24/09 RX50 (a).
    Compatible Windows PowerShell 5.1 (pwsh absent d'une partie de la flotte) —
    la version utilisee est affichee au demarrage.

    Codes de sortie :
    0 = OK (rapport seul / rien a faire / archivage + retrait complet)
    1 = echec(s) Remove-Item a l'etape 4
    2 = refus / precondition : -Execute sans -ArchiveTo ; 7z introuvable ;
        -TestHook invalide ; collision d'archive non resoluble
    3 = divergence d'integrite (7z t / extraction / relecture destination) —
        AUCUN fichier supprime
    4 = echec d'empaquetage 7z — aucun fichier supprime

    Le deploiement en tache planifiee se fait par
    install-rotate-scheduling-logs-schtask.ps1 (separe, -WhatIf, elevation
    requise pour Register-ScheduledTask = fenetre UAC groupee, #3834).
#>

param(
    [string]$RepoRoot = '',
    [string]$LogDir = '',
    [string]$ArchiveTo = '',
    [switch]$Execute,
    [string]$SevenZip = '',
    [string]$TestHook = '',
    [int]$WorkerIterRetentionDays = 14,
    [int]$RegularRetentionDays = 30,
    [int]$MetaRetentionDays = 7
)

$ErrorActionPreference = 'Stop'

# --- Refus structurel : -Execute exige -ArchiveTo (decision user 13/09, #3834) ---
if ($Execute -and [string]::IsNullOrEmpty($ArchiveTo)) {
    Write-Output "[REFUS] -Execute sans -ArchiveTo : la suppression sans archivage est interdite."
    Write-Output "[REFUS] Decision user du 13/09 (#3323), reprise par #3834 : archivage d'abord, retrait ensuite."
    Write-Output "[REFUS] Relancer avec -ArchiveTo <dossier> [-Execute], ou sans -Execute pour le rapport seul."
    exit 2
}

if ($TestHook -and $TestHook -notmatch '^(corrupt-archive|mutate:.+)$') {
    Write-Output "[REFUS] -TestHook invalide : '$TestHook' (attendu : 'corrupt-archive' ou 'mutate:<nom>')."
    exit 2
}

# --- Resolution des chemins (meme pattern que les wrappers siblings) ---
if ([string]::IsNullOrEmpty($RepoRoot)) {
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
    $RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
}
if ([string]::IsNullOrEmpty($LogDir)) {
    $LogDir = Join-Path $RepoRoot 'outputs\scheduling\logs'
}

if (-not (Test-Path -LiteralPath $LogDir -PathType Container)) {
    Write-Output "[INFO] LogDir absent : $LogDir — rien a faire."
    exit 0
}
$ResolvedLogDir = (Resolve-Path -LiteralPath $LogDir).Path
Write-Output "[INFO] PowerShell : $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
Write-Output "[INFO] LogDir : $ResolvedLogDir"

# --- Classification : chaque fichier dans exactement un bucket ---
# Ordre important : worker-iter-* AVANT worker-* (le second matche le premier).
function Get-RetentionBucket {
    param([string]$Name)
    if ($Name -like '*.lock')                { return 'Lock' }
    if ($Name -like '*.lastrun')             { return 'Lock' }
    if ($Name -like 'worker-iter-*')         { return 'WorkerIter' }
    if ($Name -like 'worker-*')              { return 'Regular' }
    if ($Name -like 'executor-*')            { return 'Regular' }
    if ($Name -like 'coordinator-*')         { return 'Regular' }
    if ($Name -like 'dashboard-watcher-*')   { return 'Regular' }
    if ($Name -like 'listener-*')            { return 'Regular' }
    if ($Name -like 'copilot-dispatcher*')   { return 'Regular' }
    if ($Name -like 'meta*')                 { return 'Meta' }
    if ($Name -like '*.env')                 { return 'Env' }
    return 'Unknown'
}

# Buckets jamais archives ni supprimes (#3834) : Unknown (patterns inconnus),
# Env (*.env = secrets potentiels), Lock (*.lock / *.lastrun = verrous).
$NeverTouched = @('Unknown', 'Env', 'Lock')

$RetentionByBucket = @{
    WorkerIter = $WorkerIterRetentionDays
    Regular    = $RegularRetentionDays
    Meta       = $MetaRetentionDays
}

# --- Resolution 7z (requise en mode -ArchiveTo uniquement) ---
function Resolve-SevenZipPath {
    param([string]$Hint)
    if ($Hint) {
        if (Test-Path -LiteralPath $Hint) { return $Hint }
        return $null    # hint explicite invalide = echec, pas de fallback silencieux
    }
    $cmd = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $cands = @(
        'C:\ProgramData\chocolatey\tools\7z.exe',
        (Join-Path $env:ProgramFiles 'Docker\Docker\7zr.exe'),
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        'D:\Apps\PortableApps\7-ZipPortable\App\7-Zip64\7z.exe'
    )
    foreach ($c in $cands) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

$SevenZipExe = $null
if ($ArchiveTo) {
    $SevenZipExe = Resolve-SevenZipPath -Hint $SevenZip
    if (-not $SevenZipExe) {
        Write-Output "[REFUS] 7z introuvable — l'archivage empaquete est impossible, et la copie fichier par fichier est ecartee par design (lenteur DriveFS, #3323)."
        if ($SevenZip) { Write-Output "[REFUS] -SevenZip fourni mais introuvable : $SevenZip" }
        Write-Output "[REFUS] Chemins verifies : PATH (7z.exe), C:\ProgramData\chocolatey\tools\7z.exe, $env:ProgramFiles\Docker\Docker\7zr.exe, $($env:ProgramFiles)\7-Zip\7z.exe, D:\Apps\PortableApps\7-ZipPortable\App\7-Zip64\7z.exe"
        exit 2
    }
    if (-not [System.IO.Path]::IsPathRooted($ArchiveTo)) {
        $ArchiveTo = Join-Path (Get-Location).Path $ArchiveTo
    }
}

if ($Execute) {
    Write-Output "[INFO] Mode   : ARCHIVE-PUIS-RETRAIT (-ArchiveTo -Execute)"
} elseif ($ArchiveTo) {
    Write-Output "[INFO] Mode   : PREVIEW ARCHIVAGE (-ArchiveTo sans -Execute : rien n'est ecrit)"
} else {
    Write-Output "[INFO] Mode   : REPORT-ONLY (aucune suppression possible sans -ArchiveTo)"
}

# --- Passe 1 : inventaire par bucket + selection des eligibles ---
$Now = Get-Date
$Files = @(Get-ChildItem -LiteralPath $ResolvedLogDir -File)

$Stats = @{}
$Eligible = @()
foreach ($f in $Files) {
    $Bucket = Get-RetentionBucket -Name $f.Name
    if (-not $Stats.ContainsKey($Bucket)) {
        $Stats[$Bucket] = @{ Files = 0; Bytes = [long]0; Eligible = 0; EligibleBytes = [long]0 }
    }
    $Stats[$Bucket].Files++
    $Stats[$Bucket].Bytes += $f.Length

    if ($NeverTouched -contains $Bucket) { continue }   # jamais archives ni supprimes

    $AgeDays = ($Now - $f.LastWriteTime).TotalDays
    if ($AgeDays -ge $RetentionByBucket[$Bucket]) {
        $Stats[$Bucket].Eligible++
        $Stats[$Bucket].EligibleBytes += $f.Length
        $Eligible += $f
    }
}

Write-Output ""
Write-Output ("{0,-12} {1,8} {2,11} {3,10} {4,13}" -f 'Bucket', 'Fichiers', 'Taille(MB)', 'Eligibles', 'Eligible(MB)')
Write-Output ("{0,-12} {1,8} {2,11} {3,10} {4,13}" -f '------', '--------', '----------', '---------', '------------')
$TotalBytes = [long]0
foreach ($f in $Files) { $TotalBytes += $f.Length }
$TotalEligible = 0
$TotalEligibleBytes = [long]0
foreach ($Key in @($Stats.Keys | Sort-Object)) {
    $S = $Stats[$Key]
    Write-Output ("{0,-12} {1,8} {2,11:N1} {3,10} {4,13:N1}" -f $Key, $S.Files, ($S.Bytes / 1MB), $S.Eligible, ($S.EligibleBytes / 1MB))
    $TotalEligible += $S.Eligible
    $TotalEligibleBytes += $S.EligibleBytes
}
Write-Output ("{0,-12} {1,8} {2,11:N1} {3,10} {4,13:N1}" -f 'TOTAL', $Files.Count, ($TotalBytes / 1MB), $TotalEligible, ($TotalEligibleBytes / 1MB))

$NeverTouchedNote = @()
foreach ($Key in $NeverTouched) {
    if ($Stats.ContainsKey($Key) -and $Stats[$Key].Files -gt 0) {
        $NeverTouchedNote += ("{0}={1}" -f $Key, $Stats[$Key].Files)
    }
}
if ($NeverTouchedNote.Count -gt 0) {
    Write-Output ""
    Write-Output ("[INFO] Jamais archives ni supprimes, comptes seulement : {0}" -f ($NeverTouchedNote -join ', '))
}

function Get-Sha256Hex {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

# ============================================================
# SORTIES SANS EFFET : report-only / preview archivage
# ============================================================
if (-not $Execute) {
    Write-Output ""
    if ($ArchiveTo) {
        $MachinePreview = $env:COMPUTERNAME.ToLower()
        $DatePreview = (Get-Date).ToString('yyyy-MM-dd')
        $DestDirPreview = Join-Path (Join-Path $ArchiveTo $MachinePreview) $DatePreview
        $ArchiveNamePreview = "scheduling-logs-$MachinePreview-$DatePreview.7z"
        $SuffixNote = ''
        if (Test-Path -LiteralPath (Join-Path $DestDirPreview $ArchiveNamePreview)) {
            $ArchiveNamePreview = "scheduling-logs-$MachinePreview-$DatePreview-HHmmss.7z"
            $SuffixNote = " (l'archive du jour existe : un suffixe -HHmmss sera pose, jamais d'ecrasement)"
        }
        Write-Output "[PREVIEW] 7z          : $SevenZipExe"
        Write-Output "[PREVIEW] Destination : $DestDirPreview"
        Write-Output "[PREVIEW] Archive     : $ArchiveNamePreview$SuffixNote"
        Write-Output "[PREVIEW] Artefacts   : .7z + .7z.sha256 + <archive>.MANIFEST.sha256 + <archive>.INVENTORY.txt (nommes par archive, jamais ecrases)"
        Write-Output ("[PREVIEW] Eligibles a archiver puis retirer : {0} fichier(s) ({1:N1} MB) — WorkerIter/Regular/Meta seulement." -f $TotalEligible, ($TotalEligibleBytes / 1MB))
        Write-Output "[PREVIEW] Relancer avec -Execute pour : inventaire -> empaquetage -> verification -> retrait."
    } else {
        Write-Output ("[REPORT-ONLY] {0} fichier(s) eligibles ({1:N1} MB) — archivables via -ArchiveTo (WorkerIter/Regular/Meta seulement)." -f $TotalEligible, ($TotalEligibleBytes / 1MB))
        Write-Output "[REPORT-ONLY] La suppression nue est impossible : -Execute exige -ArchiveTo (decision user 13/09, #3834)."
    }
    exit 0
}

# ============================================================
# MODE ARCHIVE-PUIS-RETRAIT (-ArchiveTo -Execute) — 4 etapes
# ============================================================
if ($TotalEligible -eq 0) {
    Write-Output ""
    Write-Output "[ETAPE 1/4] Inventaire : 0 eligible — rien a archiver, rien a retirer."
    exit 0
}

$Machine = $env:COMPUTERNAME.ToLower()
$DateStamp = (Get-Date).ToString('yyyy-MM-dd')
$DestDir = Join-Path (Join-Path $ArchiveTo $Machine) $DateStamp
$BaseName = "scheduling-logs-$Machine-$DateStamp"
$ArchiveName = "$BaseName.7z"

# --- Idempotence : jamais d'ecrasement d'une archive existante (#3834) ---
if (Test-Path -LiteralPath (Join-Path $DestDir $ArchiveName)) {
    $ArchiveName = "{0}-{1}.7z" -f $BaseName, (Get-Date).ToString('HHmmss')
    if (Test-Path -LiteralPath (Join-Path $DestDir $ArchiveName)) {
        Write-Output "[REFUS] Collision d'archive non resoluble : $ArchiveName existe deja dans $DestDir — aucune action."
        exit 2
    }
    Write-Output ("[INFO] Archive du jour deja presente — suffixe pose, sans ecrasement : {0}" -f $ArchiveName)
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Stage = Join-Path ([System.IO.Path]::GetTempPath()) ("rotate-logs-stage-" + [guid]::NewGuid().ToString('N').Substring(0, 8))

# Manifeste, inventaire et sidecar portent le nom de LEUR archive : deux runs le
# meme jour (suffixe -HHmmss) ne s'ecrasent jamais la preuve l'un de l'autre.
$ArchiveBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ArchiveName)
$ManifestName = "$ArchiveBaseName.MANIFEST.sha256"
$InventoryName = "$ArchiveBaseName.INVENTORY.txt"
$SidecarName = "$ArchiveName.sha256"

try {
    New-Item -ItemType Directory -Path $Stage -Force | Out-Null
    $ArchivePath = Join-Path $Stage $ArchiveName

    # ---------------- ETAPE 1/4 : inventaire (rapport chiffre) ----------------
    Write-Output ""
    Write-Output ("[ETAPE 1/4] Inventaire : {0} fichier(s) analyse(s), {1} eligible(s) ({2:N1} MB) — Env/Lock/Unknown laisses en place." -f $Files.Count, $TotalEligible, ($TotalEligibleBytes / 1MB))

    # ---------------- ETAPE 2/4 : empaquetage ----------------
    # Sources hashees AVANT packing — le manifeste est la preuve de reference.
    $HashByName = @{}
    $ManifestLines = New-Object System.Collections.Generic.List[string]
    $InventoryLines = New-Object System.Collections.Generic.List[string]
    foreach ($f in $Eligible) {
        $h = Get-Sha256Hex -Path $f.FullName
        $HashByName[$f.Name] = $h
        $ManifestLines.Add(("{0}  {1}  {2}" -f $h, $f.Length, $f.Name))
        $BucketInv = Get-RetentionBucket -Name $f.Name
        $AgeInv = ($Now - $f.LastWriteTime).TotalDays
        $InventoryLines.Add(("{0}`t{1:N1}`t{2}`t{3}" -f $BucketInv, $AgeInv, $f.Length, $f.Name))
    }
    $ManifestPath = Join-Path $Stage $ManifestName
    $InventoryPath = Join-Path $Stage $InventoryName
    [System.IO.File]::WriteAllLines($ManifestPath, $ManifestLines, $Utf8NoBom)
    [System.IO.File]::WriteAllLines($InventoryPath, $InventoryLines, $Utf8NoBom)

    # 7z avec listfile relatif (CWD = LogDir). NB : pas de "--" avec @listfile —
    # 7-Zip y lirait la fin de switches comme un nom de fichier litteral.
    # -scsUTF-8 : le listfile est ecrit UTF-8 sans BOM ; sans le switch, 7z le
    # relit dans la codepage systeme et un nom non ASCII echouerait au packing.
    $ListFile = Join-Path $Stage 'packlist.txt'
    [System.IO.File]::WriteAllLines($ListFile, @($Eligible | ForEach-Object { $_.Name }), $Utf8NoBom)
    Push-Location -LiteralPath $ResolvedLogDir
    try {
        & $SevenZipExe a -t7z -mx=7 -mmt=on -scsUTF-8 -bso0 -bsp0 $ArchivePath "@$ListFile" | Out-Null
        $PackRc = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($PackRc -ne 0 -or -not (Test-Path -LiteralPath $ArchivePath)) {
        Write-Output "[ETAPE 2/4] ECHEC empaquetage 7z (rc=$PackRc) — archive partielle ecartee, RIEN supprime."
        exit 4
    }

    # Sidecar sha256 de l'archive.
    $ArchiveHash = Get-Sha256Hex -Path $ArchivePath
    $SidecarPath = Join-Path $Stage $SidecarName
    [System.IO.File]::WriteAllText($SidecarPath, ("{0}  {1}" -f $ArchiveHash, $ArchiveName) + [Environment]::NewLine, $Utf8NoBom)

    $ArchiveMB = (Get-Item -LiteralPath $ArchivePath).Length / 1MB
    Write-Output ("[ETAPE 2/4] Empaquetage : {0} fichier(s) ({1:N1} MB) -> {2} ({3:N1} MB) + {4} ({5} lignes) + {6} + sidecar." -f $Eligible.Count, ($TotalEligibleBytes / 1MB), $ArchiveName, $ArchiveMB, $ManifestName, $ManifestLines.Count, $InventoryName)

    # --- Hook de test (test-rotate-scheduling-logs.ps1 uniquement, #3834) ---
    if ($TestHook -eq 'corrupt-archive') {
        [System.IO.File]::AppendAllText($ArchivePath, 'CORRUPTION-TEST-PAYLOAD')
        Write-Output "[TESTHOOK] corrupt-archive : archive locale corrompue a dessein."
    } elseif ($TestHook -like 'mutate:*') {
        $MutName = $TestHook.Substring(7)
        Add-Content -LiteralPath (Join-Path $ResolvedLogDir $MutName) -Value 'mutated-after-packing'
        Write-Output "[TESTHOOK] mutate : $MutName modifie apres l'empaquetage."
    }

    # ---------------- ETAPE 3/4 : integrite ----------------
    & $SevenZipExe t -bso0 -bsp0 $ArchivePath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "[ETAPE 3/4] DIVERGENCE : test 7z echoue (archive corrompue) — ARRET AVANT LE RETRAIT, aucun fichier supprime."
        exit 3
    }

    $ExtractDir = Join-Path $Stage 'extract'
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
    & $SevenZipExe x "-o$ExtractDir" -y -bso0 -bsp0 $ArchivePath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "[ETAPE 3/4] DIVERGENCE : extraction 7z echouee — ARRET AVANT LE RETRAIT, aucun fichier supprime."
        exit 3
    }

    # Re-hash de chaque entree extraite contre le manifeste.
    $ExtractedHashByName = @{}
    foreach ($x in @(Get-ChildItem -LiteralPath $ExtractDir -File)) {
        $ExtractedHashByName[$x.Name] = Get-Sha256Hex -Path $x.FullName
    }
    $Matched = 0; $Mismatched = 0; $Missing = 0
    foreach ($Name in $HashByName.Keys) {
        if ($ExtractedHashByName.ContainsKey($Name)) {
            if ($ExtractedHashByName[$Name] -eq $HashByName[$Name]) { $Matched++ } else { $Mismatched++ }
        } else {
            $Missing++
        }
    }
    $Extra = 0
    foreach ($Name in $ExtractedHashByName.Keys) {
        if (-not $HashByName.ContainsKey($Name)) { $Extra++ }
    }
    Write-Output ("[ETAPE 3/4] Extraction : {0} concordant(s), {1} discordant(s), {2} manquant(s), {3} en trop." -f $Matched, $Mismatched, $Missing, $Extra)
    if (($Mismatched -gt 0) -or ($Missing -gt 0) -or ($Extra -gt 0)) {
        Write-Output "[ETAPE 3/4] DIVERGENCE : manifeste vs extraction — ARRET AVANT LE RETRAIT, aucun fichier supprime."
        exit 3
    }

    # Copie des 4 artefacts vers la destination, puis RELECTURE par chemin direct
    # (jamais par listing DriveFS — #3323 : un listing apres ecriture massive ment).
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    foreach ($Artifact in @($ArchivePath, $SidecarPath, $ManifestPath, $InventoryPath)) {
        Copy-Item -LiteralPath $Artifact -Destination $DestDir -Force
    }
    $DestArchivePath = Join-Path $DestDir $ArchiveName
    $DestArchiveHash = Get-Sha256Hex -Path $DestArchivePath
    $DestManifestRaw = [System.IO.File]::ReadAllText((Join-Path $DestDir $ManifestName))
    $DestSidecarRaw = [System.IO.File]::ReadAllText((Join-Path $DestDir $SidecarName))
    if (($DestArchiveHash -ne $ArchiveHash) -or ($DestManifestRaw -ne [System.IO.File]::ReadAllText($ManifestPath)) -or ($DestSidecarRaw -ne [System.IO.File]::ReadAllText($SidecarPath))) {
        Write-Output "[ETAPE 3/4] DIVERGENCE : relecture destination != artefacts locaux — ARRET AVANT LE RETRAIT, aucun fichier supprime."
        Write-Output "[ETAPE 3/4] Artefacts laisses en place pour inspection : $DestDir"
        exit 3
    }
    Write-Output ("[ETAPE 3/4] Relecture destination OK : hash archive conforme au sidecar, manifeste identique ({0} lignes)." -f $ManifestLines.Count)

    # ---------------- ETAPE 4/4 : retrait local garde par hash ----------------
    $Step4 = $true
    $Deleted = 0; $Skipped = 0; $Failed = 0
    $FreedBytes = [long]0
    foreach ($f in $Eligible) {
        if (-not (Test-Path -LiteralPath $f.FullName)) {
            # Fichier disparu entre l'inventaire et le retrait : rien a supprimer,
            # mais son archive reste valide — compte comme saute, pas comme echec.
            Write-Output ("[WARN] Saut (disparu depuis l'inventaire) : {0}" -f $f.Name)
            $Skipped++
            continue
        }
        $CurrentHash = Get-Sha256Hex -Path $f.FullName
        if ($CurrentHash -ne $HashByName[$f.Name]) {
            Write-Output ("[WARN] Saut (hash divergent de l'entree de manifeste, fichier modifie depuis l'empaquetage) : {0}" -f $f.Name)
            $Skipped++
            continue
        }
        try {
            Remove-Item -LiteralPath $f.FullName -Force
            $Deleted++
            $FreedBytes += $f.Length
        } catch {
            Write-Output ("[WARN] Echec suppression : {0} ({1})" -f $f.Name, $_.Exception.Message)
            $Failed++
        }
    }
    Write-Output ("[ETAPE 4/4] Retrait : {0} supprime(s) ({1:N1} MB liberes), {2} saute(s), {3} echec(s)." -f $Deleted, ($FreedBytes / 1MB), $Skipped, $Failed)
    Write-Output ("[RESULTAT] Archive : {0} | {1} fichier(s) archive(s)-retire(s), {2} saute(s)." -f $DestArchivePath, $Deleted, $Skipped)
    if ($Failed -gt 0) { exit 1 }
    exit 0
} catch {
    Write-Output ("[ERREUR] {0}" -f $_.Exception.Message)
    if ($Step4) {
        Write-Output "[ERREUR] Exception pendant l'etape 4 (retrait) : des suppressions ont pu etre effectuees avant l'arret — l'archive et son manifeste restent la preuve de ce qui a ete retire."
    } else {
        Write-Output "[ERREUR] Aucune suppression effectuee (exception survenue avant l'etape 4)."
    }
    exit 1
} finally {
    if (Test-Path -LiteralPath $Stage) {
        Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}
