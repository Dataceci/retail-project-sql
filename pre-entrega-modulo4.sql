-- =====================================================================
-- PROYECTO RETAIL - Pre-entrega Módulo 4
-- Consultas multicapa para análisis de negocio (JOIN, GROUP BY, HAVING)
-- Alumna: Cecilia Nuñez
-- Motor: PostgreSQL
--
-- Requisito: haber ejecutado antes script.sql (tablas clientes,
-- productos y ventas con sus datos iniciales).
-- Este script se puede ejecutar más de una vez sin duplicar datos.
-- =====================================================================


-- =====================================================================
-- PASO 0: PREPARACIÓN DE DATOS
-- ---------------------------------------------------------------------
-- En el módulo anterior la categoría se guardaba como texto dentro de
-- "productos". Para este análisis se normaliza en una tabla propia
-- "categorias", y se cargan algunos datos más para que las consultas
-- tengan casos reales que mostrar (clientes sin compras, clientes que
-- repiten productos).
-- =====================================================================

-- Tabla categorias
CREATE TABLE IF NOT EXISTS categorias (
    id_categoria  SERIAL       PRIMARY KEY,
    nombre        VARCHAR(50)  NOT NULL UNIQUE
);

-- Una fila por cada categoría que ya existe en productos
INSERT INTO categorias (nombre)
SELECT DISTINCT p.categoria
FROM productos p
ON CONFLICT (nombre) DO NOTHING;

-- Vincular productos con categorias mediante una FOREIGN KEY
ALTER TABLE productos
    ADD COLUMN IF NOT EXISTS id_categoria INTEGER
    REFERENCES categorias (id_categoria);

UPDATE productos p
SET id_categoria = cat.id_categoria
FROM categorias cat
WHERE cat.nombre = p.categoria
  AND p.id_categoria IS NULL;

-- Datos adicionales
BEGIN;

-- Dos clientes registrados que todavía no compraron nada
INSERT INTO clientes (nombre, apellido, email, edad, ciudad, fecha_alta) VALUES
    ('Julieta', 'Ramírez', 'julieta.ramirez@mail.com', 31, 'Olavarría', '2025-08-01'),
    ('Tomás',   'Acosta',  'tomas.acosta@mail.com',    45, 'Bahía Blanca', '2025-09-15')
ON CONFLICT (email) DO NOTHING;

-- Compras repetidas de clientes existentes (precio_unitario = precio vigente
-- al momento de la venta). NOT EXISTS evita duplicarlas si se re-ejecuta.
INSERT INTO ventas (id_cliente, id_producto, cantidad, precio_unitario, fecha_venta)
SELECT n.id_cliente, n.id_producto, n.cantidad, n.precio_unitario, n.fecha_venta
FROM (VALUES
    (1, 2, 1, 20350.00, TIMESTAMP '2025-07-10 12:00:00'),
    (1, 1, 1, 49500.00, TIMESTAMP '2025-08-15 17:30:00'),
    (2, 3, 2, 12000.00, TIMESTAMP '2025-07-20 10:15:00'),
    (2, 4, 1, 95000.00, TIMESTAMP '2025-09-01 19:00:00'),
    (3, 3, 1, 12000.00, TIMESTAMP '2025-08-02 16:40:00'),
    (4, 2, 1, 20350.00, TIMESTAMP '2025-09-12 11:20:00')
) AS n (id_cliente, id_producto, cantidad, precio_unitario, fecha_venta)
WHERE NOT EXISTS (
    SELECT 1
    FROM ventas v
    WHERE v.id_cliente  = n.id_cliente
      AND v.id_producto = n.id_producto
      AND v.fecha_venta = n.fecha_venta
);

COMMIT;


-- =====================================================================
-- CONSULTA 1: RENTABILIDAD POR CATEGORÍA
-- ---------------------------------------------------------------------
-- Problema de negocio: el área comercial necesita saber qué categorías
-- generan más ingresos, para decidir dónde invertir en stock, espacio de
-- exhibición y promociones, y cuáles conviene revisar.
--
-- Une 3 tablas: ventas -> productos -> categorias.
-- Ingreso = cantidad * precio_unitario (el precio al momento de la venta,
-- no el precio actual del producto, que pudo cambiar después).
--
-- Umbral definido en $100.000 de ingreso total porque es aproximadamente
-- el valor de una sola venta de nuestro producto más caro (zapatillas,
-- $95.000): una categoría que en todo el período no supera ese monto
-- tiene un movimiento muy bajo y se considera "a revisar". Solo se
-- muestran las categorías que lo superan.
--
-- La condición va en HAVING (no en WHERE) porque filtra sobre un
-- resultado agregado (SUM).
-- =====================================================================
SELECT
    cat.nombre                            AS categoria,
    SUM(v.cantidad)                       AS unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario)   AS ingreso_total
