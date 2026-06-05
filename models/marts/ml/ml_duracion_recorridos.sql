-- =============================================================================
-- FEATURE SET ML — Predicción de duración de viaje (regresión)
-- =============================================================================
-- Grano: 1 fila = 1 recorrido.
-- Target (lo que el modelo aprende a predecir): duracion_seg.
-- Consumidor: scikit-learn. Esta tabla es el DataFrame ya aplanado y limpio,
--   listo para train_test_split + model.fit(X, y). NO debe quedar ningún
--   join ni cálculo pendiente del lado de Python.
--
-- Decisión de diseño y selección de features: docs/decisions.md (2026-06-03).
-- =============================================================================

with recorridos as (
    select * from {{ ref('stg_recorridos') }}
),

features as (
    select
        -- ---- Identificador (NO es feature; se conserva para trazabilidad) ----
        -- El equipo ML lo dropea antes de entrenar. Sirve para auditar una
        -- predicción contra el viaje real.
        id_recorrido,

        -- ============================ TARGET ================================
        -- Lo que queremos predecir: cuántos segundos dura el viaje.
        duracion_seg,

        -- ============================ FEATURES =============================

        -- (1) distancia_km — distancia geográfica entre estación origen y
        --     destino, fórmula de Haversine (distancia sobre la esfera
        --     terrestre, R=6371 km). Es la feature MÁS predictiva: a mayor
        --     distancia, mayor duración esperada. Equivalente en web: como
        --     estimar el tiempo de respuesta a partir del tamaño del payload.
        6371 * 2 * asin(sqrt(
            pow(sin(radians(lat_estacion_destino - lat_estacion_origen) / 2), 2)
            + cos(radians(lat_estacion_origen))
            * cos(radians(lat_estacion_destino))
            * pow(sin(radians(long_estacion_destino - long_estacion_origen) / 2), 2)
        ))                                              as distancia_km,

        -- (2) hora_origen — hora del día (0-23) en que arranca el viaje.
        --     Captura el patrón pico/valle (8am y 18pm vs. madrugada).
        extract(hour from fecha_origen)                 as hora_origen,

        -- (3) dia_semana — 1=lunes ... 7=domingo (isodow). Permite al modelo
        --     distinguir patrones laborales vs. de fin de semana.
        extract(isodow from fecha_origen)               as dia_semana,

        -- (4) es_fin_de_semana — feature booleana derivada de dia_semana.
        --     Redundante con (3) pero le da al modelo una señal directa.
        case when extract(isodow from fecha_origen) in (6, 7)
             then 1 else 0 end                          as es_fin_de_semana,

        -- (5) mes — estacionalidad (1-12). En invierno se anda menos en bici.
        extract(month from fecha_origen)                as mes,

        -- (6) modelo_bicicleta — feature categórica (FIT / ICONIC). El equipo
        --     ML la codifica (one-hot / label) en Python.
        modelo_bicicleta

    from recorridos

    -- ---- Filtro de filas para entrenamiento ----
    -- Solo viajes con duración "razonable": > 60 seg y < 7200 seg (2h).
    -- Excluimos:
    --   - duracion_seg <= 60  → cancelaciones o errores de registro:
    --                           no representan un viaje real.
    --   - duracion_seg >= 7200 → bicis no devueltas o errores de registro:
    --                            outliers que distorsionan el target.
    -- Y exigimos lat/long no nulos en ambos extremos para que distancia_km
    -- sea calculable (descarta las ~2 filas de 2023 con estación destino NULL).
    where duracion_seg > 60
      and duracion_seg < 7200
      and lat_estacion_origen   is not null
      and long_estacion_origen  is not null
      and lat_estacion_destino  is not null
      and long_estacion_destino is not null
)

select * from features
