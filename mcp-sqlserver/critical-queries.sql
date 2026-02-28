USE AdventureWorks2022;
GO

/*
  Critical reusable query set from the MCP SQL exploration session.
  Scope: discovery, profiling, quality checks, and latest-quarter executive KPIs.
*/

-- 1) Database discovery
SELECT name AS database_name
FROM sys.databases
ORDER BY name;
GO

-- 2) Domain inventory by schema (tables + views)
SELECT
  s.name AS domain,
  COUNT(DISTINCT t.object_id) AS table_count,
  COUNT(DISTINCT v.object_id) AS view_count
FROM sys.schemas s
LEFT JOIN sys.tables t ON t.schema_id = s.schema_id
LEFT JOIN sys.views v ON v.schema_id = s.schema_id
WHERE s.name IN ('Sales','Production','Purchasing','HumanResources','Person','dbo')
GROUP BY s.name
ORDER BY CASE s.name
  WHEN 'Sales' THEN 1
  WHEN 'Production' THEN 2
  WHEN 'Purchasing' THEN 3
  WHEN 'HumanResources' THEN 4
  WHEN 'Person' THEN 5
  WHEN 'dbo' THEN 6
  ELSE 99 END;
GO

-- 3) Core table profile (row counts)
SELECT
  (SELECT COUNT(*) FROM Sales.SalesOrderHeader) AS sales_orders,
  (SELECT COUNT(*) FROM Sales.SalesOrderDetail) AS sales_order_lines,
  (SELECT COUNT(*) FROM Sales.Customer) AS customers,
  (SELECT COUNT(*) FROM Sales.Store) AS stores,
  (SELECT COUNT(*) FROM Production.Product) AS products,
  (SELECT COUNT(*) FROM Purchasing.PurchaseOrderHeader) AS purchase_orders;
GO

-- 4) Null hotspot scan (selected business-critical columns)
WITH base AS (
    SELECT CAST('Sales.SalesOrderHeader' AS nvarchar(128)) AS table_name, CAST('SalesPersonID' AS nvarchar(128)) AS column_name,
           COUNT_BIG(*) AS total_rows, SUM(CASE WHEN SalesPersonID IS NULL THEN 1 ELSE 0 END) AS null_rows
    FROM Sales.SalesOrderHeader
    UNION ALL
    SELECT 'Sales.SalesOrderHeader', 'TerritoryID', COUNT_BIG(*), SUM(CASE WHEN TerritoryID IS NULL THEN 1 ELSE 0 END)
    FROM Sales.SalesOrderHeader
    UNION ALL
    SELECT 'Sales.SalesOrderHeader', 'ShipDate', COUNT_BIG(*), SUM(CASE WHEN ShipDate IS NULL THEN 1 ELSE 0 END)
    FROM Sales.SalesOrderHeader
    UNION ALL
    SELECT 'Sales.Customer', 'PersonID', COUNT_BIG(*), SUM(CASE WHEN PersonID IS NULL THEN 1 ELSE 0 END)
    FROM Sales.Customer
    UNION ALL
    SELECT 'Sales.Customer', 'StoreID', COUNT_BIG(*), SUM(CASE WHEN StoreID IS NULL THEN 1 ELSE 0 END)
    FROM Sales.Customer
    UNION ALL
    SELECT 'Sales.Customer', 'TerritoryID', COUNT_BIG(*), SUM(CASE WHEN TerritoryID IS NULL THEN 1 ELSE 0 END)
    FROM Sales.Customer
    UNION ALL
    SELECT 'Production.Product', 'Weight', COUNT_BIG(*), SUM(CASE WHEN Weight IS NULL THEN 1 ELSE 0 END)
    FROM Production.Product
    UNION ALL
    SELECT 'Production.Product', 'Size', COUNT_BIG(*), SUM(CASE WHEN Size IS NULL THEN 1 ELSE 0 END)
    FROM Production.Product
    UNION ALL
    SELECT 'Production.Product', 'Color', COUNT_BIG(*), SUM(CASE WHEN Color IS NULL THEN 1 ELSE 0 END)
    FROM Production.Product
    UNION ALL
    SELECT 'Purchasing.PurchaseOrderHeader', 'ShipDate', COUNT_BIG(*), SUM(CASE WHEN ShipDate IS NULL THEN 1 ELSE 0 END)
    FROM Purchasing.PurchaseOrderHeader
)
SELECT
    table_name,
    column_name,
    total_rows,
    null_rows,
    CAST(100.0 * null_rows / NULLIF(total_rows,0) AS decimal(6,2)) AS null_pct
FROM base
ORDER BY null_pct DESC, table_name, column_name;
GO

