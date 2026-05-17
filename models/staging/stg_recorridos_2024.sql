-- Cast + normalización del CSV de recorridos 2024.
-- Idiosincrasias del año:
--   - sin columnas índice
--   - sin sufijo BAEcobici; en cambio id_usuario viene con '.0' trailing
--     (artifact del cast float→str en el origen)
--   - 3.379 recorridos sin fecha_destino (duracion_seg=0); se conservan
--   - 1 registro byte-idéntico duplicado (id_recorrido 22425357); se
--     deduplica con select distinct en el union final
-- Esquema canónico definido en _stg_recorridos.yml.
with raw as (
    select * from {{ ref('raw_recorridos_2024') }}
)

select
    cast(id_recorrido as bigint)                                          as id_recorrido,
    -- '.0' viene del cast float→str; trim_string para BIGINT
    cast(replace(id_usuario, '.0', '') as bigint)                         as id_usuario,
    try_cast(duracion_recorrido as integer)                               as duracion_seg,
    cast(fecha_origen_recorrido as timestamp)                             as fecha_origen,
    try_cast(fecha_destino_recorrido as timestamp)                        as fecha_destino,

    cast(id_estacion_origen as smallint)                                  as id_estacion_origen,
    nombre_estacion_origen,
    direccion_estacion_origen,
    try_cast(lat_estacion_origen as double)                               as lat_estacion_origen,
    try_cast(long_estacion_origen as double)                              as long_estacion_origen,

    cast(id_estacion_destino as smallint)                                 as id_estacion_destino,
    nombre_estacion_destino,
    direccion_estacion_destino,
    try_cast(lat_estacion_destino as double)                              as lat_estacion_destino,
    try_cast(long_estacion_destino as double)                             as long_estacion_destino,

    modelo_bicicleta,
    genero                                                                as genero_usuario,
    cast(2024 as smallint)                                                as anio_archivo
from raw
