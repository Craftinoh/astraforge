$script:PreRunWindowState = @{
    Form = $null
    List = $null
    Footer = $null
    Rows = @{}
    Cancelled = $false
    LaunchStarted = $false
}

function New-AstraForgePreRunWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$GpuProfile,
        [Parameter(Mandatory = $true)][string]$Profile,
        [Parameter(Mandatory = $true)][string]$Console
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'AstraForge | Pre-run'
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(860, 500)
    $form.MinimumSize = New-Object System.Drawing.Size(780, 460)
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 25, 35)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(235, 240, 248)
    $form.TopMost = $true
    $form.ShowInTaskbar = $true

    $header = New-Object System.Windows.Forms.Label
    $header.Text = 'Preparazione della sessione'
    $header.AutoSize = $false
    $header.Location = New-Object System.Drawing.Point(18, 14)
    $header.Size = New-Object System.Drawing.Size(820, 32)
    $header.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 16)
    $header.ForeColor = [System.Drawing.Color]::FromArgb(104, 190, 255)
    [void]$form.Controls.Add($header)

    $summary = New-Object System.Windows.Forms.Label
    $summary.Text = "$GpuProfile  |  $Profile  |  $Console  |  avvio automatico solo se i controlli passano"
    $summary.AutoSize = $false
    $summary.Location = New-Object System.Drawing.Point(20, 50)
    $summary.Size = New-Object System.Drawing.Size(818, 24)
    $summary.ForeColor = [System.Drawing.Color]::FromArgb(195, 205, 220)
    [void]$form.Controls.Add($summary)

    $list = New-Object System.Windows.Forms.ListView
    $list.Location = New-Object System.Drawing.Point(18, 84)
    $list.Size = New-Object System.Drawing.Size(820, 345)
    $list.Anchor = 'Top, Bottom, Left, Right'
    $list.View = [System.Windows.Forms.View]::Details
    $list.FullRowSelect = $true
    $list.GridLines = $true
    $list.HideSelection = $false
    $list.BackColor = [System.Drawing.Color]::FromArgb(29, 36, 49)
    $list.ForeColor = [System.Drawing.Color]::FromArgb(235, 240, 248)
    [void]$list.Columns.Add('CONTROLLO', 190)
    [void]$list.Columns.Add('ESITO', 100)
    [void]$list.Columns.Add('DETTAGLI', 510)
    [void]$form.Controls.Add($list)

    $footer = New-Object System.Windows.Forms.Label
    $footer.Text = 'La chiusura della finestra annulla l’avvio. Nessun input del controller verrà simulato.'
    $footer.AutoSize = $false
    $footer.Location = New-Object System.Drawing.Point(20, 440)
    $footer.Size = New-Object System.Drawing.Size(818, 36)
    $footer.Anchor = 'Bottom, Left, Right'
    $footer.ForeColor = [System.Drawing.Color]::FromArgb(185, 195, 210)
    [void]$form.Controls.Add($footer)

    $script:PreRunWindowState.Form = $form
    $script:PreRunWindowState.List = $list
    $script:PreRunWindowState.Footer = $footer
    $script:PreRunWindowState.Rows = @{}
    $script:PreRunWindowState.Cancelled = $false
    $script:PreRunWindowState.LaunchStarted = $false
    $form.Tag = $script:PreRunWindowState
    $form.add_FormClosing({
        param($sender, $eventArgs)
        if (-not $sender.Tag.LaunchStarted) {
            $sender.Tag.Cancelled = $true
        }
    })
    [void]$form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    Set-AstraForgePreRunStatus -Check 'Preflight' -Status 'IN CORSO' -Details 'Verifico profilo, build, adapter, percorsi e memoria.'
}

function Set-AstraForgePreRunStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Check,
        [Parameter(Mandatory = $true)][ValidateSet('IN CORSO', 'OK', 'ATTENZIONE', 'ERRORE', 'PRONTO', 'ATTIVO', 'ANNULLATO')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Details
    )

    $form = $script:PreRunWindowState.Form
    if ($null -eq $form -or $form.IsDisposed) { return }
    $list = $script:PreRunWindowState.List
    $item = $script:PreRunWindowState.Rows[$Check]
    if ($null -eq $item) {
        $item = New-Object System.Windows.Forms.ListViewItem($Check)
        [void]$item.SubItems.Add($Status)
        [void]$item.SubItems.Add($Details)
        [void]$list.Items.Add($item)
        $script:PreRunWindowState.Rows[$Check] = $item
    } else {
        $item.SubItems[1].Text = $Status
        $item.SubItems[2].Text = $Details
    }
    $item.ForeColor = switch ($Status) {
        'OK' { [System.Drawing.Color]::FromArgb(130, 225, 165); break }
        'PRONTO' { [System.Drawing.Color]::FromArgb(104, 190, 255); break }
        'ATTIVO' { [System.Drawing.Color]::FromArgb(130, 225, 165); break }
        'ATTENZIONE' { [System.Drawing.Color]::FromArgb(255, 210, 110); break }
        'ERRORE' { [System.Drawing.Color]::FromArgb(255, 120, 120); break }
        'ANNULLATO' { [System.Drawing.Color]::FromArgb(255, 160, 120); break }
        default { [System.Drawing.Color]::FromArgb(235, 240, 248) }
    }
    if (-not $form.IsDisposed) {
        $form.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Set-AstraForgePreRunFooter {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Text)

    if ($script:PreRunWindowState.Form -and -not $script:PreRunWindowState.Form.IsDisposed) {
        $script:PreRunWindowState.Footer.Text = $Text
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Test-AstraForgePreRunCancelled {
    return [bool]$script:PreRunWindowState.Cancelled
}

function Start-AstraForgePreRunLaunch {
    $script:PreRunWindowState.LaunchStarted = $true
    if ($script:PreRunWindowState.Form -and -not $script:PreRunWindowState.Form.IsDisposed) {
        $script:PreRunWindowState.Form.TopMost = $false
    }
}

function Complete-AstraForgePreRunLaunch {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][int]$ProcessId)

    Set-AstraForgePreRunStatus -Check 'Runtime' -Status 'ATTIVO' -Details "Processo avviato (PID $ProcessId); controller manuale pronto."
    Set-AstraForgePreRunFooter -Text 'Runtime avviato. La finestra si minimizza per lasciare visibile l’applicazione; i log restano nella cartella di sessione.'
    if ($script:PreRunWindowState.Form -and -not $script:PreRunWindowState.Form.IsDisposed) {
        $script:PreRunWindowState.Form.TopMost = $false
        $script:PreRunWindowState.Form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    }
}

function Show-AstraForgePreRunFailure {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)

    if ($script:PreRunWindowState.Form -and -not $script:PreRunWindowState.Form.IsDisposed) {
        Set-AstraForgePreRunStatus -Check 'Preflight' -Status 'ERRORE' -Details $Message
        Set-AstraForgePreRunFooter -Text 'Avvio bloccato: correggi il controllo indicato e ripeti il pre-run.'
        $script:PreRunWindowState.Form.TopMost = $true
        $script:PreRunWindowState.Form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        [void][System.Windows.Forms.MessageBox]::Show(
            $script:PreRunWindowState.Form,
            $Message,
            'AstraForge | Pre-run bloccato',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
}

Export-ModuleMember -Function New-AstraForgePreRunWindow, Set-AstraForgePreRunStatus, Set-AstraForgePreRunFooter, Test-AstraForgePreRunCancelled, Start-AstraForgePreRunLaunch, Complete-AstraForgePreRunLaunch, Show-AstraForgePreRunFailure
