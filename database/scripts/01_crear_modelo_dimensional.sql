/* =====================================================================
   Kent Foods - Modelo Dimensional (esquema estrella)
   Certamen 2 - Inteligencia de Negocios - Fase 1
   Proceso de negocio : Ventas (órdenes de clientes)
   Granularidad       : una fila por producto vendido en una orden
                        (una línea de DetalleOrden)
   ===================================================================== */

USE master;
GO

IF DB_ID('KentFoodsDW') IS NOT NULL
BEGIN
    ALTER DATABASE KentFoodsDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE KentFoodsDW;
END
GO

CREATE DATABASE KentFoodsDW;
GO

USE KentFoodsDW;
GO

/* ---------------------------------------------------------------------
   DIMENSIONES
   --------------------------------------------------------------------- */

-- Dimensión Tiempo (se usa dos veces en el hecho: fecha de orden y fecha de envío)
CREATE TABLE DimTiempo (
    TiempoKey       INT          NOT NULL PRIMARY KEY,  -- formato AAAAMMDD; -1 = sin fecha
    Fecha           DATE         NULL,
    Anio            SMALLINT     NOT NULL,
    Semestre        TINYINT      NOT NULL,
    Trimestre       TINYINT      NOT NULL,
    Mes             TINYINT      NOT NULL,
    NombreMes       NVARCHAR(15) NOT NULL,
    Dia             TINYINT      NOT NULL,
    DiaSemana       TINYINT      NOT NULL,              -- 1 = lunes ... 7 = domingo
    NombreDiaSemana NVARCHAR(15) NOT NULL
);
GO

CREATE TABLE DimCliente (
    ClienteKey   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ClienteID    NCHAR(5)      NOT NULL,                -- clave natural (origen)
    Empresa      NVARCHAR(40)  NOT NULL,
    Contacto     NVARCHAR(30)  NOT NULL,
    Ciudad       NVARCHAR(15)  NOT NULL,
    Pais         NVARCHAR(15)  NOT NULL
);
GO

CREATE TABLE DimProducto (
    ProductoKey       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProductoID        INT           NOT NULL,           -- clave natural (origen)
    Producto          NVARCHAR(40)  NOT NULL,
    CantidadPorUnidad NVARCHAR(20)  NOT NULL,
    Categoria         NVARCHAR(15)  NOT NULL,           -- desnormalizado desde Categorias
    Proveedor         NVARCHAR(40)  NOT NULL,           -- desnormalizado desde Proveedores
    PaisProveedor     NVARCHAR(15)  NOT NULL
);
GO

CREATE TABLE DimEmpleado (
    EmpleadoKey    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EmpleadoID     INT           NOT NULL,              -- clave natural (origen)
    NombreCompleto NVARCHAR(35)  NOT NULL,              -- Nombre + ' ' + Apellido
    Cargo          NVARCHAR(30)  NOT NULL,
    Ciudad         NVARCHAR(15)  NOT NULL,
    Pais           NVARCHAR(15)  NOT NULL
);
GO

CREATE TABLE DimTransportista (
    TransportistaKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    TransportistaID  INT           NOT NULL,            -- clave natural (origen)
    Transportista    NVARCHAR(40)  NOT NULL
);
GO

/* ---------------------------------------------------------------------
   TABLA DE HECHOS
   --------------------------------------------------------------------- */

CREATE TABLE FactVentas (
    OrdenID          INT           NOT NULL,            -- dimensión degenerada
    ProductoKey      INT           NOT NULL,
    ClienteKey       INT           NOT NULL,
    EmpleadoKey      INT           NOT NULL,
    TransportistaKey INT           NOT NULL,
    FechaOrdenKey    INT           NOT NULL,
    FechaEnvioKey    INT           NOT NULL,            -- -1 si la orden aún no se envía

    -- Medidas
    Cantidad         SMALLINT      NOT NULL,
    PrecioUnitario   DECIMAL(10,2) NOT NULL,            -- precio real de la venta (no el de lista)
    Descuento        DECIMAL(4,2)  NOT NULL,            -- porcentaje, ej. 0.15 = 15 %
    MontoBruto       DECIMAL(12,2) NOT NULL,            -- Cantidad * PrecioUnitario
    MontoDescuento   DECIMAL(12,2) NOT NULL,            -- MontoBruto * Descuento
    MontoNeto        DECIMAL(12,2) NOT NULL,            -- MontoBruto - MontoDescuento
    DiasDespacho     SMALLINT      NULL,                -- FechaEnvio - FechaOrden; NULL si no se envía

    CONSTRAINT PK_FactVentas PRIMARY KEY (OrdenID, ProductoKey),
    CONSTRAINT FK_FactVentas_Producto      FOREIGN KEY (ProductoKey)      REFERENCES DimProducto(ProductoKey),
    CONSTRAINT FK_FactVentas_Cliente       FOREIGN KEY (ClienteKey)       REFERENCES DimCliente(ClienteKey),
    CONSTRAINT FK_FactVentas_Empleado      FOREIGN KEY (EmpleadoKey)      REFERENCES DimEmpleado(EmpleadoKey),
    CONSTRAINT FK_FactVentas_Transportista FOREIGN KEY (TransportistaKey) REFERENCES DimTransportista(TransportistaKey),
    CONSTRAINT FK_FactVentas_FechaOrden    FOREIGN KEY (FechaOrdenKey)    REFERENCES DimTiempo(TiempoKey),
    CONSTRAINT FK_FactVentas_FechaEnvio    FOREIGN KEY (FechaEnvioKey)    REFERENCES DimTiempo(TiempoKey)
);
GO

/* ---------------------------------------------------------------------
   CARGA DE DimTiempo
   La dimensión tiempo no existe en la base transaccional: se genera aquí.
   Rango 2016-2018 = años que cubren las órdenes de Kent Foods.
   --------------------------------------------------------------------- */

-- Fila especial para órdenes sin fecha de envío
INSERT INTO DimTiempo VALUES (-1, NULL, 0, 0, 0, 0, N'Sin fecha', 0, 0, N'Sin fecha');

DECLARE @f DATE = '2016-01-01';
WHILE @f <= '2018-12-31'
BEGIN
    INSERT INTO DimTiempo
    VALUES (
        CONVERT(INT, FORMAT(@f, 'yyyyMMdd')),
        @f,
        YEAR(@f),
        CASE WHEN MONTH(@f) <= 6 THEN 1 ELSE 2 END,
        DATEPART(QUARTER, @f),
        MONTH(@f),
        CHOOSE(MONTH(@f), N'Enero', N'Febrero', N'Marzo', N'Abril', N'Mayo', N'Junio',
                          N'Julio', N'Agosto', N'Septiembre', N'Octubre', N'Noviembre', N'Diciembre'),
        DAY(@f),
        (DATEDIFF(DAY, '19000101', @f) % 7) + 1,         -- 1900-01-01 fue lunes
        CHOOSE((DATEDIFF(DAY, '19000101', @f) % 7) + 1,
               N'Lunes', N'Martes', N'Miércoles', N'Jueves', N'Viernes', N'Sábado', N'Domingo')
    );
    SET @f = DATEADD(DAY, 1, @f);
END
GO
