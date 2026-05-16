# Decisiones de diseño

Bitácora cronológica de decisiones arquitectónicas y de modelado que no son obvias del código. Cada entrada debe poder defenderse en el informe y la oral.

Formato por entrada: fecha + decisión + **Por qué** + **Trade-off** + **Estado**.

---

## [2026-05-16] Sin tabla `estaciones` como source separado

**Decisión:** No bajar el catálogo de estaciones. La dimensión `dim_estaciones` se va a derivar desde los recorridos, que ya traen `id_estacion`, `nombre_*`, `direccion_*`, `lat/long_*` denormalizados.

**Por qué:** Los CSV de recorridos ya contienen toda la información de estación inline. Mantener un catálogo paralelo agrega trabajo sin valor agregado claro para el TP.

**Trade-off:** El catálogo público (`data.buenosaires.gob.ar`) trae `barrio`/`comuna` que los trips no. Si el análisis BI necesita agrupar por barrio, hay que revertir esta decisión y bajar `estaciones.csv`. Otra pérdida: estaciones del catálogo que nunca aparecieron en trips quedan invisibles.

**Cross-team:** El equipo Python debe usar la misma fuente. Si ellos usan catálogo y nosotros derivamos, los conteos de estaciones únicas van a diferir.

**Estado:** Activa. Reabrir si BI necesita barrio/comuna o si el equipo Python toma otro camino.

---

## [2026-05-16] Raw es espejo literal del CSV — un modelo por archivo

**Decisión:** Cada CSV se materializa como un modelo raw que hace `SELECT * FROM {{ source(...) }}` y nada más. Sin CTEs, sin renames, sin filtros, sin uniones, sin columnas derivadas. Layout en `models/raw/`: cinco archivos `raw_recorridos_{2022,2024}.sql` y `raw_usuarios_{2022,2023,2024}.sql`.

**Por qué:**
- **ELT estricto:** la "T" sucede después del Load. Raw es el L.
- **Auditabilidad:** cada parquet mapea 1:1 a un CSV. Para responder "¿cuántas filas tenía el CSV de 2022?", abrís `raw_recorridos_2022.parquet` y contás — sin asumir que ningún paso intermedio fue correcto.
- **Convención dbt:** es lo que recomienda el style guide de dbt-labs y la práctica estándar.
- **Schemas heterogéneos:** los CSV de distintos años difieren entre sí (2022 trae columnas índice basura y `Género` con mayúscula, 2024 trae BOM y `genero` minúscula). Cualquier unificación es transformación, que va a staging.

Una primera versión con CTEs + UNION en raw fue descartada por estos motivos.

**Trade-off:** 5 archivos raw en vez de 2. Cada uno es una línea. Caso donde sí unificaría en raw: archivos particionados con schemas idénticos (ej. eventos diarios mismo formato) — no es nuestro caso.

**Estado:** Activa.

---

## [2026-05-16] Raw lee como `all_varchar=true`

**Decisión:** El `external_location` en `_sources.yml` usa `read_csv('data/source/{name}.csv', all_varchar=true, header=true)`. Todas las columnas entran a raw como VARCHAR. El casting explícito a INT/DATE/TIMESTAMP/BOOL vive en staging.

**Por qué:** La auto-detección de tipos de DuckDB infiere tipos mirando un sample (default 20.480 filas). Si aparece un outlier más adelante que no encaja, el load explota. Caso concreto que disparó esta decisión: `edad_usuario="1,019"` en la fila 25.799 de `usuarios_ecobici_2022.csv` (input mal tipeado, posiblemente "1019" con coma de miles). DuckDB infirió BIGINT y rompió al encontrarse el outlier. Sin `all_varchar`, raw deja de ser confiable: depende del tamaño del sample y de la distribución de los outliers, que son cosas que no controlamos.

Bonus conceptual: "raw all-varchar, staging explicit cast" hace explícita la frontera entre "preservar bytes" y "decidir qué significan". Va al pelo con el principio ELT.

**Trade-off:** Staging tiene que hacer todos los casts a mano (`cast(... as int)`, `try_cast(... as date)` donde corresponda). Para registros como `edad_usuario="1,019"`, hay que decidir política: rechazar la fila, capear, marcar nulo. Esa política se documenta como una de las métricas de calidad del TP.

**Estado:** Activa.

---
