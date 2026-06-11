with coaches as (
    select
        coach_id,
        season_year,
        team_id,
        stint,
        season_wins,
        season_losses,
        games_coached,
        playoff_wins,
        playoff_losses

    from {{ ref('stg_coach_info') }}
),

clean_seasons as (
    select
        coach_id,
        season_year,
        team_id,
        season_wins,
        season_losses,
        games_coached,
        playoff_wins,
        playoff_losses
    from coaches
    where stint = 1
    and season_year not in (
        select distinct season_year
        from coaches
        where stint > 1
    )
),

team_results as (
    select
        team_id,
        season_year,
        team_points,
        team_assists,
        team_steals,
        team_blocks,
        team_offensive_rebounds,
        team_defensive_rebounds,
        team_total_rebounds,
        opponent_points,
        opponent_assists,
        opponent_steals,
        opponent_blocks,
        opponent_offensive_rebounds,
        opponent_defensive_rebounds,
        opponent_total_rebounds,
        made_playoffs,
        playoff_round,
        attendance

    from {{ ref('stg_reg_season') }}
),

coach_awards as (
    select
        coach_id,
        count(*) as coach_of_year_awards,
        min(award_year) as first_award_year,
        max(award_year) as last_award_year

    from {{ ref('stg_coach_awards') }}
    group by coach_id
),

hof as (
    select
        full_name,
        induction_year,
        true as inducted_to_hof

    from {{ ref('stg_hof') }}

    where category = 'Coach'
),

career_totals as (
    select
        c.coach_id,
        count(distinct c.season_year) as seasons_coached,
        count(distinct c.team_id) as teams_coached,
        sum(c.season_wins) as career_wins,
        sum(c.season_losses) as career_losses,
        sum(c.games_coached) as career_games_coached,
        sum(c.playoff_wins) as career_playoff_wins,
        sum(c.playoff_losses) as career_playoff_losses,
        round(sum(c.season_wins) / nullif(sum(c.games_coached), 0), 3) as career_win_pct,
        min(c.season_year) as first_season,
        max(c.season_year) as last_season,
        max(c.season_year) - min(c.season_year) + 1 as tenure_years,
        sum(t.team_points) as total_team_points,
        sum(t.team_assists) as total_team_assists,
        sum(t.team_steals) as total_team_steals,
        sum(t.team_blocks) as total_team_blocks,
        sum(t.team_offensive_rebounds) as total_team_off_rebounds,
        sum(t.team_defensive_rebounds) as total_team_def_rebounds,
        sum(t.team_total_rebounds) as total_team_rebounds,
        sum(t.opponent_points) as total_opponent_points,
        sum(t.opponent_assists) as total_opponent_assists,
        sum(t.opponent_steals) as total_opponent_steals,
        sum(t.opponent_blocks) as total_opponent_blocks,
        sum(t.opponent_total_rebounds) as total_opponent_rebounds,
        count(case when t.made_playoffs = true then 1 end) as playoff_appearances,
        round(
            count(case when t.made_playoffs = true then 1 end) /
            nullif(count(distinct c.season_year), 0)
        , 3) as playoff_appearance_rate,
        countif(t.playoff_round = 'F') as finals_appearances,
        sum(t.attendance) as total_attendance

    from clean_seasons c
    left join team_results t
        on c.team_id = t.team_id
        and c.season_year = t.season_year

    group by c.coach_id
),

scored as (
    select
        ct.*,
        coalesce(ca.coach_of_year_awards, 0) as coach_of_year_awards,
        ca.first_award_year,
        ca.last_award_year,
        coalesce(h.inducted_to_hof, false) as inducted_to_hof,
        h.induction_year,
        (
            coalesce(ca.coach_of_year_awards, 0) * 20 +
            ct.playoff_appearances * 5 +
            ct.finals_appearances * 10 +
            case when coalesce(h.inducted_to_hof, false) = true then 50 else 0 end +
            case when ct.career_win_pct > 0.600 then 15
                 when ct.career_win_pct > 0.500 then 5
                 else 0 end
        ) as coach_score

    from career_totals ct
    left join coach_awards ca on ct.coach_id = ca.coach_id
    left join hof h on ct.coach_id = h.full_name
)

select * from scored