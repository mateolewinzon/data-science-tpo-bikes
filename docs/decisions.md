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

## [2026-05-17] Staging usuarios: 3 modelos per-año + 1 unión

**Decisión:** En `models/staging/` viven cuatro archivos para usuarios: `stg_usuarios_2022.sql`, `stg_usuarios_2023.sql`, `stg_usuarios_2024.sql` (cast + rename + lógica específica del año) y `stg_usuarios.sql` (`UNION ALL` de los tres). El esquema canónico (`id_usuario, genero_usuario, edad_usuario, fecha_alta, hora_alta, tiene_dni, anio_archivo`) se define en los modelos per-año; el union es `select *`.

**Por qué:** Cada CSV de usuarios tiene idiosincrasias distintas (`ID_usuario` vs `id_usuario`, columna `Customer.Has.Dni..Yes...No.` presente en 2022/23 y ausente en 2024). Aislar cada una en su propio modelo per-año mantiene el SQL legible y mapea 1:1 con la convención ya tomada en raw (`[2026-05-16] Raw es espejo literal del CSV — un modelo por archivo`). Cuando llegue 2025, se toca un archivo nuevo y una línea del union.

**Trade-off:** Cuatro archivos para algo que cabría en uno. Aceptable: el costo es una línea extra en el union por año.

**Estado:** Activa.

---

## [2026-05-17] Política de edad: NULL fuera de [16, 100]

**Decisión:** En staging, `edad_usuario` se castea y luego se filtra con `case when edad_parsed between 16 and 100 then edad_parsed end`. Fuera del rango (incluyendo el thousand-separator `"1,019"` que parsea a 1019, edades `<16` que violan la FAQ Ecobici, y outliers tipo año-de-nacimiento) queda NULL. **La fila se conserva** — id, género, fechas siguen valiendo.

**Por qué:** El enunciado pide ≥2 métricas de calidad con thresholds. Mantener la fila con edad NULL permite (a) no perder al usuario para joins con recorridos, (b) medir `% de filas con edad válida` como métrica de calidad reportable. El rango es defendible: 16 es la cota inferior oficial del servicio (FAQ Ecobici), 100 es una cota superior razonable.

**Trade-off:** BI y ML reciben edad nullable y tienen que decidir cómo tratarla (excluir, imputar, etc.). Reportes que necesiten edad obligatoria deben filtrar `edad_usuario is not null` explícitamente.

**Cross-team:** El equipo Python debe aplicar el mismo filtro para que los conteos cuadren. Si ellos deciden droppear filas, los row counts van a diferir.

**Estado:** Activa.

---

## [2026-05-17] No recuperar outliers de edad como "año de nacimiento"

**Decisión:** Los ~5 valores de `edad_usuario` que caen en el rango 1924-2024 (sobre 94 outliers totales `>100`) no se reconstruyen como `anio_archivo - valor`. Quedan NULL como el resto del ruido.

**Por qué:** 5 casos sobre 439.140 usuarios (~0.001%) no justifican una heurística que tendríamos que defender en la oral. Reconstruir como `2024 - valor` da edades de 3-20 años, varias de las cuales caerían `<16` y volverían a quedar fuera del rango. Ganancia marginal vs. complejidad y riesgo de inventar señal.

**Trade-off:** Se pierden ~3 usuarios potencialmente recuperables. Si más adelante aparece una motivación BI/ML concreta para recuperarlos, la decisión se puede revertir.

**Estado:** Activa.

---

## [2026-05-17] Staging recorridos: normalización de IDs heterogéneos

**Decisión:** En `stg_recorridos_*` se aplica la siguiente normalización:

- `id_recorrido`, `id_estacion_origen`, `id_estacion_destino`, `id_usuario` en 2022/23 traen sufijo `BAEcobici` (100% de filas). Se hace `replace(..., 'BAEcobici', '')` antes del cast.
- `id_usuario` en 2024 trae sufijo `.0` (100% de filas, artifact del cast float→str en el export). Se hace `replace(..., '.0', '')` antes del cast.
- Columnas índice basura `column00` (2022 y 2023) y `X` (solo 2022) se descartan; eran enumeraciones 1..999999 sin valor analítico.
- `duracion_recorrido` con separador de miles (`"1,020"`) en ~46% de filas de 2022/23: `replace(',', '')` + cast.
- Capitalización dispar (`Id_recorrido`/`id_recorrido`, `Género`/`género`/`genero`): se unifica al lowercase canónico (`id_recorrido`, `genero_usuario`).

