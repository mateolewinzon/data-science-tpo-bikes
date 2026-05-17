-- Unión de los tres padrones anuales. El schema canónico se define en
-- los modelos per-año; acá solo se concatenan.
select * from {{ ref('stg_usuarios_2022') }}
union all
select * from {{ ref('stg_usuarios_2023') }}
union all
select * from {{ ref('stg_usuarios_2024') }}
