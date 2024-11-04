/*
	Enable logging of permission errors to the ErrorLog
*/
EXEC msdb.dbo.sp_altermessage 229,'WITH_LOG','true';

/*
	Show all permissions for a predefined set of SQL Server logins
*/
DECLARE @Logins TABLE (LoginName NVARCHAR(128));
INSERT INTO @Logins (LoginName)
VALUES 
    ('my_login_1'),
    ('my_login_2'),
    ('my_login_3'),
    ('my_login_4'),
    ('my_login_5');

DECLARE @LoginName NVARCHAR(100)
DECLARE @DatabaseName NVARCHAR(100)
DECLARE @SQL NVARCHAR(MAX)

IF OBJECT_ID('tempdb..#LoginPermissions') IS NOT NULL
    DROP TABLE #LoginPermissions;

CREATE TABLE #LoginPermissions
(
    LoginName NVARCHAR(128),
    PermissionType NVARCHAR(128),
    PermissionDetail NVARCHAR(MAX),
    DatabaseName NVARCHAR(128) NULL
);

DECLARE LoginCursor CURSOR FOR
SELECT LoginName FROM @Logins;

OPEN LoginCursor
FETCH NEXT FROM LoginCursor INTO @LoginName

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #LoginPermissions (LoginName, PermissionType, PermissionDetail)
    SELECT @LoginName, 'System Role', rp.name
    FROM sys.server_role_members srm
    JOIN sys.server_principals rp ON srm.role_principal_id = rp.principal_id
    JOIN sys.server_principals sp ON srm.member_principal_id = sp.principal_id
    WHERE sp.name = @LoginName;

    DECLARE DatabaseCursor CURSOR FOR
    SELECT name FROM sys.databases WHERE 
		state_desc = 'ONLINE' AND 
		database_id > 4 AND 
		user_access = 0 -- not SINGLE_USER

    OPEN DatabaseCursor
    FETCH NEXT FROM DatabaseCursor INTO @DatabaseName

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = '
        USE ' + QUOTENAME(@DatabaseName) + ';
        INSERT INTO #LoginPermissions (LoginName, PermissionType, PermissionDetail, DatabaseName)
        SELECT ''' + @LoginName + ''', ''Database Role'', dp.name, ''' + @DatabaseName + '''
        FROM sys.database_principals u
        JOIN sys.database_role_members rm ON u.principal_id = rm.member_principal_id
        JOIN sys.database_principals dp ON rm.role_principal_id = dp.principal_id
        WHERE u.type IN (''S'', ''G'') AND u.name = ''' + @LoginName + ''';'

        EXEC sp_executesql @SQL

		SET @SQL = '
		USE ' + QUOTENAME(@DatabaseName) + ';
		INSERT INTO #LoginPermissions (LoginName, PermissionType, PermissionDetail, DatabaseName)
		SELECT ''' + @LoginName + ''', 
			   ''Object Permission'', 
			   permission_name + '' ON '' + 
			   CASE 
					WHEN class_desc = ''DATABASE'' THEN ''DATABASE''
					WHEN class_desc = ''XML_SCHEMA_COLLECTION'' THEN 
						ISNULL((SELECT name FROM sys.xml_schema_collections WHERE xml_collection_id = major_id), ''Unknown XML Schema'') COLLATE DATABASE_DEFAULT
					ELSE COALESCE(SCHEMA_NAME(major_id), '''') + COALESCE(OBJECT_NAME(major_id), '''')
			   END + 
			   '' ('' + state_desc + '')'', 
			   ''' + @DatabaseName + '''
		FROM sys.database_permissions dp
		JOIN sys.database_principals p ON dp.grantee_principal_id = p.principal_id
		WHERE p.name = ''' + @LoginName + ''';';

		EXEC sp_executesql @SQL;

        FETCH NEXT FROM DatabaseCursor INTO @DatabaseName
    END

    CLOSE DatabaseCursor
    DEALLOCATE DatabaseCursor

    INSERT INTO #LoginPermissions (LoginName, PermissionType, PermissionDetail)
    SELECT @LoginName, 'Server Permission', permission_name + ' (' + state_desc + ')'
    FROM sys.server_permissions
    WHERE grantee_principal_id = (SELECT principal_id FROM sys.server_principals WHERE name = @LoginName);

    FETCH NEXT FROM LoginCursor INTO @LoginName
END

CLOSE LoginCursor
DEALLOCATE LoginCursor

SELECT * FROM #LoginPermissions
ORDER BY DatabaseName, LoginName, PermissionType, PermissionDetail;

DROP TABLE #LoginPermissions;
GO