**Por qué:** Para que `stg_recorridos` (el UNION ALL) tenga tipos uniformes (BIGINT/SMALLINT) y los marts puedan hacer joins eficientes sin string-matching. Estos sufijos son artefactos del CSV de origen, no semántica del dominio.

**Trade-off:** Cada `stg_recorridos_<año>.sql` lleva su propia receta de cleaning. Si en 2025 aparece un nuevo formato (otro sufijo, otra variación), se agrega un cuarto archivo. Aceptable.

**Estado:** Activa.

---

## [2026-05-17] Recorridos: preservar outliers de duración y recorridos sin cierre

**Decisión:** `stg_recorridos.duracion_seg` se castea pero NO se filtra. Se preservan:
- 260 viajes >24h en 2022 (probables bicis no devueltas).
- ~3.4k filas de 2024 con `duracion_seg=0` y `fecha_destino is null` (recorridos sin cierre al momento del export, concentrados al final del año).

**Por qué:** Son outliers reales del dominio, no errores de parsing. Filtrarlos en staging oculta señal útil (tasa de bicis no devueltas es un KPI operacional). El mart BI o el feature set ML deciden qué hacer (excluir, separar dim "perdidos", etc.). La métrica Q1 mide el % de viajes con duración válida (>0 y ≤24h) — threshold 99%.

**Trade-off:** Cualquier reporte BI que use `duracion_seg` sin filtrar va a tener cola larga. Hay que documentarlo en cada gráfico.

**Estado:** Activa.

---

## [2026-05-17] Dedup en recorridos: 1 registro byte-idéntico en 2024

**Decisión:** En `stg_recorridos.sql` (el union) se usa `select distinct *` para eliminar el único duplicado byte-idéntico detectado (id_recorrido `22425357` en 2024, dos filas idénticas).

**Por qué:** Es un dup byte-idéntico — no hay ambigüedad sobre cuál fila "preservar". `distinct` es la opción más simple y honesta. Alternativa `row_number() partition by id_recorrido` no aporta acá porque no hay criterio de ordenamiento que distinga las filas.

**Trade-off:** `distinct *` sobre 9M filas tiene costo (hash sobre todas las columnas). En DuckDB local es aceptable (~1-2s). Si en el futuro aparecieran muchos dups con diferencias parciales, conviene migrar a un dedup explícito con criterio.

**Estado:** Activa.

---

## [2026-05-17] FK floja entre recorridos e usuarios: ~30% de huérfanos esperados

**Decisión:** `stg_recorridos.id_usuario` NO tiene relationship test contra `stg_usuarios.id_usuario`. El join `recorridos → usuarios` en marts será LEFT (outer), no INNER.

**Por qué:** El padrón de usuarios contiene solo *altas* del año respectivo (439k usuarios únicos 2022-2024). Los recorridos referencian 488k usuarios únicos, de los cuales ~147k (~30%) son usuarios dados de alta antes de 2022 y por lo tanto no figuran en ningún padrón. Esto es comportamiento esperado de los datasets, no inconsistencia.

**Trade-off:** Análisis BI/ML que dependan de atributos del usuario (edad, género del padrón) van a tener cobertura ~70%. Para el segmento "histórico" no hay forma de recuperar esos atributos desde el dataset disponible. Documentar en el informe como limitación.

**Cross-team:** El equipo Python debería ver exactamente el mismo % de huérfanos. Si los conteos difieren, hay bug de matching de tipos (string vs int, sufijo no removido, etc.).

**Estado:** Activa.

---

## [2026-05-17] `tiene_dni` BOOLEAN nullable, NULL para 2024

