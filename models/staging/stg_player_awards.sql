select

    playerID as player_id,
    award,
    year as award_year,
    lgID as league_id,
    pos as position

from {{ source('nba_database', 'player_awards') }}

where lgID = 'NBA'
and playerID is not null
and year is not null