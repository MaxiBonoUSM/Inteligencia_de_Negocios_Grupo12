/* =====================================================================
   Kent Foods - Permiso de lectura para Analysis Services (Fase 2)
   El cubo lee KentFoodsDW con la cuenta del servicio de SSAS.
   Esa cuenta necesita un login en SQL Server y permiso de lectura.
   Ejecutar UNA vez en el motor de base de datos (no en Analysis Services).
   Cuenta del servicio para la instancia por defecto: NT Service\MSSQLServerOLAPService
   ===================================================================== */

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'NT Service\MSSQLServerOLAPService')
    CREATE LOGIN [NT Service\MSSQLServerOLAPService] FROM WINDOWS;
GO

USE KentFoodsDW;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'NT Service\MSSQLServerOLAPService')
    CREATE USER [NT Service\MSSQLServerOLAPService] FOR LOGIN [NT Service\MSSQLServerOLAPService];
GO

ALTER ROLE db_datareader ADD MEMBER [NT Service\MSSQLServerOLAPService];
GO
