-- OBJECTIVE QUESTION QUERIES :
-- Question 1 
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema  = 'ipl' 
AND table_name = 'ball_by_ball' ;

-- Question 2
WITH runs_scored_by_batsman AS (
	SELECT
	SUM(CASE WHEN toss_winner = 2 AND toss_decide = 1 AND b.innings_no = 2 THEN runs_scored
			 WHEN toss_winner = 2 AND toss_decide = 2 AND b.innings_no = 1 THEN runs_scored 
			 WHEN toss_winner <> 2 AND toss_decide = 1 AND b.innings_no = 1 THEN runs_scored
			 WHEN toss_winner <> 2  AND toss_decide = 2 AND b.innings_no = 2 THEN runs_scored 
	 END ) AS total_batsman_runs
	FROM matches m JOIN batsman_scored b ON m.match_id = b.match_id 
	WHERE season_id = 1
	AND ( team_1 = 2 or team_2 = 2 ) ),
    
Extra_runs_scored AS ( 
SELECT
SUM(CASE WHEN toss_winner = 2 AND toss_decide = 1 AND e.innings_no = 2 THEN e.extra_runs
		 WHEN toss_winner = 2 AND toss_decide = 2 AND e.innings_no = 1 THEN e.extra_runs
		 WHEN toss_winner <> 2 AND toss_decide = 1 AND e.innings_no = 1 THEN e.extra_runs
		 WHEN toss_winner <> 2  AND toss_decide = 2 AND e.innings_no = 2 THEN e.extra_runs
 END ) as total_extra_runs 
from matches m JOIN extra_runs e ON m.match_id = e.match_id 
WHERE season_id = 1
AND ( team_1 = 2 or team_2 = 2 ) )

SELECT ( total_extra_runs + total_batsman_runs ) as total_rcb_runs
FROM extra_runs_scored, runs_scored_by_batsman ;

-- Question 3
SELECT count(player_name) AS player_above25_count
FROM player 
WHERE (SELECT season_year FROM season WHERE season_id = 2) - EXTRACT(YEAR FROM dob) > 25 ;

-- Question 4
SELECT count(match_id) as matches_won
FROM matches m 
WHERE season_id = 1 and match_winner = 2 ;

-- Question 5
WITH last_4_season_matches AS ( 
SELECT m.match_id FROM matches m
JOIN season s ON m.season_id = s.season_id
WHERE s.season_id IN (6,7,8,9) )

SELECT player_name, (runs_scored/balls_faced)*100 AS strike_rate FROM (
SELECT b.striker, COUNT(b.ball_id) AS balls_faced, SUM(bt.runs_scored) as runs_scored
FROM ball_by_ball b 
JOIN batsman_scored bt ON
b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id  
AND b.innings_no = bt.innings_no
JOIN last_4_season_matches t1 ON b.match_id = t1.match_id
GROUP BY striker ) t1 
JOIN player p ON p.player_id = striker
WHERE balls_faced > 100
ORDER BY strike_rate DESC LIMIT 10 ;
       

-- Question 6
SELECT player_name, ROUND((runs_scored/matches),2) AS avg_runs_per_season FROM (
SELECT striker, sum(runs_scored) as runs_scored, COUNT(distinct b.match_id) AS matches
FROM ball_by_ball b join batsman_scored bt on
b.match_id = bt.match_id AND b.over_id = bt.over_id AND bt.ball_id = b.ball_id
AND bt.innings_no = b.innings_no
GROUP BY striker ) p1 JOIN player p ON p1.striker = p.player_id
ORDER BY avg_runs_per_season DESC ;

-- Question 7
WITH runs_conceded AS (
SELECT bowler, SUM(runs_scored) AS runs_conceded FROM ball_by_ball b 
JOIN batsman_scored bt ON b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id
AND b.innings_no = bt.innings_no
GROUP BY bowler )

