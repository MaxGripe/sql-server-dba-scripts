/**********************************************************************************************/
-- When was the database restored?

SELECT
    rs.destination_database_name,
    rs.restore_date,
    bmf.physical_device_name,
    bs.backup_start_date,
    bs.backup_finish_date,
    bs.database_name,
    bs.user_name
FROM msdb.dbo.restorehistory rs
INNER JOIN msdb.dbo.backupset bs ON rs.backup_set_id = bs.backup_set_id
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE rs.destination_database_name = 'my_database_name'
ORDER BY rs.restore_date DESC;

/**********************************************************************************************/
-- Monitor ongoing RESTORE progress

SELECT 
    r.percent_complete,
    r.command,
    d.name AS database_name,
    d.state_desc,
    r.start_time
FROM 
    sys.dm_exec_requests r
CROSS APPLY 
    sys.dm_exec_sql_text(r.sql_handle) AS t
JOIN 
    sys.databases d ON t.text LIKE '%' + d.name + '%' 
WHERE 
    r.command = 'RESTORE DATABASE'
    AND d.state_desc = 'RESTORING';


/**********************************************************************************************/
/*
	History of backups from the specified database.
	If @DatabaseName is an empty string, it returns backup history for all databases.
*/
DECLARE @DatabaseName NVARCHAR(255);
SET @DatabaseName = '';

SELECT 
    bs.media_set_id,
    bs.backup_finish_date,
    bs.type,
    bs.backup_size,
    bs.compressed_backup_size,
    mf.physical_device_name
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id
WHERE (@DatabaseName = '' OR bs.database_name = @DatabaseName)
ORDER BY bs.backup_finish_date DESC;
GO


/**********************************************************************************************/
/*
	Get ETA for ongoing RESTORE
*/
DECLARE @ProgressTable TABLE (
    DatabaseName NVARCHAR(128),
    InitialProgress FLOAT,
    SecondProgress FLOAT,
    ProgressDifference FLOAT,
    EstimatedMinutes FLOAT
);
INSERT INTO @ProgressTable (DatabaseName, InitialProgress)
SELECT 
    d.name AS DatabaseName,
    r.percent_complete AS InitialProgress
FROM 
    sys.dm_exec_requests r
CROSS APPLY 
    sys.dm_exec_sql_text(r.sql_handle) AS t
JOIN 
    sys.databases d ON t.text LIKE '%' + d.name + '%'
WHERE 
    r.command = 'RESTORE DATABASE'
    AND d.state_desc = 'RESTORING';
-- Wait 10 sec
WAITFOR DELAY '00:00:10';
UPDATE @ProgressTable
SET 
    SecondProgress = t.SecondProgress
FROM 
    @ProgressTable p
INNER JOIN (
    SELECT 
        d.name AS DatabaseName,
        r.percent_complete AS SecondProgress
    FROM 
        sys.dm_exec_requests r
    CROSS APPLY 
        sys.dm_exec_sql_text(r.sql_handle) AS t
    JOIN 
        sys.databases d ON t.text LIKE '%' + d.name + '%'
    WHERE 
        r.command = 'RESTORE DATABASE'
        AND d.state_desc = 'RESTORING'
) t ON p.DatabaseName = t.DatabaseName;
UPDATE @ProgressTable
SET 
    ProgressDifference = SecondProgress - InitialProgress,
    EstimatedMinutes = CASE 
        WHEN (SecondProgress - InitialProgress) > 0 THEN 
            ((100 - SecondProgress) / (SecondProgress - InitialProgress)) * (10.0 / 60.0) -- 10 sec in mins
        ELSE 
            NULL
    END;
SELECT 
    DatabaseName,
    InitialProgress,
    SecondProgress,
    ProgressDifference,
    EstimatedMinutes AS EstimatedTimeRemainingInMinutes
FROM 
    @ProgressTable;
