function Assert-AstraForgeCommitHeadroom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][double]$AvailableGiB,
        [ValidateRange(12, 256)][int]$MinimumGiB = 12
    )

    if ([double]::IsNaN($AvailableGiB) -or [double]::IsInfinity($AvailableGiB) -or $AvailableGiB -lt 0) {
        throw 'Il campionamento della memoria commit non ha restituito un valore finito valido.'
    }
    if ($AvailableGiB -lt $MinimumGiB) {
        throw ("Commit disponibile {0:N1} GiB, sotto la soglia minima {1} GiB. Libera memoria/commit e ripeti il preflight." -f $AvailableGiB, $MinimumGiB)
    }
}

Export-ModuleMember -Function Assert-AstraForgeCommitHeadroom
