# AdventureWorks2022 Onboarding Brief (One Page)

## 1) Major domains (business map)
- **Sales**: customer, order, pricing, territory, and sales performance.
- **Production**: product catalog, inventory, manufacturing/work orders, and transaction history.
- **Purchasing**: vendor management and purchase order flow.
- **Person**: shared master entities (person, address, contact, geography).
- **HumanResources**: employee, department, and pay history.

---

## 2) Critical tables and views

### Core transactional tables
- `Sales.SalesOrderHeader` (order-level facts)
- `Sales.SalesOrderDetail` (line-level facts)
- `Sales.Customer` (customer grain)
- `Production.Product` (product dimension backbone)
- `Purchasing.PurchaseOrderHeader`, `Purchasing.PurchaseOrderDetail` (procurement flow)
- `Production.TransactionHistory`, `Production.WorkOrder`, `Production.WorkOrderRouting` (ops/manufacturing)

### Key supporting dimensions
- `Sales.SalesTerritory`
- `Person.Person`, `Person.Address`, `Person.StateProvince`, `Person.CountryRegion`
- `Production.ProductSubcategory`, `Production.ProductCategory`
- `Sales.SalesPerson`, `HumanResources.Employee`

### Useful views for fast orientation
- `Sales.vIndividualCustomer`
- `Sales.vSalesPerson`
- `Sales.vStoreWithDemographics`
- `Person.vStateProvinceCountryRegion`
- `Production.vProductAndDescription`
- `Purchasing.vVendorWithContacts`

---

## 3) Common joins (most-used patterns)

```sql
-- Orders -> order lines -> product -> product hierarchy
FROM Sales.SalesOrderHeader h
JOIN Sales.SalesOrderDetail d ON d.SalesOrderID = h.SalesOrderID
JOIN Production.Product p ON p.ProductID = d.ProductID
LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID = ps.ProductCategoryID
```

```sql
-- Customer/account context
FROM Sales.SalesOrderHeader h
JOIN Sales.Customer c ON c.CustomerID = h.CustomerID
LEFT JOIN Person.Person pp ON pp.BusinessEntityID = c.PersonID
LEFT JOIN Sales.Store st ON st.BusinessEntityID = c.StoreID
```

```sql
-- Geography context
FROM Sales.SalesOrderHeader h
JOIN Sales.SalesTerritory t ON t.TerritoryID = h.TerritoryID
LEFT JOIN Person.StateProvince sp ON sp.TerritoryID = t.TerritoryID
LEFT JOIN Person.CountryRegion cr ON cr.CountryRegionCode = t.CountryRegionCode
```

```sql
-- Salesperson context
FROM Sales.SalesOrderHeader h
LEFT JOIN Sales.SalesPerson s ON s.BusinessEntityID = h.SalesPersonID
LEFT JOIN HumanResources.Employee e ON e.BusinessEntityID = s.BusinessEntityID
```

```sql
-- Procurement / supply relationship
FROM Purchasing.PurchaseOrderHeader poh
JOIN Purchasing.PurchaseOrderDetail pod ON pod.PurchaseOrderID = poh.PurchaseOrderID
JOIN Production.Product p ON p.ProductID = pod.ProductID
JOIN Purchasing.Vendor v ON v.BusinessEntityID = poh.VendorID
```

---

## 4) Top 5 diagnostic queries (copy/paste)

### Q1. Data inventory by schema (size and footprint)
```sql
WITH table_rows AS (
  SELECT s.name AS schema_name, t.object_id, SUM(p.rows) AS row_count
  FROM sys.tables t
  JOIN sys.schemas s ON s.schema_id = t.schema_id
  JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
  GROUP BY s.name, t.object_id
)
SELECT schema_name, SUM(row_count) AS total_rows, COUNT(*) AS table_count
FROM table_rows
GROUP BY schema_name
ORDER BY total_rows DESC;
```

### Q2. Freshness + monthly trend (last 6 months)
```sql
WITH max_date AS (
  SELECT MAX(OrderDate) AS max_order_date FROM Sales.SalesOrderHeader
)
SELECT
  (SELECT max_order_date FROM max_date) AS data_through_date,
  DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1) AS month_start,
  CAST(SUM(d.LineTotal) AS DECIMAL(18,2)) AS revenue
FROM Sales.SalesOrderHeader h
JOIN Sales.SalesOrderDetail d ON d.SalesOrderID = h.SalesOrderID
CROSS JOIN max_date m
WHERE h.OrderDate > DATEADD(MONTH, -6, m.max_order_date)
GROUP BY DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1)
ORDER BY month_start;
```

