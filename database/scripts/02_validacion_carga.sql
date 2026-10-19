/* =====================================================================
   Kent Foods - Validación de la carga ETL
   Ejecutar DESPUÉS del paquete SSIS. Compara la base origen (KentFoods)
   con el modelo dimensional (KentFoodsDW). La columna Resultado debe
   decir OK en todas las filas.
   ===================================================================== */

USE KentFoodsDW;
GO

SELECT Validacion, Origen, DW,
       CASE WHEN Origen = DW THEN 'OK' ELSE 'ERROR' END AS Resultado
FROM (
    SELECT 'Filas DimCliente', (SELECT COUNT(*) FROM KentFoods.dbo.Clientes),       (SELECT COUNT(*) FROM DimCliente)
    UNION ALL
    SELECT 'Filas DimProducto', (SELECT COUNT(*) FROM KentFoods.dbo.Productos),     (SELECT COUNT(*) FROM DimProducto)
    UNION ALL
    SELECT 'Filas DimEmpleado', (SELECT COUNT(*) FROM KentFoods.dbo.Empleados),     (SELECT COUNT(*) FROM DimEmpleado)
    UNION ALL
    SELECT 'Filas DimTransportista', (SELECT COUNT(*) FROM KentFoods.dbo.Transportistas), (SELECT COUNT(*) FROM DimTransportista)
    UNION ALL
    SELECT 'Filas FactVentas', (SELECT COUNT(*) FROM KentFoods.dbo.DetalleOrden),   (SELECT COUNT(*) FROM FactVentas)
    UNION ALL
    SELECT 'Órdenes distintas', (SELECT COUNT(*) FROM KentFoods.dbo.Ordenes),       (SELECT COUNT(DISTINCT OrdenID) FROM FactVentas)
    UNION ALL
    SELECT 'Órdenes sin envío', (SELECT COUNT(*) FROM KentFoods.dbo.Ordenes WHERE FechaEnvio IS NULL),
                                (SELECT COUNT(DISTINCT OrdenID) FROM FactVentas WHERE FechaEnvioKey = -1)
    UNION ALL
    SELECT 'Suma Cantidad', (SELECT SUM(Cantidad) FROM KentFoods.dbo.DetalleOrden),  (SELECT SUM(Cantidad) FROM FactVentas)
    UNION ALL
    SELECT 'Suma MontoBruto',
           (SELECT SUM(CAST(PrecioUnitario * Cantidad AS DECIMAL(12,2))) FROM KentFoods.dbo.DetalleOrden),
           (SELECT SUM(MontoBruto) FROM FactVentas)
) AS v (Validacion, Origen, DW);
GO

-- Hechos con claves que no encontraron su dimensión (debe devolver 0)
SELECT COUNT(*) AS HechosSinDimension
FROM FactVentas f
LEFT JOIN DimCliente       c ON c.ClienteKey       = f.ClienteKey
LEFT JOIN DimProducto      p ON p.ProductoKey      = f.ProductoKey
LEFT JOIN DimEmpleado      e ON e.EmpleadoKey      = f.EmpleadoKey
LEFT JOIN DimTransportista t ON t.TransportistaKey = f.TransportistaKey
WHERE c.ClienteKey IS NULL OR p.ProductoKey IS NULL
   OR e.EmpleadoKey IS NULL OR t.TransportistaKey IS NULL;
GO

-- Ventas netas por año (esperado: 2016 = 208.083,95 | 2017 = 617.085,05 | 2018 = 440.623,76)
SELECT t.Anio, SUM(f.MontoNeto) AS VentasNetas
FROM FactVentas f
JOIN DimTiempo t ON t.TiempoKey = f.FechaOrdenKey
GROUP BY t.Anio
ORDER BY t.Anio;
GO
