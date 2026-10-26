<#
.SYNOPSIS
    Classification pure des echecs HTTP du moniteur embeddings.

.DESCRIPTION
    Fonctions SANS reseau, SANS cle et SANS effet de bord : elles decident
    ce qu est un echec de l appel HTTP. check-embeddings.ps1 les utilise ;
    les tests Pester les appellent directement, avec des exceptions
    instancies (pas de mock de chaine).

    Pourquoi un fichier separe : la version monitee du probe (issue 1499)
    diagnostiquait un timeout via $_.Exception -is [System.Net.WebException].
    Sous PowerShell 7 un timeout leve TaskCanceledException, jamais
    WebException => isTimeout = False => le service etait classe FAIL sans
    passer par la confirmation, et la branche DEGRADED (tout l objet du
    correctif) ne jouait jamais. Un 401 (cle refusee) levait aussi
    WebException/Status=ProtocolError => egalement FAIL, avec un message
    qui recommandait de redemarrer vLLM alors que le service REPONDAIT.

.NOTES
    Issue #1499. Aucun acces reseau ici.
#>

function Test-EmbeddingsTimeout {
    param([object]$ErrorRecord)
    if (-not $ErrorRecord) { return $false }
    $e = $ErrorRecord
    while ($e) {
        if ($e -is [System.Net.WebException]) {
            if ($e.Status -eq [System.Net.WebExceptionStatus]::Timeout) { return $true }
        }
        if ($e -is [System.TimeoutException]) { return $true }
        if ($e -is [System.OperationCanceledException]) { return $true }
        $e = $e.InnerException
    }
    return $false
}

function Get-EmbeddingsHttpStatus {
    param([object]$ErrorRecord)
    if (-not $ErrorRecord) { return 0 }
    $resp = $null
    try { $resp = $ErrorRecord.Response } catch { $resp = $null }
    if (-not $resp) { return 0 }
    try {
        $code = [int]$resp.StatusCode
        if ($code -gt 0) { return $code }
    } catch { }
    return 0
}

function Get-EmbeddingsVerdict {
    param(
        [object]$ErrorRecord,
        [string]$Message = ""
    )

    $text = $Message
    if (-not $text) { $text = $ErrorRecord.Message }

    if (Test-EmbeddingsTimeout -ErrorRecord $ErrorRecord) {
        return [pscustomobject]@{ Status = "TIMEOUT"; FailureKind = "timeout"; Detail = $text }
    }

    $code = Get-EmbeddingsHttpStatus -ErrorRecord $ErrorRecord
    if ($code -ge 400 -and $code -lt 500) {
        return [pscustomobject]@{ Status = "AUTH"; FailureKind = "auth"; Detail = "HTTP " + $code + " : l endpoint a repondu et refuse la cle" }
    }
    if ($code -ge 500) {
        return [pscustomobject]@{ Status = "HTTP"; FailureKind = "http"; Detail = "HTTP " + $code + " : " + $text }
    }
    return [pscustomobject]@{ Status = "FAILURE"; FailureKind = "unknown"; Detail = $text }
}