SELECT player_name, runs_conceded/wickets_taken AS bowling_avg_season FROM (
SELECT b.bowler, COUNT(player_out) AS wickets_taken, runs_conceded 
FROM ball_by_ball b JOIN wicket_taken w ON
b.match_id = w.match_id AND b.over_id = w.over_id AND b.ball_id = w.ball_id
AND b.innings_no = w.innings_no JOIN runs_conceded r ON r.bowler = b.bowler
WHERE kind_out NOT IN (3,5,9)
GROUP BY bowler HAVING COUNT(player_out) > 20 ) p1 JOIN player p ON p1.bowler = p.player_id 
ORDER BY bowling_avg_season DESC ;

-- Question 8
WITH average_runs_table as (
SELECT AVG(runs_scored) as average_runs FROM (
SELECT player_name, runs_scored FROM (
SELECT striker, sum(runs_scored) as runs_scored 
FROM ball_by_ball b join batsman_scored bt on
b.match_id = bt.match_id AND b.over_id = bt.over_id AND bt.ball_id = b.ball_id
AND bt.innings_no = b.innings_no
GROUP BY striker ) p1 JOIN player p ON p1.striker = p.player_id ) t1 ),

player_greater_than_overall_average_score AS (
SELECT player_name FROM (
SELECT player_name, runs_scored AS avg_runs_per_season FROM (
SELECT striker, sum(runs_scored) as runs_scored 
FROM ball_by_ball b join batsman_scored bt on
b.match_id = bt.match_id AND b.over_id = bt.over_id AND bt.ball_id = b.ball_id
AND bt.innings_no = b.innings_no
GROUP BY striker 
HAVING runs_scored > ( SELECT average_runs FROM average_runs_table )) p1
JOIN player p ON p1.striker = p.player_id ) t1 ),

average_wickets_table AS (
SELECT AVG(wickets_taken) as average_wickets FROM (
SELECT player_name, wickets_taken FROM (
SELECT bowler, count(player_out) as wickets_taken
FROM ball_by_ball b JOIN wicket_taken w ON
b.match_id = w.match_id AND b.over_id = w.over_id AND b.ball_id = w.ball_id
AND b.innings_no = w.innings_no
WHERE kind_out NOT IN (3,5,9)
GROUP BY bowler ) p1 JOIN player p ON p1.bowler = p.player_id ) t1 ) ,

player_greater_than_overall_avg_wickets AS (
SELECT player_name,wickets_taken AS avg_wickets FROM (
SELECT bowler, count(player_out) as wickets_taken
FROM ball_by_ball b JOIN wicket_taken w ON
b.match_id = w.match_id AND b.over_id = w.over_id AND b.ball_id = w.ball_id
AND b.innings_no = w.innings_no
WHERE kind_out NOT IN (3,5,9)
GROUP BY bowler 
HAVING wickets_taken > ( SELECT average_wickets FROM average_wickets_table ) ) p1 
JOIN player p ON p1.bowler = p.player_id )

SELECT r.player_name FROM player_greater_than_overall_average_score r 
WHERE r.player_name IN ( SELECT w.player_name FROM player_greater_than_overall_avg_wickets w ) ;

-- Question 9
SELECT v.venue_name,
       COUNT(CASE WHEN match_winner = 2 THEN 1 END ) AS rcb_wins,
       COUNT(CASE WHEN match_winner <> 2 THEN 1 END ) AS rcb_loses
FROM matches m JOIN venue v ON m.venue_id = v.venue_id
WHERE m.team_1 = 2 OR m.team_2 = 2
GROUP BY v.venue_id ;

