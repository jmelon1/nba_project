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