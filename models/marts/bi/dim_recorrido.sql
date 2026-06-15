with rutas as (
    select
        id_estacion_origen,
        id_estacion_destino,
        max(nombre_estacion_origen) as nombre_origen,
        max(nombre_estacion_destino) as nombre_destino
    from {{ ref('stg_recorridos') }}
    where id_estacion_origen is not null
      and id_estacion_destino is not null
    group by id_estacion_origen, id_estacion_destino
)
select
    row_number() over (order by id_estacion_origen, id_estacion_destino) as id,
    id_estacion_origen,
    id_estacion_destino,
    nombre_origen || ' → ' || nombre_destino as ruta
from rutas
