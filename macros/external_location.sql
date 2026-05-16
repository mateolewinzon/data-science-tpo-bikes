{#
  Override del macro built-in `external_location` de dbt-duckdb
  (.venv/.../dbt/include/duckdb/macros/utils/external_location.sql).
  El default arma {external_root}/{identifier}.{format} — sin el schema,
  así que todos los parquet caían en data/ en vez de data/{schema}/.

  Acá lo extendemos para que cada modelo se materialice en
    {external_root}/{relation.schema}/{relation.identifier}.{format}
  o sea: data/raw/, data/stg/, data/mart_bi/, data/mart_ml/.

  Con esto los modelos NO necesitan setear `location` en su config —
  el path se deriva del schema (que ya viene de +schema en dbt_project.yml,
  resuelto por generate_schema_name).
#}
{%- macro external_location(relation, config) -%}
  {%- if config.get('options', {}).get('partition_by') is none -%}
    {%- set format = config.get('format', 'parquet') -%}
    {{- adapter.external_root() }}/{{ relation.schema }}/{{ relation.identifier }}.{{ format }}
  {%- else -%}
    {{- adapter.external_root() }}/{{ relation.schema }}/{{ relation.identifier }}
  {%- endif -%}
{%- endmacro -%}