-- Question 10
SELECT bs.bowling_skill AS bowling_style, wickets_taken FROM (
SELECT bowling_skill, SUM(wickets_taken) AS wickets_taken FROM (
SELECT bowler, count(player_out) as wickets_taken
FROM ball_by_ball b JOIN wicket_taken w ON
b.match_id = w.match_id AND b.over_id = w.over_id AND b.ball_id = w.ball_id
AND b.innings_no = w.innings_no
WHERE kind_out NOT IN (3,5,9)
GROUP BY bowler ) p1
JOIN player p ON p1.bowler = p.player_id 
GROUP BY bowling_skill ) t1
JOIN bowling_style bs ON t1.bowling_skill = bs.bowling_id
ORDER BY wickets_taken DESC ;

-- Question 11

WITH runs_scored_by_batsman AS (
	SELECT season_id,
	SUM(CASE WHEN toss_winner = 2 AND toss_decide = 1 AND b.innings_no = 2 THEN runs_scored
			 WHEN toss_winner = 2 AND toss_decide = 2 AND b.innings_no = 1 THEN runs_scored 
			 WHEN toss_winner <> 2 AND toss_decide = 1 AND b.innings_no = 1 THEN runs_scored
			 WHEN toss_winner <> 2  AND toss_decide = 2 AND b.innings_no = 2 THEN runs_scored 
	    END ) AS total_batsman_runs
	FROM matches m
    JOIN batsman_scored b ON m.match_id = b.match_id 
    WHERE team_1 = 2 or team_2 = 2 
    GROUP BY season_id),
Extra_runs_scored AS ( 
SELECT season_id,
SUM(CASE WHEN toss_winner = 2 AND toss_decide = 1 AND e.innings_no = 2 THEN e.extra_runs
		 WHEN toss_winner = 2 AND toss_decide = 2 AND e.innings_no = 1 THEN e.extra_runs
		 WHEN toss_winner <> 2 AND toss_decide = 1 AND e.innings_no = 1 THEN e.extra_runs
		 WHEN toss_winner <> 2  AND toss_decide = 2 AND e.innings_no = 2 THEN e.extra_runs
    END ) as total_extra_runs 
FROM matches m 
JOIN extra_runs e ON m.match_id = e.match_id 
WHERE team_1 = 2 or team_2 = 2
GROUP BY season_id ) ,
runs_scored_by_rcb AS (
select a.season_id, total_batsman_runs+total_extra_runs AS total_team_runs
FROM Extra_runs_scored a
JOIN runs_scored_by_batsman b ON a.season_id = b.season_id)
    
SELECT t1.season_id, 
CASE WHEN t1.season_id = 1 THEN NULL
     WHEN total_team_runs > previous_year_runs THEN 'Better'
     ELSE 'Worse' END AS batting_performance FROM (
SELECT a.season_id, total_team_runs,
LAG(total_team_runs) OVER(ORDER BY season_id) AS previous_year_runs
FROM runs_scored_by_rcb a ) t1 ;

-- Bowling Performance 

With wickets_taken_by_rcb AS (
SELECT m.season_id,
COUNT(CASE WHEN m.toss_winner = 2 and toss_decide = 1 AND innings_no = 1 THEN ball_id
		   WHEN m.toss_winner = 2 and toss_decide = 2 AND innings_no = 2 THEN ball_id
		   WHEN m.toss_winner <> 2 and toss_decide = 1 AND innings_no = 2 THEN ball_id
		   WHEN m.toss_winner <> 2 and toss_decide = 2 AND innings_no = 1 THEN ball_id 
	  END ) AS wickets_taken
FROM matches m
JOIN wicket_taken w ON m.match_id = w.match_id
WHERE m.team_1 = 2 OR m.team_2 = 2
GROUP BY season_id )

SELECT t2.season_id, 
CASE WHEN t2.season_id = 1 THEN NULL 
     WHEN wickets_taken > previous_year_wickets THEN 'Better'
     ELSE 'Worse' END AS bowling_performance FROM (
SELECT a.season_id, wickets_taken,
LAG(wickets_taken) OVER(ORDER BY season_id) AS previous_year_wickets
FROM wickets_taken_by_rcb a ) t2 ;

