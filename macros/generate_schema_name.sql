{#
  Overrides the default dbt schema generation so that `+schema: raw`
  in dbt_project.yml resolves to literally `raw` instead of
  `{target.schema}_raw`. Keeps the lakehouse layer names clean
  (raw, stg, mart_bi, mart_ml) regardless of the target.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
