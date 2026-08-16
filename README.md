---
layout: Conceptual
title: 'Tutorial: Migrate SQL Server to Azure SQL Database (Offline) - Azure Database Migration Service | Microsoft Learn'
canonicalUrl: https://learn.microsoft.com/en-us/data-migration/sql-server/database/database-migration-service
breadcrumb_path: /data-migration/breadcrumb/toc.json
feedback_system: Standard
uhfHeaderId: Azure
description: Learn how to migrate on-premises SQL Server to Azure SQL Database offline by using Azure Database Migration Service.
author: rwestMSFT
ms.author: randolphwest
ms.reviewer: abhishekum, mathoma
ms.date: 2026-05-04T00:00:00.0000000Z
ms.service: azure-database-migration-service
ms.topic: tutorial
ms.collection:
- sql-migration-content
- migration
- onprem-to-azure
ms.custom:
- sfi-image-nochange
locale: en-us
document_id: 1fa1c1cd-199b-9688-0b6b-fe04cb11da04
document_version_independent_id: 1fa1c1cd-199b-9688-0b6b-fe04cb11da04
updated_at: 2026-08-04T17:38:00.0000000Z
original_content_git_url: https://github.com/MicrosoftDocs/sql-docs-pr/blob/live/data-migration/sql-server/database/database-migration-service.md
gitcommit: https://github.com/MicrosoftDocs/sql-docs-pr/blob/ff8019261a23debea4077cd0b1c9efdc57b8f0c3/data-migration/sql-server/database/database-migration-service.md
git_commit_id: ff8019261a23debea4077cd0b1c9efdc57b8f0c3
site_name: Docs
depot_name: MSDN.data-migration
page_type: conceptual
toc_rel: ../../toc.json
pdf_url_template: https://learn.microsoft.com/pdfstore/en-us/MSDN.data-migration/{branchName}{pdfName}
feedback_product_url: ''
feedback_help_link_type: ''
feedback_help_link_url: ''
word_count: 2114
asset_id: sql-server/database/database-migration-service
moniker_range_name: 
monikers: []
item_type: Content
source_path: data-migration/sql-server/database/database-migration-service.md
cmProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/7ce09da1-faab-41d3-88ef-a0ca3bd78eb7
- https://authoring-docs-microsoft.poolparty.biz/devrel/6ab7faaf-d791-4a26-96a2-3b11738538e7
- https://authoring-docs-microsoft.poolparty.biz/devrel/cbe4ca68-43ac-4375-aba5-5945a6394c20
spProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/216f2a55-66c2-40db-8770-b34875556df7
- https://authoring-docs-microsoft.poolparty.biz/devrel/302e28b0-1f09-4811-9a9b-2a72e0770581
- https://authoring-docs-microsoft.poolparty.biz/devrel/ced846cc-6a3c-4c8f-9dfb-3de0e90e2742
platformId: 9b3a4115-1f4c-3d61-6711-8d58d44587f9
---

# Tutorial: Migrate SQL Server to Azure SQL Database (Offline) - Azure Database Migration Service | Microsoft Learn

You can use Azure Database Migration Service via the Azure portal, to migrate databases from an on-premises instance of SQL Server to Azure SQL Database (offline).

In this tutorial, learn how to migrate the sample `AdventureWorks2022` database from an on-premises instance of SQL Server to Azure SQL Database, by using Database Migration Service. This tutorial uses offline migration mode, which considers an acceptable downtime during the migration process.

In this tutorial, you learn how to:

- Create an instance of Azure Database Migration Service
- Start your migration and monitor progress to completion

Important

Currently, *online* migrations for Azure SQL Database targets aren't available with Azure Database Migration Service. In an *offline* migration, application downtime starts when the migration starts. Testing an offline migration is recommended to determine whether the downtime is acceptable.

## Migration options

The following section describes how to use Azure Database Migration Service with the Azure portal.

### Prerequisites

Before you begin the tutorial:

