-- Espejo literal del CSV de origen. Sin transformaciones.
-- La normalización de columnas (renames, casts, género, etc.) vive en staging.
select * from {{ source('bicis_src', 'badata_ecobici_recorridos_realizados_2024') }}
