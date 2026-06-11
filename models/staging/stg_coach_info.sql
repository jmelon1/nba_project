select
    coachID as coach_id,
    year as season_year,
    tmID as team_id,
    lgID as league_id,
    stint,
    won as season_wins,
    lost as season_losses,
    won + lost + post_wins + post_losses as games_coached,
    COALESCE(post_wins, 0) as playoff_wins,
    COALESCE(post_losses, 0) as playoff_losses

from {{ source('nba_database', 'coaches') }}

where lgID = 'NBA'
and coachID is not null
and tmID is not null
and year is not null