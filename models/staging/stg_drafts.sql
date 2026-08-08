with source as (
    select
        draftYear as draft_year,
        draftRound as draft_round,
        draftSelection as draft_pick,
        draftOverall as draft_overall_pick,
        tmID as team_id,
        firstName as first_name,
        playerID as player_id,
        draftFrom as drafted_from,
        lgID as league_id
    from {{ source('nba_database', 'drafts') }}
    where lgID = 'NBA'
    and draftYear is not null
    and tmID is not null
),

deduped as (
    select
        *,
        row_number() over (
            partition by player_id
            order by
                case when draft_round = 99 then 1 else 0 end asc,
                draft_year desc,
                team_id asc
        ) as rn
    from source
)

select
    draft_year,
    draft_round,
    draft_pick,
    draft_overall_pick,
    team_id,
    first_name,
    player_id,
    drafted_from,
    league_id
from deduped
where rn = 1