### Q3. YoY category/subcategory performance
```sql
WITH max_date AS (
  SELECT MAX(OrderDate) AS max_order_date FROM Sales.SalesOrderHeader
), base AS (
  SELECT
    CASE
      WHEN h.OrderDate > DATEADD(YEAR,-1,m.max_order_date) THEN 'last_12m'
      WHEN h.OrderDate > DATEADD(YEAR,-2,m.max_order_date)
       AND h.OrderDate <= DATEADD(YEAR,-1,m.max_order_date) THEN 'prior_12m'
    END AS period,
    COALESCE(pc.Name,'Uncategorized') AS category_name,
    COALESCE(ps.Name,'Uncategorized') AS subcategory_name,
    d.LineTotal
  FROM Sales.SalesOrderHeader h
  JOIN Sales.SalesOrderDetail d ON d.SalesOrderID = h.SalesOrderID
  JOIN Production.Product p ON p.ProductID = d.ProductID
  LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
  LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID = ps.ProductCategoryID
  CROSS JOIN max_date m
  WHERE h.OrderDate > DATEADD(YEAR,-2,m.max_order_date)
)
SELECT TOP 15
  category_name,
  subcategory_name,
  CAST(SUM(CASE WHEN period='last_12m' THEN LineTotal ELSE 0 END) AS DECIMAL(18,2)) AS revenue_last_12m,
  CAST(SUM(CASE WHEN period='prior_12m' THEN LineTotal ELSE 0 END) AS DECIMAL(18,2)) AS revenue_prior_12m
FROM base
WHERE period IS NOT NULL
GROUP BY category_name, subcategory_name
ORDER BY revenue_last_12m DESC;
```

### Q4. Relational integrity quick checks (orphans should be 0)
```sql
SELECT 'SalesOrderDetail without Header' AS check_name, COUNT(*) AS orphan_rows
FROM Sales.SalesOrderDetail d
LEFT JOIN Sales.SalesOrderHeader h ON h.SalesOrderID = d.SalesOrderID
WHERE h.SalesOrderID IS NULL
UNION ALL
SELECT 'SalesOrderHeader without Customer', COUNT(*)
FROM Sales.SalesOrderHeader h
LEFT JOIN Sales.Customer c ON c.CustomerID = h.CustomerID
WHERE c.CustomerID IS NULL
UNION ALL
SELECT 'PurchaseOrderDetail without Header', COUNT(*)
FROM Purchasing.PurchaseOrderDetail d
LEFT JOIN Purchasing.PurchaseOrderHeader h ON h.PurchaseOrderID = d.PurchaseOrderID
WHERE h.PurchaseOrderID IS NULL;
```

### Q5. Performance health snapshot (missing indexes + fragmentation)
```sql
-- Missing index recommendations (current workload)
SELECT TOP 10
  OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) AS schema_name,
  OBJECT_NAME(mid.object_id, mid.database_id) AS table_name,
  migs.user_seeks,
  migs.user_scans,
  mid.equality_columns,
  mid.inequality_columns,
  mid.included_columns
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY (migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) DESC;

-- Fragmentation for large indexes
SELECT TOP 10
  s.name AS schema_name,
  t.name AS table_name,
  i.name AS index_name,
  ips.page_count,
  CAST(ips.avg_fragmentation_in_percent AS DECIMAL(6,2)) AS avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
JOIN sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
JOIN sys.tables t ON t.object_id = ips.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE ips.index_id > 0 AND ips.page_count >= 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;
```

---

## 5) First-week learning path (new engineer)
- **Day 1:** Read schema map and run Q1/Q2. Identify data-through date and biggest domains.
- **Day 2:** Validate business flow with joins (Orders -> Lines -> Product -> Customer -> Territory).
- **Day 3:** Run Q3 and replicate one KPI cut (e.g., category YoY trend).
- **Day 4:** Run Q4 and confirm integrity assumptions before building transformations.
- **Day 5:** Run Q5, review index/stats/query-store posture, and write a 1-page tuning proposal.

### Week-1 deliverables
- A reproducible SQL notebook/script for monthly revenue + category YoY.
- A documented “golden join path” for analytics models.
- A short risk list (data quality checks + performance hotspots).
