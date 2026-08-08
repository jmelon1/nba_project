select

    year as award_year,
    coachID as coach_id,
    award,
    lgID as league_id

from {{ source('nba_database', 'coach_awards') }}

where lgID = 'NBA'
and coachID is not null
and year is not null