-- 5) Duplicate-risk check on natural keys
SELECT 'Sales.SalesOrderHeader.SalesOrderNumber' AS key_name,
       COUNT(*) AS total_rows,
       COUNT(DISTINCT SalesOrderNumber) AS distinct_values,
       COUNT(*) - COUNT(DISTINCT SalesOrderNumber) AS duplicate_count
FROM Sales.SalesOrderHeader
UNION ALL
SELECT 'Production.Product.ProductNumber', COUNT(*), COUNT(DISTINCT ProductNumber), COUNT(*) - COUNT(DISTINCT ProductNumber)
FROM Production.Product
UNION ALL
SELECT 'Sales.Customer.AccountNumber', COUNT(*), COUNT(DISTINCT AccountNumber), COUNT(*) - COUNT(DISTINCT AccountNumber)
FROM Sales.Customer
UNION ALL
SELECT 'Person.EmailAddress.EmailAddress', COUNT(*), COUNT(DISTINCT EmailAddress), COUNT(*) - COUNT(DISTINCT EmailAddress)
FROM Person.EmailAddress
UNION ALL
SELECT 'Purchasing.Vendor.AccountNumber', COUNT(*), COUNT(DISTINCT AccountNumber), COUNT(*) - COUNT(DISTINCT AccountNumber)
FROM Purchasing.Vendor;
GO

-- 6) Outlier scan (IQR) + negative freight check
WITH so AS (
  SELECT CAST(TotalDue AS float) AS v
  FROM Sales.SalesOrderHeader
), so_bounds AS (
  SELECT DISTINCT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY v) OVER() AS q1,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY v) OVER() AS q3
  FROM so
), so_stats AS (
  SELECT
    'Sales.SalesOrderHeader.TotalDue' AS metric,
    CAST(MIN(v) AS decimal(18,2)) AS min_val,
    CAST(MAX(v) AS decimal(18,2)) AS max_val,
    CAST(MAX(b.q1) AS decimal(18,2)) AS q1,
    CAST(MAX(b.q3) AS decimal(18,2)) AS q3,
    SUM(CASE WHEN v < (b.q1 - 1.5*(b.q3-b.q1)) OR v > (b.q3 + 1.5*(b.q3-b.q1)) THEN 1 ELSE 0 END) AS iqr_outlier_count,
    CAST(100.0 * SUM(CASE WHEN v < (b.q1 - 1.5*(b.q3-b.q1)) OR v > (b.q3 + 1.5*(b.q3-b.q1)) THEN 1 ELSE 0 END) / COUNT(*) AS decimal(6,2)) AS iqr_outlier_pct
  FROM so
  CROSS JOIN so_bounds b
),
od AS (
  SELECT CAST(OrderQty AS float) AS v
  FROM Sales.SalesOrderDetail
), od_bounds AS (
  SELECT DISTINCT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY v) OVER() AS q1,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY v) OVER() AS q3
  FROM od
), od_stats AS (
  SELECT
    'Sales.SalesOrderDetail.OrderQty' AS metric,
    CAST(MIN(v) AS decimal(18,2)) AS min_val,
    CAST(MAX(v) AS decimal(18,2)) AS max_val,
    CAST(MAX(b.q1) AS decimal(18,2)) AS q1,
    CAST(MAX(b.q3) AS decimal(18,2)) AS q3,
    SUM(CASE WHEN v < (b.q1 - 1.5*(b.q3-b.q1)) OR v > (b.q3 + 1.5*(b.q3-b.q1)) THEN 1 ELSE 0 END) AS iqr_outlier_count,
    CAST(100.0 * SUM(CASE WHEN v < (b.q1 - 1.5*(b.q3-b.q1)) OR v > (b.q3 + 1.5*(b.q3-b.q1)) THEN 1 ELSE 0 END) / COUNT(*) AS decimal(6,2)) AS iqr_outlier_pct
  FROM od
  CROSS JOIN od_bounds b
), fr AS (
  SELECT
    'Sales.SalesOrderHeader.Freight_negative_check' AS metric,
    CAST(MIN(CAST(Freight AS float)) AS decimal(18,2)) AS min_val,
    CAST(MAX(CAST(Freight AS float)) AS decimal(18,2)) AS max_val,
    CAST(NULL AS decimal(18,2)) AS q1,
    CAST(NULL AS decimal(18,2)) AS q3,
    SUM(CASE WHEN Freight < 0 THEN 1 ELSE 0 END) AS iqr_outlier_count,
    CAST(100.0 * SUM(CASE WHEN Freight < 0 THEN 1 ELSE 0 END) / COUNT(*) AS decimal(6,2)) AS iqr_outlier_pct
  FROM Sales.SalesOrderHeader
)
SELECT * FROM so_stats
UNION ALL
SELECT * FROM od_stats
UNION ALL
SELECT * FROM fr;
GO

