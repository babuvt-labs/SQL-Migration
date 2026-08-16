---
layout: Conceptual
monikers:
- azuresql
- azuresql-mi
defaultMoniker: azuresql
versioningType: Ranged
title: Migrate TDE certificate from SQL Server - Azure SQL Managed Instance | Microsoft Learn
canonicalUrl: https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/tde-certificate-migrate?view=azuresql
config_moniker_range: = azuresql|| azuresql-db || azuresql-mi || azuresql-vm || fabricsql
feedback_system: Standard
feedback_product_url: https://aka.ms/sqlfeedback
uhfHeaderId: Azure
toc_preview: true
recommendations: true
breadcrumb_path: /azure/azure-sql/breadcrumb/toc.json
description: Learn how to migrate a SQL Server TDE certificate when you're migrating your SQL Server database to Azure SQL Managed Instance.
author: MladjoA
ms.author: mlandzic
ms.reviewer: mathoma, jovanpop
ms.date: 2026-03-31T00:00:00.0000000Z
ms.service: azure-sql-managed-instance
ms.subservice: security
ms.topic: how-to
ms.custom:
- sqldbrb=1
- devx-track-azurepowershell
- sfi-image-nochange
locale: en-us
document_id: 81464db1-3b91-b6dd-5ef0-45dc18cbf6f0
document_version_independent_id: 5c9cda0e-f7ef-85a0-5352-deddf0d48a93
updated_at: 2026-04-01T17:39:00.0000000Z
original_content_git_url: https://github.com/MicrosoftDocs/sql-docs-pr/blob/live/azure-sql/managed-instance/tde-certificate-migrate.md
gitcommit: https://github.com/MicrosoftDocs/sql-docs-pr/blob/cd0e3ba10f24a2be3fbe506675b3a92059849ca7/azure-sql/managed-instance/tde-certificate-migrate.md
git_commit_id: cd0e3ba10f24a2be3fbe506675b3a92059849ca7
default_moniker: azuresql
site_name: Docs
depot_name: MSDN.azure-sql
page_type: conceptual
toc_rel: ../toc.json
pdf_url_template: https://learn.microsoft.com/pdfstore/en-us/MSDN.azure-sql/{branchName}{pdfName}
feedback_help_link_type: ''
feedback_help_link_url: ''
word_count: 795
asset_id: managed-instance/tde-certificate-migrate
moniker_range_name: 7d543cd59120eb6d5015a6f340104871
monikers:
- azuresql
- azuresql-mi
item_type: Content
source_path: azure-sql/managed-instance/tde-certificate-migrate.md
cmProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/768b4698-4866-4946-8059-08ef5f568fcb
- https://authoring-docs-microsoft.poolparty.biz/devrel/cbe4ca68-43ac-4375-aba5-5945a6394c20
spProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/48a90357-592c-4146-a92b-4c2dcc560cbf
- https://authoring-docs-microsoft.poolparty.biz/devrel/ced846cc-6a3c-4c8f-9dfb-3de0e90e2742
platformId: e8563cbc-5e61-e40e-8afe-50f69e9e7e24
---

# Migrate TDE certificate from SQL Server - Azure SQL Managed Instance | Microsoft Learn

