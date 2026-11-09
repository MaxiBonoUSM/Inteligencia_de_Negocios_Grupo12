/* =====================================================================
   Kent Foods - Vistas para el cubo OLAP (Fase 2)
   Ejecutar en KentFoodsDW DESPUÉS del ETL. No modifica ninguna tabla:
   solo crea dos vistas que el cubo SSAS usa como origen.
   ===================================================================== */

USE KentFoodsDW;
GO

/* ---------------------------------------------------------------------
   vDimTiempo: DimTiempo + nombres legibles para cada nivel del calendario.
   La fila -1 muestra "Sin fecha" en todos los niveles.
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vDimTiempo AS
SELECT
    TiempoKey,
    Fecha,
    CASE WHEN TiempoKey = -1 THEN N'Sin fecha'
         ELSE CONVERT(NVARCHAR(10), Fecha, 105) END                              AS FechaNombre,     -- 15-03-2017
    Anio,
    CASE WHEN TiempoKey = -1 THEN N'Sin fecha'
         ELSE CAST(Anio AS NVARCHAR(4)) END                                        AS AnioNombre,      -- 2017
    Semestre,
    CASE WHEN TiempoKey = -1 THEN N'Sin fecha'
         ELSE N'S' + CAST(Semestre AS NVARCHAR(1)) + N' ' + CAST(Anio AS NVARCHAR(4)) END  AS SemestreNombre,  -- S1 2017
    Trimestre,
    CASE WHEN TiempoKey = -1 THEN N'Sin fecha'
         ELSE N'T' + CAST(Trimestre AS NVARCHAR(1)) + N' ' + CAST(Anio AS NVARCHAR(4)) END AS TrimestreNombre, -- T1 2017
    Mes,
    CASE WHEN TiempoKey = -1 THEN N'Sin fecha'
         ELSE NombreMes + N' ' + CAST(Anio AS NVARCHAR(4)) END                     AS MesNombre,       -- Marzo 2017
    DiaSemana,
    NombreDiaSemana
FROM dbo.DimTiempo;
GO

/* ---------------------------------------------------------------------
   vFactOrdenes: una fila por ORDEN (830 filas).
   FactVentas tiene una fila por producto, así que los datos de la orden
   se repiten. Esta vista los deja una sola vez, para contar órdenes y
   promediar días de despacho correctamente.
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vFactOrdenes AS
SELECT
    OrdenID,
    MIN(ClienteKey)       AS ClienteKey,        -- iguales en todas las líneas de la orden
    MIN(EmpleadoKey)      AS EmpleadoKey,
    MIN(TransportistaKey) AS TransportistaKey,
    MIN(FechaOrdenKey)    AS FechaOrdenKey,
    MIN(FechaEnvioKey)    AS FechaEnvioKey,
    CAST(MAX(CASE WHEN FechaEnvioKey = -1 THEN 0 ELSE DiasDespacho END) AS INT) AS DiasDespacho, -- 0 si no se envió (no se promedia)
    CAST(MAX(CASE WHEN FechaEnvioKey = -1 THEN 0 ELSE 1 END) AS INT)            AS Enviada,      -- 1 = orden enviada
    CAST(MAX(CASE WHEN FechaEnvioKey = -1 THEN 1 ELSE 0 END) AS INT)            AS Pendiente     -- 1 = orden sin envío
FROM dbo.FactVentas
GROUP BY OrdenID;
GO

-- Comprobación rápida (esperado: 830 órdenes, 809 enviadas, 21 pendientes, 6870 días)
SELECT COUNT(*) AS Ordenes, SUM(Enviada) AS Enviadas, SUM(Pendiente) AS Pendientes,
       SUM(DiasDespacho) AS DiasTotales
FROM dbo.vFactOrdenes;
GO
