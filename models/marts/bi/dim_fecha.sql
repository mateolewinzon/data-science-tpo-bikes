-- Dimensión fecha generada desde las fechas de inicio de viaje presentes
-- en los datos. Grano: 1 fila por día calendario con al menos un recorrido.
-- id = YYYYMMDD como entero; hace que los joins desde fct_viajes no
-- requieran una tabla auxiliar de fechas pre-generada.
with fechas as (
    select distinct
        cast(fecha_origen as date) as fecha_completa
    from {{ ref('stg_recorridos') }}
    where fecha_origen is not null
)
select
    cast(strftime('%Y%m%d', fecha_completa) as integer)   as id,
    extract(day   from fecha_completa)::integer            as dia,
    extract(month from fecha_completa)::integer            as mes,
    extract(week  from fecha_completa)::integer            as semana,
    extract(year  from fecha_completa)::integer            as anio,
    fecha_completa
from fechas
