# Tests de COMPORTEMENT du classifieur embeddings (embeddings-verdict.ps1)
#
# Ces tests EXECUTENT la classification : ils instancient les exceptions
# en memoire (aucun reseau, aucune cle) et appellent la fonction. Un test
# qui ne fait que matcher du texte passerait a l identique avec les
# defauts presents : c est le piege mesure sur #4365 (10 assertions
# vertes, 401 et PowerShell 7 toujours mal classes).
BeforeAll {    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/monitoring/embeddings-verdict.ps1")
}
Describe "Classifieur embeddings -- detection de timeout" {    It "Un WebException Timeout (PowerShell 5.1) est un TIMEOUT" {        $ex = [System.Net.WebException]::new("timeout", [System.Net.WebExceptionStatus]::Timeout)
        (Get-EmbeddingsVerdict -ErrorRecord $ex).Status | Should -Be "TIMEOUT"
    }
    It "Un TaskCanceledException (PowerShell 7) est un TIMEOUT" {        $ex = [System.Threading.Tasks.TaskCanceledException]::new("annule", [System.TimeoutException]::new("delai depasse"))
        (Get-EmbeddingsVerdict -ErrorRecord $ex).Status | Should -Be "TIMEOUT"
    }
    It "Un timeout imbrique dans une autre exception reste un TIMEOUT" {        $ex = [System.InvalidOperationException]::new("externe", [System.TimeoutException]::new("delai depasse"))
        (Get-EmbeddingsVerdict -ErrorRecord $ex).Status | Should -Be "TIMEOUT"
    }
}
Describe "Classifieur embeddings -- reponse HTTP explicite" {    It "Un 401 est un AUTH : le service a repondu, il n est pas mort" {        $ex = [pscustomobject]@{ Message = "401 Non autorise"; Response = [pscustomobject]@{ StatusCode = 401 }; InnerException = $null }
        $v = Get-EmbeddingsVerdict -ErrorRecord $ex
        $v.Status | Should -Be "AUTH"
        $v.FailureKind | Should -Be "auth"
    }
    It "Un 403 est un AUTH" {        $ex = [pscustomobject]@{ Message = "403 Interdit"; Response = [pscustomobject]@{ StatusCode = 403 }; InnerException = $null }
        (Get-EmbeddingsVerdict -ErrorRecord $ex).Status | Should -Be "AUTH"
    }
    It "Un 503 est une erreur HTTP : la panne peut etre cote backend" {        $ex = [pscustomobject]@{ Message = "503 Service indisponible"; Response = [pscustomobject]@{ StatusCode = 503 }; InnerException = $null }
        $v = Get-EmbeddingsVerdict -ErrorRecord $ex
        $v.Status | Should -Be "HTTP"
        $v.FailureKind | Should -Be "http"
    }
    It "Une erreur sans reponse HTTP est une FAILURE inconnue" {        $ex = [pscustomobject]@{ Message = "boom"; Response = $null; InnerException = $null }
        (Get-EmbeddingsVerdict -ErrorRecord $ex).Status | Should -Be "FAILURE"
    }
}
