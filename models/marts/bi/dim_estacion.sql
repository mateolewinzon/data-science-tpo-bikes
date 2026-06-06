-- Dimensión estaciones derivada de stg_recorridos (sin catálogo externo;
-- ver decisions.md [2026-05-16]). Se combinan origen y destino para
-- capturar todas las estaciones activas en el período.
with origen as (
    select
        id_estacion_origen as id,
        nombre_estacion_origen as nombre
    from {{ ref('stg_recorridos') }}
    where id_estacion_origen is not null
),
destino as (
    select
        id_estacion_destino as id,
        nombre_estacion_destino as nombre
    from {{ ref('stg_recorridos') }}
    where id_estacion_destino is not null
),
todas as (
    select id, nombre from origen
    union
    select id, nombre from destino
)
select
    id,
    max(nombre) as nombre
from todas
group by id
