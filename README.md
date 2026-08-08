NBA Historical Data Pipeline - BigQuery/dbt/Tableau

This project uses NBA history (1947–2012) to answer four questions about how value gets created and recognized in professional basketball: where does draft value actually come from, what separates a Hall of Famer from a very good player, how much do coaches actually matter to a team's success, and how have playoff dynasties and league parity shifted over time. Each question maps to one of the four dashboards linked below, built on top of a fully modeled dbt warehouse.

End-to-end data pipeline and analytics project built on historical NBA data (1947–2012) sourced from Kaggle. Raw source tables are loaded into BigQuery and modeled using dbt, producing analytical outputs around coach performance, draft value, player accolades, and playoff trends. The project demonstrates data modeling, SQL transformations, layered CTE design, testing, and documentation.

## Live Dashboards
[View on Tableau Public](https://public.tableau.com/app/profile/joseph.malone6625/viz/TheNBALifecycle/Drafts) — opens on the Draft dashboard; use the in-dashboard nav to move between Draft Value, Hall of Fame, Coach Performance, and Playoff Legacy.

## Tech stack
- **Data Warehouse:** BigQuery (GCP)
- **Transformation:** dbt (dbt-fusion)
- **Visualization:** Tableau Public
- **Version Control:** GitHub
- **Source Data:** [NBA Dataset (1947–2012)](https://www.kaggle.com/datasets/open-source-sports/mens-professional-basketball) — Kaggle. Source dataset covers mens professional basketball from 1937–2012 across multiple leagues. This project filters to NBA records only, resulting in an effective range of 1947–2012.

## Model Breakdown
**Staging Models (9)** - materialized as views
Renamed columns to snake_case, cast data types, filtered to NBA league, 
and handled nulls close to the source.

stg_bios, stg_coach_info, stg_coach_awards, stg_drafts, stg_hof, 
stg_player_awards, stg_allstars, stg_playoffs, stg_reg_season

**Mart Models (4)** - materialized as tables
fct_coach_performance: career stats and weighted score per coach
fct_draft_performance: career accolades and draft value score per pick
fct_player_accolades: aggregated awards, all-star, and HOF status per player
fct_playoff_trends: team playoff performance and era-based trend analysis

## Analytical Methodology
**Draft Pick Weighted Score (`draft_pick_score`)**
Each drafted player is assigned a weighted career achievement score to enable quantitative comparison across draft positions and draft classes. The score is calculated based on the table below:

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

Weights are intentionally designed to reflect career prestige hierarchy. HOF induction and MVP awards are treated as the strongest signals of all-time value, while All-Star appearances and team selections reflect sustained above-average performance.

This score is aggregated at the draft pick level to answer the question: *which overall selections have historically produced the most career value?* It is also aggregated at the draft class level via window functions to identify historically strong or weak draft years.

**Coach Weighted Score (`coach_score`)**
Each coach is assigned a weighted career achievement score to enable quantitative comparison across coaching careers. The score is calculated in the table below:

| Achievement              | Points  |
|--------------------------|---------|
| Hall of Fame Induction   | 50      |
| Coach of the Year Award  | 20 each |
| Finals Appearance        | 10 each |
| Playoff Appearance       | 5 each  |
| Career Win Pct > .600    | 15 bonus|
| Career Win Pct > .500    | 5 bonus |

## Scoring & Ranking Methodology: dbt vs. Tableau

This project draws a consistent line between **entity-level scoring** and **display-specific ranking**:

- **Entity-level scores** (`coach_score`, `draft_pick_score`) are built in dbt because they represent standalone, reusable properties of an entity, not a single chart's framing. They can answer multiple types of questions on their own. For example, `draft_pick_score` supports both a per-pick line chart *and* a draft-class strength heatmap, and could equally support a future "best value picks" or "bust" leaderboard without any new modeling. The score is a fact about the entity, independent of how it gets visualized.

- **Display-specific composites** (the "greatest playoff run" ranking) are implemented as Tableau calculated fields. These exist to answer one specific framing of one specific chart, built by weighting raw fields that already live in the mart layer (`won_championship`, `total_series_losses`). The weighting itself isn't a reusable property of a team-season — it only makes sense in the context of that one ranking question.

**The test applied throughout:** not "how many charts use this today," but "can this score answer more than one type of question, or does it only exist to produce one chart's sort order." This keeps the dbt layer focused on durable, reusable business logic, and keeps Tableau focused on presentation-layer flexibility.

## Data Notes

**Drafts**
- `draft_pick`: The selection number within a given round (resets to 1 each round)
- `draft_overall_pick`: The continuous overall selection number across all rounds — used as the primary draft ranking variable in analysis
- `drafted_from`: Contains a mix of college programs and international countries of origin, reflecting the dataset's coverage of both domestic and international players
- `player_id`: Null for ~58% of draft picks — these represent players who were drafted but never appeared in an NBA game and therefore have no career stats
- Early-era draft classes are small, so a handful of standout players can pull average class score higher than in larger modern classes (1960's average class score exceeds 1984's). This is a small-sample-size effect distinct from, but analogous to, the post-2012-cutoff deflation affecting recent classes.

**Modeling Notes**
- Seasons involving mid-season coaching changes (identified through stint > 1) are excluded from team stat attributions in fct_coach_performance. This intentionally underestimates career totals for affected coaches in favor of analytical integrity. Partial season stats cannot be reliably attributed to an individual coach.
- The NBA's playoff format changed several times between 1947 and 2012. Round labels in `fct_playoff_trends` are normalized to a numeric `deepest_round_order` scale to enable consistent era comparisons despite structural format changes.

## Data Corrections

**Playoff Year Mislabeling**
The source playoff results table labeled rows using the year the season began (a 2011-12 playoff run was recorded as 2011), rather than the calendar year the playoffs actually occurred. This was corrected in `stg_playoffs` by deriving `playoff_year` as `year + 1`, and the join logic in `fct_playoff_trends` was updated to align playoff years with the correct regular season (`playoff_year = season_year + 1`) when pulling in team and coach context.

**Conference normalization across eras**
`conference_id` only exists in the source data from 1971 onward, when the NBA formally adopted East/West conference structure. Earlier eras used divisions instead (`ED`, `WD`, `CD`). A `conference_normalized` field was added to `fct_playoff_trends` to unify both schemes: `ED` maps to `EC`, while `WD` and `CD` maps to `WC` (`CD` was historically a subdivision of the Eastern division). This allows conference-level analysis across the full 1947–2012 dataset rather than only from 1971 onward.

**League size for `fct_playoff_trends`**
`total_teams_that_year` counts all teams within the regular season data for a given year. This was done to give a true league-size denominator distinct from the `fct_playoff_trends`'s grain of only playoff contenders.

**`fct_draft_performance`/`fct_player_accolades` duplicate player rows**
`stg_drafts` had 71 players with more than one draft entry due to some genuine re-drafts under old-era rules where a player drafted, not signed, and re-entered a later draft.  Others were unrelated same-year duplicate rows. This was fixed via a row_number() window partitioned by player_id, prioritizing non-dispersal-draft entries (draft_round ≠ 99) and the most recent legitimate draft year, with team_id as a deterministic tiebreaker. Separately, fct_player_accolades's HOF join double-counted 4 individuals inducted as both player and coach (e.g. Elgin Baylor, K.C. Jones). This was fixed by filtering the HOF join to category = 'Player' only and verified via duplicate-count checks pre/post fix.

**Player ID Collisions (Earvin "Magic" Johnson/Marques Johnson, Neil Johnston)**
The source data's `player_id`/`bio_id` collided for two unrelated sets of players who share a surname and first-name prefix. johnsma01 was shared between Magic Johnson and Marques Johnson. Similarly, Neil Johnston was misfiled under johnsne02 instead of his correct ID, johnsne01. A broader audit of all_star_data against the bios confirmed these were the only two genuine ID collisions in the dataset; a third candidate (johnsne01 tagged as a different "Neil Johnson" from a 1970 ABA season) required no fix, since it was already excluded by the existing NBA-league filter. This was fixed with a composite-key seed and cross-referenced against the bios table's birth year and college data to confirm Neil Johnston and the second Neil Johnson are genuinely distinct individuals rather than a data entry duplicate.

## Known Data Limitations

**All-Star ID Inconsistencies**
The source `all_star_data` table contains 16 player records using inconsistent ID formats relative to the `bios` table (an example is Shaquille O'Neal appears as `oneash01` in all-star data vs `onealsh01` in bios). This caused several notable players to show 0 all-star appearances in `fct_player_accolades` despite having real appearances on record. A correction seed (`allstar_id_corrections.csv`) maps known inconsistent IDs to their correct `bios` equivalent, applied in `stg_allstars`. Jeff Rutland could not be matched to any `bios` record and remains under his original all-star ID with no biographical data joined. This explains the failing of the **All-star to bios relationship** test.

**Player-Level Playoff Statistics**
The dataset does not include player-level playoff statistics, only team-level playoff results (`fct_playoff_trends`). As a result, a direct comparison of individual regular season performance vs. playoff performance for Hall of Fame analysis is not possible at the player grain. Finals MVP awards are the closest available proxy, but they conflate playoff success with team success rather than isolating individual playoff performance.

**Draft Class Strength for Recent Classes**
Draft class strength metrics (`avg_class_score`, `total_class_score`) are based on full career accolade totals. Players from classes near the end of the dataset's coverage have artificially low scores since their careers were still ongoing as of the ~2012 cutoff. A more accurate cross-era comparison would require season-by-season accolade data to normalize for years of eligibility, which is not available with the current database.

**Conference Mapping in `fct_playoff_trends`**
The 1983 Lakers playoff year has a failed join to `team_results`, where team name, regular season stats, and conference/division fields are all blank, while playoff-specific fields like series wins/losses and coach_id are intact. The root cause appears to be a join key mismatch in `team_results` for that team/season combination and has not yet been diagnosed. Since the Lakers are unambiguously a Western Conference franchise, `conference_normalized` for this specific row was manually hardcoded to `WC` rather than left as `Unknown`. This is a targeted, single-row override and does not address the underlying join gap, which would need separate investigation if regular season stats for this row are needed in the future.

**`draft_overall_pick`s with a value of 0**
`draft_overall_pick` is unavailable (recorded as 0) for most drafts prior to 1957, for all territorial picks (1949–1965), and for 1976 ABA dispersal-draft selections. These players are correctly included in class-level scoring (`avg_class_score`, `total_class_score`), which doesn't depend on pick number, but are excluded from the per-pick draft chart (filtered to picks 1–60).

**General Limitations**
- Players who were drafted but never played in the NBA have a score of 0 by definition, which naturally pulls down expected value at lower pick numbers
- Weight values are a modeling choice and can be adjusted to reflect alternative definitions of player/coach value
- The source `games` column in `team_results` contains zero values for 2009-2012 seasons. Games played is instead derived by summing home and away wins and losses, which produces accurate results for all seasons in the dataset.

## dbt Test Results

28 tests were run across staging and mart models. 23 passed. 5 failures were identified, all attributable to known source data characteristics rather than modeling errors:

- **Playoff round accepted values**: resolved by adding all historical round formats including pre-modern era labels (DT, RR, QF etc.)
- **Conference ID accepted values**: early NBA seasons predate the conference system and contain non-standard values
- **All-star to bios relationship**: Found later in Tableau to be due to `player_id` inconsistencies between `stg_allstars` and `stg_bios`
- **Coach to team relationship**: 3 rows affected by Charlotte Bobcats franchise ID inconsistency (CHR vs CHA) across tables
- **Player accolades uniqueness**: 72 players have multiple bio entries in the source data; unique constraint removed accordingly