-- Question 12
WITH last_2_season_matches AS ( 
SELECT m.match_id FROM matches m
JOIN season s ON m.season_id = s.season_id
WHERE s.season_id IN (8,9) )

SELECT player_name, (runs_scored/balls_faced)*100 AS strike_rate FROM (
SELECT b.striker, COUNT(b.ball_id) AS balls_faced, SUM(bt.runs_scored) as runs_scored
FROM ball_by_ball b 
JOIN batsman_scored bt ON
b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id  
AND b.innings_no = bt.innings_no
JOIN last_2_season_matches t1 ON b.match_id = t1.match_id
GROUP BY striker ) t1 
JOIN player p ON p.player_id = striker
WHERE balls_faced > 100
ORDER BY strike_rate DESC LIMIT 10 ;

-- Question 13
WITH wickets_taken as (
SELECT m.match_id, COUNT(m.ball_id) AS wickets , bowler, venue_id
FROM wicket_taken m
JOIN ball_by_ball b 
ON m.match_id = b.match_id AND m.over_id = b.over_id AND m.ball_id = b.ball_id AND m.innings_no = b.innings_no
JOIN matches on m.match_id = matches.match_id 
GROUP BY bowler, venue_id, m.match_id )


SELECT venue_name, player_name,
ROUND(AVG(wickets),1) AS Average_wickets_taken,
DENSE_RANK() OVER( PARTITION BY venue_name ORDER BY ROUND(AVG(wickets),1) DESC ) AS bowler_ranking
FROM wickets_taken w JOIN player p ON p.player_id = bowler 
JOIN venue v ON v.venue_id = w.venue_id
GROUP BY player_name, venue_name 
ORDER BY player_name;

-- Question 14
-- Top performing batsman ( top_performing_batsman)

WITH t1 as (
SELECT b.striker, mt.season_id, sum(m.runs_scored) as runs_scored
FROM batsman_scored m
JOIN ball_by_ball b ON b.match_id = m.match_id AND m.over_id = b.over_id AND b.ball_id = m.ball_id
AND m.innings_no = b.innings_no
JOIN matches mt ON mt.match_id = m.match_id WHERE season_id IN (7,8,9)
GROUP BY b.striker, mt.season_id ),

t2 AS (
SELECT player_name, runs_scored AS runs_scored_this_season, season_id,
LEAD(runs_scored) OVER(PARTITION BY player_name ORDER BY season_id DESC ) AS runs_scored_previous_season
FROM t1
JOIN player p ON t1.striker = p.player_id ),

t3 AS (
SELECT player_name, runs_scored_this_season, runs_scored_previous_season,
LEAD(runs_scored_previous_season) OVER(partition by player_name ORDER BY season_id DESC ) AS runs_scored_previous_to__season
FROM t2) 

SELECT  player_name, runs_scored_this_season, runs_scored_previous_season,runs_scored_previous_to__season
FROM t3
ORDER BY (runs_scored_this_season + runs_scored_previous_season + runs_scored_previous_to__season ) DESC LIMIT 10  ;

-- Top performing bowlers ( View created top_performing_bowlers)
WITH t1 as (
SELECT b.bowler, mt.season_id, COUNT(m.ball_id) as wickets_taken
FROM wicket_taken m
JOIN ball_by_ball b ON b.match_id = m.match_id AND m.over_id = b.over_id AND b.ball_id = m.ball_id
AND m.innings_no = b.innings_no
JOIN matches mt ON mt.match_id = m.match_id WHERE season_id IN (7,8,9) AND kind_out NOT IN (3,5,9)
GROUP BY b.bowler, mt.season_id ),

t2 AS (
SELECT player_name, wickets_taken AS wickets_taken_this_season, season_id,
LEAD(wickets_taken) OVER(PARTITION BY player_name ORDER BY season_id DESC ) AS wickets_taken_previous_season
FROM t1
JOIN player p ON t1.bowler = p.player_id ),

