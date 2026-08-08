with awards as (
    select
        player_id,
        count(*) as total_awards,
        countif(award = 'Most Valuable Player') as mvp_awards,
        countif(award = 'Finals MVP') as finals_mvp_awards,
        countif(award like '%All-NBA%') as all_nba_selections,
        countif(award like '%Defensive%') as defensive_awards,
        countif(award = 'Rookie of the Year') as rookie_of_year,
        countif(award like '%All-Rookie%') as all_rookie_selections,
        countif(award = 'Sixth Man of the Year') as sixth_man_awards,
        min(award_year) as first_award_year,
        max(award_year) as last_award_year
    from {{ ref('stg_player_awards') }}
    group by player_id
),

all_star as (
    select
        player_id,
        count(*) as all_star_appearances,
        sum(points) as total_all_star_points,
        min(season_year) as first_all_star_year,
        max(season_year) as last_all_star_year
    from {{ ref('stg_allstars') }}
    group by player_id
),

hof as (
    select
        hof_id,
        any_value(full_name) as full_name,
        any_value(induction_year) as induction_year,
        any_value(category) as category,
        true as inducted_to_hof
    from {{ ref('stg_hof') }}
    where category = 'Player'
    group by hof_id
),

bios as (
    select
        bio_id,
        first_name,
        last_name,
        position,
        birth_country,
        college
    from {{ ref('stg_bios') }}
),

draft as (
    select
        player_id,
        draft_year,
        draft_overall_pick,
        team_id as drafting_team_id,
        drafted_from
    from {{ ref('stg_drafts') }}
    where player_id is not null
)

select
    b.bio_id as player_id,
    b.first_name,
    b.last_name,
    b.position,
    b.birth_country,
    b.college,
    d.draft_year,
    d.draft_overall_pick,
    d.drafting_team_id,
    d.drafted_from,
    coalesce(a.total_awards, 0) as total_awards,
    coalesce(a.mvp_awards, 0) as mvp_awards,
    coalesce(a.finals_mvp_awards, 0) as finals_mvp_awards,
    coalesce(a.all_nba_selections, 0) as all_nba_selections,
    coalesce(a.defensive_awards, 0) as defensive_awards,
    coalesce(a.rookie_of_year, 0) as rookie_of_year,
    coalesce(a.all_rookie_selections, 0) as all_rookie_selections,
    coalesce(a.sixth_man_awards, 0) as sixth_man_awards,
    a.first_award_year,
    a.last_award_year,
    coalesce(s.all_star_appearances, 0) as all_star_appearances,
    coalesce(s.total_all_star_points, 0) as total_all_star_points,
    s.first_all_star_year,
    s.last_all_star_year,
    coalesce(h.inducted_to_hof, false) as inducted_to_hof,
    h.induction_year,
    h.category as hof_category
from bios b
left join awards a on b.bio_id = a.player_id
left join all_star s on b.bio_id = s.player_id
left join draft d on b.bio_id = d.player_id
left join hof h on b.bio_id = h.hof_id
where a.player_id is not null
or s.player_id is not null
or d.player_id is not null