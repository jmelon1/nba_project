select

    year + 1 as playoff_year,
    round as playoff_round,
    tmIDWinner as winner_team_id,
    lgIDWinner as winner_league_id,
    tmIDLoser as loser_team_id,
    lgIDLoser as loser_league_id,
    W as series_wins,
    L as series_losses

from {{ source('nba_database', 'playoff_results') }}

where lgIDWinner = 'NBA'
and tmIDWinner is not null
and tmIDLoser is not null
and year is not null