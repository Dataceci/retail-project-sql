-- =====================================================================
-- PROYECTO RETAIL - Pre-entrega
-- Tablas principales con restricciones y datos iniciales
-- Motor: PostgreSQL
-- =====================================================================

-- ---------------------------------------------------------------------
-- PASO 0: Crear la base de datos
-- Ejecutar esta línea SOLA, conectado a la base "postgres".
-- Después, conectarse a "retail_project" y ejecutar el resto del script.
-- (CREATE DATABASE no puede correr junto con otras sentencias en pgAdmin/DBeaver)
-- ---------------------------------------------------------------------
-- CREATE DATABASE retail_project;


-- =====================================================================
-- DDL - ESTRUCTURA DE TABLAS
-- Orden: clientes -> productos -> ventas (ventas va última por las FK)
-- =====================================================================

-- Permite re-ejecutar el script desde cero (borra en orden inverso)
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS clientes;

-- ---------------------------------------------------------------------
-- Tabla: clientes
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id_cliente     SERIAL        PRIMARY KEY,
    nombre         VARCHAR(50)   NOT NULL,
    apellido       VARCHAR(50)   NOT NULL,
    email          VARCHAR(100)  NOT NULL UNIQUE,
    edad           INTEGER       NOT NULL,
    ciudad         VARCHAR(60),
    fecha_alta     DATE          NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT chk_clientes_edad CHECK (edad >= 18 AND edad <= 120)
);

-- ---------------------------------------------------------------------
-- Tabla: productos
-- ---------------------------------------------------------------------
CREATE TABLE productos (
    id_producto    SERIAL         PRIMARY KEY,
    nombre         VARCHAR(100)   NOT NULL,
    categoria      VARCHAR(50)    NOT NULL,
    precio         DECIMAL(10,2)  NOT NULL,
    stock          INTEGER        NOT NULL DEFAULT 0,
    CONSTRAINT chk_productos_precio CHECK (precio > 0),
    CONSTRAINT chk_productos_stock  CHECK (stock >= 0)
);

-- ---------------------------------------------------------------------
-- Tabla: ventas (se crea última: depende de clientes y productos)
-- ---------------------------------------------------------------------
CREATE TABLE ventas (
    id_venta         SERIAL         PRIMARY KEY,
    id_cliente       INTEGER        NOT NULL,
    id_producto      INTEGER        NOT NULL,
    cantidad         INTEGER        NOT NULL,
    precio_unitario  DECIMAL(10,2)  NOT NULL,
    fecha_venta      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ventas_cliente
        FOREIGN KEY (id_cliente)  REFERENCES clientes (id_cliente),
    CONSTRAINT fk_ventas_producto
        FOREIGN KEY (id_producto) REFERENCES productos (id_producto),
    CONSTRAINT chk_ventas_cantidad        CHECK (cantidad > 0),
    CONSTRAINT chk_ventas_precio_unitario CHECK (precio_unitario > 0)
);


-- =====================================================================
-- DML - CARGA INICIAL DE DATOS (transacción explícita)
-- =====================================================================
BEGIN;

-- Clientes (5 registros)
INSERT INTO clientes (nombre, apellido, email, edad, ciudad, fecha_alta) VALUES
    ('Lucía',    'Fernández', 'lucia.fernandez@mail.com', 29, 'La Plata',     '2025-01-15'),
    ('Martín',   'Gómez',     'martin.gomez@mail.com',    41, 'Buenos Aires', '2025-02-03'),
    ('Sofía',    'Pereyra',   'sofia.pereyra@mail.com',   35, 'Azul',         '2025-03-10'),
    ('Diego',    'Romero',    'diego.romero@mail.com',    52, 'Tandil',       '2025-04-22'),
    ('Valentina','Sosa',      'valentina.sosa@mail.com',  23, 'Mar del Plata','2025-05-07');

-- Productos (5 registros)
INSERT INTO productos (nombre, categoria, precio, stock) VALUES
    ('Auriculares Bluetooth', 'Electrónica', 45000.00, 30),
    ('Mouse inalámbrico',     'Electrónica', 18500.00, 50),
    ('Remera de algodón',     'Indumentaria', 12000.00, 80),
    ('Zapatillas urbanas',    'Indumentaria', 95000.00, 20),
    ('Cafetera eléctrica',    'Hogar',        72000.00, 15);

-- Ventas (6 registros: la última es un registro de PRUEBA que se elimina abajo)
INSERT INTO ventas (id_cliente, id_producto, cantidad, precio_unitario, fecha_venta) VALUES
    (1, 1, 1, 45000.00, '2025-06-01 10:30:00'),
    (2, 3, 3, 12000.00, '2025-06-02 15:45:00'),
    (3, 5, 1, 72000.00, '2025-06-03 11:10:00'),
    (4, 2, 2, 18500.00, '2025-06-04 18:20:00'),
    (5, 4, 1, 95000.00, '2025-06-05 09:05:00'),
    (1, 2, 1,     1.00, '2025-06-06 00:00:00');  -- venta de prueba

COMMIT;


-- =====================================================================
-- DML - MANTENIMIENTO
-- =====================================================================

-- ---------------------------------------------------------------------
-- UPDATE masivo: aumento del 10% en la categoría "Electrónica"
-- Primero verificamos qué filas se van a modificar
-- ---------------------------------------------------------------------
SELECT id_producto, nombre, categoria, precio
FROM productos
WHERE categoria = 'Electrónica';

UPDATE productos
SET precio = ROUND(precio * 1.10, 2)
WHERE categoria = 'Electrónica';

-- Control posterior
SELECT id_producto, nombre, categoria, precio
FROM productos
WHERE categoria = 'Electrónica';

-- ---------------------------------------------------------------------
-- DELETE: eliminar la venta de prueba (id_venta = 6)
-- Primero verificamos que la fila a borrar es la correcta
-- ---------------------------------------------------------------------
SELECT *
FROM ventas
WHERE id_venta = 6;

DELETE FROM ventas
WHERE id_venta = 6;

-- Control final: deben quedar 5 ventas
SELECT * FROM ventas ORDER BY id_venta;
