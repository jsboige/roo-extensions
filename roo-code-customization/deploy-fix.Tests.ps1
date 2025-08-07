#Requires -Modules Pester
# a powershell script to test the deploy-fix.ps1 script
#
# Path: deploy-fix.Tests.ps1

Describe "deploy-fix.ps1" {
    BeforeAll {
        # Path to the script to be tested
        $script:script_path = (Resolve-Path "deploy-fix.ps1").Path

        # Create temporary directories for testing
        $script:tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP (New-Guid).Guid)
        $script:paramSourceDir = Join-Path $script:tempDir.FullName "source"
        $script:paramTargetDir = Join-Path $script:tempDir.FullName "target"
        $script:paramBackupDir = Join-Path $script:tempDir.FullName "target_backup"


        # Create reset function
        $script:ResetTestEnvironment = {
            # Clean up directories
            if (Test-Path $script:paramSourceDir) { Remove-Item $script:paramSourceDir -Recurse -Force }
            if (Test-Path $script:paramTargetDir) { Remove-Item $script:paramTargetDir -Recurse -Force }
            if (Test-Path $script:paramBackupDir) { Remove-Item $script:paramBackupDir -Recurse -Force }

            # Recreate directories
            New-Item -ItemType Directory -Path $script:paramSourceDir | Out-Null
            New-Item -ItemType Directory -Path $script:paramTargetDir | Out-Null
            
            # Create dummy files
            "source_content_v1" | Set-Content -Path (Join-Path $script:paramSourceDir "file1.txt")
            "source_content_v1" | Set-Content -Path (Join-Path $script:paramSourceDir "file2.js")
            "original_content" | Set-Content -Path (Join-Path $script:paramTargetDir "file1.txt")
        }
    }

    AfterAll {
        # Remove temporary directories
        Remove-Item -Path $script:tempDir -Recurse -Force
    }

    BeforeEach {
        # Reset environment before each test
        & $script:ResetTestEnvironment
    }


    Context "Deploy" {
        It "should create a backup and copy new files on first deploy" {
            # Run the script
            & $script:script_path -Action Deploy -sourceDir $script:paramSourceDir -targetDir $script:paramTargetDir -backupDir $script:paramBackupDir

            # Check that the backup directory was created
            (Test-Path $script:paramBackupDir) | Should Be $true
            (Get-Content (Join-Path $script:paramBackupDir "file1.txt")) | Should Be "original_content"


            # Check that the file was copied
            (Get-Content (Join-Path $script:paramTargetDir "file1.txt")) | Should Be "source_content_v1"
            (Test-Path (Join-Path $script:paramTargetDir "file2.js")) | Should Be $true
        }

        It "should not modify an existing backup on a subsequent deploy" {
            # Arrange: create an existing backup
            New-Item -ItemType Directory -Path $script:paramBackupDir | Out-Null
            "manual_backup_content" | Set-Content -Path (Join-Path $script:paramBackupDir "file1.txt")
            $backupModificationTime = (Get-Item $script:paramBackupDir).LastWriteTime

            # Act
            & $script:script_path -Action Deploy -sourceDir $script:paramSourceDir -targetDir $script:paramTargetDir -backupDir $script:paramBackupDir

            # Assert
            $newBackupModificationTime = (Get-Item $script:paramBackupDir).LastWriteTime
            $newBackupModificationTime | Should Be $backupModificationTime
            (Get-Content (Join-Path $script:paramBackupDir "file1.txt")) | Should Be "manual_backup_content"
        }

        It "should throw an error if the source directory does not exist" {
            # Arrange
            Remove-Item $script:paramSourceDir -Recurse -Force

            # Act & Assert
            { & $script:script_path -Action Deploy -sourceDir $script:paramSourceDir -targetDir $script:paramTargetDir -backupDir $script:paramBackupDir } | Should Throw "Le répertoire source '$($script:paramSourceDir)' est introuvable. Veuillez vérifier le chemin."
        }
    }

    Context "Rollback" {
        It "should restore files from the backup" {
            # Arrange: perform a deploy first to create a valid backup
            & $script:script_path -Action Deploy -sourceDir $script:paramSourceDir -targetDir $script:paramTargetDir -backupDir $script:paramBackupDir
            "new_changed_content" | Set-Content -Path (Join-Path $script:paramTargetDir "file1.txt")

            # Act
            & $script:script_path -Action Rollback -targetDir $script:paramTargetDir -backupDir $script:paramBackupDir

            # Assert
            (Test-Path $script:paramBackupDir) | Should Be $false
            (Test-Path $script:paramTargetDir) | Should Be $true
            (Get-Content (Join-Path $script:paramTargetDir "file1.txt")) | Should Be "original_content"
        }

        It "should throw an error if the backup directory does not exist" {
            # Arrange: backup dir does not exist (it is cleaned up by BeforeEach)

            # Act & Assert
            { & $script:script_path -Action Rollback -targetDir $script:paramTargetDir -backupDir $script:paramBackupDir } | Should Throw "Répertoire de sauvegarde '$($script:paramBackupDir)' introuvable. Impossible de restaurer."
        }
    }
}