select

    year as induction_year,
    hofID as hof_id,
    name as full_name,
    category

from {{ source('nba_database', 'hall_of_fame') }}

where hofID is not null
and category in ('Player', 'Coach')