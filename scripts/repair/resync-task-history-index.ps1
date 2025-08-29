<#
.SYNOPSIS
    Resynchronize the Roo-Code taskHistory index with the actual task metadata files.
.DESCRIPTION
    This script reads the 'taskHistory' index from the VS Code state database (state.vscdb)
    and compares the 'workspace' property of each task with the 'workspacePath' from its
    corresponding task_metadata.json file. If a mismatch is found, it updates the index
    in memory. The script can run in -WhatIf mode to preview changes without writing to the database.
.PARAMETER StateDbPath
    The path to the state.vscdb file. If not provided, the script will attempt to find it in the default VS Code user data location.
.PARAMETER TasksDirectory
    The path to the Roo-Code tasks directory. If not provided, the script will attempt to find it in the default global storage location.
.PARAMETER WhatIf
    A switch parameter that, if present, simulates the resynchronization without making any actual changes to the database.
.EXAMPLE
    .\resync-task-history-index.ps1 -WhatIf
    Runs the script in simulation mode, showing what changes would be made.
.EXAMPLE
    .\resync-task-history-index.ps1 -StateDbPath "C:\Users\YourUser\AppData\Roaming\Code\User\globalStorage\state.vscdb" -TasksDirectory "C:\Users\YourUser\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"
    Runs the script with explicit paths.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$StateDbPath,
    [string]$TasksDirectory
)

function Ensure-PSSQLiteModule {
    if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
        Write-Host "The 'PSSQLite' module is not installed. Attempting to install it now..."
        try {
            Install-Module -Name PSSQLite -Repository PSGallery -Force -Scope CurrentUser -Confirm:$false
            Write-Host "PSSQLite module installed successfully."
        }
        catch {
            Write-Error "Failed to install PSSQLite module. Please install it manually by running 'Install-Module -Name PSSQLite' and try again."
            throw
        }
    }
}

function Get-DefaultPaths {
    $DefaultPaths = @{}
    if ($env:APPDATA) {
        $DefaultPaths.StateDb = Join-Path $env:APPDATA "Code\User\globalStorage\state.vscdb"
        $DefaultPaths.TasksDir = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"
    }
    # Add other OS-specific paths if needed (e.g., for Linux/macOS)
    return $DefaultPaths
}

try {
    Ensure-PSSQLiteModule
    Import-Module PSSQLite

    $DefaultPaths = Get-DefaultPaths

    if (-not $StateDbPath) {
        $StateDbPath = $DefaultPaths.StateDb
        Write-Verbose "StateDbPath not provided. Using default: $StateDbPath"
    }

    if (-not $TasksDirectory) {
        $TasksDirectory = $DefaultPaths.TasksDir
        Write-Verbose "TasksDirectory not provided. Using default: $TasksDirectory"
    }

    if (-not (Test-Path $StateDbPath)) {
        throw "State database not found at '$StateDbPath'. Please provide a valid path using -StateDbPath."
    }

    if (-not (Test-Path $TasksDirectory)) {
        throw "Tasks directory not found at '$TasksDirectory'. Please provide a valid path using -TasksDirectory."
    }

    Write-Host "Connecting to state database: $StateDbPath"
    $db = [System.Data.SQLite.SQLiteConnection]::new("Data Source=$StateDbPath")
    $db.Open()

    # 1. Read taskHistory from DB
    $taskHistoryKey = 'RooVeterinaryInc.roo-cline'
    $command = $db.CreateCommand()
    $command.CommandText = "SELECT value FROM ItemTable WHERE key = '$taskHistoryKey'"
    $taskHistoryJson = $command.ExecuteScalar()

    if (-not $taskHistoryJson) {
        throw "Could not find taskHistory with key '$taskHistoryKey' in the database."
    }

    Write-Host "Successfully retrieved taskHistory. Deserializing JSON..."
    # 2. Convert byte array to JSON string
    $jsonString = [System.Text.Encoding]::UTF8.GetString($taskHistoryJson)
    
    # 2. Deserialize JSON
    $data = $jsonString | ConvertFrom-Json
    $taskHistory = $data.taskHistory

    $originalTaskCount = $taskHistory.Count
    Write-Host "$originalTaskCount tasks found in the index."

    $correctionsCount = 0

    # 3. Iterate and compare with task_metadata.json
    foreach ($task in $taskHistory) {
        $taskId = $task.id
        $metadataPath = Join-Path $TasksDirectory "$taskId\task_metadata.json"

        if (-not (Test-Path $metadataPath)) {
            Write-Warning "Metadata file not found for task ID '$taskId'. Skipping."
            continue
        }

        $metadata = Get-Content -Path $metadataPath | ConvertFrom-Json
        $workspaceFromIndex = $task.workspace
        $workspaceFromFile = $metadata.workspacePath

        if ($workspaceFromIndex -ne $workspaceFromFile) {
            Write-Host "Mismatch found for task '$taskId':" -ForegroundColor Yellow
            Write-Host "  Index:   $workspaceFromIndex"
            Write-Host "  Metadata:$workspaceFromFile"
            
            # 4. Update in-memory object
            $task.workspace = $workspaceFromFile
            $correctionsCount++
            Write-Host "  -> Marked for update." -ForegroundColor Green
        }
    }


    if ($correctionsCount -eq 0) {
        Write-Host "Index is already synchronized. No changes needed."
        return
    }

    # 5. Serialize back to JSON
    $updatedTaskHistoryJson = $taskHistory | ConvertTo-Json -Depth 100

    if ($pscmdlet.ShouldProcess("the state.vscdb database", "Update taskHistory index ($correctionsCount corrections)")) {
        # 6. Write back to DB if not -WhatIf
        $updateCommand = $db.CreateCommand()
        $updateCommand.CommandText = "UPDATE ItemTable SET value = @value WHERE key = @key"
        $updateCommand.Parameters.AddWithValue("@value", $updatedTaskHistoryJson) | Out-Null
        $updateCommand.Parameters.AddWithValue("@key", $taskHistoryKey) | Out-Null
        
        $rowsAffected = $updateCommand.ExecuteNonQuery()
        
        if ($rowsAffected -gt 0) {
            Write-Host "Successfully updated taskHistory in the database." -ForegroundColor Green
        }
        else {
            Write-Error "Failed to update taskHistory in the database."
        }
    }

    Write-Host "Resynchronization complete. $correctionsCount tasks were corrected."

}
catch {
    Write-Error $_.Exception.Message
}
finally {
    if ($db -and $db.State -eq 'Open') {
        $db.Close()
        Write-Host "Database connection closed."
    }
}