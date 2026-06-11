NBA Historical Data Pipeline - BigQuery/dbt/Tableau

End-to-end data pipeline and analytics project built on historical NBA data (1946–2011) sourced from Kaggle. Raw source tables are loaded into BigQuery and modeled using dbt, producing analytical outputs around coach performance, draft value, player accolades, and playoff trends. The project demonstrates data modeling, SQL transformations, layered CTE design, testing, and documentation.

## Tech stack
- **Data Warehouse:** BigQuery (GCP)
- **Transformation:** dbt (dbt-fusion)
- **Visualization:** Tableau Public
- **Version Control:** GitHub
- **Source Data:** [NBA Dataset (1946–2011)](https://www.kaggle.com/datasets/open-source-sports/mens-professional-basketball) — Kaggle. Source dataset covers mens professional basketball from 1937–2012 across multiple leagues. This project filters to NBA records only, resulting in an effective range of 1946–2011.

## Model Breakdown
**Staging Models (9)** — materialized as views
Rename columns to snake_case, cast data types, filter to NBA league, 
and handle nulls close to the source.

stg_bios, stg_coach_info, stg_coach_awards, stg_drafts, stg_hof, 
stg_player_awards, stg_allstars, stg_playoffs, stg_reg_season

**Mart Models (4)** — materialized as tables
fct_coach_performance — career stats and weighted score per coach
fct_draft_performance — career accolades and draft value score per pick
fct_player_accolades — aggregated awards, all-star, and HOF status per player
fct_playoff_trends — team playoff performance and era-based trend analysis

## Analytical Methodology
**Draft Pick Weighted Score (`draft_pick_score`)**
Each drafted player is assigned a weighted career achievement score to enable quantitative comparison across draft positions and draft classes. The score is calculated as follows:

| Achievement              | Points |
|--------------------------|--------|
| Hall of Fame Induction   | 50     |
| MVP Award                | 20 each|
| Finals MVP               | 15 each|
| All-NBA Selection        | 10 each|
| All-Star Appearance      | 5 each |
| All-Rookie Selection     | 3 each |
| Sixth Man of the Year    | 3 each |
| Other Awards             | 3 each |

Weights are intentionally designed to reflect career prestige hierarchy — HOF induction and MVP awards are treated as the strongest signals of all-time value, while All-Star appearances and team selections reflect sustained above-average performance.

This score is aggregated at the draft pick level to answer the question: *which overall selections have historically produced the most career value?* It is also aggregated at the draft class level via window functions to identify historically strong or weak draft years.

**Coach Weighted Score (`coach_score`)**
Each coach is assigned a weighted career achievement score to enable quantitative comparison across coaching careers. The score is calculated as follows:

| Achievement              | Points  |
|--------------------------|---------|
| Hall of Fame Induction   | 50      |
| Coach of the Year Award  | 20 each |
| Finals Appearance        | 10 each |
| Playoff Appearance       | 5 each  |
| Career Win Pct > .600    | 15 bonus|
| Career Win Pct > .500    | 5 bonus |

Note: HOF induction reflects 0 for all coached due to a source data limitation documented in KNown Data Limitations.

## Data Notes

**Drafts**
- `draft_pick`: The selection number within a given round (resets to 1 each round)
- `draft_overall_pick`: The continuous overall selection number across all rounds — used as the primary draft ranking variable in analysis
- `drafted_from`: Contains a mix of college programs and international countries of origin, reflecting the dataset's coverage of both domestic and international players
- `player_id`: Null for ~58% of draft picks — these represent players who were drafted but never appeared in an NBA game and therefore have no career stats

**General Notes**
- Seasons involving mid-season coaching changes (identified via stint > 1) are excluded from team stat attributions in fct_coach_performance. This intentionally underestimates career totals for affected coaches in favor of analytical integrity — partial season stats cannot be reliably attributed to an individual coach.
- The NBA's playoff format changed several times between 1946 and 2011. Round labels in `fct_playoff_trends` are normalized to a numeric `deepest_round_order` scale to enable consistent era comparisons despite structural format changes.

## Known Data Limitations

**Hall of Fame Join — Players and Coaches**
The `stg_hof` table contains no shared player or coach ID with any other table in the dataset. HOF status in `fct_player_accolades` and `fct_coach_performance` is derived by joining on name fields, which produces imperfect results due to discrepancies between legal names stored in the HOF table and preferred names used elsewhere in the dataset (e.g. "William Russell" vs "Bill Russell"). For players, approximately 74 confirmed HOF matches were achieved. For coaches, the join produced no matches due to the coach ID format (e.g. 'gottled01') being incompatible with the full name format in the HOF table (e.g. 'RedAuerbach'). No manual lookup table was introduced intentionally — the mismatch is a source data limitation rather than a modeling error, and is documented here for transparency. A seed file mapping coach IDs to full names would resolve this in a future iteration, and is a known enhancement opportunity.

**General Limitations**
- Players who were drafted but never played in the NBA have a score of 0 by definition, which naturally pulls down expected value at lower pick numbers
- The dataset covers accolades through approximately 2011, so active players at that time have incomplete career scores
- Weight values are a modeling choice and can be adjusted to reflect alternative definitions of player value
- The source `games` column in `team_results` contains zero values for 2009-2011 seasons. Games played is instead derived by summing home and away wins and losses, which produces accurate results for all seasons in the dataset.


## dbt Test Results

28 tests were run across staging and mart models. 23 passed. 5 failures were identified, all attributable to known source data characteristics rather than modeling errors:

- **Playoff round accepted values** — resolved by adding all historical round formats including pre-modern era labels (DT, RR, QF etc.)
- **Conference ID accepted values** — early NBA seasons predate the conference system and contain non-standard values
- **All-star to bios relationship** — a subset of all-star players have no matching bio entry, likely fringe players absent from the bios table
- **Coach to team relationship** — 3 rows affected by Charlotte Bobcats franchise ID inconsistency (CHR vs CHA) across tables
- **Player accolades uniqueness** — 72 players have multiple bio entries in the source data; unique constraint removed accordingly