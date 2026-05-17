-- Cast + normalización del padrón 2024.
-- Esquema canónico definido en _stg_usuarios.yml.
-- Notar: el CSV 2024 no incluye la columna Customer.Has.Dni..Yes...No.,
-- así que tiene_dni se setea a NULL para todo el año.
with raw as (
    select * from {{ ref('raw_usuarios_2024') }}
),

casted as (
    select
        cast(id_usuario as bigint)                                   as id_usuario,
        genero_usuario,
        try_cast(replace(edad_usuario, ',', '') as integer)          as edad_parsed,
        cast(fecha_alta as date)                                     as fecha_alta,
        cast(hora_alta as time)                                      as hora_alta,
        cast(null as boolean)                                        as tiene_dni,
        cast(2024 as smallint)                                       as anio_archivo
    from raw
)

select
    id_usuario,
    genero_usuario,
    case when edad_parsed between 16 and 100 then edad_parsed end    as edad_usuario,
    fecha_alta,
    hora_alta,
    tiene_dni,
    anio_archivo
from casted
