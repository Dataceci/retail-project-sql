-- =====================================================================
-- PROYECTO RETAIL - Pre-entrega: Análisis avanzado con Window Functions
-- Alumna: Cecilia Nuñez
-- Motor: PostgreSQL
--
-- Requisito: haber ejecutado antes script.sql y pre-entrega-modulo4.sql
-- (este último crea la tabla categorias y carga ventas de varios meses).
--
-- Objetivo de negocio: ver, mes a mes, cómo le va a cada categoría de
-- productos: cuánto vendió, qué lugar ocupó frente a las demás ese mes,
-- cuánto lleva acumulado en el tiempo y si el mes estuvo por encima o
-- por debajo de lo que esa categoría vende normalmente.
--
-- Reporte final (una fila por mes y categoría):
--   mes | categoria | venta_total | ranking_mes | venta_acumulada | comparativa
-- =====================================================================

WITH
-- ---------------------------------------------------------------------
-- CTE 1: ventas_mensuales
-- Limpia y agrupa los datos: lleva cada venta al primer día de su mes
-- con DATE_TRUNC('month', ...) y suma el monto vendido por mes y
-- categoría. Monto de cada venta = cantidad * precio_unitario (el precio
-- al momento de la venta). Desde acá, todo el análisis trabaja al mismo
-- nivel de detalle: mes/categoría.
-- ---------------------------------------------------------------------
ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', v.fecha_venta)::DATE   AS mes,
        cat.nombre                                 AS categoria,
        SUM(v.cantidad * v.precio_unitario)        AS venta_total
    FROM ventas v
    INNER JOIN productos  p   ON p.id_producto    = v.id_producto
    INNER JOIN categorias cat ON cat.id_categoria = p.id_categoria
    GROUP BY DATE_TRUNC('month', v.fecha_venta)::DATE, cat.nombre
),

-- ---------------------------------------------------------------------
-- CTE 2: metricas_ventana
-- Calcula las funciones de ventana sobre ventas_mensuales:
--   ranking_mes: posición de cada categoría dentro de su mes, de mayor
--     a menor venta. PARTITION BY mes reinicia el ranking cada mes.
--     RANK() da el mismo puesto a las categorías empatadas.
--   venta_acumulada (running total): suma progresiva de ventas de cada
--     categoría a lo largo de los meses. El ORDER BY mes dentro del
--     OVER es lo que hace que sume "hasta este mes"; sin él daría el
--     total general en todas las filas.
-- ---------------------------------------------------------------------
metricas_ventana AS (
    SELECT
        vm.mes,
        vm.categoria,
        vm.venta_total,
        RANK() OVER (
            PARTITION BY vm.mes
            ORDER BY vm.venta_total DESC
        )                                          AS ranking_mes,
        SUM(vm.venta_total) OVER (
            PARTITION BY vm.categoria
            ORDER BY vm.mes
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                          AS venta_acumulada
    FROM ventas_mensuales vm
)

-- ---------------------------------------------------------------------
-- CONSULTA FINAL
-- Agrega la lógica de negocio: compara la venta del mes contra el
-- promedio histórico mensual de esa misma categoría (AVG con
-- PARTITION BY categoria, calculado sobre los totales mensuales, así
-- se compara mes contra mes y no se mezcla granularidad).
--   Si la venta del mes es igual o mayor al promedio -> 'Exitoso'
--   Si es menor                                      -> 'Bajo el promedio'
-- ---------------------------------------------------------------------
SELECT
    TO_CHAR(mv.mes, 'YYYY-MM')                     AS mes,
    mv.categoria,
    mv.venta_total,
    mv.ranking_mes,
    mv.venta_acumulada,
    CASE
        WHEN mv.venta_total >= AVG(mv.venta_total) OVER (PARTITION BY mv.categoria)
            THEN 'Exitoso'
        ELSE 'Bajo el promedio'
    END                                            AS comparativa
FROM metricas_ventana mv
ORDER BY mv.mes, mv.ranking_mes;