- Ensure that you can access the [Azure portal](https://portal.azure.com).
- Make sure that the [**Microsoft.DataMigration** resource provider is registered in your subscription](/en-us/azure/dms/quickstart-create-data-migration-service-portal#register-the-resource-provider).
- Have an Azure account that's assigned to one of the following built-in roles:

    - Contributor for the target Azure SQL Database
    - Reader role for the Azure resource group that contains the target Azure SQL Database
    - Owner or Contributor role for the Azure subscription (required if you create a new instance of Azure Database Migration Service)

    As an alternative to using one of these built-in roles, you can [assign a custom role](custom-roles).
- Create a target [Azure SQL Database](/en-us/azure/azure-sql/database/single-database-create-quickstart).
- The source SQL Server login must be a member of the **db\_datareader** role on the source database and have the **VIEW ANY DEFINITION** server permission. The target SQL Server login must be a member of the db\_owner role on the target database.
- To migrate the database Schema from the source to the target Azure SQL Database by using the Database Migration Service, the minimum supported [SHIR version](https://www.microsoft.com/download/details.aspx?id=39717) required is 5.37 or above.
- For schema migration, minimum permissions on the source SQL Server is **db\_owner** to access the database and on the target Azure SQL Database, the user should be member of the all the **server level roles** in the following table:

| Roles | Description |
| --- | --- |
| **##MS\_DatabaseManager##** | Members of the **##MS\_DatabaseManager##** fixed server role can create and delete databases. A member of the **##MS\_DatabaseManager##** role that creates a database becomes the owner of that database, which allows that user to connect to that database as the dbo user. The dbo user has all database permissions in the database. Members of the **##MS\_DatabaseManager##** role don't necessarily have permission to access databases that they don't own. Use this server role instead of the **dbmanager** fixed database role that exists in `master`. |
| **##MS\_DatabaseConnector##** | Members of the **##MS\_DatabaseConnector##** fixed server role can connect to any database without requiring a user account in the database to connect with. |
| **##MS\_DefinitionReader##** | Members of the **##MS\_DefinitionReader##** fixed server role can read all catalog views that are covered by `VIEW ANY DEFINITION` on any database on which the member of this role has a user account. |
| **##MS\_LoginManager##** | Members of the **##MS\_LoginManager##** fixed server role can create and delete logins. It's recommended to use this server role over the **loginmanager** database level role that exists in the `master` database. |

### Prepare the target Azure SQL Database

To create the login and user on the target Azure SQL Database, run the following script on the `master` database:

```sql
CREATE LOGIN testuser WITH PASSWORD = '<password>';

ALTER SERVER ROLE ##MS_DefinitionReader## ADD MEMBER [testuser];
GO

ALTER SERVER ROLE ##MS_DatabaseConnector## ADD MEMBER [testuser];
GO

ALTER SERVER ROLE ##MS_DatabaseManager## ADD MEMBER [testuser];
GO

ALTER SERVER ROLE ##MS_LoginManager## ADD MEMBER [testuser];
GO

CREATE USER testuser FOR LOGIN testuser;
EXECUTE sp_addRoleMember 'dbmanager', 'testuser';
EXECUTE sp_addRoleMember 'loginmanager', 'testuser';
```

Now, you can migrate both the database schema and data using Database Migration Service. You can also use other tools such as the [SQL Database Projects extension](/en-us/sql/tools/sql-database-projects/sql-database-projects#original-projects-vs-sdk-style-projects) in Visual Studio Code to migrate the schema before selecting the list of tables to migrate.

Note

If no tables exist on the Azure SQL Database target, or no tables are selected before starting the migration, the **Next** button isn't available to initiate the migration. If no table exists on the target, then you must select the schema migration option to move forward.

### Create a Database Migration Service instance

**Step 1:** In the [Azure portal](https://portal.azure.com/#browse/Microsoft.DataMigration%2Fservices), navigate to the **Azure Database Migration Service** page. Create a new instance of Azure Database Migration Service, or reuse an existing instance that you created earlier.

#### Use an existing instance of Database Migration Service

To use an existing instance of Database Migration Service:

- On Azure portal, under **Azure Database Migration Services**, select an existing instance of Database Migration Service that you want to use, ensuring that it's present in right Resource Group and region.

    [![Screenshot that shows Database Migration Service overview.](../../includes/media/create-database-migration-service-instance/dms-portal-overview.png)](../../includes/media/create-database-migration-service-instance/dms-portal-overview.png#lightbox)

#### Create a new instance of Database Migration Service

To create a new instance of Database Migration Service:

1. On Azure portal, under **Azure Database Migration Service**, select **Create**.

    [![Screenshot that shows Database Migration Service create option.](../../includes/media/create-database-migration-service-instance/dms-portal-create.png)](../../includes/media/create-database-migration-service-instance/dms-portal-create.png#lightbox)
2. In **Select migration scenario and Database Migration Service**, select the desired input like Source and Target server type, choose **Database Migration Service** and choose **Select**.

    ![Screenshot that shows Database Migration Service Migration scenarios.](../../includes/media/create-database-migration-service-instance/dms-portal-select-migration.png)
3. On the next screen **Create Data Migration Service**, select your subscription and resource group, then select **Location**, and enter the Database Migration Service name. Select **Review + Create**. This creates the Azure Database Migration Service.

    ![Screenshot that shows Database Migration Service required input details.](../../includes/media/create-database-migration-service-instance/dms-portal-input-details.png)
4. If the self-hosted integration runtime (SHIR) is required, on the overview page of your Database Migration Service and under Settings, select **Integration runtime**, and complete the following steps:

    1. Select **Configure integration runtime** and choose the **[Download and install integration runtime](https://aka.ms/sql-migration-shir-download)** link to open the download link in a web browser. Download the integration runtime, and then install it on a computer that meets the prerequisites for connecting to the source SQL Server instance. For more information, see [Self-hosted integration runtime for database migrations](../self-hosted-integration-runtime).

        [![Screenshot that shows the Download and install integration runtime link.](../../includes/media/create-database-migration-service-instance/dms-portal-shir-configure.png)](../../includes/media/create-database-migration-service-instance/dms-portal-shir-configure.png#lightbox)

        When installation is finished, Microsoft Integration Runtime Configuration Manager automatically opens to begin the registration process.
    2. In the **Authentication key** table, copy one of the authentication keys that are provided in the wizard and paste it in Microsoft Integration Runtime Configuration Manager.

        [![Screenshot that highlights the authentication key table in the wizard.](../../includes/media/create-database-migration-service-instance/dms-portal-shir-authentication-key.png)](../../includes/media/create-database-migration-service-instance/dms-portal-shir-authentication-key.png#lightbox)

        If the authentication key is valid, a green check icon appears in Integration Runtime Configuration Manager. A green check indicates that you can continue to **Register**.

        After you register the self-hosted integration runtime, close Microsoft Integration Runtime Configuration Manager. It might take several minutes to reflect the Node details on Azure portal for Database Migration Service, under **Settings &gt; Integration runtime**.

        [![Screenshot that highlights SHIR status on Azure portal.](../../includes/media/create-database-migration-service-instance/dms-portal-shir-status.png)](../../includes/media/create-database-migration-service-instance/dms-portal-shir-status.png#lightbox)

        Note

        For more information about the self-hosted integration runtime, see [Create and configure a self-hosted integration runtime](/en-us/azure/data-factory/create-self-hosted-integration-runtime).

### Start a new migration

1. To start a new migration, go to [Azure Database Migration Service](https://portal.azure.com) in the Azure portal, and either use **+Create** to create a new instance of Database Migration Service, or select an existing instance, and then go to your Azure Database Migration Service instance.
2. On the **Overview** pane of your Azure Database Migration Service instance, select **New migration**:

    [![Screenshot of Azure Database Migration Dashboard.](media/database-migration-service/dms-portal-sql-database-dashboard-4-new.png)](media/database-migration-service/dms-portal-sql-database-dashboard-4-new.png#lightbox)
3. Under **Select new migration** scenario, choose your source, target server type, migration mode and choose **Select**.

    [![Screenshot of select new migration scenario.](media/database-migration-service/dms-portal-sql-database-scenario-new.png)](media/database-migration-service/dms-portal-sql-database-scenario-new.png#lightbox)
4. On the **Azure SQL Database Offline Migration Wizard**, follow these steps:

    1. On the **Source details** tab, enter details for the source SQL Server instance, and then select **Next: Connect to source SQL Server**:

        [![Screenshot of Source Tracking.](media/database-migration-service/dms-portal-sql-database-source-1-new.png)](media/database-migration-service/dms-portal-sql-database-source-1-new.png#lightbox)
    2. On the **Connect to source SQL Server** tab, provide connection details and then select **Next: Select databases for migration**:

        [![Screenshot of Connect to source.](media/database-migration-service/dms-portal-sql-database-source-2-new.png)](media/database-migration-service/dms-portal-sql-database-source-2-new.png#lightbox)
    3. On the **Select databases for migration** tab, check the box next to the databases you want to migrate. Populating the list of databases can take some time. Select **Next: Connect to target Azure SQL Database**.

        [![Screenshot of select db.](media/database-migration-service/dms-portal-sql-database-select-db-1-new.png)](media/database-migration-service/dms-portal-sql-database-select-db-1-new.png#lightbox)
    4. On the **Connect to target Azure SQL Database** tab, provide connection details and then select **Next: Map source and target databases**:

        [![Screenshot of connect target.](media/database-migration-service/dms-portal-sql-database-connect-target-1-new.png)](media/database-migration-service/dms-portal-sql-database-connect-target-1-new.png#lightbox)
    5. On the **Map source and target databases** tab, map the databases between the source and target.

        [![Screenshot of Map databases.](media/database-migration-service/dms-portal-sql-database-map-db-1-new.png)](media/database-migration-service/dms-portal-sql-database-map-db-1-new.png#lightbox)
    6. (Optional) Check the box next to **Migrate Missing schema** to deploy missing schema objects from the source to the Azure SQL Database target to migrate the following schema objects with a *single checkbox*:

        - Schemas
        - Tables (selected)
        - Indexes
        - Views
        - Stored procedures (StoredProcedures)
        - Synonyms
        - DDL triggers (DdlTriggers)
        - Defaults
        - Full text catalogs (FullTextCatalogs)
        - Plan guides (PlanGuides)
        - Roles
        - Rules
        - Application roles (ApplicationRoles)
        - User defined aggregates (UserDefinedAggregates)
        - User defined data types (UserDefinedDataTypes)
        - User defined functions (UserDefinedFunctions)
        - User defined table types (UserDefinedTableTypes)
        - User defined types (UserDefinedTypes)
        - Users\* (not every user type)
        - XmlSchemaCollections

        Note

        - If you select **Migrate Missing Schema**, the Database Migration service performs the schema migration before data is migrated.
        - DMS proceeds with the data migration phase even if schema migration encounters errors, unless there are issues with table objects.

        Next, either use **Select all tables** to migrate all tables, or use the text entry box to filter the list of tables and select individual tables to migrate. Then select **Next: Database migration summary**.

        [![Screenshot of select schema and tables.](media/database-migration-service/dms-portal-sql-database-select-schema-table-new.png)](media/database-migration-service/dms-portal-sql-database-select-schema-table-new.png#lightbox)
    7. On the **Database migration summary** tab, review the details and then select **Start migration**, which starts database migration and automatically takes you back to the Database Migration Service dashboard.

        [![Screenshot of Summary.](media/database-migration-service/dms-portal-sql-database-summary-new.png)](media/database-migration-service/dms-portal-sql-database-summary-new.png#lightbox)

        Note

        For an offline migration, application downtime starts when the migration starts.

### Monitor the database migration

1. To monitor your database migration, on the **Overview** pane of your Database Migration Service instance, select **Monitor migrations**.

    [![Screenshot of Azure Database Migration Service overview in the Azure portal.](media/database-migration-service/dms-portal-sql-database-dashboard-4-new.png)](media/database-migration-service/dms-portal-sql-database-dashboard-4-new.png#lightbox)
2. Under the **Migrations** tab, you can track migrations that are in progress, completed, and failed (if any), or you can view all database migrations. In the menu bar, select **Refresh** to update the migration status.

    [![Screenshot of DMS dashboard monitoring.](media/database-migration-service/dms-portal-sql-database-dashboard-3-new.png)](media/database-migration-service/dms-portal-sql-database-dashboard-3-new.png#lightbox)

    Database Migration Service returns the latest known migration status each time migration status refreshes. The following table describes possible statuses:

    | Status | Description |
    | --- | --- |
    | **Creating** | The service is starting the migration. |
    | **Preparing for copy** | The service is disabling autostats, triggers, and indexes in the target table. |
    | **Copying** | Data is being copied from the source database to the target database. |
    | **Copy finished** | Data copy is finished. The service is waiting on other tables to finish copying to begin the final steps to return tables to their original schema. |
    | **Rebuilding indexes** | The service is rebuilding indexes on target tables. |
    | **Succeeded** | All data is copied and the indexes are rebuilt. |
3. Under **Source name**, select a database name to open the table view.. In this detailed view, you see the current status of the migration, the number of tables that currently are in that status, and a detailed status of each table:

    [![Screenshot of Detailed migration monitoring.](media/database-migration-service/dms-portal-sql-database-monitoring-1-new.png)](media/database-migration-service/dms-portal-sql-database-monitoring-1-new.png#lightbox)
4. When all table data is migrated to the Azure SQL Database target, Database Migration Service updates the migration status from **In progress** to **Succeeded**.

    [![Screenshot of Detailed migration success.](media/database-migration-service/dms-portal-sql-database-monitoring-2-new.png)](media/database-migration-service/dms-portal-sql-database-monitoring-2-new.png#lightbox)

Note

Database Migration Service optimizes migration by skipping tables with no data (0 rows). Tables that don't have data don't appear in the list, even if you selected the tables when you created the migration.

You've completed the migration to Azure SQL Database. Go through a series of post-migration tasks to ensure that everything functions smoothly and efficiently.

## Limitations

Azure SQL Database offline migration utilizes Azure Data Factory (ADF) pipelines for data movement and thus abides by ADF limitations. A corresponding ADF is created when a database migration service is also created. Thus factory limits apply per service.

- The machine where the SHIR is installed acts as the compute for migration. Make sure this machine can handle the cpu and memory load of the data copy. To learn more, review [Create and configure a self-hosted integration runtime](/en-us/azure/data-factory/create-self-hosted-integration-runtime).
- 100,000 table per database limit.
- 10,000 concurrent database migrations per service.
- Migration speed heavily depends on the target Azure SQL Database SKU and the self-hosted Integration Runtime host.
- Azure SQL Database migration scales poorly with table numbers due to ADF overhead in starting activities. If a database has thousands of tables, the startup process of each table might take a couple of seconds, even if they're composed of one row with 1 bit of data.
- Azure SQL Database table names with double-byte characters currently aren't supported for migration. Mitigation is to rename tables before migration; they can be changed back to their original names after successful migration.
- Tables with large blob columns might fail to migrate due to timeout.
- Database names with SQL Server reserved are currently not supported.
- Database names that include semicolons are currently not supported.
- Computed columns don't get migrated.
- Columns in the source database that have default constraints and contain `NULL` values, are migrated with their defined default values on the target Azure SQL database, rather than retaining the NULLs.
- If your source database has [change data capture](/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server) (CDC) enabled and you are using Azure Database Migration Service (Azure DMS) for schema migration, you should disable CDC on the source database before starting the migration. If CDC isn't disabled beforehand, Azure DMS will migrate CDC-related objects (such as tables) to the target. This can cause problems when attempting to enable CDC on the target database post-migration.
