# Mart BI — Guía de uso

## Qué son estos archivos

El mart BI produce cuatro parquets en `data/mart_bi/` que implementan un esquema estrella sobre los recorridos de Ecobici 2022–2024:

| Archivo | Filas | Descripción |
|---|---|---|
| `fct_viajes.parquet` | ~8.9M | Tabla de hechos. Un registro por combinación de (usuario, estación origen, estación destino, día). |
| `dim_estacion.parquet` | 416 | Catálogo de estaciones con su nombre. |
| `dim_fecha.parquet` | 1.096 | Atributos de cada día presente en los datos (día, mes, semana, año). |
| `dim_usuario.parquet` | 439.140 | Atributos del usuario del padrón (edad, género, rango etario). |

### Columnas de fct_viajes

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | BIGINT | Surrogate key. |
| `id_usuario` | BIGINT | FK → dim_usuario. ~30% sin match (usuarios dados de alta antes de 2022). |
| `id_estacion_origen` | SMALLINT | FK → dim_estacion. |
| `id_estacion_destino` | SMALLINT | FK → dim_estacion. |
| `id_fecha` | INTEGER | FK → dim_fecha. Formato YYYYMMDD (ej. `20220315`). |
| `cantidad` | INTEGER | Cantidad de viajes en esa combinación ese día. |
| `minutos_promedio` | INTEGER | Duración promedio de esos viajes en minutos. |

---

## Cómo conectar en Power BI / Tableau

1. **Importar** cada parquet como tabla separada (en Power BI: *Obtener datos → Parquet*; en Tableau: *Conectar → Archivos → Parquet*).
2. **Definir las relaciones** en la vista de modelo:
   - `fct_viajes.id_estacion_origen` → `dim_estacion.id`
   - `fct_viajes.id_estacion_destino` → `dim_estacion.id`
   - `fct_viajes.id_fecha` → `dim_fecha.id`
   - `fct_viajes.id_usuario` → `dim_usuario.id`
3. La herramienta hace los JOINs automáticamente cuando construís un gráfico.

> **Nota:** Para la FK `id_estacion_destino` e `id_estacion_origen` apuntan ambas a la misma tabla `dim_estacion`. En Power BI hay que crear una segunda relación inactiva y activarla con `USERELATIONSHIP` en la medida, o duplicar la tabla de dimensión como `dim_estacion_origen` y `dim_estacion_destino`.

---

## Cómo consultar directamente con DuckDB o SQL

```bash
# desde la raíz del repo
duckdb
```

```sql
-- viajes por mes y año
SELECT
    f.anio,
    f.mes,
    SUM(v.cantidad)          AS total_viajes,
    AVG(v.minutos_promedio)  AS minutos_prom
FROM 'data/mart_bi/fct_viajes.parquet'   v
JOIN 'data/mart_bi/dim_fecha.parquet'    f ON f.id = v.id_fecha
GROUP BY f.anio, f.mes
ORDER BY f.anio, f.mes;

-- top 10 estaciones de origen
SELECT
    e.nombre,
    SUM(v.cantidad) AS total_viajes
FROM 'data/mart_bi/fct_viajes.parquet'     v
JOIN 'data/mart_bi/dim_estacion.parquet'   e ON e.id = v.id_estacion_origen
GROUP BY e.nombre
ORDER BY total_viajes DESC
LIMIT 10;

-- viajes por rango etario (solo usuarios con match en el padrón)
SELECT
    u.rango_etario,
    SUM(v.cantidad) AS total_viajes
FROM 'data/mart_bi/fct_viajes.parquet'    v
JOIN 'data/mart_bi/dim_usuario.parquet'   u ON u.id = v.id_usuario
GROUP BY u.rango_etario
ORDER BY total_viajes DESC;
```

---

## Limitaciones conocidas

- **30% de usuarios sin atributos:** los usuarios dados de alta antes de 2022 no figuran en el padrón. Sus viajes aparecen en `fct_viajes` pero el JOIN con `dim_usuario` devuelve NULL. Filtrar con `WHERE u.id IS NOT NULL` si el análisis requiere atributos del usuario.
- **Viajes sin cierre excluidos:** los ~3.400 recorridos de 2024 con `duracion_seg = 0` (bicicletas no devueltas al momento del export) no están en `fct_viajes`. Son menos del 0.1% del total.
- **Sin barrio/comuna:** `dim_estacion` solo tiene `id` y `nombre`. No se descargó el catálogo externo de estaciones.
- **`minutos_promedio` truncado a entero:** la duración promedio se trunca, no se redondea. Diferencia máxima: 1 minuto.
