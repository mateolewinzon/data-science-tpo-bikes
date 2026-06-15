-- Grano: 1 fila por (fecha, segmento demográfico, estación de salida).
-- Cuenta viajes completados que partieron de cada estación, útil para
-- analizar demanda por nodo y perfil de usuario.
with recorridos as (
    select
        r.id_usuario,
        r.id_estacion_origen                         as id_estacion,
        cast(r.fecha_origen as date)                 as fecha
    from {{ ref('stg_recorridos') }} r
    where r.id_estacion_origen is not null
      and r.duracion_seg > 0
),
con_demografia as (
    select
        r.id_estacion,
        cast(strftime('%Y%m%d', r.fecha) as integer) as id_fecha,
        u.genero_usuario                             as genero,
        case
            when u.edad_usuario between 16 and 25 then '16-25'
            when u.edad_usuario between 26 and 35 then '26-35'
            when u.edad_usuario between 36 and 50 then '36-50'
            when u.edad_usuario between 51 and 65 then '51-65'
            when u.edad_usuario > 65              then '66+'
            else 'Desconocido'
        end                                          as rango_etario
    from recorridos r
    left join {{ ref('stg_usuarios') }} u on r.id_usuario = u.id_usuario
),
agregado as (
    select
        cd.id_fecha,
        dd.id                                        as id_demografia,
        cd.id_estacion,
        count(*)                                     as cantidad
    from con_demografia cd
    left join {{ ref('dim_demografia') }} dd
        on dd.genero is not distinct from cd.genero
        and dd.rango_etario = cd.rango_etario
    group by 1, 2, 3
)
select
    row_number() over ()    as id,
    id_fecha,
    id_demografia,
    id_estacion,
    cantidad
from agregado
