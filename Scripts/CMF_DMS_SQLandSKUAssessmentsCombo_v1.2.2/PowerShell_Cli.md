# Azure DMS: Elastic Pools SKU Recommendation with PowerShell & CLI

This guide explains how to use **Azure Database Migration Service (DMS)** to generate **Elastic Pool SKU recommendations** using Azure PowerShell or Azure CLI.

---

## 📽️ Demo Video

[![Watch the video](https://img.youtube.com/vi/CBbz0-XYvCI/0.jpg)](https://www.youtube.com/watch?v=CBbz0-XYvCI)

Click the thumbnail above to view a quick demo of the process.

---

## ⚙️ How to Use the Command

### 🔹 Azure PowerShell

Run the following command to generate SKU recommendations:

```powershell
Get-AzDataMigrationSkuRecommendation -OutputFolder "C:\Output" -DisplayResult -Overwrite
```

## 📁 Reviewing the Output JSON File

The output is saved in the specified output folder in JSON format. This file includes detailed SKU recommendations for Azure SQL Database, including Elastic Pools where applicable.

### 🔍 Key JSON Properties

- **`ResourceType`**  
  Indicates if the recommendation is for a `SingleDatabase` or an `ElasticPool`.

- **`PoolCount`**  
  Specifies how many Elastic Pools of a particular configuration are recommended.

- **`ElasticPoolMemberDatabases`**  
  Lists the databases that are recommended to be part of the Elastic Pool.
