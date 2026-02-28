# MCP SQL Session Summary (2026-02-20)

## Environment + Connection
- Server discovered: `localhost`
- Active connection context: `master` (SQL login: `sa`)
- Databases available: `AdventureWorks2022`, `master`, `model`, `msdb`, `tempdb`
- Analysis database selected: `AdventureWorks2022`

## Why `AdventureWorks2022` was selected
- Contains business schemas and entities needed for analytics (`Sales`, `Production`, `Purchasing`, `Person`, `HumanResources`).
- System databases (`master`, `model`, `msdb`, `tempdb`) are operational/administrative, not business-analysis targets.

## Data Profile Snapshot (Readiness)
- `SalesOrderHeader`: 31,465 rows
- `SalesOrderDetail`: 121,317 rows
- `Customer`: 19,820 rows
- `Store`: 701 rows
- `Product`: 504 rows
- `PurchaseOrderHeader`: 4,012 rows

Assessment: dataset is analysis-ready with sufficient transaction volume and cross-domain coverage.

## Lightweight Data Quality Audit

### Null hotspots (selected columns)
- `Sales.Customer.StoreID`: 93.26% null
- `Sales.SalesOrderHeader.SalesPersonID`: 87.90% null
- `Production.Product.Weight`: 59.33% null
- `Production.Product.Size`: 58.13% null
- `Production.Product.Color`: 49.21% null

Likely interpretation: many are structural/optional attributes, not necessarily data defects.

### Duplicate risk on natural keys
Checked keys had **0 duplicates**:
- `Sales.SalesOrderHeader.SalesOrderNumber`
- `Production.Product.ProductNumber`
- `Sales.Customer.AccountNumber`
- `Person.EmailAddress.EmailAddress`
- `Purchasing.Vendor.AccountNumber`

### Outliers + rule checks
- IQR outliers:
  - `SalesOrderHeader.TotalDue`: 2,127 rows (6.76%)
  - `SalesOrderDetail.OrderQty`: 6,927 rows (5.71%)
- No invalid negatives found in tested economic fields:
  - `SalesOrderDetail.UnitPrice <= 0`: 0
  - `SalesOrderDetail.OrderQty <= 0`: 0
  - `SalesOrderDetail.LineTotal < 0`: 0
  - `Production.Product.ListPrice < 0`: 0
  - `Production.Product.StandardCost < 0`: 0

### Date-range sanity checks
No violations found in sampled checks:
- `DueDate < OrderDate`: 0
- `ShipDate < OrderDate`: 0
- `ShipDate > OrderDate + 365 days`: 0
- Product lifecycle date-order anomalies in tested rules: 0

### Audit confidence
- Confidence: **High (0.84)** for a lightweight audit scope.
- Caveat: this was targeted, not full-column/full-FK validation.

## Schema Visualization Work
- Opened interactive schema view from MCP.
- Domain split summary:
  - `Sales`: 19 tables, 7 views
  - `Production`: 25 tables, 3 views
  - `Purchasing`: 5 tables, 2 views
  - `HumanResources`: 6 tables, 6 views
  - `Person`: 13 tables, 2 views
  - `dbo`: 3 tables, 0 views
- Produced focused ERD views (domain and cross-domain):
  - Sales domain
  - Production domain
  - Purchasing domain
  - Cross-domain analytics map

## Latest Sales Executive Summary
Period selected: latest quarter in data = **Q2 2014** (`2014-04-01` to `2014-06-30`)

### KPI headline
- Revenue: **8,046,220.84**
- Orders: **5,465**
- Customers: **5,111**
- Avg order value: **1,472.32**
- Versus prior quarter:
  - Revenue: **-6,327,056.64** (**-44.02%**)
  - Orders: **-831** (**-13.20%**)

### Performance concentration
Top territories by revenue:
1. Southwest: 1,582,378.66
2. Australia: 1,257,302.64
3. Northwest: 1,183,049.00
4. United Kingdom: 1,003,098.15
5. Canada: 968,756.40

Top products by revenue (all Mountain-200 variants):
- Mountain-200 Black, 38: 389,230.30
- Mountain-200 Silver, 38: 369,806.41
- Mountain-200 Black, 42: 365,362.41
- Mountain-200 Silver, 46: 325,726.60
- Mountain-200 Black, 46: 307,987.66

### Monthly pattern in Q2 2014
- 2014-04: 1,985,886.15
- 2014-05: 6,006,183.21
- 2014-06: 54,151.48

Data coverage check showed full daily coverage across all months (30/31/30 active order days), suggesting this is likely business mix/price behavior rather than missing dates.

## Saved Artifacts
- Summary: `mcp-sqlserver/docs/session-summary-2026-02-20.md`
- Critical SQL queries: `mcp-sqlserver/critical-queries.sql`