t3 AS (
SELECT player_name, wickets_taken_this_season, wickets_taken_previous_season,
LEAD(wickets_taken_previous_season) OVER(partition by player_name ORDER BY season_id DESC ) AS wickets_taken_previous_to_previous_season
FROM t2) 

SELECT  player_name, wickets_taken_this_season, wickets_taken_previous_season,wickets_taken_previous_to_previous_season
FROM t3
ORDER BY (wickets_taken_this_season + wickets_taken_previous_season + wickets_taken_previous_to_previous_season ) DESC LIMIT 10  ;

-- Question 15
SELECT  venue_name, ROUND(SUM(runs_scored)/COUNT( distinct m.match_id),2) AS average, player_name
FROM ball_by_ball b 
JOIN batsman_scored bt ON b.match_id = bt.match_id AND b.over_id = bt.over_id AND bt.ball_id = b.ball_id
AND bt.innings_no = b.innings_no
JOIN matches m ON b.match_id = m.match_id JOIN player p ON striker = p.player_id 
JOIN venue V ON v.venue_id = m.venue_id WHERE season_id IN (6,7,8,9)
AND player_name IN (
SELECT player_name FROM top_performing_batsman )
GROUP BY striker, m.venue_id
ORDER BY average DESC;

-- SUBJECTIVE QUESTION QUERIES :

-- Question 1
SELECT venue_name,
COUNT( CASE WHEN toss_winner = match_winner AND toss_decide = 1 THEN match_id END ) AS field_first_and_win,
COUNT( CASE WHEN toss_winner = match_winner AND toss_decide = 2 THEN match_id END ) AS bat_first_and_win,
COUNT( CASE WHEN toss_winner <> match_winner AND toss_decide = 1 THEN match_id END ) AS field_first_and_lose,
COUNT( CASE WHEN toss_winner <> match_winner AND toss_decide = 2 THEN match_id END ) AS bat_first_and_lose
FROM matches m JOIN venue v ON v.venue_id = m.venue_id
GROUP BY venue_name;

-- Question 2
-- Suggested batsman
WITH last_4_season_matches AS ( 
SELECT m.match_id FROM matches m
JOIN season s ON m.season_id = s.season_id
WHERE s.season_id IN (6,7,8,9) )

SELECT player_name, (runs_scored/balls_faced)*100 AS strike_rate FROM (
SELECT b.striker, COUNT(b.ball_id) AS balls_faced, SUM(bt.runs_scored) as runs_scored
FROM ball_by_ball b 
JOIN batsman_scored bt ON
b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id  
AND b.innings_no = bt.innings_no
JOIN last_4_season_matches t1 ON b.match_id = t1.match_id
GROUP BY striker ) t1 
JOIN player p ON p.player_id = striker
WHERE balls_faced > 100
ORDER BY strike_rate DESC LIMIT 10 ;

-- Suggested bowlers
SELECT player_name, ROUND(wickets_taken/4,0) AS wickets_taken_in_death_overs_per_season FROM (
SELECT bowler, count(player_out) as wickets_taken
FROM ball_by_ball b JOIN wicket_taken w ON
b.match_id = w.match_id AND b.over_id = w.over_id AND b.ball_id = w.ball_id
AND b.innings_no = w.innings_no JOIN matches m ON m.match_id = w.match_id
WHERE kind_out NOT IN (3,5,9) AND w.over_id > 15 AND m.season_id IN (6,7,8,9)
GROUP BY bowler ) p1 JOIN player p ON p1.bowler = p.player_id 
ORDER BY wickets_taken_in_death_overs_per_season DESC ;

-- Question 3
-- Experience
SELECT player_name, COUNT(DISTINCT match_id) as matches_played
FROM player_match p
JOIN player p1 ON p.player_id = p1.player_id
GROUP BY player_name
ORDER BY matches_played DESC;

