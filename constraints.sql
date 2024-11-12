/*
  This script identifies and re-enables untrusted foreign keys and check constraints across all writable databases, 
  optionally executing or just printing the commands based on the @PrintOnly setting.
*/

-- Setting this value to 0 will cause the script to execute
DECLARE @PrintOnly bit;
SET @PrintOnly = 1

SET NOCOUNT ON;

DECLARE @DatabaseName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

CREATE TABLE #ConstraintsToFix (
	DatabaseName NVARCHAR(128),
	SchemaName NVARCHAR(128),
	TableName NVARCHAR(128),
	ConstraintName NVARCHAR(128)
);

DECLARE db_cursor CURSOR FOR
SELECT name
FROM sys.databases
WHERE state_desc = 'ONLINE'
	AND DATABASEPROPERTYEX(name, 'Updateability') = 'READ_WRITE'
	AND name NOT IN ('master', 'tempdb', 'model', 'msdb') 
	AND is_read_only = 0;
OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = '
    INSERT INTO #ConstraintsToFix (DatabaseName, SchemaName, TableName, ConstraintName)
    SELECT
        ''' + @DatabaseName + ''' AS DatabaseName
        ,s.name AS SchemaName
        ,o.name AS TableName
        ,i.name AS ConstraintName
    FROM ' + QUOTENAME(@DatabaseName) + '.sys.foreign_keys i
    INNER JOIN ' + QUOTENAME(@DatabaseName) + '.sys.objects o ON i.parent_object_id = o.object_id
    INNER JOIN ' + QUOTENAME(@DatabaseName) + '.sys.schemas s ON o.schema_id = s.schema_id
    WHERE i.is_not_trusted = 1 AND i.is_not_for_replication = 0
        
    UNION
        
    SELECT 
        ''' + @DatabaseName + ''' AS DatabaseName
        ,s.name AS SchemaName
        ,o.name AS TableName
        ,i.name AS ConstraintName
    FROM ' + QUOTENAME(@DatabaseName) + '.sys.check_constraints i
    INNER JOIN ' + QUOTENAME(@DatabaseName) + '.sys.objects o ON i.parent_object_id = o.object_id
    INNER JOIN ' + QUOTENAME(@DatabaseName) + '.sys.schemas s ON o.schema_id = s.schema_id
    WHERE i.is_not_trusted = 1 AND i.is_not_for_replication = 0 AND i.is_disabled = 0';

    EXEC sp_executesql @SQL;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

DECLARE @DBName NVARCHAR(128);
DECLARE @SchemaName NVARCHAR(128);
DECLARE @TableName NVARCHAR(128);
DECLARE @ConstraintName NVARCHAR(128);

DECLARE constraint_cursor CURSOR FOR
SELECT DatabaseName, SchemaName, TableName, ConstraintName
FROM #ConstraintsToFix;

OPEN constraint_cursor;
FETCH NEXT FROM constraint_cursor INTO @DBName, @SchemaName, @TableName, @ConstraintName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'USE ' + QUOTENAME(@DBName) + ';
    ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
    WITH CHECK CHECK CONSTRAINT ' + QUOTENAME(@ConstraintName) + ';';

	PRINT CHAR(13) + CHAR(10);
	PRINT @SQL;

	IF @PrintOnly = 0
    BEGIN TRY
		EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        PRINT 'Error processing constraint ' + QUOTENAME(@ConstraintName) +
              ' in table ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) +
              ' in database ' + QUOTENAME(@DBName) + ': ' + ERROR_MESSAGE();
    END CATCH

    FETCH NEXT FROM constraint_cursor INTO @DBName, @SchemaName, @TableName, @ConstraintName;
END;

CLOSE constraint_cursor;
DEALLOCATE constraint_cursor;
DROP TABLE #ConstraintsToFix;
