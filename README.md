# retail-project-sql

Pre-entrega del proyecto retail: esquema base (`clientes`, `productos`, `ventas`) con restricciones de integridad y carga inicial de datos. Motor: **PostgreSQL**.

## Contenido

- `script.sql`: DDL (creación de tablas con PK, FK, UNIQUE y CHECK) y DML (carga en transacción `BEGIN ... COMMIT`, `UPDATE` masivo de precios y `DELETE` de una venta de prueba).

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