-- Age
SELECT player_name, 2017-EXTRACT(YEAR FROM dob) AS age
FROM player
ORDER BY age ;

-- Question 4
WITH runs_scored_by_each_player AS (
SELECT striker, SUM(runs_scored) AS total_runs_scored
FROM ball_by_ball b JOIN batsman_scored bt 
ON b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id 
AND b.innings_no = bt.innings_no JOIN matches m ON m.match_id = b.match_id
WHERE season_id IN (6,7,8,9)
GROUP BY striker),

wickets_taken_by_each_player AS ( 
SELECT bowler, COUNT(b.ball_id) as wickets_taken
FROM ball_by_ball b
JOIN wicket_taken w ON b.match_id = w.match_id AND b.ball_id = w.ball_id AND b.over_id = w.over_id
JOIN matches m ON m.match_id = b.match_id AND b.innings_no = w.innings_no
WHERE season_id IN (6,7,8,9) AND kind_out NOT IN (3,5,9)
GROUP BY bowler )

SELECT player_name, total_runs_scored, wickets_taken FROM runs_scored_by_each_player
JOIN wickets_taken_by_each_player ON striker = bowler
JOIN player p ON player_id = striker
WHERE wickets_taken > ( SELECT AVG(wickets_taken) FROM wickets_taken_by_each_player )
AND total_runs_scored > ( SELECT AVG(total_runs_scored) FROM runs_scored_by_each_player ) ;

-- Question 5
WITH runs_scored_in_boundaries AS (
SELECT striker, SUM(runs_scored) AS boundary_runs
FROM ball_by_ball b JOIN batsman_scored bt ON
b.match_id = bt.match_id AND b.ball_id = bt.ball_id AND b.over_id = bt.over_id AND b.innings_no = bt.innings_no
JOIN matches m ON m.match_id = b.match_id 
WHERE runs_scored IN (4,6) AND season_id IN (7,8,9)
GROUP BY striker ),

total_runs_scored AS (
SELECT striker, SUM(runs_scored) as total_runs
FROM ball_by_ball b JOIN batsman_scored bt ON
b.match_id = bt.match_id AND b.ball_id = bt.ball_id AND b.over_id = bt.over_id AND b.innings_no = bt.innings_no
JOIN matches m ON m.match_id = b.match_id 
WHERE season_id IN (7,8,9) 
GROUP BY striker HAVING count(b.ball_id) > 200 )

select player_name, total_runs, boundary_runs, ROUND(boundary_runs/total_runs*100,2) AS boundary_percent
FROM total_runs_scored t
JOIN runs_scored_in_boundaries b ON b.striker = t.striker
JOIN player p ON p.player_id = t.striker
ORDER BY boundary_percent DESC ;

-- Question 7
-- Runs Scored
WITH runs_scored_in_powerplay_and_death AS (
SELECT SUM(runs_scored) AS powerplay_and_death_over_runs, s.season_id
FROM batsman_scored bt 
JOIN matches m ON m.match_id= bt.match_id
JOIN season s ON s.season_id = m.season_id
WHERE bt.over_id <= 6 OR bt.over_id >= 16
GROUP BY season_id ),

runs_scored_in_middle_overs AS (
SELECT SUM(runs_scored) AS middle_overs_runs, s.season_id
FROM batsman_scored bt
JOIN matches m ON m.match_id= bt.match_id
JOIN season s ON s.season_id = m.season_id
WHERE bt.over_id BETWEEN 7 AND 15
GROUP BY season_id )

SELECT p.season_id, powerplay_and_death_over_runs, middle_overs_runs
FROM runs_scored_in_powerplay_and_death p 
JOIN runs_scored_in_middle_overs m ON m.season_id = p.season_id ;

