
-- BPIC 2017
-- Outcomes of the process 'A_Denied','O_Accepted'

drop table if exists #traces_raw
select 
	a.*,
	case 
		when a.activity = 'A_Create Application' then 0
		when a.activity in ('A_Denied','O_Accepted') then 2
		else 1 end as process_order
into  #traces_raw
from
DATASETS.dbo.BPIC_2017 a
where lifecycle_transition = 'complete'
	and a.Activity <> 'O_Refused' -- Redundant end outcome, which is the same as 'A_denied'


drop table if exists #traces
select 
	a.*, 
	row_number() over (partition by Case_ID order by Complete_Timestamp,process_order) as activity_index
into #traces
from  #traces_raw a


-- outcomes
drop table if exists #outcomes

select 
	a.Case_ID,
	a.Activity as OUTCOME,
	b.last_act as TRACE_END
	into #outcomes
from #traces a
	join( select 
			case_ID, 
			Max(activity_index) as last_act 
		   from ( select Case_ID, Activity, activity_index
			      from #traces 
			      where Activity in ('A_Denied','O_Accepted') ) a
		          group by Case_ID) b on a.activity_index = b.last_act and a.Case_ID = b.Case_ID

-- prefixes
drop table if exists #prefixes

select 
	a.Case_ID AS CASEID,
	a.Activity AS ACTIVITY,
	a.activity_index as ACTIVITY_INDEX,
	a.Resource AS 'RESOURCE',
	isnull(b.Complete_Timestamp, a.Complete_Timestamp) as START_TIMESTAMP,
	a.Complete_Timestamp as COMPLETE_TIMESTAMP,
	datediff(hour,t.TRACE_START,isnull(b.Complete_Timestamp, a.Complete_Timestamp)) TIME_ELAPSED,
	datediff(hour,isnull(b.Complete_Timestamp, a.Complete_Timestamp),a.Complete_Timestamp) TASK_DURATION,
	isnull(a.CreditScore+1,0) as CREDIT_SCORE, -- added a 1 to replace nulls with 0
	a.ApplicationType as APP_TYPE,
	a.RequestedAmount as AMT_REQ,
	isnull(t.TERMS,0) as TERMS,
	o2.OUTCOME
into #prefixes
from #traces a
	left join #traces b on a.Case_ID = b.Case_ID and a.activity_index-1 = b.activity_index
	join #outcomes o on a.Case_ID = o.Case_ID and a.activity_index < o.TRACE_END
	join #outcomes o2 on a.Case_ID = o2.Case_ID
	left join (select Case_ID, max(NumberofTerms) as TERMS, min(start_Timestamp) as TRACE_START from #traces group by Case_ID ) t on a.Case_ID = t.Case_ID
order by a.Case_ID, a.activity_index


select* from #prefixes

