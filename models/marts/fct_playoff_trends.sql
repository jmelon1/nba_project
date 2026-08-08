with playoffs as (
    select
        playoff_year,
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

league_size as (
    select
        season_year,
        count(distinct team_id) as total_teams_that_year

    from {{ ref('stg_reg_season') }}

    group by season_year
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
        playoff_year,
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
        playoff_year,
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
        series_losses as total_series_wins,
        series_wins as total_series_losses

    from playoffs
),

team_playoff_summary as (
    select
        playoff_year,
        team_id,
        max(round_order) as deepest_round_order,
        sum(series_won) as series_won,
        sum(total_series_wins) as total_series_wins,
        sum(total_series_losses) as total_series_losses,
        case
            when team_id in (
                select winner_team_id from playoffs
                where playoff_round = 'F'
                and playoff_year = playoff_runs.playoff_year
                union all
                select loser_team_id from playoffs
                where playoff_round = 'F'
                and playoff_year = playoff_runs.playoff_year
            ) then true
            else false
        end as reached_finals,
        case 
            when team_id in (
                select winner_team_id 
                from playoffs 
                where playoff_round = 'F'
                and playoff_year = playoff_runs.playoff_year
            ) then true 
            else false 
        end as won_championship

    from playoff_runs

    group by playoff_year, team_id
),

team_playoff_summary_with_max as (
    select
        *,
        max(deepest_round_order) over (partition by playoff_year) as max_round_order_that_year

    from team_playoff_summary
),

team_playoff_summary_normalized as (
    select
        *,
        7 - (max_round_order_that_year - deepest_round_order) as deepest_round_normalized
    from team_playoff_summary_with_max
)

select

    tp.playoff_year,
    ls.total_teams_that_year,
    tp.team_id,
    tp.deepest_round_order,
    tp.max_round_order_that_year,
    tp.deepest_round_normalized,
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
        when tp.playoff_year < 1960 then '1940s-1950s'
        when tp.playoff_year < 1970 then '1960s'
        when tp.playoff_year < 1980 then '1970s'
        when tp.playoff_year < 1990 then '1980s'
        when tp.playoff_year < 2000 then '1990s'
        when tp.playoff_year < 2010 then '2000s'
        else '2010s'
    end as playoff_decade,
    case
        when not(tr.conference_id is null) then tr.conference_id
        when tr.division_id = 'ED' then 'EC'
        when tr.division_id = 'WD' or tr.division_id = 'CD' then 'WC'
        when tp.team_id = 'LAL' and tp.playoff_year = 1983 then 'WC'
        else 'Unknown'
    end as conference_normalized,
    tr.team_points - tr.opponent_points as season_point_differential
from team_playoff_summary_normalized tp
left join team_results tr
    on tp.team_id = tr.team_id
    and tp.playoff_year = tr.season_year + 1
left join coaches c
    on tp.team_id = c.team_id
    and tp.playoff_year = c.season_year + 1
left join league_size ls
    on tp.playoff_year = ls.season_year + 1