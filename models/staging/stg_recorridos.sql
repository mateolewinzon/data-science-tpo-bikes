-- Unión de los tres años de recorridos.
-- select distinct elimina el único duplicado byte-idéntico detectado
-- (id_recorrido 22425357 en 2024). Es barato: el dedup actúa solo sobre
-- los pocos casos byte-idénticos; los recorridos normales no se tocan
-- porque cada uno tiene un id_recorrido único.
select distinct *
from (
    select * from {{ ref('stg_recorridos_2022') }}
    union all
    select * from {{ ref('stg_recorridos_2023') }}
    union all
    select * from {{ ref('stg_recorridos_2024') }}
)