**Decisión:** La columna `Customer.Has.Dni..Yes...No.` de los CSV 2022/2023 se mapea a `tiene_dni BOOLEAN` (`Yes→true, No→false`). El CSV 2024 no trae esa columna, así que para todas las filas de 2024 `tiene_dni = NULL`.

**Por qué:** Conservar la señal donde existe (~106k filas con dato real) es preferible a dropear la columna globalmente. NULL es semánticamente correcto: significa "columna no provista en el archivo de origen", distinguible de un usuario que efectivamente reportó no tener DNI (`false`).

**Trade-off:** Cualquier análisis BI/ML que use `tiene_dni` tiene que filtrar por `anio_archivo in (2022,2023)` o aceptar el sesgo. Documentado en la descripción del campo en `_stg_usuarios.yml`.

**Estado:** Activa.

---

## [2026-06-03] Mart ML: caso de uso = predicción de duración de viaje (regresión)

**Decisión:** El primer (y por ahora único) modelo de `mart_ml` es `ml_duracion_recorridos`, un feature set para **regresión supervisada** que predice `duracion_seg`. Grano: 1 fila = 1 recorrido. Features: `distancia_km` (haversine entre estaciones), `hora_origen`, `dia_semana` (isodow), `es_fin_de_semana`, `mes`, `modelo_bicicleta`. Se conserva `id_recorrido` como clave de trazabilidad (no es feature; el equipo ML lo dropea antes de `fit`).

**Por qué:**
- **Target real, no inventado:** `duracion_seg` ya existe en `stg_recorridos`. Caso defendible en la oral sin construir labels heurísticos (descartamos "commuter vs. paseo" justamente porque el label habría que justificarlo).
- **Mínima fricción de modelado:** el mart es casi `stg_recorridos` + columnas derivadas, sin capa de agregación (descartamos "demanda por estación/hora", que la requería).
- **Pocas features, todas derivables sin joins externos** — apropiado para el nivel del equipo y suficiente para un baseline de regresión con métrica estándar (RMSE/MAE en segundos).
- `distancia_km` por Haversine es la feature dominante esperada (a más distancia, más duración).

**Filtro de entrenamiento:** se incluyen solo viajes con `duracion_seg > 0 and <= 86400` (≤24h) y con lat/long no nulos en ambos extremos. Reutiliza el umbral de la métrica de calidad Q1 de `stg_recorridos` (no es un threshold nuevo): `duracion=0` son viajes sin cierre (~3.4k en 2024) y `>24h` son bicis no devueltas (~260 en 2022) — ruido que envenena la regresión. Resultado: ~9.06M filas sobre las ~9.1M de staging.

**Trade-off:** Es un único caso de uso; si el TP exige cubrir clasificación o no-supervisado, hay que sumar otro mart. La selección de features es deliberadamente mínima: no incluimos estación origen/destino como categóricas (alta cardinalidad) ni edad/género del usuario (requeriría join con `stg_usuarios`, que tiene ~30% de no-match). Si el modelo baseline rinde mal, esas son las primeras palancas para enriquecer.

**Cross-team:** Si el equipo Python hace el mismo caso de uso, deben aplicar idéntico filtro de duración y la misma fórmula de Haversine (R=6371 km) para que los row counts y las distancias cuadren.

**Estado:** Activa — filtro de duración superado por [2026-06-05].

---

## [2026-06-05] Mart BI: estrella con Fact_Viajes + 3 dimensiones

**Decisión:** El mart BI implementa un esquema estrella con 4 tablas: `fct_viajes`, `dim_estacion`, `dim_fecha`, `dim_usuario`. Grano de la tabla de hechos: 1 fila por combinación de (usuario, estación origen, estación destino, día). Medidas: `cantidad` (COUNT de viajes) y `minutos_promedio` (AVG de duración truncada a minutos).

