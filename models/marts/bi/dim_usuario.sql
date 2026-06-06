-- Dimensión usuarios con atributos del padrón. Cubre ~70% de los usuarios
-- activos en recorridos; el 30% restante son altas previas a 2022 que no
-- figuran en ningún CSV del padrón (ver decisions.md [2026-05-17] FK floja).
-- Grano: 1 fila por usuario único (stg_usuarios ya garantiza unicidad).
select
    id_usuario                                    as id,
    edad_usuario                                  as edad,
    genero_usuario                                as genero,
    case
        when edad_usuario between 16 and 25 then '16-25'
        when edad_usuario between 26 and 35 then '26-35'
        when edad_usuario between 36 and 50 then '36-50'
        when edad_usuario between 51 and 65 then '51-65'
        when edad_usuario > 65              then '66+'
        else 'Desconocido'
    end                                           as rango_etario
from {{ ref('stg_usuarios') }}
