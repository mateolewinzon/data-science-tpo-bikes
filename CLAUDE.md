# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project context

UADE — TPO DataScience 2026. This repo contains **only the ELT (dbt) track** of the trabajo práctico. Dataset: **Bicis Buenos Aires** (recorridos, estaciones, usuarios 2022–2024) from `data.buenosaires.gob.ar`. A separate team is processing the same dataset with Python/Pandas; **results from both pipelines must match** — that cross-check is part of the grading. If you change semantics in a model, expect questions from the focal point on the other team.

The user is a web developer learning the data stack. Prefer analogies that map to web/devops when explaining new concepts.

## Architecture

Medallion lakehouse, all layers persisted as **Parquet** (required by the enunciado):

```
data/source/*.csv           # gitignored — original downloads
   │
   ▼ (dbt source w/ external_location read_csv)
models/raw/        → data/raw/*.parquet         schema: raw
   │
   ▼ (cleaning + normalization)
models/staging/    → data/stg/*.parquet         schema: stg
   │
   ├──► models/marts/bi/   → data/mart_bi/*.parquet   schema: mart_bi   (star schema: fct_recorridos + dims)
   └──► models/marts/ml/   → data/mart_ml/*.parquet   schema: mart_ml   (feature set for sklearn)
```

Diagram: `docs/diagrams/elt_dbt_overview.puml`.

## Non-obvious config decisions

- **`profiles.yml` lives in the repo root**, not in `~/.dbt/`. Every dbt command needs `DBT_PROFILES_DIR=.` (or `--profiles-dir .`) or it won't find the profile. This is intentional — the team needs the profile under version control for reproducibility.
- **All models materialize as `external` parquet** via `+materialized: external` + `+format: parquet` in `dbt_project.yml`. Combined with `external_root: "data"` in `profiles.yml`, each model writes to `data/{schema}/{name}.parquet`. DuckDB still keeps a view in `db/bicis.duckdb` pointing at the parquet for `dbt run`/`dbt test`.
- **`macros/generate_schema_name.sql` overrides the default schema generation** so that `+schema: raw` resolves to literally `raw` (not `main_raw` or `<target>_raw`). Do not rename this macro or revert it without also fixing the parquet paths.
- **Source CSVs go in `data/source/`** (gitignored). Filenames must match the table names in `models/raw/_sources.yml` — the `external_location: "data/source/{name}.csv"` substitution uses the source table name verbatim. Add new sources by editing `_sources.yml`, not by symlinking files.

## Common commands

```bash
# one-time setup
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export DBT_PROFILES_DIR=.      # required — profiles.yml is project-local
dbt deps                        # install dbt_utils + dbt_expectations
dbt debug                       # verify DuckDB connection

# day-to-day
dbt run                         # build all models
dbt run --select staging        # build one layer
dbt run --select stg_recorridos # build one model + its parents w/ +
dbt test                        # run all tests (schema + data quality)
dbt test --select fct_recorridos
dbt build                       # run + test, in DAG order
dbt docs generate && dbt docs serve   # lineage graph + catalog

# inspecting outputs (parquet is the source of truth, not the duckdb file)
duckdb -c "select count(*) from 'data/mart_bi/fct_recorridos.parquet'"
```

## Data quality conventions

The enunciado requires **≥ 2 quality metrics with documented thresholds**. Use `dbt_expectations` tests (already in `packages.yml`) for things schema tests can't express (row count ranges, distribution checks, freshness). When adding a quality test, document the threshold and its justification in a comment on the test in the `.yml` — the report has to cite it.

## What NOT to do here

- Don't add the Python/Pandas pipeline to this repo. That's another team's deliverable; mixing them invalidates the cross-validation.
- Don't materialize anything as `table` or `view` only. The enunciado requires parquet persistence at every layer.
- Don't put credentials or absolute paths in `profiles.yml` — it's committed.
