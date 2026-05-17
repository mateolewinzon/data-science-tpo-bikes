-- Quality test Q1: % de filas con edad_usuario no-null debe ser ≥ 99%.
-- Justificación: el análisis preliminar midió 99.96% válido tras aplicar el
-- filtro [16, 100]. Dejamos 1 punto de margen para acomodar futuros años o
-- pequeñas variaciones; si el ratio cae por debajo de 0.99, hay degradación
-- material en la fuente (más outliers, parsing roto, etc.).
-- El test falla si retorna alguna fila.
select
    cast(count(edad_usuario) as double) / count(*) as pct_edad_no_null
from {{ ref('stg_usuarios') }}
having cast(count(edad_usuario) as double) / count(*) < 0.99
