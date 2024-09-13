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
    ISNULL(SUM(dm_db_index_usage_stats.user_seeks), 0) AS user_seeks,
    ISNULL(SUM(dm_db_index_usage_stats.user_scans), 0) AS user_scans,
    ISNULL(SUM(dm_db_index_usage_stats.user_updates), 0) AS user_updates,
    STRING_AGG(CASE WHEN index_columns.is_included_column = 0 THEN columns.name END, ', ') 
        WITHIN GROUP (ORDER BY index_columns.index_column_id) AS Index_Columns,
    STRING_AGG(CASE WHEN index_columns.is_included_column = 1 THEN columns.name END, ', ') 
        WITHIN GROUP (ORDER BY index_columns.index_column_id) AS Included_Columns
FROM
    sys.indexes AS indexes
    INNER JOIN sys.objects AS objects ON indexes.object_id = objects.object_id
    INNER JOIN sys.schemas AS schemas ON objects.schema_id = schemas.schema_id
    LEFT JOIN sys.dm_db_index_usage_stats AS dm_db_index_usage_stats ON indexes.object_id = dm_db_index_usage_stats.object_id
        AND indexes.index_id = dm_db_index_usage_stats.index_id
        AND dm_db_index_usage_stats.database_id = DB_ID()
    LEFT JOIN sys.index_columns AS index_columns ON indexes.object_id = index_columns.object_id 
        AND indexes.index_id = index_columns.index_id
    LEFT JOIN sys.columns AS columns ON index_columns.object_id = columns.object_id 
        AND index_columns.column_id = columns.column_id
WHERE
    objects.name = @object_name
    AND schemas.name = @schema_name
GROUP BY 
    indexes.name,
    indexes.is_unique
ORDER BY 
    6, 7;