-- 7) Rule-based invalid value checks (non-positive / negative amounts)
SELECT
  SUM(CASE WHEN UnitPrice <= 0 THEN 1 ELSE 0 END) AS nonpositive_unitprice_rows,
  SUM(CASE WHEN OrderQty <= 0 THEN 1 ELSE 0 END) AS nonpositive_orderqty_rows,
  SUM(CASE WHEN LineTotal < 0 THEN 1 ELSE 0 END) AS negative_linetotal_rows
FROM Sales.SalesOrderDetail;
GO

SELECT
  SUM(CASE WHEN ListPrice < 0 THEN 1 ELSE 0 END) AS negative_listprice_rows,
  SUM(CASE WHEN StandardCost < 0 THEN 1 ELSE 0 END) AS negative_standardcost_rows,
  SUM(CASE WHEN SafetyStockLevel < 0 THEN 1 ELSE 0 END) AS negative_safetystock_rows
FROM Production.Product;
GO

-- 8) Date-range sanity checks
SELECT
  'Sales.SalesOrderHeader' AS entity,
  MIN(OrderDate) AS min_order_date,
  MAX(OrderDate) AS max_order_date,
  SUM(CASE WHEN DueDate < OrderDate THEN 1 ELSE 0 END) AS due_before_order,
  SUM(CASE WHEN ShipDate < OrderDate THEN 1 ELSE 0 END) AS ship_before_order,
  SUM(CASE WHEN ShipDate > DATEADD(day, 365, OrderDate) THEN 1 ELSE 0 END) AS ship_over_365d
FROM Sales.SalesOrderHeader
UNION ALL
SELECT
  'Purchasing.PurchaseOrderHeader',
  MIN(OrderDate),
  MAX(OrderDate),
  SUM(CASE WHEN ShipDate < OrderDate THEN 1 ELSE 0 END),
  SUM(CASE WHEN ShipDate < OrderDate THEN 1 ELSE 0 END),
  SUM(CASE WHEN ShipDate > DATEADD(day, 365, OrderDate) THEN 1 ELSE 0 END)
FROM Purchasing.PurchaseOrderHeader
UNION ALL
SELECT
  'Production.Product',
  MIN(SellStartDate),
  MAX(ISNULL(SellEndDate, SellStartDate)),
  SUM(CASE WHEN SellEndDate IS NOT NULL AND SellEndDate < SellStartDate THEN 1 ELSE 0 END),
  SUM(CASE WHEN DiscontinuedDate IS NOT NULL AND SellStartDate IS NOT NULL AND DiscontinuedDate < SellStartDate THEN 1 ELSE 0 END),
  SUM(CASE WHEN SellStartDate > GETDATE() THEN 1 ELSE 0 END)
FROM Production.Product;
GO

-- 9) Executive KPI snapshot for latest quarter vs prior quarter
WITH max_date AS (
    SELECT MAX(OrderDate) AS max_order_date
    FROM Sales.SalesOrderHeader
), latest_q AS (
    SELECT
        DATEADD(QUARTER, DATEDIFF(QUARTER, 0, max_order_date), 0) AS quarter_start,
        DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, max_order_date) + 1, 0)) AS quarter_end,
        max_order_date
    FROM max_date
), prev_q AS (
    SELECT
        DATEADD(QUARTER, -1, quarter_start) AS prev_start,
        DATEADD(DAY, -1, quarter_start) AS prev_end
    FROM latest_q
), q_sales AS (
    SELECT
        SUM(TotalDue) AS revenue,
        COUNT(*) AS orders,
        COUNT(DISTINCT CustomerID) AS customers,
        AVG(TotalDue) AS avg_order_value,
        SUM(SubTotal) AS subtotal,
        SUM(TaxAmt) AS tax,
        SUM(Freight) AS freight
    FROM Sales.SalesOrderHeader h
    CROSS JOIN latest_q q
    WHERE h.OrderDate >= q.quarter_start AND h.OrderDate <= q.quarter_end
), p_sales AS (
    SELECT
        SUM(TotalDue) AS revenue,
        COUNT(*) AS orders,
        COUNT(DISTINCT CustomerID) AS customers,
        AVG(TotalDue) AS avg_order_value
    FROM Sales.SalesOrderHeader h
    CROSS JOIN prev_q p
    WHERE h.OrderDate >= p.prev_start AND h.OrderDate <= p.prev_end
)
SELECT
    q.quarter_start,
    q.quarter_end,
    q.max_order_date,
    CAST(s.revenue AS decimal(18,2)) AS revenue,
    s.orders,
    s.customers,
    CAST(s.avg_order_value AS decimal(18,2)) AS avg_order_value,
    CAST(s.subtotal AS decimal(18,2)) AS subtotal,
    CAST(s.tax AS decimal(18,2)) AS tax,
    CAST(s.freight AS decimal(18,2)) AS freight,
    CAST((s.revenue - ISNULL(p.revenue,0)) AS decimal(18,2)) AS revenue_delta_vs_prev_q,
    CAST(CASE WHEN ISNULL(p.revenue,0)=0 THEN NULL ELSE 100.0*(s.revenue-p.revenue)/p.revenue END AS decimal(10,2)) AS revenue_pct_vs_prev_q,
    CAST((s.orders - ISNULL(p.orders,0)) AS int) AS orders_delta_vs_prev_q,
    CAST(CASE WHEN ISNULL(p.orders,0)=0 THEN NULL ELSE 100.0*(s.orders-p.orders)*1.0/p.orders END AS decimal(10,2)) AS orders_pct_vs_prev_q