**Applies to:**![](../media/applies-to/yes-icon.svg)[Azure SQL Managed Instance](/en-us/sql/sql-server/sql-docs-navigation-guide#applies-to)

In this article, learn how to migrate the certificate before you migrate your TDE-protected SQL Server database to Azure SQL Managed Instance by using the native restore option.

When you migrate a database protected by [Transparent Data Encryption (TDE)](/en-us/sql/relational-databases/security/encryption/transparent-data-encryption) from SQL Server to Azure SQL Managed Instance by using the *native restore option*, you must first migrate the corresponding certificate before you restore the database to the SQL managed instance.

Alternatively, you can use the fully managed [Azure Database Migration Service](/en-us/data-migration/sql-server/managed-instance/database-migration-service) to seamlessly migrate both a TDE-protected database and the corresponding certificate.

This article focuses on migrating databases from SQL Server to Azure SQL Managed Instance. To move databases between SQL managed instances, see:

- [Copy-only backups](/en-us/sql/relational-databases/backup-restore/copy-only-backups-sql-server)
- [Point-in-time restore](point-in-time-restore)
- [Copy or move a database](database-copy-move-how-to)

## Prerequisites

To complete the steps in this article, you need the following prerequisites:

- [Pvk2Pfx](/en-us/windows-hardware/drivers/devtest/pvk2pfx) command-line tool installed on the on-premises server or other computer with access to the certificate exported as a file. The Pvk2Pfx tool is part of the [Enterprise Windows Driver Kit](/en-us/windows-hardware/drivers/download-the-wdk), a self-contained command-line environment.
- [Windows PowerShell](/en-us/powershell/scripting/install/installing-windows-powershell) version 5.0 or higher installed.

# [PowerShell](#tab/azure-powershell)
Make sure you have the following prerequisites:

- [Azure PowerShell module installed and updated](/en-us/powershell/azure/install-az-ps).
- [Az.Sql module](https://www.powershellgallery.com/packages/Az.Sql).

Run the following commands in PowerShell to install or update the module:

```azurepowershell
Install-Module -Name Az.Sql
Update-Module -Name Az.Sql
```

---

## Export the TDE certificate to a .pfx file

You can export the certificate directly from the source SQL Server instance, or from the certificate store if you're keeping it there.

### Export the certificate from the source SQL Server instance

The following steps export the certificate by using SQL Server Management Studio and convert it into .pfx format. The generic names *TDE\_Cert* and *full\_path* are placeholders for certificate names, file names, and paths. Replace them with the actual names.

1. In SSMS, open a new query window and connect to the source SQL Server instance.
2. Use the following script to list TDE-protected databases and get the name of the certificate protecting encryption of the database to be migrated:

    ```sql
    USE master
    GO
    SELECT db.name as [database_name], cer.name as [certificate_name]
    FROM sys.dm_database_encryption_keys dek
    LEFT JOIN sys.certificates cer
    ON dek.encryptor_thumbprint = cer.thumbprint
    INNER JOIN sys.databases db
    ON dek.database_id = db.database_id
    WHERE dek.encryption_state = 3
    ```

    [![Screenshot in SSMS that shows a list of TDE certificates.](media/tde-certificate-migrate/on-premises-certificate-list.png)](media/tde-certificate-migrate/on-premises-certificate-list.png#lightbox)
3. Execute the following script to export the certificate to a pair of files (.cer and .pvk), keeping the public and private key information:

    ```sql
    USE master
    GO
    BACKUP CERTIFICATE TDE_Cert
    TO FILE = 'c:\full_path\TDE_Cert.cer'
    WITH PRIVATE KEY (
      FILE = 'c:\full_path\TDE_Cert.pvk',
      ENCRYPTION BY PASSWORD = '<SomeStrongPassword>'
    )
    ```

    [![Screenshot in SSMS that shows the backed up TDE certificate.](media/tde-certificate-migrate/backup-on-premises-certificate.png)](media/tde-certificate-migrate/backup-on-premises-certificate.png#lightbox)
4. Use the PowerShell console to copy certificate information from a pair of newly created files to a .pfx file by using the Pvk2Pfx tool:

    ```cmd
    .\pvk2pfx -pvk c:/full_path/TDE_Cert.pvk  -pi "<SomeStrongPassword>" -spc c:/full_path/TDE_Cert.cer -pfx c:/full_path/TDE_Cert.pfx
    ```

### Export the certificate from a certificate store

If you keep the certificate in the SQL Server local machine certificate store, use the following steps to export it:

1. Open the PowerShell console and run the following command to open the Certificates snap-in of Microsoft Management Console:

    ```cmd
    certlm
    ```
2. In the Certificates MMC snap-in, expand the path **Personal** &gt; **Certificates** to see the list of certificates.
3. Right-click the certificate and select **Export**.
4. Follow the wizard to export the certificate and private key to a .pfx format.

## Upload the certificate to Azure SQL Managed Instance by using an Azure PowerShell cmdlet

Important

Use a migrated certificate only to restore the TDE-protected database. Shortly after the restore finishes, the migrated certificate is replaced by a different protector. The new protector is either a service-managed certificate or an asymmetric key from the key vault, depending on the type of TDE you set on the instance.

# [PowerShell](#tab/azure-powershell)
1. Start with preparation steps in PowerShell:

    ```azurepowershell
    # import the module into the PowerShell session
    Import-Module Az
    # connect to Azure with an interactive dialog for sign-in
    Connect-AzAccount
    # list subscriptions available and copy id of the subscription target the managed instance belongs to
    Get-AzSubscription
    # set subscription for the session
    Select-AzSubscription <subscriptionId>
    ```
2. After you complete all preparation steps, run the following commands to upload the base-64 encoded certificate to the target SQL managed instance:

    ```azurepowershell
    # If you are using PowerShell 6.0 or higher, run this command:
    $fileContentBytes = Get-Content 'C:/full_path/TDE_Cert.pfx' -AsByteStream
    # If you are using PowerShell 5.x, uncomment and run this command instead of the one above:
    # $fileContentBytes = Get-Content 'C:/full_path/TDE_Cert.pfx' -Encoding Byte
    $base64EncodedCert = [System.Convert]::ToBase64String($fileContentBytes)
    $securePrivateBlob = $base64EncodedCert  | ConvertTo-SecureString -AsPlainText -Force
    $password = "<password>"
    $securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
    Add-AzSqlManagedInstanceTransparentDataEncryptionCertificate -ResourceGroupName "<resourceGroupName>" `
        -ManagedInstanceName "<managedInstanceName>" -PrivateBlob $securePrivateBlob -Password $securePassword
    ```

---

The certificate is now available to the specified SQL managed instance, and you can restore the backup of the corresponding TDE-protected database.

Note

The uploaded certificate isn't visible in the `sys.certificates` catalog view. To confirm successful upload of the certificate, run the [RESTORE FILELISTONLY](/en-us/sql/t-sql/statements/restore-statements-filelistonly-transact-sql) command.
