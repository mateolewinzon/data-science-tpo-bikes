with de_usuarios as (
    select distinct
        genero_usuario as genero,
        case
            when edad_usuario between 16 and 25 then '16-25'
            when edad_usuario between 26 and 35 then '26-35'
            when edad_usuario between 36 and 50 then '36-50'
            when edad_usuario between 51 and 65 then '51-65'
            when edad_usuario > 65              then '66+'
            else 'Desconocido'
        end as rango_etario
    from {{ ref('stg_usuarios') }}
),
todas as (
    select genero, rango_etario from de_usuarios
    union
    -- Fila para usuarios huérfanos (~30%) sin padrón disponible
    select null as genero, 'Desconocido' as rango_etario
)
select
    row_number() over (order by genero nulls last, rango_etario) as id,
    genero,
    rango_etario
from todas
