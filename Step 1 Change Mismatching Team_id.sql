--Change Team_id based on person1 type due to team_id not matching the correct team_id in the game_lineup csv
--Person1_type = odd, then change to team_id that correspond to team_id_type = 3
--Person1_type = even (not including 0), then change to team_id that correspond to team_id_type = 2
WITH JoinTable as (
	select distinct 
		A.Game_id,
		A.Team_id,
		case 
			when B.Person1_type = 4 then 4
			when  B.Person1_type = 5 then 5 end as Person1_type
	FROM [NBA_Hackathon].[dbo].[Game_lineup] AS A
	Inner join [NBA_Hackathon].[dbo].[Play_by_play] AS B
	on 
	A.Game_id = B.Game_id and 
	A.Team_id = B.Team_id and 
	A.person_id = B.person1
)

UPDATE [NBA_Hackathon].[dbo].[Play_by_Play]
	SET [NBA_Hackathon].[dbo].[Play_by_Play].[Team_id] = S.Team_id
	FROM JoinTable as S
	WHERE 
	S.Game_id = [NBA_Hackathon].[dbo].[Play_by_Play].Game_id	and 
	S.Person1_type = [NBA_Hackathon].[dbo].[Play_by_Play].Person1_type


--Change Period Data type to nvarchar to concatenate 
ALTER TABLE [NBA_Hackathon].[dbo].[Game_Lineup] 
	ALTER COLUMN Period nvarchar(20);

--Add a new column to identify the starter of each period by game
ALTER TABLE [NBA_Hackathon].[dbo].[Game_Lineup] 
	ADD Starting_Lineup_by_Quarter AS ('Starter' + ' ' + 'Q' + Period) 

