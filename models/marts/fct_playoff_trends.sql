with playoffs as (
    select
        season_year,
        playoff_round,
        winner_team_id,
        loser_team_id,
        series_wins,
        series_losses

    from {{ ref('stg_playoffs') }}
),

team_results as (
    select
        team_id,
        season_year,
        team_name,
        wins as regular_season_wins,
        losses as regular_season_losses,
        games_played,
        made_playoffs,
        playoff_round as team_playoff_round,
        conference_id,
        division_id,
        team_points,
        team_assists,
        team_steals,
        team_blocks,
        team_total_rebounds,
        opponent_points,
        attendance

    from {{ ref('stg_reg_season') }}

    where made_playoffs = true
),

coaches as (
    select
        coach_id,
        team_id,
        season_year

    from {{ ref('stg_coach_info') }}

    where stint = 1
),

playoff_runs as (
    select
        season_year,
        winner_team_id as team_id,
        case playoff_round
        when 'RR' then 1
        when 'QF' then 2
        when 'DSF' then 2
        when 'DF' then 3
        when 'SF' then 3
        when 'CFR' then 4
        when 'CSF' then 5
        when 'CF' then 6
        when 'F' then 7
        else 0
    end as round_order,
        1 as series_won,
        series_wins as total_series_wins,
        series_losses as total_series_losses
        
    from playoffs

    union all

    select
        season_year,
        loser_team_id as team_id,
        case playoff_round
            when 'RR' then 1
            when 'QF' then 2
            when 'DSF' then 2
            when 'DF' then 3
            when 'SF' then 3
            when 'CFR' then 4
            when 'CSF' then 5
            when 'CF' then 6
            when 'F' then 7
            else 0
        end as round_order,
        0 as series_won,
        series_wins as total_series_wins,
        series_losses as total_series_losses

    from playoffs
),

team_playoff_summary as (
    select
        season_year,
        team_id,
        max(round_order) as deepest_round_order,
        sum(series_won) as series_won,
        sum(total_series_wins) as total_series_wins,
        sum(total_series_losses) as total_series_losses,

        case
            when team_id in (
                select winner_team_id from playoffs
                where playoff_round = 'F'
                and season_year = playoff_runs.season_year
                union all
                select loser_team_id from playoffs
                where playoff_round = 'F'
                and season_year = playoff_runs.season_year
            ) then true
            else false
        end as reached_finals,

        case 
            when team_id in (
                select winner_team_id 
                from playoffs 
                where playoff_round = 'F'
                and season_year = playoff_runs.season_year
            ) then true 
            else false 
        end as won_championship
        
    from playoff_runs
    group by season_year, team_id
)

select

    tp.season_year,
    tp.team_id,
    tp.deepest_round_order,
    tr.team_name,
    tr.conference_id,
    tr.division_id,
    c.coach_id,
    tr.regular_season_wins,
    tr.regular_season_losses,
    tr.games_played,
    round(tr.regular_season_wins / nullif(tr.games_played, 0), 3) as regular_season_win_pct,
    tr.team_points,
    tr.team_assists,
    tr.team_steals,
    tr.team_blocks,
    tr.team_total_rebounds,
    tr.opponent_points,
    tr.attendance,
    tp.series_won,
    tp.total_series_wins,
    tp.total_series_losses,
    tp.reached_finals,
    tp.won_championship,
    case
        when tp.season_year < 1960 then '1940s-1950s'
        when tp.season_year < 1970 then '1960s'
        when tp.season_year < 1980 then '1970s'
        when tp.season_year < 1990 then '1980s'
        when tp.season_year < 2000 then '1990s'
        when tp.season_year < 2010 then '2000s'
        else '2010s'
    end as era,
    tr.team_points - tr.opponent_points as season_point_differential
from team_playoff_summary tp
left join team_results tr
    on tp.team_id = tr.team_id
    and tp.season_year = tr.season_year
left join coaches c
    on tp.team_id = c.team_id
    and tp.season_year = c.season_year