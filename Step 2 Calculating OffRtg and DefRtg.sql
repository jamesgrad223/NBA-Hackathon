--Add Action Type Description and Event Msg Type Description
With DescriptionAdded as (
	Select 
		a.[Game_id],
		a.[Event_Num],
		a.[Event_Msg_Type],
		a.[Period],
		a.[WC_Time],
		a.[PC_Time],
		a.[Action_Type],
		a.[Option1],
		a.[Option2],
		a.[Option3],
		a.[Team_id] as Merged_team_id,
		a.[Person1],
		a.[Person2],
		a.[Person3],
		a.[Team_id_type],
		a.[Person1_type],
		a.[Person2_type],
		a.[Person3_type],
		b.event_msg_type_Description,
		b.action_type_Description
	From [NBA_Hackathon].[dbo].[play_by_play] as A
	left join [NBA_Hackathon].[dbo].[Event_Codes] as B
	on 
		a.[Event_Msg_Type] = b.event_msg_type and 
		a.[Action_Type]=b.action_type
),

PointsandPossessions AS (
	Select 
	  [Game_id],
	  [Merged_Team_id],
      [Event_Num],
      [Period],
      [PC_Time],
	  --Points Scored count
       CASE 
			WHEN Event_Msg_Type_Description='Made Shot' THEN [Option1]
			WHEN Event_Msg_Type_Description='Free Throw' 
				and Option1='1' THEN [Option1]
			ELSE 0 END AS Points_Scored,
	  CASE 
	  --Possession count of Made Field Goal Attempt
			WHEN Event_Msg_type_description='Made Shot' THEN 1
	  --Possession count of Made Final Free Throw Attempt 		
			When event_msg_type_description='Free Throw' 
				and action_type in ('10', '12', '15', '16', '17', '19', '20', '22', '26', '29') 
				and option1 = 1 then 1 
	  --Possession count of Missed Final Free Throw Attempt That Results in Defensive Rebound		
			When event_msg_type_description='Free Throw' 
				and action_type in ('10', '12', '15', '16', '17', '19', '20', '22', '26', '29') 
				and option1 != 1 and lead(Merged_Team_id,1) 
				over (order by game_id asc, period asc, PC_Time desc, wc_time asc, event_num asc) != Merged_Team_id THEN 1
	  --Possession count of Missed Field Goal Attempt That Results in Defensive Rebound		
			WHEN Event_Msg_Type_Description='Missed Shot' 
				and merged_team_id != lead(Merged_Team_id,1) 
				over (order by game_id asc, period asc, PC_Time desc, wc_time asc, event_num asc) THEN 1
	  --Possession count of Turnover		
			WHEN Event_Msg_type_description='Turnover' THEN 1
	  --Possession count of End of Time Period		
			WHEN event_msg_type_Description='End Period' then 1
			ELSE 0 END AS Possession,
      [Person1],
      [Person2],
      [Event_Msg_Type_Description],
	  action_type_Description
	From DescriptionAdded 
),

--Figuring out all PC_time when a player is "Subbed-in" by game_id and period
SubIntime as (
--Figuring out Starter of each game_id and period where Starter is considered as "Subbed-in" at the beginning of the period
	Select distinct 
		b.game_id,
		b.merged_team_id,
		b.Person1,
		b.period,
		case when a.Starting_Lineup_by_Quarter 
		in ('Starter Q1','Starter Q2','Starter Q3','Starter Q4','Starter Q5','Starter Q6','Starter Q7') then '7200' 
		else 0 end as SubinPCTime
	from [NBA_Hackathon].[dbo].[Game_Lineup] as A
	left join PointsandPossessions as B 
	on 
		A.game_id=B.game_id and 
		A.Team_id = B.Merged_team_id and 
		A.person_id=B.Person1 and 
		A.period=b.Period
	
	union 

--Figuring out when a player gets "Subbed-in" during the game
	Select 
		b.game_id,
		b.merged_team_id,
		b.person2,
		b.period,
		B.PC_Time as SubinPCTime
	from [NBA_Hackathon].[dbo].[Game_Lineup] as A
	right join PointsandPossessions as B 
	on 
		A.game_id=B.game_id and
		A.Team_id = B.Merged_team_id and 
		A.person_id=B.person2 and 
		A.period=b.Period
	where 
		Event_Msg_Type_Description = 'substitution' 
),

--Figuring out all PC_time when a player is "Subbed-out" by game_id and period
Subouttime as (
	Select 
		b.game_id,
		b.merged_team_id,
		b.person1,
		b.period,
		B.PC_Time as SuboutPCTime
	from [NBA_Hackathon].[dbo].[Game_Lineup] as A
	right join PointsandPossessions as B 
	on 
		A.game_id=B.game_id and
		A.Team_id = B.Merged_team_id and
		A.person_id=B.person1 and 
		A.period=b.Period
	where 
		Event_Msg_Type_Description = 'substitution'  
),

--Combining PC_time of when player gets "Subbed-in" and "Subbed-out" by game_id and period
SubInOut as (
	Select 
		a.game_id,
		a.merged_team_id,
		a.person1,
		a.period,
		a.subinpctime,
		case when b.suboutpctime is null then '0'
		when suboutpctime > subinpctime then '0' else b.SuboutPCTime end as suboutpctime
	from subintime as a
	left join subouttime as b
	on 
		a.Game_id=b.Game_id and 
		a.Merged_Team_id=b.Merged_Team_id and 
		a.Period=b.Period and a.Person1=b.Person1 
	where 
		a.game_id is not null
),

--Figuring out the Offensive Rating of a player by game_id and person1
OffRTG as (
	select
		a.game_id,	
		a.merged_team_id,	
		a.person1,
		sum(b.points_Scored) as OFFPoints,
		sum(b.possession) as OFFPossession  
	from Subinout as A
	join PointsandPossessions as b
	on 
		a.game_id=b.game_id and 
		a.merged_team_id=b.merged_team_id and 
		a.period=b.period
	where 
		b.PC_Time < a.SubinPCTime and 
		b.PC_Time >= a.suboutpctime 
	group by 
		a.game_id,	
		a.merged_team_id,	
		a.person1
),

--Figuring out the Defensive Rating of a player by game_id and person1
DefRTG as (
	select
		a.game_id,	
		a.merged_team_id,	
		a.person1,
		sum(b.points_Scored) as DEFPoints,
		sum(b.possession) as DEFPossession  
	from Subinout as A
	join PointsandPossessions as b
	on 
		a.game_id=b.game_id and 
		a.merged_team_id!=b.merged_team_id and 
		a.period=b.period
	where 
		b.PC_Time < a.SubinPCTime and 
		b.PC_Time >= a.suboutpctime 
	group by 
		a.game_id,	
		a.merged_team_id,	
		a.person1
),

--Combining Offensive and Defensive Rating
OFFDEFRTG as (
	Select 
		a.game_id,	
		a.merged_team_id,	
		a.person1,
		a.OFFPoints,
		a.OFFPossession,
		b.DEFPoints,
		b.DEFPossession  
	FROM OffRTG as A
	join DefRTG as B 
	on 
		a.game_id=b.game_id and 
		a.person1=b.person1
)

--Final Answer
	Select 
		Game_ID,
		Person1 as Player_ID,
		round(case when OFFPoints*100/nullif(OFFPossession,0) is null then 0 else OFFPoints*100/nullif(OFFPossession,0) end,1) as OffRtg,
		round(case when DEFPoints*100/nullif(DEFPossession,0) is null then 0 else DEFPoints*100/nullif(DEFPossession,0) end,1) as DefRtg
	from OFFDEFRTG