FROM latest_q q
CROSS JOIN q_sales s
CROSS JOIN p_sales p;
GO

-- 10) Top 5 territories for latest quarter
WITH max_date AS (
    SELECT MAX(OrderDate) AS max_order_date FROM Sales.SalesOrderHeader
), latest_q AS (
    SELECT DATEADD(QUARTER, DATEDIFF(QUARTER, 0, max_order_date), 0) AS quarter_start,
           DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, max_order_date) + 1, 0)) AS quarter_end
    FROM max_date
)
SELECT TOP 5
    ISNULL(st.Name,'Unknown') AS territory,
    CAST(SUM(h.TotalDue) AS decimal(18,2)) AS revenue,
    COUNT(*) AS orders,
    COUNT(DISTINCT h.CustomerID) AS customers,
    CAST(AVG(h.TotalDue) AS decimal(18,2)) AS avg_order_value
FROM Sales.SalesOrderHeader h
LEFT JOIN Sales.SalesTerritory st ON h.TerritoryID = st.TerritoryID
CROSS JOIN latest_q q
WHERE h.OrderDate >= q.quarter_start AND h.OrderDate <= q.quarter_end
GROUP BY ISNULL(st.Name,'Unknown')
ORDER BY revenue DESC;
GO

-- 11) Top 5 products for latest quarter
WITH max_date AS (
    SELECT MAX(OrderDate) AS max_order_date FROM Sales.SalesOrderHeader
), latest_q AS (
    SELECT DATEADD(QUARTER, DATEDIFF(QUARTER, 0, max_order_date), 0) AS quarter_start,
           DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, max_order_date) + 1, 0)) AS quarter_end
    FROM max_date
)
SELECT TOP 5
    p.Name AS product,
    CAST(SUM(d.LineTotal) AS decimal(18,2)) AS revenue,
    SUM(d.OrderQty) AS units,
    COUNT(DISTINCT d.SalesOrderID) AS orders
FROM Sales.SalesOrderDetail d
JOIN Sales.SalesOrderHeader h ON h.SalesOrderID = d.SalesOrderID
JOIN Production.Product p ON p.ProductID = d.ProductID
CROSS JOIN latest_q q
WHERE h.OrderDate >= q.quarter_start AND h.OrderDate <= q.quarter_end
GROUP BY p.Name
ORDER BY revenue DESC;
GO

-- 12) Monthly trend + daily coverage in latest quarter
WITH max_date AS (
    SELECT MAX(OrderDate) AS max_order_date FROM Sales.SalesOrderHeader
), latest_q AS (
    SELECT DATEADD(QUARTER, DATEDIFF(QUARTER, 0, max_order_date), 0) AS quarter_start,
           DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, max_order_date) + 1, 0)) AS quarter_end
    FROM max_date
)
SELECT
    DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1) AS month_start,
    CAST(SUM(h.TotalDue) AS decimal(18,2)) AS revenue,
    COUNT(*) AS orders,
    COUNT(DISTINCT h.CustomerID) AS customers,
    CAST(AVG(h.TotalDue) AS decimal(18,2)) AS avg_order_value,
    COUNT(DISTINCT CAST(h.OrderDate AS date)) AS active_order_days,
    MIN(CAST(h.OrderDate AS date)) AS first_order_day,
    MAX(CAST(h.OrderDate AS date)) AS last_order_day
FROM Sales.SalesOrderHeader h
CROSS JOIN latest_q q
WHERE h.OrderDate >= q.quarter_start AND h.OrderDate <= q.quarter_end
GROUP BY DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1)
ORDER BY month_start;
GO
