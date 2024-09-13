/*
	This script retrieves information about all indexes associated with a specific table in SQL Server,
	and can be used to identify duplicates
*/
DECLARE @object_name NVARCHAR(255);
DECLARE @schema_name NVARCHAR(255);
SET @object_name = 'my_table_name';
SET @schema_name = 'dbo';

SELECT
    indexes.name AS Index_name,
    indexes.is_unique,
    dm_db_index_usage_stats.user_seeks AS user_seeks,
    dm_db_index_usage_stats.user_scans AS user_scans,
    dm_db_index_usage_stats.user_updates AS user_updates,
    STRING_AGG(CASE WHEN index_columns.is_included_column = 0 THEN columns.name END, ', ') 
        WITHIN GROUP (ORDER BY index_columns.index_column_id) AS Index_Columns,
    STRING_AGG(CASE WHEN index_columns.is_included_column = 1 THEN columns.name END, ', ') 
        WITHIN GROUP (ORDER BY index_columns.index_column_id) AS Included_Columns
FROM
    sys.indexes
    INNER JOIN sys.objects ON indexes.object_id = objects.object_id
    INNER JOIN sys.schemas ON objects.schema_id = schemas.schema_id
    LEFT JOIN sys.dm_db_index_usage_stats ON indexes.object_id = dm_db_index_usage_stats.object_id
        AND indexes.index_id = dm_db_index_usage_stats.index_id
    LEFT JOIN sys.index_columns ON indexes.object_id = index_columns.object_id 
        AND indexes.index_id = index_columns.index_id
    LEFT JOIN sys.columns ON index_columns.object_id = columns.object_id 
        AND index_columns.column_id = columns.column_id
WHERE
    objects.name = @object_name
    AND schemas.name = @schema_name
GROUP BY 
    indexes.name,
    indexes.is_unique,
    dm_db_index_usage_stats.user_seeks,
    dm_db_index_usage_stats.user_scans,
    dm_db_index_usage_stats.user_updates
ORDER BY 
    Index_name;
