USE AdventureWorks2022;
GO

-- 1) Top customers by total spend
SELECT TOP 10
  c.CustomerID,
  COALESCE(
    NULLIF(LTRIM(RTRIM(CONCAT(p.FirstName, ' ', p.LastName))), ''),
    s.Name,
    CONCAT('CustomerID ', c.CustomerID)
  ) AS CustomerName,
  COUNT(DISTINCT soh.SalesOrderID) AS Orders,
  CAST(SUM(soh.TotalDue) AS DECIMAL(18,2)) AS TotalSpend
FROM Sales.Customer c
LEFT JOIN Person.Person p ON p.BusinessEntityID = c.PersonID
LEFT JOIN Sales.Store s ON s.BusinessEntityID = c.StoreID
JOIN Sales.SalesOrderHeader soh ON soh.CustomerID = c.CustomerID
GROUP BY
  c.CustomerID,
  COALESCE(
    NULLIF(LTRIM(RTRIM(CONCAT(p.FirstName, ' ', p.LastName))), ''),
    s.Name,
    CONCAT('CustomerID ', c.CustomerID)
  )
ORDER BY TotalSpend DESC;
GO

-- 2) Monthly sales trend (last 12 full months)
WITH month_sales AS (
  SELECT
    DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS MonthStart,
    SUM(TotalDue) AS Revenue
  FROM Sales.SalesOrderHeader
  WHERE OrderDate >= DATEADD(MONTH, -12, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))
    AND OrderDate < DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)
  GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)
)
SELECT
  MonthStart,
  CAST(Revenue AS DECIMAL(18,2)) AS Revenue
FROM month_sales
ORDER BY MonthStart;
GO

-- 3) Product category performance
SELECT
  pc.Name AS ProductCategory,
  COUNT(DISTINCT soh.SalesOrderID) AS Orders,
  CAST(SUM(sod.LineTotal) AS DECIMAL(18,2)) AS LineRevenue,
  CAST(AVG(sod.UnitPrice) AS DECIMAL(18,2)) AS AvgUnitPrice
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON p.ProductID = sod.ProductID
JOIN Production.ProductSubcategory psc ON psc.ProductSubcategoryID = p.ProductSubcategoryID
JOIN Production.ProductCategory pc ON pc.ProductCategoryID = psc.ProductCategoryID
GROUP BY pc.Name
ORDER BY LineRevenue DESC;
GO
