# ============================================================================
# Single-Instance Mutex (#3277)
# Module partagé : dot-sourcé par dashboard-listener.ps1 et
# dashboard-listener-wrapper.ps1. Incident fondateur (25/08) : 1 dispatch
# [WAKE-VIBE] → 2 chaînes wrapper→listener concurrentes (dont une invoquée
# hors wrapper, sans trace disque) → 2 workers payés → timeout → re-livraison
# → 3e session. Un mutex nommé kernel-side est la seule garde qui élimine
# TOUTE 2e chaîne, quelle que soit sa voie de spawn : pas de fenêtre
# check-then-create, pas d'état stale à détecter (le kernel libère le mutex
# à la mort du process titulaire).
#
# Auto-contenu : aucune dépendance au scope appelant.
# ============================================================================

function Get-SingleInstance {
    <#
    .SYNOPSIS
        Tente d'acquérir un mutex nommé non-persistant, sans attendre.

    .DESCRIPTION
        Retourne immédiatement. Si le mutex est déjà détenu par un processus
        vivant, Acquired=$false — l'appelant doit exit proprement avec une
        trace (jamais en silence : c'est le diagnostic qui a manqué le 25/08).

        L'AbandonedMutexException signifie que le titulaire précédent est MORT
        sans relâcher : l'acquisition a réussi, on la garde.

        Namespace Global\ d'abord (visible cross-session, utile quand schtask
        et invocation manuelle vivent dans des sessions différentes) ;
        fallback Local\ si Global\ est refusé (politique de session).

    .PARAMETER Name
        Nom logique (ex. "RooSync-DashboardListener"). Suffixé par l'appelant
        pour l'isolation de test.
    #>
    param([Parameter(Mandatory)][string]$Name)

    $result = @{ Acquired = $false; Mutex = $null; Namespace = '' }
    foreach ($ns in @('Global\', 'Local\')) {
        $mutex = $null
        try {
            $mutex = New-Object System.Threading.Mutex($false, "$ns$Name")
        } catch {
            # Nom inaccessible dans ce namespace (privilège) → essayer le suivant
            continue
        }
        try {
            $acquired = $mutex.WaitOne(0)
        } catch [System.Threading.AbandonedMutexException] {
            # Titulaire mort : le wait a réussi malgré l'exception
            $acquired = $true
        } catch {
            $mutex.Dispose()
            continue
        }
        if ($acquired) {
            $result.Acquired = $true
            $result.Mutex = $mutex
            $result.Namespace = $ns
            return $result
        }
        $mutex.Dispose()
        return $result
    }
    return $result
}

function Release-SingleInstance {
    param($Handle)
    if ($null -eq $Handle -or $null -eq $Handle.Mutex) { return }
    try {
        if ($Handle.Acquired) { $Handle.Mutex.ReleaseMutex() }
    } catch {
        # Best-effort : la mort du process libère le mutex de toute façon
    } finally {
        $Handle.Mutex.Dispose()
        $Handle.Acquired = $false
    }
}
