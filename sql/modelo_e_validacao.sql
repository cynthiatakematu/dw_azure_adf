/* =====================================================================
   FIAP - Checkpoint DW ADF 02
   Nome: Cynthia Takematu - RM 564100
   ===================================================================== */

/* ---------------------------------------------------------------------
   PARTE 3 - MODELO
   --------------------------------------------------------------------- */

IF OBJECT_ID('dbo.DIM_REDE_SISMICA', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DIM_REDE_SISMICA (
        REDE_SK      INT IDENTITY(1,1) PRIMARY KEY,
        CODIGO_REDE  NVARCHAR(20) NOT NULL UNIQUE
    );
END;
GO

IF OBJECT_ID('dbo.FATO_TERREMOTO', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FATO_TERREMOTO (
        EVENTO_SK        BIGINT IDENTITY(1,1) PRIMARY KEY,
        EVENTO_ID        NVARCHAR(80)  NOT NULL UNIQUE,
        REDE_SK          INT           NOT NULL,
        DATA_HORA_UTC    DATETIME2(3)  NOT NULL,
        MAGNITUDE        DECIMAL(6,2)  NULL,
        PROFUNDIDADE_KM  DECIMAL(10,3) NULL,
        LONGITUDE        DECIMAL(10,6) NULL,
        LATITUDE         DECIMAL(10,6) NULL,
        LOCAL_DESCRICAO  NVARCHAR(300) NULL,
        CONSTRAINT FK_FATO_REDE FOREIGN KEY (REDE_SK)
            REFERENCES dbo.DIM_REDE_SISMICA(REDE_SK)
    );
END;
GO

/* ---------------------------------------------------------------------
   PARTE 5 - VALIDAÇÃO
   --------------------------------------------------------------------- */

-- 5.1 Contagem da fato x metadata.count do GeoJSON
SELECT
    623                                   AS METADATA_COUNT_GEOJSON,
    (SELECT COUNT(*) FROM dbo.FATO_TERREMOTO) AS LINHAS_FATO,
    CASE WHEN (SELECT COUNT(*) FROM dbo.FATO_TERREMOTO) = 623
         THEN 'OK' ELSE 'DIVERGENTE' END  AS STATUS;

-- 5.2 EVENTO_ID duplicados (resultado esperado: nenhuma linha)
SELECT EVENTO_ID, COUNT(*) AS QTD
FROM dbo.FATO_TERREMOTO
GROUP BY EVENTO_ID
HAVING COUNT(*) > 1;

-- 5.3 Dez terremotos de maior magnitude
SELECT TOP 10
    f.EVENTO_ID,
    f.DATA_HORA_UTC,
    f.MAGNITUDE,
    f.PROFUNDIDADE_KM,
    f.LATITUDE,
    f.LONGITUDE,
    f.LOCAL_DESCRICAO,
    d.CODIGO_REDE
FROM dbo.FATO_TERREMOTO f
JOIN dbo.DIM_REDE_SISMICA d ON d.REDE_SK = f.REDE_SK
ORDER BY f.MAGNITUDE DESC, f.DATA_HORA_UTC;
