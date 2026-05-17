-- Cast + normalización del padrón 2022.
-- Esquema canónico definido en _stg_usuarios.yml.
with raw as (
    select * from {{ ref('raw_usuarios_2022') }}
),

casted as (
    select
        cast("ID_usuario" as bigint)                                 as id_usuario,
        genero_usuario,
        try_cast(replace(edad_usuario, ',', '') as integer)          as edad_parsed,
        cast(fecha_alta as date)                                     as fecha_alta,
        cast(hora_alta as time)                                      as hora_alta,
        case "Customer.Has.Dni..Yes...No."
            when 'Yes' then true
            when 'No'  then false
        end                                                          as tiene_dni,
        cast(2022 as smallint)                                       as anio_archivo
    from raw
)

select
    id_usuario,
    genero_usuario,
    -- Política: edad fuera de [16,100] queda NULL (cubre thousand-separator
    -- como '1,019' que parsea a 1019, y outliers tipo año-de-nacimiento).
    case when edad_parsed between 16 and 100 then edad_parsed end    as edad_usuario,
    fecha_alta,
    hora_alta,
    tiene_dni,
    anio_archivo
from casted
