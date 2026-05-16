-- Espejo literal del CSV de origen. Sin transformaciones.
select * from {{ source('bicis_src', 'usuarios_ecobici_2024') }}
