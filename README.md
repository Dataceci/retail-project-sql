# retail-project-sql

Pre-entrega del proyecto retail: esquema base (`clientes`, `productos`, `ventas`) con restricciones de integridad y carga inicial de datos. Motor: **PostgreSQL**.

## Contenido

- `script.sql`: DDL (creación de tablas con PK, FK, UNIQUE y CHECK) y DML (carga en transacción `BEGIN ... COMMIT`, `UPDATE` masivo de precios y `DELETE` de una venta de prueba).
- `pre-entrega-modulo4.sql`: consultas multicapa para análisis de negocio (JOIN, GROUP BY, HAVING). Ver sección "Módulo 4".
- `preentrega_analisis_avanzado.sql`: reporte mensual por categoría con CTEs y Window Functions. Ver sección "Análisis avanzado".

## Cómo ejecutarlo (pgAdmin o DBeaver)

1. Conectado a la base `postgres`, crear la base de datos:
   ```sql
   CREATE DATABASE retail_project;
   ```
2. Conectarse a la base `retail_project`.
3. Abrir `script.sql` y ejecutarlo completo.

Desde la terminal también se puede:

```bash
createdb retail_project
psql -d retail_project -f script.sql
```

El script empieza con `DROP TABLE IF EXISTS`, así que se puede volver a ejecutar desde cero.

## Restricciones incluidas

| Tabla | Restricciones |
|---|---|
| `clientes` | PK `id_cliente`, `email` UNIQUE y NOT NULL, CHECK edad entre 18 y 120 |
| `productos` | PK `id_producto` (SERIAL), CHECK `precio > 0`, CHECK `stock >= 0` |
| `ventas` | PK `id_venta`, FK a `clientes` y a `productos`, CHECK `cantidad > 0`, CHECK `precio_unitario > 0` |

## Mantenimiento

- `UPDATE`: aumenta 10% el precio de la categoría `Electrónica` (con `SELECT` de control antes y después).
- `DELETE`: elimina la venta de prueba `id_venta = 6` (con `SELECT` previo). Quedan 5 ventas.

## Módulo 4: consultas multicapa

Ejecutar `pre-entrega-modulo4.sql` en la base `retail_project`, **después** de `script.sql`.

El script empieza con un paso de preparación: crea la tabla `categorias`, la vincula con `productos` mediante una FK y agrega algunos datos (dos clientes sin compras y compras repetidas). Se puede ejecutar más de una vez sin duplicar datos.

| Consulta | Problema de negocio | Técnicas |
|---|---|---|
| 1. Rentabilidad por categoría | Qué categorías generan más ingresos (umbral: más de $100.000) | JOIN de 3 tablas, `SUM`, `GROUP BY`, `HAVING` |
| 2. Clientes sin compras | Clientes registrados a los que apuntar una campaña de primera compra | `LEFT JOIN`, `COALESCE`, `HAVING COUNT = 0` |
| 3. Top de compras por cliente | Producto preferido y fecha de última compra de cada cliente | JOIN de 3 tablas, `WITH`, `ROW_NUMBER`, `MAX` |

## Análisis avanzado: Window Functions

Ejecutar `preentrega_analisis_avanzado.sql` en la base `retail_project`, **después** de `script.sql` y `pre-entrega-modulo4.sql`. Es solo una consulta: no modifica datos.

Estructura:

- CTE `ventas_mensuales`: agrupa las ventas por mes (`DATE_TRUNC('month', ...)`) y categoría, y suma el total vendido.
- CTE `metricas_ventana`: calcula el ranking de cada categoría dentro de su mes (`RANK() OVER (PARTITION BY mes ...)`) y el acumulado de ventas por categoría (`SUM() OVER (PARTITION BY categoria ORDER BY mes)`).
- Consulta final: con `CASE WHEN` compara la venta del mes contra el promedio mensual de la categoría y devuelve `Exitoso` o `Bajo el promedio`.

Columnas del reporte: `mes`, `categoria`, `venta_total`, `ranking_mes`, `venta_acumulada`, `comparativa`.
