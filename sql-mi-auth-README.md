# Hybrid Windows (Legacy-Style) AD Authentication to Azure SQL Managed Instance

> Assumptions: - Microsoft Entra Connect is already installed and
> syncing users - Azure AD (Entra ID) Admin is already configured on the
> SQL Managed Instance - User exists in On-Prem AD and is successfully
> synced to Entra ID - VM / machine is domain joined - Network
> connectivity to SQL MI is working (Port 1433 open internally)

------------------------------------------------------------------------

# 1. Create Windows Login in SQL Managed Instance

## 1.1 Connect as Azure AD Admin

Open SSMS and connect using:

Server Name: my-free-sql-mi.e5fb5eadee34.database.windows.net

Authentication: Azure Active Directory - Password or Azure Active
Directory - Universal with MFA

------------------------------------------------------------------------

## 1.2 Create Login from External Provider

``` sql
CREATE LOGIN [yourdomain\username] FROM EXTERNAL PROVIDER;
GO
```

------------------------------------------------------------------------

## 1.3 Create Database User and Assign Role

``` sql
USE YourDatabaseName;
GO

CREATE USER [yourdomain\username] FROM LOGIN [yourdomain\username];
GO

ALTER ROLE db_owner ADD MEMBER [yourdomain\username];
GO
```

------------------------------------------------------------------------

# 2. Validate Domain & Kerberos Readiness

## 2.1 Confirm Logged-In Domain Identity

``` powershell
whoami
```

Expected format: yourdomain`\username`{=tex}

------------------------------------------------------------------------

## 2.2 Verify Kerberos Ticket

``` powershell
klist
```

------------------------------------------------------------------------

## 2.3 Verify DNS Resolution

``` powershell
nslookup my-free-sql-mi.e5fb5eadee34.database.windows.net
```

------------------------------------------------------------------------

## 2.4 Verify Port Connectivity

``` powershell
Test-NetConnection my-free-sql-mi.e5fb5eadee34.database.windows.net -Port 1433
```

Expected: TcpTestSucceeded : True

------------------------------------------------------------------------

# 3. .NET Application Connection String

Do NOT use: Integrated Security=SSPI;

------------------------------------------------------------------------

## 3.1 Required NuGet Package

Microsoft.Data.SqlClient

------------------------------------------------------------------------

## 3.2 Connection String

``` csharp
"Server=my-free-sql-mi.e5fb5eadee34.database.windows.net,1433;" +
"Database=YourDatabaseName;" +
"Authentication=Active Directory Integrated;" +
"Encrypt=True;" +
"TrustServerCertificate=False;" +
"Connection Timeout=30;"
```

------------------------------------------------------------------------

## 3.3 Example .NET Code

``` csharp
using Microsoft.Data.SqlClient;

var connectionString =
    "Server=my-free-sql-mi.e5fb5eadee34.database.windows.net,1433;" +
    "Database=YourDatabaseName;" +
    "Authentication=Active Directory Integrated;" +
    "Encrypt=True;" +
    "TrustServerCertificate=False;";

using var connection = new SqlConnection(connectionString);
connection.Open();
```

------------------------------------------------------------------------

# Important Notes

-   Machine must be domain joined
-   User must be synced to Entra ID
-   Login must be created using FROM EXTERNAL PROVIDER
-   DNS and port 1433 must be reachable
-   Time synchronization must be correct

This configuration enables modern Kerberos-backed Windows authentication
via Microsoft Entra ID.
