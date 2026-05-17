-- Quality test Q1 (recorridos): % de filas con duracion_seg en rango
-- razonable (>0 y ≤ 24h) debe ser ≥ 99%.
-- Justificación: duracion_seg=0 marca recorridos sin cierre (~3.4k en 2024);
-- >24h marca bicis no devueltas (~260 en 2022). Juntos representan <0.5%
-- del total. 99% como threshold detecta degradación material (más casos
-- abiertos o más bicis perdidas que el baseline histórico).
-- El test falla si retorna alguna fila.
select
    cast(count(*) filter (where duracion_seg between 1 and 24*3600) as double) / count(*) as pct_duracion_valida
from {{ ref('stg_recorridos') }}
having cast(count(*) filter (where duracion_seg between 1 and 24*3600) as double) / count(*) < 0.99
