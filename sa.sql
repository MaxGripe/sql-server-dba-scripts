/*
	Find jobs not owned by 'sa'
*/
SELECT j.name, suser_sname(j.owner_sid) AS 'job_owner'
FROM msdb.dbo.sysjobs j
WHERE j.owner_sid <> 0x01 order by 1;

/*
	Find databases not owned by 'sa'
*/
SELECT d.name, suser_sname(d.owner_sid) AS 'database_owner'
FROM master.sys.databases d
WHERE suser_sname(d.owner_sid) <> 'sa' order by 1;

/*
	Auto-fix job_owner -> sa 
*/
DECLARE @job_name NVARCHAR(128);

DECLARE job_cursor CURSOR FOR
SELECT j.name
FROM msdb.dbo.sysjobs j
WHERE j.owner_sid <> 0x01;

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @job_name;

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC msdb.dbo.sp_update_job 
		@job_name = @job_name, 
		@owner_login_name = 'sa';
	
	FETCH NEXT FROM job_cursor INTO @job_name;
END;

CLOSE job_cursor;
DEALLOCATE job_cursor;

/*
	Auto-fix database_owner -> sa  
*/
DECLARE @database_name NVARCHAR(128);
DECLARE db_cursor CURSOR FOR
SELECT d.name
FROM master.sys.databases d
WHERE suser_sname(d.owner_sid) <> 'sa';

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @database_name;

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC('ALTER AUTHORIZATION ON DATABASE:: [' + @database_name + '] TO sa');
	
	FETCH NEXT FROM db_cursor INTO @database_name;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;