-- Wickets
WITH wickets_taken_in_powerplay_and_death AS (
SELECT COUNT(w.ball_id) AS powerplay_and_death_over_wickets, s.season_id
FROM wicket_taken w
JOIN matches m ON m.match_id= w.match_id
JOIN season s ON s.season_id = m.season_id
WHERE w.over_id <= 6 OR w.over_id >= 16
GROUP BY season_id ),

wickets_taken_in_middle_overs AS (
SELECT COUNT(w.ball_id) AS middle_overs_wickets, s.season_id
FROM wicket_taken w
JOIN matches m ON m.match_id= w.match_id
JOIN season s ON s.season_id = m.season_id
WHERE w.over_id BETWEEN 7 AND 15
GROUP BY season_id )

SELECT p.season_id, powerplay_and_death_over_wickets, middle_overs_wickets
FROM wickets_taken_in_powerplay_and_death p 
JOIN wickets_taken_in_middle_overs m ON m.season_id = p.season_id ;

-- Question 8
-- Win percentage home VS away

WITH home_matches AS ( 
SELECT 
ROUND(COUNT(CASE WHEN match_winner = 2 THEN match_id END)/COUNT(match_id)*100,2) AS win_percent_home
FROM matches m JOIN venue v ON v.venue_id = m.venue_id
WHERE ( team_1 = 2 OR team_2 = 2 ) AND m.venue_id = 1 ),

away_matches AS ( 
SELECT 
ROUND(COUNT(CASE WHEN match_winner = 2 THEN match_id END)/COUNT(match_id)*100,2) AS win_percent_away
FROM matches m JOIN venue v ON v.venue_id = m.venue_id
WHERE ( team_1 = 2 OR team_2 = 2 ) AND m.venue_id <> 1 )

SELECT  win_percent_home, win_percent_away FROM away_matches, home_matches ;

-- Runs scored VS conceded at home per season
WITH runs_scored AS (
SELECT season_year, SUM(runs_scored) AS runs_scored
FROM batsman_scored bt JOIN ball_by_ball b
ON b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id AND b.innings_no = bt.innings_no
JOIN matches m ON m.match_id = bt.match_id JOIN season s ON m.season_id = s.season_id
WHERE team_batting = 2 AND venue_id = 1
GROUP BY season_year ),

runs_conceded AS (
SELECT season_year, SUM(runs_scored) AS runs_conceded
FROM batsman_scored bt JOIN ball_by_ball b
ON b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id AND b.innings_no = bt.innings_no
JOIN matches m ON m.match_id = bt.match_id JOIN season s ON m.season_id = s.season_id
WHERE team_bowling = 2 AND venue_id = 1
GROUP BY season_year )

SELECT s.season_year, runs_scored, runs_conceded FROM runs_scored s JOIN runs_conceded c 
ON s.season_year = c.season_year ;

-- Question 9
WITH runs_scored AS (
SELECT season_year, SUM(runs_scored) AS runs_scored
FROM batsman_scored bt JOIN ball_by_ball b
ON b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id AND b.innings_no = bt.innings_no
JOIN matches m ON m.match_id = bt.match_id JOIN season s ON m.season_id = s.season_id
WHERE team_batting = 2 
GROUP BY season_year ),

runs_conceded AS (
SELECT season_year, SUM(runs_scored) AS runs_conceded
FROM batsman_scored bt JOIN ball_by_ball b
ON b.match_id = bt.match_id AND b.over_id = bt.over_id AND b.ball_id = bt.ball_id AND b.innings_no = bt.innings_no
JOIN matches m ON m.match_id = bt.match_id JOIN season s ON m.season_id = s.season_id
WHERE team_bowling = 2 
GROUP BY season_year )

SELECT s.season_year, runs_scored, runs_conceded FROM runs_scored s JOIN runs_conceded c 
ON s.season_year = c.season_year ;

-- Question 11
UPDATE matches SET opponent_team = 'Delhi_Daredevils'
WHERE opponent_team = 'Delhi_Capitals'


