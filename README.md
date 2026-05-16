# data-science-tpo-bikes

Pipeline ELT con **dbt + DuckDB** sobre el dataset de **Bicicletas Públicas de Buenos Aires** (2022–2024). Trabajo Práctico Obligatorio de DataScience — UADE 2026.

## Contexto

El TPO pide construir un pipeline de datos end-to-end bajo arquitectura **Data Lakehouse + Medallion** (RAW → STG → MART). Cada equipo procesa dos datasets con dos tecnologías distintas (Python/Pandas y dbt/SQL), y un mismo dataset es procesado en paralelo por otro equipo con la otra tecnología.

Este repo cubre **solo el track ELT con dbt**. Los resultados de cada capa deben coincidir con los del equipo que procesa Bicis con Python — esa validación cruzada es parte de la consigna.

- **Dataset**: [Bicicletas Públicas BA](https://data.buenosaires.gob.ar/dataset/bicicletas-publicas) — recorridos, estaciones, usuarios (2022–2024).
- **Stack**: dbt-core, dbt-duckdb, DuckDB, Parquet.
- **Entregables**: pipeline dbt, reporte de calidad, modelo de ML (sklearn), dashboard de BI, presentación.

## Arquitectura

Medallion lakehouse con persistencia en **Parquet** en todas las capas:

```
data/source/*.csv          archivos originales (gitignored)
        │
        ▼ read_csv_auto via dbt source
   ┌─────────┐
   │   RAW   │  data/raw/*.parquet           schema: raw
   │ Bronze  │  datos crudos, 1 tabla por archivo origen
   └────┬────┘
        │
        ▼ limpieza + normalización
   ┌─────────┐
   │   STG   │  data/stg/*.parquet           schema: stg
   │ Silver  │  tipos, timestamps, dedup, nulos
   └────┬────┘
        │
        ├──► MART_BI    data/mart_bi/*.parquet    schema: mart_bi
        │    Gold — modelo estrella (fct_recorridos + dims)
        │    → Dashboard (Looker / PowerBI)
        │
        └──► MART_ML    data/mart_ml/*.parquet    schema: mart_ml
             Gold — feature set (input + target)
             → Modelo scikit-learn
```

Diagrama detallado: [`docs/diagrams/elt_dbt_overview.puml`](docs/diagrams/elt_dbt_overview.puml).

### Decisiones de diseño

- **Todo materializa como `external` parquet** (`+materialized: external` en `dbt_project.yml`). DuckDB mantiene una vista sobre el parquet para que `dbt run`/`dbt test` funcionen; el archivo `.parquet` es la fuente de verdad.
- **`profiles.yml` vive en el repo** (no en `~/.dbt/`) para que todo el equipo corra exactamente la misma configuración.
- **Override de `generate_schema_name`** hace que los schemas queden como `raw`, `stg`, `mart_bi`, `mart_ml` (sin prefijo del target).
- **Override de `external_location`** (macro built-in de `dbt-duckdb`) hace que cada modelo se materialice en `data/{schema}/{name}.parquet`. El default de la lib omite el schema y todo cae plano en `data/`.

## Flujo

1. **Descarga**: los CSVs de Bicis BA se ponen en `data/source/` con los nombres declarados en `models/raw/_sources.yml`.
2. **RAW**: dbt lee los CSV con `read_csv_auto` y los materializa como parquet en `data/raw/`. Sin transformaciones.
3. **STG**: limpieza por tabla — casteo de tipos, normalización de timestamps a UTC, dedup, manejo de nulos, nombres consistentes. Materializa en `data/stg/`.
4. **MART_BI**: join + modelo estrella (`fct_recorridos` + `dim_estacion`, `dim_usuario`, `dim_tiempo`) para el dashboard.
5. **MART_ML**: feature set listo para entrenar sklearn (ej. predicción de duración de viaje o demanda por estación).
6. **Tests**: en cada paso corren tests de schema (`not_null`, `unique`, `relationships`) y de calidad (`dbt_expectations`) con umbrales documentados.
7. **Cross-check**: el focal point compara conteos y métricas contra el pipeline Python del otro equipo.

## Cómo correrlo localmente

Requisitos: Python **3.10–3.12**. dbt-core no soporta Python 3.13+ todavía (mashumaro, una dep transitiva, falla al importar). En macOS: `brew install python@3.12` y crear el venv con `/opt/homebrew/bin/python3.12 -m venv .venv`.

```bash
# clonar y entrar al repo
cd data-science-tpo-bikes

# entorno virtual + dependencias
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# dbt usa el profiles.yml local del repo
export DBT_PROFILES_DIR=.          # Windows: set DBT_PROFILES_DIR=.

# instalar paquetes de dbt y verificar la conexión
dbt deps
dbt debug
```

Los CSVs viven en este [drive compartido del equipo](https://drive.google.com/drive/u/0/folders/1NFPPRk0epJU4Uyf76mtCti4HAXI3B5lo) — descargarlos tal cual a `data/source/` (los nombres ya coinciden con los declarados en `models/raw/_sources.yml`).

```bash
# correr el pipeline completo (run + test)
dbt build

# o por partes
dbt run --select raw               # solo RAW
dbt run --select staging           # solo STG (asume RAW ya existe)
dbt run --select marts.bi          # solo MART_BI
dbt test                           # todos los tests
dbt test --select fct_recorridos   # tests de un modelo

# documentación interactiva + lineage
dbt docs generate
dbt docs serve
```

Los parquet resultantes quedan en `data/{raw,stg,mart_bi,mart_ml}/`. Inspección rápida con DuckDB:

```bash
duckdb -c "select count(*) from 'data/mart_bi/fct_recorridos.parquet'"
```

## Estructura

```
.
├── dbt_project.yml          configuración dbt (paths, materializaciones)
├── profiles.yml             conexión DuckDB (project-local)
├── packages.yml             dbt_utils, dbt_expectations
├── requirements.txt         dbt-core, dbt-duckdb
├── macros/                  overrides de generate_schema_name y external_location
├── models/
│   ├── raw/                 sources + parquet bronze
│   ├── staging/             limpieza + normalización
│   └── marts/
│       ├── bi/              modelo estrella para el dashboard
│       └── ml/              feature set para sklearn
├── seeds/  tests/  analyses/  snapshots/
├── data/                    parquets por capa (gitignored salvo .gitkeep)
└── docs/diagrams/           diagrama PlantUML de la arquitectura
```
