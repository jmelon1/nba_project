select

    bioID as bio_id,
    useFirst as preferred_name,
    firstName as first_name,
    lastName as last_name,
    pos as position,
    height,
    weight,
    college,
    PARSE_DATE('%Y/%m/%d', birthDate) as birth_date,
    birthCity as birth_city,
    birthState as birth_state,
    birthCountry as birth_country,
    deathDate as death_date

from {{ source('nba_database', 'bios') }}

where bioID is not null
and lastName is not null