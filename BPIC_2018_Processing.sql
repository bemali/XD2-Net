
--CASES
-- The log contains case IDs that has multiple applications. 
--Once investigated some of the duplicated applications have process traces that are not realistic. 
--i.e having application insert document an year after application finish payment
-- thus we remove such case_ids (23 in total) and use application id as the case id

DROP TABLE IF EXISTS #CASES
SELECT
	distinct A.application AS CASEID
INTO #CASES
FROM BPIC.DBO.BPIC_2018_Payment_application_subprocess A
	JOIN (	select  Case_ID,count(distinct application) apps
			from BPIC.DBO.BPIC_2018_Payment_application_subprocess
			group by Case_ID
			having count(distinct application) = 1 ) B on A.Case_ID = B.Case_ID

--- RAW EVENTS
DROP TABLE IF EXISTS #TRACES_RAW

SELECT
	C.CASEID  AS CASEID,
	[RESOURCE] AS 'RESOURCE',
	subprocess+'_'+activity2 AS ACTIVITY,
	activity2,
	CASE 
		WHEN activity2 IN ('abort payment','finish payment') THEN 1
		ELSE 0 END AS MILESTONE_ID,
	COMPLETE_TIMESTAMP AS COMPLETE_TIMESTAMP,
	AMOUNT_APPLIED0 AS AMOUNT_REQ
INTO #TRACES_RAW
FROM BPIC.DBO.BPIC_2018_Payment_application_subprocess A
JOIN #CASES C ON A.application = C.CASEID
WHERE  LIFECYCLE_TRANSITION = 'COMPLETE'


-- OBTAIN THE END OUTCOME
-- Except for 6 cases, for all the cases in this application process, the end outcome is 'application_finish payment'.
-- Thus, we redefine the end outcome for this process if the application has encountered a 'application_abort payment' event or not. 
-- An abort payment event can occur as a result of change or objection to the original application, or taking too long to process a payment once 'application_begin payment' activity has started

DROP TABLE IF EXISTS #END_OUTCOME

drop table if exists #t1
select distinct ACTIVITY, CASEID, complete_timestamp 
into #t1
from #TRACES_RAW
where ACTIVITY in ('application_abort payment', 'application_finish payment')

drop table if exists #t2
select t1.CASEID, 
ISNULL (MIN(case when ACTIVITY = 'application_abort payment' then t1.complete_timestamp end), MAX(t1.complete_timestamp)) max_time_stamp
into #t2
from #t1 t1
group by t1.CASEID

-- hence we mark the trace end for those traces which encountered an 'application_abort payment' event to be the first encountered 'application_abort payment' event.

select t1.CASEID, t1.ACTIVITY as END_OUTCOME, t2.max_time_stamp AS TRACE_END
INTO #END_OUTCOME
from #t1 t1
join #t2 t2 on t1.CASEID = t2.CASEID and t1.Complete_Timestamp = t2.max_time_stamp




-- WITH ACTIVITY INDEX

DROP TABLE IF EXISTS #TRACES

SELECT
	T.*,
	E.END_OUTCOME AS OUTCOME,
	ROW_NUMBER ( )   OVER ( PARTITION BY T.CASEID ORDER BY COMPLETE_TIMESTAMP,MILESTONE_ID ) AS ACTIVITY_INDEX
INTO #TRACES
FROM #TRACES_RAW T
JOIN #END_OUTCOME E ON T.CASEID = E.CASEID AND T.COMPLETE_TIMESTAMP <= E.TRACE_END AND T.ACTIVITY <> E.END_OUTCOME


---OBTAIN THE ACTIVITY START TIME STAMP
-- We define the activity start time stamp as the same as complete time stamp of the previous activity

-- dropping the non required tables
DROP TABLE IF EXISTS #TRACES_RAW

DROP TABLE IF EXISTS #TRACES_REFINED

SELECT
	A.CASEID,
	A.RESOURCE,
	A.ACTIVITY,
	C.TRACE_START_TIMESTAMP,
	A.COMPLETE_TIMESTAMP AS END_TIMESTAMP,
	ISNULL(B.COMPLETE_TIMESTAMP, A.COMPLETE_TIMESTAMP) AS START_TIMESTAMP,
	A.AMOUNT_REQ,
	A.ACTIVITY_INDEX,
	CASE WHEN A.ACTIVITY_INDEX = C.TRACE_END THEN 1 ELSE 0 END AS TRACE_END,
	A.OUTCOME
INTO #TRACES_REFINED
FROM #TRACES A
	LEFT JOIN #TRACES B ON A.ACTIVITY_INDEX -1 = B.ACTIVITY_INDEX AND A.CASEID = B.CASEID
	JOIN (SELECT CASEID, MAX(ACTIVITY_INDEX) AS TRACE_END, MIN(COMPLETE_TIMESTAMP) AS TRACE_START_TIMESTAMP FROM #TRACES GROUP BY CASEID) C ON A.CASEID = C.CASEID

-- dropping the non required tables
DROP TABLE IF EXISTS #TRACES

---- FINAL SELECT
DROP TABLE IF EXISTS #FINAL_SELECT

SELECT 
A.CASEID,
A.ACTIVITY,
A.RESOURCE,
DATEDIFF(DAY,A.START_TIMESTAMP,A.END_TIMESTAMP) TASK_DURATION,
DATEDIFF(DAY,A.TRACE_START_TIMESTAMP,A.START_TIMESTAMP) TIME_ELAPSED,
A.END_TIMESTAMP,
A.ACTIVITY_INDEX,
A.AMOUNT_REQ,
A.TRACE_END,
A.OUTCOME
INTO #FINAL_SELECT
FROM #TRACES_REFINED A



SELECT *FROM #FINAL_SELECT A
--where a.activity in ('application_abort payment', 'application_finish payment')
ORDER BY A.CASEID, A.ACTIVITY_INDEX





