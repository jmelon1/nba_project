select

    player_id,
    first_name,
    last_name,
    season_id as season_year,
    conference,
    league_id,
    minutes,
    points,
    o_rebounds as offensive_rebounds,
    d_rebounds as defensive_rebounds,
    rebounds as total_rebounds,
    assists,
    steals,
    blocks,
    turnovers,
    personal_fouls,
    fg_made as field_goals_made,
    fg_attempted as field_goals_attempted,
    ft_made as free_throws_made,
    ft_attempted as free_throws_attempted,
    three_made as three_pointers_made,
    three_attempted as three_pointers_attempted

from {{ source('nba_database', 'all_star_data') }}

where league_id = 'NBA'
and player_id is not null
and season_id is not null