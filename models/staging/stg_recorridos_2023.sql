-- Cast + normalización del CSV de recorridos 2023.
-- Idiosincrasias del año:
--   - columna índice basura: column00 (drop)
--   - Id_recorrido, id_estacion_* e id_usuario con sufijo 'BAEcobici' (strip)
--   - duracion_recorrido con separador de miles
--   - género (minúscula + tilde)
-- Esquema canónico definido en _stg_recorridos.yml.
with raw as (
    select * from {{ ref('raw_recorridos_2023') }}
)

select
    cast(replace("Id_recorrido", 'BAEcobici', '') as bigint)              as id_recorrido,
    cast(replace(id_usuario, 'BAEcobici', '') as bigint)                  as id_usuario,
    try_cast(replace(duracion_recorrido, ',', '') as integer)             as duracion_seg,
    cast(fecha_origen_recorrido as timestamp)                             as fecha_origen,
    try_cast(fecha_destino_recorrido as timestamp)                        as fecha_destino,

    cast(replace(id_estacion_origen, 'BAEcobici', '') as smallint)        as id_estacion_origen,
    nombre_estacion_origen,
    direccion_estacion_origen,
    try_cast(lat_estacion_origen as double)                               as lat_estacion_origen,
    try_cast(long_estacion_origen as double)                              as long_estacion_origen,

    cast(replace(id_estacion_destino, 'BAEcobici', '') as smallint)       as id_estacion_destino,
    nombre_estacion_destino,
    direccion_estacion_destino,
    try_cast(lat_estacion_destino as double)                              as lat_estacion_destino,
    try_cast(long_estacion_destino as double)                             as long_estacion_destino,

    modelo_bicicleta,
    "género"                                                              as genero_usuario,
    cast(2023 as smallint)                                                as anio_archivo
from raw