**Por qué:**
- **Pre-agregación por día:** reduce el volumen de 9M filas a ~1-2M combinaciones únicas. Las herramientas BI (Tableau, Power BI) trabajan más rápido con tablas pre-agregadas que calculando SUM/AVG sobre la tabla de hechos transaccional.
- **dim_fecha con id YYYYMMDD:** evita una tabla de fechas pre-generada externa. DuckDB puede evaluar `strftime('%Y%m%d', date)` directamente en el filtro del hecho.
- **Excluir duracion_seg = 0 en el hecho:** los viajes sin cierre (~3.4k en 2024) tienen duración=0 y no representan recorridos completados. Incluirlos sesgaría `minutos_promedio` hacia 0.
- **dim_estacion derivada de recorridos:** consistente con la decisión [2026-05-16] de no bajar el catálogo externo.

**Trade-off:** El grano pre-agregado impide analizar viajes individuales desde la herramienta BI (no hay `id_recorrido`). Si se necesita drill-down a nivel de viaje individual, habría que agregar una segunda tabla de hechos con grano transaccional. La FK `id_usuario → dim_usuario` tiene ~30% de huérfanos esperados (ver [2026-05-17]); las herramientas BI mostrarán un nulo o "Desconocido" para esos usuarios.

**Estado:** Activa.

---

## [2026-06-13] Mart BI: rediseño a esquema con Dim_Demografía + Dim_Recorrido + Fact_Actividad

**Decisión:** El mart BI pasa de 4 a 6 tablas. `dim_usuario` queda eliminada y es reemplazada por `dim_demografia` (combinaciones únicas de genero × rango_etario). Se agregan `dim_recorrido` (pares origen→destino) y `fact_actividad` (segunda tabla de hechos con grano estación × demografía × día). La tabla `fct_viajes` cambia de grano: antes era (usuario, estación_origen, estación_destino, día); ahora es (demografía, recorrido, día). La medida `minutos_promedio` pasa a llamarse `minutos`.

**Por qué:**
- El diagrama de diseño entregado por el grupo reemplaza la dimensión de usuario individual por un segmento demográfico, lo que reduce la cardinalidad del hecho y lo hace más útil para análisis agregados en herramientas BI.
- `dim_recorrido` encapsula el par origen-destino como una entidad, separando la semántica de "ruta" de la geometría de las estaciones.
- `fact_actividad` permite responder preguntas de demanda por estación y perfil sin necesidad de abrir `fct_viajes` completa.
- El ~30% de viajes con usuarios huérfanos se agrupa en el segmento `(genero=NULL, rango_etario='Desconocido')` en lugar de quedar fuera del fact.

**Trade-off:** Ya no es posible trazar un viaje individual a un usuario concreto desde el mart BI. `fct_viajes` y `fact_actividad` repiten el mismo JOIN `stg_recorridos → stg_usuarios` (9M × 439k), lo que duplica tiempo de build; si fuera necesario optimizar se podría crear una CTE materializada intermedia. `dim_recorrido` incluye las columnas `id_estacion_origen` e `id_estacion_destino` para facilitar el join desde `fct_viajes` aunque no aparezcan en el diagrama conceptual.

**Superada por:** — (activa).

**Estado:** Activa.

---

## [2026-06-05] Mart ML: filtro de duración ajustado a > 60 seg y < 7200 seg

**Decisión:** El filtro de entrenamiento de `ml_duracion_recorridos` pasa de `duracion_seg > 0 and <= 86400` a `duracion_seg > 60 and < 7200`. Reemplaza el filtro registrado en [2026-06-03].

**Por qué:**
- `<= 60 seg` → cancelaciones o errores de registro: el usuario saca y devuelve la bici en segundos, no es un viaje real y contamina la regresión.
- `>= 7200 seg (2h)` → bicis no devueltas o errores de registro: outlier de cola larga que distorsiona el target mucho más que el umbral previo.

**Trade-off:** Se excluyen viajes de entre 2h y 24h que el filtro anterior incluía. Para el baseline de regresión de viajes cotidianos el rango 1min–2h cubre el grueso de la distribución; si se quisieran predecir viajes muy largos habría que elevar el techo.

**Cross-team:** El equipo Python debe aplicar el mismo filtro (`> 60 and < 7200`) para que los row counts del feature set cuadren.

**Estado:** Activa.

---
