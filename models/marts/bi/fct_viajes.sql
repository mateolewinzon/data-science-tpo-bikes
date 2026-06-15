with recorridos as (
    select
        r.id_usuario,
        r.id_estacion_origen,
        r.id_estacion_destino,
        cast(r.fecha_origen as date)                         as fecha,
        r.duracion_seg
    from {{ ref('stg_recorridos') }} r
    where r.duracion_seg > 0
      and r.id_estacion_origen is not null
      and r.id_estacion_destino is not null
),
con_atributos as (
    select
        r.id_estacion_origen,
        r.id_estacion_destino,
        cast(strftime('%Y%m%d', r.fecha) as integer)         as id_fecha,
        r.duracion_seg,
        u.genero_usuario                                     as genero,
        case
            when u.edad_usuario between 16 and 25 then '16-25'
            when u.edad_usuario between 26 and 35 then '26-35'
            when u.edad_usuario between 36 and 50 then '36-50'
            when u.edad_usuario between 51 and 65 then '51-65'
            when u.edad_usuario > 65              then '66+'
            else 'Desconocido'
        end                                                  as rango_etario
    from recorridos r
    left join {{ ref('stg_usuarios') }} u on r.id_usuario = u.id_usuario
),
agregado as (
    select
        ca.id_fecha,
        dd.id                                                as id_demografia,
        dr.id                                                as id_recorrido,
        count(*)                                             as cantidad,
        cast(avg(ca.duracion_seg) / 60 as integer)           as minutos
    from con_atributos ca
    left join {{ ref('dim_demografia') }} dd
        on dd.genero is not distinct from ca.genero
        and dd.rango_etario = ca.rango_etario
    left join {{ ref('dim_recorrido') }} dr
        on dr.id_estacion_origen  = ca.id_estacion_origen
        and dr.id_estacion_destino = ca.id_estacion_destino
    group by 1, 2, 3
)
select
    row_number() over ()    as id,
    id_fecha,
    id_demografia,
    id_recorrido,
    cantidad,
    minutos
from agregado
