## Migration Strategy Overview

**Migration Options:**
1. **Online migration** (minimal downtime) - via Azure Database Migration Service (DMS)
2. **Offline migration** (maintenance window required) - via backup/restore

## Step 1: Infrastructure Setup with Terraform## Step 2: CI/CD Pipeline Configuration## Step 3: Migration Scripts## Implementation Steps:

### 1. **Prerequisites Setup**
- Azure subscription with contributor access
- Service Principal for Terraform
- Azure DevOps organization
- Network connectivity between on-prem and Azure (VPN/ExpressRoute recommended)

### 2. **Terraform State Backend**
```bash
# Create storage for Terraform state
az group create -n rg-terraform-state -l eastus
az storage account create -n sttfstate -g rg-terraform-state -l eastus --sku Standard_LRS
az storage container create -n tfstate --account-name sttfstate
```

### 3. **Configure Azure DevOps**
- Create service connection to Azure
- Add pipeline variables (mark as secret):
  - `SQL_ADMIN_USER`
  - `SQL_ADMIN_PASSWORD`
  - `ON_PREM_SERVER`
  - `DATABASE_NAME`

### 4. **Migration Approaches**

**Option A: Offline (Backup/Restore)** - Used in the pipeline above
- Backup on-prem DB
- Upload to Azure Blob Storage
- Restore to SQL MI
- Downtime: Minutes to hours depending on size

**Option B: Online (DMS)** - Minimal downtime
```bash
# Use Azure DMS for continuous sync
az dms create-task --resource-group rg-sqlmi-production \
  --service-name dms-production \
  --task-name migration-task \
  --source-connection-json @source.json \
  --target-connection-json @target.json
```

### 5. **Key Considerations**

- **SQL MI takes 4-6 hours to provision** - Plan accordingly
- **Network Requirements**: Dedicated subnet with /24 or larger
- **Costs**: SQL MI is more expensive than SQL Database - choose appropriate SKU
- **Compatibility**: Check compatibility level (use Data Migration Assistant)
- **Cutover Plan**: Test connection strings, update applications

### 6. **Post-Migration Tasks**
- Update connection strings in applications
- Configure backups and retention
- Set up monitoring (Azure Monitor, alerts)
- Enable threat detection
- Configure firewall rules
