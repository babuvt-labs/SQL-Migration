### **Azure SQL PaaS Database - User and Access Setup**

This guide provides the standard procedure for setting up a SQL-authenticated user in **Azure SQL Database (PaaS)** using best practices.

* * * * *

### **1\. Create Login on the `master` Database**

Run the following command **on the `master` database** to create a SQL login:

```sql
CREATE LOGIN [cleartax] WITH PASSWORD = '<YourSecurePassword>';
```

🔐 Replace `<YourSecurePassword>` with a strong and secure password.

* * * * *

### **2\. Create User and Assign Role on the User Database**

Run the following commands **on your specific user database**:

```sql
-- Create a database user mapped to the login
CREATE USER [cleartax] FOR LOGIN [cleartax];

-- Grant appropriate role to the user
ALTER ROLE db_owner ADD MEMBER [cleartax];
```

ℹ️ You may assign a different role instead of `db_owner` depending on your permission requirements (e.g., `db_datareader`, `db_datawriter`).

* * * * *

### **3\. Change Password for Existing Login**

If you need to update the password later, execute the following **on the master database**:

```sql
ALTER LOGIN [cleartax] WITH PASSWORD = '<NewSecurePassword>';
```

🔄 Replace `<NewSecurePassword>` with the new password you wish to use.

* * * * *

### **Summary & Recommendations**

-   Azure SQL Database does **not support** setting a default database for a login.

-   Always **explicitly specify the target database** when connecting via SQL Authentication.

-   This process is the **recommended and standard practice** for working with Azure SQL (PaaS) environments.
