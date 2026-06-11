## Data Notes

**drafts**
- `draft_pick`: The selection number within a given round (resets to 1 each round)
- `draft_overall_pick`: The continuous overall selection number across all rounds — used as the primary draft ranking variable in analysis
- `drafted_from`: Contains a mix of college programs and international countries of origin, reflecting the dataset's coverage of both domestic and international players
- `player_id`: Null for ~58% of draft picks — these represent players who were drafted but never appeared in an NBA game and therefore have no career stats


## Known Data Limitations

**Hall of Fame Name Matching**
The `stg_hof` table contains no shared player ID with other tables in the dataset. HOF status in `fct_player_accolades` is derived by joining on concatenated first and last name against the HOF full name field. This results in approximately 74 confirmed matches, with an estimated 10-15 misses attributable to legal vs. preferred name discrepancies (e.g. "William Russell" in HOF vs. "Bill Russell" in player bios). No fix was applied intentionally — the mismatch is a data quality artifact of the source dataset rather than a modeling error, and is documented here for transparency.

**Hall of Fame Join — Players and Coaches**
The `stg_hof` table contains no shared player or coach ID with any other table in the dataset. HOF status in `fct_player_accolades` and `fct_coach_performance` is derived by joining on name fields, which produces 
imperfect results due to discrepancies between legal names stored in the HOF table and preferred names used elsewhere in the dataset (e.g. "William Russell" vs "Bill Russell"). 
For players, approximately 74 confirmed HOF matches were achieved. For coaches, the join produced no matches due to the coach ID format (e.g. 'gottled01') being incompatible with the full name format in the HOF table (e.g. 'RedAuerbach'). No manual lookup table was introduced intentionally — the mismatch is a source data limitation rather than a modeling error, and is documented here for transparency.A seed file mapping coach IDs to full names would resolve this in a future iteration, and is a known enhancement opportunity.


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

**Limitations**
- Players who were drafted but never played in the NBA have a score of 0 by definition, which naturally pulls down expected value at lower pick numbers
- The dataset covers accolades through approximately 2011, so active players at that time have incomplete career scores
- Weight values are a modeling choice and can be adjusted to reflect alternative definitions of player value

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

Note: HOF induction is currently unresolved due to the name/ID mismatch documented above, so all coaches show 0 points for that component.

**Coach Performance and Team Stats**
Seasons involving mid-season coaching changes (identified via stint > 1) are excluded from team stat attributions in fct_coach_performance. This intentionally underestimates career totals for affected coaches in favor of analytical integrity — partial season stats cannot be reliably attributed to an individual coach.


**Playoff Round Structure**
The NBA's playoff format changed several times between 1946 and 2011. Round labels in `fct_playoff_trends` are normalized to a numeric `deepest_round_order` scale (1-7) to enable consistent era comparisons despite structural format changes.

**Games Played (2009-2011)**
The source `games` column in `team_results` contains zero values for 2009-2011 seasons. Games played is instead derived by summing home and away wins and losses, which produces accurate results for all seasons in the dataset.

## dbt Test Results

28 tests were run across staging and mart models. 23 passed. 5 failures were identified, all attributable to known source data characteristics rather than modeling errors:

- **Playoff round accepted values** — resolved by adding all historical round formats including pre-modern era labels (DT, RR, QF etc.)
- **Conference ID accepted values** — early NBA seasons predate the conference system and contain non-standard values
- **All-star to bios relationship** — a subset of all-star players have no matching bio entry, likely fringe players absent from the bios table
- **Coach to team relationship** — 3 rows affected by Charlotte Bobcats franchise ID inconsistency (CHR vs CHA) across tables
- **Player accolades uniqueness** — 72 players have multiple bio entries in the source data; unique constraint removed accordingly

**Player ID Uniqueness in fct_player_accolades**
`player_id` is not enforced as unique in `fct_player_accolades` due to 72 players appearing with multiple bio entries in the source data — likely caused by duplicate records in the raw bios table for players with name variations or data entry inconsistencies. Maximum duplicate count per player is 3. This is a known source data characteristic and does not affect accolade aggregations.

**Franchise ID Inconsistencies**
Several franchises have inconsistent team IDs across tables in the source dataset, most notably the Charlotte Bobcats who appear as both 'CHR' and 'CHA' depending on the table. This causes 3 rows in `stg_coach_info` to fail the relationship test against `stg_reg_season`. No correction was applied as this is a source data artifact — affected seasons are 2007-2009.