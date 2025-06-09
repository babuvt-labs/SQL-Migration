-- Get row count for all user tables in the database
SELECT 
    QUOTENAME(SCHEMA_NAME(sOBJ.schema_id)) + '.' + QUOTENAME(sOBJ.name) AS [TableName],
    SUM(sdmvPTNS.row_count) AS [RowCount]
FROM 
    sys.objects AS sOBJ
    INNER JOIN sys.dm_db_partition_stats AS sdmvPTNS
        ON sOBJ.object_id = sdmvPTNS.object_id
WHERE 
    sOBJ.type = 'U'                    -- User tables only
    AND sOBJ.is_ms_shipped = 0x0      -- Exclude system tables
    AND sdmvPTNS.index_id < 2          -- Include clustered index (1) and heap (0)
GROUP BY 
    sOBJ.schema_id,
    sOBJ.name
ORDER BY 
    [TableName]
GO
