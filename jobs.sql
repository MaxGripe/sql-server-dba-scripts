/*
	Find jobs that contain PowerShell or CmdExec steps
*/
SELECT 
    jobs.name AS job,
    steps.step_id,
    steps.step_name,
    steps.subsystem
FROM 
    msdb.dbo.sysjobsteps AS steps
INNER JOIN 
    msdb.dbo.sysjobs AS jobs
    ON steps.job_id = jobs.job_id
WHERE 
    steps.subsystem IN ('PowerShell', 'CmdExec')
order by 1,2
