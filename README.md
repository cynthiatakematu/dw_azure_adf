# dw_azure_adf

Checkpoint FIAP de Data Warehouse com Azure Data Factory: ingestão da API pública de terremotos do USGS, armazenamento do GeoJSON original no ADLS Gen2 e carga de um modelo dimensional (dimensão + fato) no Azure SQL Database.

Aluna: Cynthia Takematu (RM 564100)

## Arquitetura

```
API USGS (REST, GET anônimo)
        │  Copy Activity (sem transformação)
        ▼
ADLS Gen2  landing/raw/prova_usgs/earthquakes_2024_01.geojson
        │  Mapping Data Flows (Flatten em features)
        ▼
Azure SQL  dbo.DIM_REDE_SISMICA  ◄──FK──  dbo.FATO_TERREMOTO
```

Fonte: `https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&starttime=2024-01-01&endtime=2024-02-01&minmagnitude=4.5&orderby=time-asc`

## Recursos Azure

| Recurso | Nome | Observação |
|---|---|---|
| Resource group | `GR_RM564100` | região `canadacentral` |
| Data Factory | `adf-aula-dw` | integrado a este repositório (branch `main`, publish `adf_publish`) |
| Storage ADLS Gen2 | `adlsdw564100` | hierarchical namespace ativo, container `landing` |
| Azure SQL | `server64100` / `free-sql-db-0970308` | oferta gratuita |

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `linkedService/` | `LS_REST_USGS` (REST anônimo), `LS_ADLS_USGS` (ADLS Gen2), `LS_SQL_DW` (Azure SQL) |
| `dataset/` | `DS_REST_USGS`, `DS_JSON_USGS_RAW`, `DS_JSON_USGS_RAW_DF`, `DS_SQL_DIM_REDE`, `DS_SQL_FATO_TERREMOTO` |
| `dataflow/` | `DF_DIM_REDE_SISMICA`, `DF_FATO_TERREMOTO` |
| `pipeline/` | `PL_CP_USGS` |
| `factory/` | definição do Data Factory |

## Pipeline `PL_CP_USGS`

Três atividades em sequência, cada uma dependente do sucesso da anterior:

1. **`CP_USGS_API_TO_RAW`** (Copy): consulta a API e grava o retorno em `landing/raw/prova_usgs/earthquakes_2024_01.geojson`, sem mapeamento, preservando `metadata` e `features`.
2. **`DF_CARGA_DIM`** (Data flow `DF_DIM_REDE_SISMICA`): Flatten em `features`, redes distintas de `properties.net` via Aggregate, Exists para inserir apenas redes novas, carga em `DIM_REDE_SISMICA`.
3. **`DF_CARGA_FATO`** (Data flow `DF_FATO_TERREMOTO`): Flatten em `features`, conversões de tipo, Lookup de `properties.net` em `DIM_REDE_SISMICA`, Exists por `EVENTO_ID` e carga em `FATO_TERREMOTO` sem mapear a coluna identity `EVENTO_SK`.

Transformações da fato:

```
DATA_HORA_UTC   = toTimestamp(toLong(features.properties.time))
LONGITUDE       = toDecimal(features.geometry.coordinates[1], 10, 6)
LATITUDE        = toDecimal(features.geometry.coordinates[2], 10, 6)
PROFUNDIDADE_KM = toDecimal(features.geometry.coordinates[3], 10, 3)
MAGNITUDE       = toDecimal(features.properties.mag, 6, 2)
```

Os índices de array em Mapping Data Flow começam em 1.

## Decisões de implementação

- **Dois datasets para o arquivo raw.** Com o encoding padrão, a Copy gravava o arquivo com BOM (`EF BB BF`), o que fazia o Spark do data flow rejeitar o JSON. A Copy usa `DS_JSON_USGS_RAW` com `UTF-8 without BOM`. Como esse encoding não é aceito em data flow, a leitura usa `DS_JSON_USGS_RAW_DF` (mesmo arquivo, `UTF-8`).
- **Document form `Single document`** nas sources JSON, pois o GeoJSON é um único objeto.
- **Campos extraídos no Flatten.** O Flatten da fato já projeta `id`, `net`, `time`, `mag`, `place` e `coordinates`, e o Derived Column aplica as conversões acima sobre essas colunas.
- **Cargas idempotentes.** Os dois fluxos usam Exists (`Doesn't exist`) contra a tabela de destino, então o pipeline pode ser reexecutado sem violar as restrições `UNIQUE` de `CODIGO_REDE` e `EVENTO_ID`.

## Modelo e validação

DDL e consultas de validação em `modelo_e_validacao.sql` (entregue junto com as evidências).

Resultado da execução:

| Validação | Resultado |
|---|---|
| `metadata.count` do GeoJSON x linhas da fato | 623 = 623 |
| `EVENTO_ID` duplicados | nenhum |
| Redes na dimensão | `us` (616), `ak` (5), `pr` (2) |
| Maior magnitude | `us6000m0xl`, 2024 Noto Peninsula, Japão, M 7.5 |

## Como executar

1. Criar as tabelas com a Parte 3 de `modelo_e_validacao.sql`.
2. Garantir a regra de firewall do Azure SQL que permite serviços do Azure.
3. No ADF Studio, abrir `PL_CP_USGS` e executar via Debug ou Publish + Trigger now.
4. Rodar as consultas da Parte 5 para validar.