FROM ventas v
INNER JOIN productos  p   ON p.id_producto    = v.id_producto
INNER JOIN categorias cat ON cat.id_categoria = p.id_categoria
GROUP BY cat.nombre
HAVING SUM(v.cantidad * v.precio_unitario) > 100000
ORDER BY ingreso_total DESC;


-- =====================================================================
-- CONSULTA 2: CLIENTES SIN COMPRAS
-- ---------------------------------------------------------------------
-- Problema de negocio: hay clientes que se registraron pero nunca
-- compraron. Marketing quiere identificarlos para enviarles una campaña
-- de "primera compra" (por ejemplo, un cupón de bienvenida) y así
-- convertir registros en ventas.
--
-- LEFT JOIN conserva a todos los clientes, aunque no tengan ventas;
-- en ese caso las columnas de ventas vienen en NULL. COALESCE convierte
-- esos NULL en 0 para que el reporte sea claro. HAVING COUNT(...) = 0
-- se queda solo con los que no tienen ninguna venta.
-- =====================================================================
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido                         AS cliente,
    c.email,
    c.fecha_alta,
    COUNT(v.id_venta)                                     AS cantidad_compras,
    COALESCE(SUM(v.cantidad * v.precio_unitario), 0)      AS total_gastado
FROM clientes c
LEFT JOIN ventas v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido, c.email, c.fecha_alta
HAVING COUNT(v.id_venta) = 0
ORDER BY c.fecha_alta;


-- =====================================================================
-- CONSULTA 3: TOP DE COMPRAS POR CLIENTE
-- ---------------------------------------------------------------------
-- Problema de negocio: para personalizar ofertas y detectar clientes
-- inactivos, necesitamos conocer, por cada cliente, cuál es su producto
-- preferido (el que compró más veces) y cuándo fue su última compra.
--
-- Une 3 tablas: clientes -> ventas -> productos.
-- Se arma en dos pasos (WITH):
--   compras_por_producto: cuántas veces compró cada cliente cada
--     producto, y le pone un ranking (1 = el más comprado). Si hay
--     empate en cantidad de veces, gana el de más unidades y después
--     el comprado más recientemente.
--   ultima_compra: la fecha de la última transacción de cada cliente,
--     sobre todas sus compras.
-- Al final se muestra solo el producto con ranking 1 de cada cliente.
-- =====================================================================
WITH compras_por_producto AS (
    SELECT
        v.id_cliente,
        p.nombre                      AS producto,
        COUNT(v.id_venta)             AS veces_comprado,
        SUM(v.cantidad)               AS unidades,
        ROW_NUMBER() OVER (
            PARTITION BY v.id_cliente
            ORDER BY COUNT(v.id_venta) DESC,
                     SUM(v.cantidad) DESC,
                     MAX(v.fecha_venta) DESC
        )                             AS ranking
    FROM ventas v
    INNER JOIN productos p ON p.id_producto = v.id_producto
    GROUP BY v.id_cliente, p.nombre
),
ultima_compra AS (
    SELECT
        v.id_cliente,
        MAX(v.fecha_venta)            AS fecha_ultima_compra
    FROM ventas v
    GROUP BY v.id_cliente
)
SELECT
    c.nombre || ' ' || c.apellido     AS cliente,
    cp.producto                       AS producto_mas_comprado,
    cp.veces_comprado,
    uc.fecha_ultima_compra
FROM clientes c
INNER JOIN compras_por_producto cp ON cp.id_cliente = c.id_cliente
                                  AND cp.ranking    = 1
INNER JOIN ultima_compra        uc ON uc.id_cliente = c.id_cliente
ORDER BY cp.veces_comprado DESC, uc.fecha_ultima_compra DESC;
