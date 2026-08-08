with draft as (
    select
        player_id,
        draft_year,
        draft_overall_pick,
        draft_round,
        team_id,
        drafted_from
    from {{ ref('stg_drafts') }}
    where player_id is not null
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

accolades as (
    select
        player_id,
        total_awards,
        mvp_awards,
        finals_mvp_awards,
        all_nba_selections,
        all_star_appearances,
        all_rookie_selections,
        sixth_man_awards,
        inducted_to_hof
    from {{ ref('fct_player_accolades') }}
),

notable_players as (
    select
        d.draft_overall_pick,
        string_agg(
            concat(b.first_name, ' ', b.last_name), ', '
            order by (
                coalesce(a.mvp_awards, 0) * 20 +
                coalesce(a.finals_mvp_awards, 0) * 15 +
                coalesce(a.all_nba_selections, 0) * 10 +
                coalesce(a.all_star_appearances, 0) * 5 +
                coalesce(a.all_rookie_selections, 0) * 3 +
                coalesce(a.sixth_man_awards, 0) * 3 +
                coalesce(a.total_awards, 0) * 3 +
                case when coalesce(a.inducted_to_hof, false) = true then 50 else 0 end
            ) desc
            limit 3
        ) as notable_players_at_pick
    from draft d
    left join bios b on d.player_id = b.bio_id
    left join accolades a on d.player_id = a.player_id
    group by d.draft_overall_pick
),

notable_players_in_class as (
    select
        d.draft_year,
        string_agg(
            concat(b.first_name, ' ', b.last_name), ', '
            order by (
                coalesce(a.mvp_awards, 0) * 20 +
                coalesce(a.finals_mvp_awards, 0) * 15 +
                coalesce(a.all_nba_selections, 0) * 10 +
                coalesce(a.all_star_appearances, 0) * 5 +
                coalesce(a.all_rookie_selections, 0) * 3 +
                coalesce(a.sixth_man_awards, 0) * 3 +
                coalesce(a.total_awards, 0) * 3 +
                case when coalesce(a.inducted_to_hof, false) = true then 50 else 0 end
            ) desc
            limit 3
        ) as notable_players_in_class
    from draft d
    left join bios b on d.player_id = b.bio_id
    left join accolades a on d.player_id = a.player_id
    group by d.draft_year
)

select
    d.player_id,
    b.first_name,
    b.last_name,
    b.position,
    b.birth_country,
    b.college,
    d.draft_year,
    case
        when d.draft_year < 1960 then '1940s-1950s'
        when d.draft_year < 1970 then '1960s'
        when d.draft_year < 1980 then '1970s'
        when d.draft_year < 1990 then '1980s'
        when d.draft_year < 2000 then '1990s'
        when d.draft_year < 2010 then '2000s'
        else '2010s'
    end as draft_decade,
    d.draft_overall_pick,
    d.draft_round,
    d.team_id,
    d.drafted_from,
    coalesce(a.total_awards, 0) as total_awards,
    coalesce(a.mvp_awards, 0) as mvp_awards,
    coalesce(a.finals_mvp_awards, 0) as finals_mvp_awards,
    coalesce(a.all_nba_selections, 0) as all_nba_selections,
    coalesce(a.all_star_appearances, 0) as all_star_appearances,
    coalesce(a.all_rookie_selections, 0) as all_rookie_selections,
    coalesce(a.sixth_man_awards, 0) as sixth_man_awards,
    coalesce(a.inducted_to_hof, false) as inducted_to_hof,
    (
        coalesce(a.mvp_awards, 0) * 20 +
        coalesce(a.finals_mvp_awards, 0) * 15 +
        coalesce(a.all_nba_selections, 0) * 10 +
        coalesce(a.all_star_appearances, 0) * 5 +
        coalesce(a.all_rookie_selections, 0) * 3 +
        coalesce(a.sixth_man_awards, 0) * 3 +
        coalesce(a.total_awards, 0) * 3 +
        case when coalesce(a.inducted_to_hof, false) = true then 50 else 0 end
    ) as draft_pick_score,
    avg(
        coalesce(a.mvp_awards, 0) * 20 +
        coalesce(a.finals_mvp_awards, 0) * 15 +
        coalesce(a.all_nba_selections, 0) * 10 +
        coalesce(a.all_star_appearances, 0) * 5 +
        coalesce(a.all_rookie_selections, 0) * 3 +
        coalesce(a.sixth_man_awards, 0) * 3 +
        coalesce(a.total_awards, 0) * 3 +
        case when coalesce(a.inducted_to_hof, false) = true then 50 else 0 end
    ) over (partition by d.draft_year) as avg_class_score,
    sum(
        coalesce(a.mvp_awards, 0) * 20 +
        coalesce(a.finals_mvp_awards, 0) * 15 +
        coalesce(a.all_nba_selections, 0) * 10 +
        coalesce(a.all_star_appearances, 0) * 5 +
        coalesce(a.all_rookie_selections, 0) * 3 +
        coalesce(a.sixth_man_awards, 0) * 3 +
        coalesce(a.total_awards, 0) * 3 +
        case when coalesce(a.inducted_to_hof, false) = true then 50 else 0 end
    ) over (partition by d.draft_year) as total_class_score,
    count(d.player_id) over (partition by d.draft_year) as class_size,
    count(d.player_id) over (partition by d.draft_overall_pick) as players_at_pick,
    np.notable_players_at_pick,
    npc.notable_players_in_class
from draft d
left join bios b on d.player_id = b.bio_id
left join accolades a on d.player_id = a.player_id
left join notable_players np on d.draft_overall_pick = np.draft_overall_pick
left join notable_players_in_class npc on d.draft_year = npc.draft_year