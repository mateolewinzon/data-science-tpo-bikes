-- Tabla de hechos del mart BI. Grano: 1 fila por combinación de
-- (usuario, estación origen, estación destino, día). Pre-agrega
-- cantidad de viajes y duración promedio para acelerar los dashboards.
-- Se excluyen viajes sin cierre (duracion_seg = 0) porque no son
-- viajes completados y sesgan minutos_promedio.
with recorridos as (
    select
        id_usuario,
        id_estacion_origen,
        id_estacion_destino,
        cast(fecha_origen as date)                                      as fecha,
        duracion_seg
    from {{ ref('stg_recorridos') }}
    where duracion_seg > 0
      and id_estacion_origen is not null
      and id_estacion_destino is not null
),
agregado as (
    select
        id_usuario,
        id_estacion_origen,
        id_estacion_destino,
        cast(strftime('%Y%m%d', fecha) as integer)                      as id_fecha,
        count(*)                                                         as cantidad,
        cast(avg(duracion_seg) / 60 as integer)                         as minutos_promedio
    from recorridos
    group by 1, 2, 3, 4
)
select
    row_number() over ()       as id,
    id_usuario,
    id_estacion_origen,
    id_estacion_destino,
    id_fecha,
    cantidad,
    minutos_promedio
from agregado
