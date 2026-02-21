# Production-Grade Hybrid Windows Authentication

## Azure SQL Managed Instance with On-Prem Active Directory

------------------------------------------------------------------------

## Overview

This document describes a **production-ready hybrid identity
configuration** that enables domain users from On-Prem Active Directory
to authenticate to Azure SQL Managed Instance using Microsoft Entra ID
(formerly Azure AD).

> Note: Azure SQL Managed Instance does NOT support classic NTLM/SSPI
> authentication. Authentication is performed using Entra-backed
> Kerberos (Hybrid Identity).

------------------------------------------------------------------------

# 1. Architecture Design

## 1.1 Recommended Topology

On-Prem AD Domain Controller\
↓\
Member Server (Microsoft Entra Connect)\
↓\
Microsoft Entra ID\
↓\
Azure SQL Managed Instance (Private Endpoint)

------------------------------------------------------------------------

## 1.2 Security Principles

-   Do NOT install Entra Connect on Domain Controller
-   Use Password Hash Sync or Pass-through Authentication
-   Use least privilege SQL roles
-   Keep SQL MI private (no public endpoint)
-   Restrict NSG inbound rules to required subnets only
-   Enforce TLS 1.2+
-   Use Azure Private DNS zone for SQL MI resolution

------------------------------------------------------------------------

# 2. Identity Configuration

## 2.1 Entra Connect Configuration

-   Install on dedicated member server
-   Enable Password Hash Sync (recommended)
-   Enable Seamless SSO (optional but recommended)
-   Ensure UPN suffix matches verified Azure domain
-   Validate sync status

Force sync (if needed):

``` powershell
Start-ADSyncSyncCycle -PolicyType Delta
```

Verify user exists in Entra ID before proceeding.

------------------------------------------------------------------------

## 2.2 Configure Azure AD Admin on SQL MI

``` bash
az sql mi ad-admin create   --resource-group my-rg-babu   --managed-instance my-free-sql-mi   --display-name "YourAADUser"   --object-id "<AAD Object ID>"
```

------------------------------------------------------------------------

# 3. SQL Security Configuration

## 3.1 Connect as Azure AD Admin

Server: my-free-sql-mi.e5fb5eadee34.database.windows.net

Authentication: Azure Active Directory - Universal with MFA

------------------------------------------------------------------------

## 3.2 Create Login from External Provider

``` sql
CREATE LOGIN [yourdomain\username] FROM EXTERNAL PROVIDER;
GO
```

------------------------------------------------------------------------

## 3.3 Create Database User and Grant Least Privilege

``` sql
USE YourDatabaseName;
GO

CREATE USER [yourdomain\username] FROM LOGIN [yourdomain\username];
GO

ALTER ROLE db_datareader ADD MEMBER [yourdomain\username];
ALTER ROLE db_datawriter ADD MEMBER [yourdomain\username];
GO
```

Avoid using db_owner unless strictly required.

------------------------------------------------------------------------

# 4. Network & Connectivity Validation

## 4.1 DNS Resolution

``` powershell
nslookup my-free-sql-mi.e5fb5eadee34.database.windows.net
```

Must resolve to private IP.

------------------------------------------------------------------------

## 4.2 Port Connectivity

``` powershell
Test-NetConnection my-free-sql-mi.e5fb5eadee34.database.windows.net -Port 1433
```

Expected: TcpTestSucceeded : True

------------------------------------------------------------------------

## 4.3 NSG Rules

Allow inbound to SQL MI subnet:

-   Source: Web/App subnet CIDR
-   Destination Port: 1433, 11000-11999
-   Protocol: TCP
-   Direction: Inbound

No 0.0.0.0/0 access allowed.

------------------------------------------------------------------------

# 5. Kerberos Validation

On domain-joined machine:

``` powershell
whoami
klist
```

Ensure: - Logged in as domain user - Kerberos tickets present - Time
synchronization correct

------------------------------------------------------------------------

# 6. Application Configuration (.NET)

## 6.1 Required Package

Install:

Microsoft.Data.SqlClient

------------------------------------------------------------------------

## 6.2 Production Connection String

``` csharp
"Server=my-free-sql-mi.e5fb5eadee34.database.windows.net,1433;" +
"Database=YourDatabaseName;" +
"Authentication=Active Directory Integrated;" +
"Encrypt=True;" +
"TrustServerCertificate=False;" +
"Connection Timeout=30;"
```

------------------------------------------------------------------------

## 6.3 Secure Coding Example

``` csharp
using Microsoft.Data.SqlClient;

var builder = new SqlConnectionStringBuilder
{
    DataSource = "my-free-sql-mi.e5fb5eadee34.database.windows.net,1433",
    InitialCatalog = "YourDatabaseName",
    Authentication = SqlAuthenticationMethod.ActiveDirectoryIntegrated,
    Encrypt = true,
    TrustServerCertificate = false,
    ConnectTimeout = 30
};

using var connection = new SqlConnection(builder.ConnectionString);
connection.Open();
```

------------------------------------------------------------------------

# 7. Production Hardening Checklist

-   [ ] Entra Connect installed on member server
-   [ ] Azure AD Admin configured
-   [ ] Users synced and validated
-   [ ] Least privilege roles applied
-   [ ] SQL MI public endpoint disabled
-   [ ] NSG rules restricted to specific subnets
-   [ ] TLS 1.2 enforced
-   [ ] Azure Monitor enabled for SQL MI
-   [ ] Advanced Threat Protection enabled
-   [ ] Auditing enabled to Log Analytics

------------------------------------------------------------------------

# 8. Troubleshooting Guide

  ------------------------------------------------------------------------
  Issue               Cause               Resolution
  ------------------- ------------------- --------------------------------
  Error 18452         Login not created   Create login properly
                      from external       
                      provider            

  Login fails         User not synced     Force Entra sync

  Cannot resolve      DNS                 Fix Private DNS zone
  server              misconfiguration    

  Timeout error       NSG blocking port   Open 1433 internally

  SSPI error          Using Integrated    Use Active Directory Integrated
                      Security            
  ------------------------------------------------------------------------

------------------------------------------------------------------------

# 9. Important Notes

-   Classic NTLM (SSPI) authentication is NOT supported.
-   Always use Entra-backed authentication.
-   For cloud-native workloads, prefer Managed Identity.
-   Avoid over-permissioning database roles.

------------------------------------------------------------------------

End of Production-Grade Configuration Guide
