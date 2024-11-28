/*
	Search the entire SQL instance for an object
*/
DECLARE @searchTerm NVARCHAR(100) = '%Person%'; -- Name or search pattern
DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql += '
USE [' + name + ']; 
SELECT 
    ''' + name + ''' AS DatabaseName,
    SCHEMA_NAME(o.schema_id) AS SchemaName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType,
    ISNULL(a.name, ''N/A'') AS AssemblyName
FROM 
    sys.objects o
    LEFT JOIN sys.assembly_modules m ON o.object_id = m.object_id
    LEFT JOIN sys.assemblies a ON m.assembly_id = a.assembly_id
WHERE 
    o.name LIKE ''' + @searchTerm + '''
UNION ALL
SELECT 
    ''' + name + ''' AS DatabaseName,
    NULL AS SchemaName,
    a.name AS ObjectName,
    ''ASSEMBLY'' AS ObjectType,
    ''N/A'' AS AssemblyName
FROM 
    sys.assemblies a
WHERE 
    a.name LIKE ''' + @searchTerm + '''
UNION ALL
SELECT 
    ''' + name + ''' AS DatabaseName,
    SCHEMA_NAME(x.schema_id) AS SchemaName,
    x.name AS ObjectName,
    ''XML_SCHEMA_COLLECTION'' AS ObjectType,
    ''N/A'' AS AssemblyName
FROM 
    sys.xml_schema_collections x
WHERE 
    x.name LIKE ''' + @searchTerm + '''; 
'
FROM sys.databases
WHERE state_desc = 'ONLINE';
EXEC sp_executesql @sql;
