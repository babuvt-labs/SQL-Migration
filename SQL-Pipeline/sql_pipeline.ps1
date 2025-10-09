# backup-database.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceServer,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory=$true)]
    [string]$BackupPath
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $BackupPath "$DatabaseName`_$timestamp.bak"

$query = @"
BACKUP DATABASE [$DatabaseName] 
TO DISK = N'$backupFile' 
WITH COMPRESSION, CHECKSUM, STATS = 10
"@

try {
    Write-Host "Starting backup of database $DatabaseName..."
    Invoke-Sqlcmd -ServerInstance $SourceServer -Query $query -QueryTimeout 0
    Write-Host "Backup completed successfully: $backupFile"
    Write-Host "##vso[task.setvariable variable=BACKUP_FILE]$backupFile"
} catch {
    Write-Error "Backup failed: $_"
    exit 1
}

# ============================================
# restore-database.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$SqlMiFqdn,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccount,
    
    [Parameter(Mandatory=$true)]
    [string]$Container,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUser,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword
)

# Get Storage Account Key
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName "rg-sqlmi-production" -Name $StorageAccount)[0].Value

# Create credential in SQL MI
$credentialName = "BackupCredential"
$blobUrl = "https://$StorageAccount.blob.core.windows.net/$Container"

$createCredentialQuery = @"
IF NOT EXISTS (SELECT * FROM sys.credentials WHERE name = '$credentialName')
BEGIN
    CREATE CREDENTIAL [$credentialName]
    WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
    SECRET = '$storageKey'
END
"@

# Find the backup file
$ctx = New-AzStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $storageKey
$backupBlob = Get-AzStorageBlob -Container $Container -Context $ctx | 
              Where-Object { $_.Name -like "$DatabaseName*.bak" } | 
              Sort-Object LastModified -Descending | 
              Select-Object -First 1

if (-not $backupBlob) {
    Write-Error "No backup file found for database $DatabaseName"
    exit 1
}

$backupUrl = "$blobUrl/$($backupBlob.Name)"

try {
    Write-Host "Creating credential in SQL MI..."
    Invoke-Sqlcmd -ServerInstance $SqlMiFqdn -Username $AdminUser -Password $AdminPassword -Query $createCredentialQuery
    
    Write-Host "Starting restore from $backupUrl..."
    
    # Get logical file names first
    $fileListQuery = "RESTORE FILELISTONLY FROM URL = N'$backupUrl'"
    $fileList = Invoke-Sqlcmd -ServerInstance $SqlMiFqdn -Username $AdminUser -Password $AdminPassword -Query $fileListQuery
    
    # Build MOVE clauses
    $moveClauses = @()
    foreach ($file in $fileList) {
        $logicalName = $file.LogicalName
        $fileType = if ($file.Type -eq 'D') { 'mdf' } else { 'ldf' }
        $moveClauses += "MOVE N'$logicalName' TO N'/var/opt/mssql/data/$DatabaseName`_$logicalName.$fileType'"
    }
    $moveString = $moveClauses -join ", "
    
    $restoreQuery = @"
RESTORE DATABASE [$DatabaseName]
FROM URL = N'$backupUrl'
WITH $moveString,
REPLACE, STATS = 10
"@
    
    Write-Host "Executing restore..."
    Invoke-Sqlcmd -ServerInstance $SqlMiFqdn -Username $AdminUser -Password $AdminPassword -Query $restoreQuery -QueryTimeout 0
    
    Write-Host "Database restored successfully"
    
} catch {
    Write-Error "Restore failed: $_"
    exit 1
}

# ============================================
# validate-migration.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceServer,
    
    [Parameter(Mandatory=$true)]
    [string]$SqlMiFqdn,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUser,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword
)

function Get-DatabaseStats {
    param($Server, $Database, $User, $Password)
    
    $query = @"
SELECT 
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE') as TableCount,
    (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0) as ProcedureCount,
    (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0) as ViewCount,
    (SELECT SUM(rows) FROM sys.partitions WHERE index_id IN (0,1)) as TotalRows
"@
    
    Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Username $User -Password $Password -Query $query
}

try {
    Write-Host "Validating migration for database $DatabaseName..."
    
    # Get stats from source
    Write-Host "Getting source database statistics..."
    $sourceStats = Get-DatabaseStats -Server $SourceServer -Database $DatabaseName -User $AdminUser -Password $AdminPassword
    
    # Get stats from target
    Write-Host "Getting target database statistics..."
    $targetStats = Get-DatabaseStats -Server $SqlMiFqdn -Database $DatabaseName -User $AdminUser -Password $AdminPassword
    
    # Compare
    Write-Host "`nComparison Results:"
    Write-Host "===================="
    Write-Host "Tables - Source: $($sourceStats.TableCount), Target: $($targetStats.TableCount)"
    Write-Host "Stored Procedures - Source: $($sourceStats.ProcedureCount), Target: $($targetStats.ProcedureCount)"
    Write-Host "Views - Source: $($sourceStats.ViewCount), Target: $($targetStats.ViewCount)"
    Write-Host "Total Rows - Source: $($sourceStats.TotalRows), Target: $($targetStats.TotalRows)"
    
    $isValid = ($sourceStats.TableCount -eq $targetStats.TableCount) -and
               ($sourceStats.ProcedureCount -eq $targetStats.ProcedureCount) -and
               ($sourceStats.ViewCount -eq $targetStats.ViewCount)
    
    if ($isValid) {
        Write-Host "`nValidation PASSED - Migration appears successful" -ForegroundColor Green
    } else {
        Write-Warning "Validation showed differences - manual verification recommended"
    }
    
} catch {
    Write-Error "Validation failed: $_"
    exit 1
}
