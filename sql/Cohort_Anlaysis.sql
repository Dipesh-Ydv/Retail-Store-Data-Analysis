-- drop table dbo.Add_records;
-- drop table dbo.Finalised_Records_no;
-- drop table dbo.Integrated_Table_1;
-- drop table dbo.Matched_order_1;
-- drop table dbo.NEW_ORDER_TABLE_1;
-- drop table dbo.Remaining_orders_1;

SELECT * FROM Orders360;
SELECT * FROM Customer360;



-- COHORT ANLAYSIS -> FIXED MONTH
WITH FirstPurchase AS (
    SELECT 
        Customer_id,
        MIN(DATEFROMPARTS(YEAR(Order_datetime), MONTH(Order_datetime), 1)) AS CohortMonth
    FROM Orders360
    GROUP BY Customer_id
), AllOrdersWithCohort AS (
    SELECT 
        s.Customer_id,
        s.Order_id,
        s.Order_datetime,
        s.Total_amount,
        f.CohortMonth,
        DATEFROMPARTS(YEAR(s.Order_datetime), MONTH(s.Order_datetime), 1) AS OrderMonth
    FROM Orders360 s
    JOIN FirstPurchase f ON s.Customer_id = f.Customer_id
), OrderStats AS (
    SELECT 
        CohortMonth,
        Customer_id,
        COUNT(*) AS TotalOrders,
        SUM(Total_amount) AS TotalRevenue,
        COUNT(DISTINCT DATEFROMPARTS(YEAR(Order_datetime), MONTH(Order_datetime), 1)) AS ActiveMonths,
        MIN(CASE 
            WHEN DATEDIFF(MONTH, CohortMonth, Order_datetime) > 0 
            THEN DATEDIFF(MONTH, CohortMonth, Order_datetime)
        END) AS MonthsToRepeat
    FROM AllOrdersWithCohort
    GROUP BY CohortMonth, Customer_id
), Repeaters AS (
    SELECT 
        CohortMonth,
        Customer_id,
        MonthsToRepeat
    FROM OrderStats
    WHERE TotalOrders > 1
)
SELECT 
    f.CohortMonth,
    FORMAT(COUNT(DISTINCT f.Customer_id), 'N0') AS Cohort_Customers,
    COUNT(DISTINCT r.Customer_id) AS Repeat_Customers,
    FORMAT(1.0 * COUNT(DISTINCT r.Customer_id) / NULLIF(COUNT(DISTINCT f.Customer_id), 0), 'P3') AS Retention_Rate,
    FORMAT(ISNULL(AVG(CASE WHEN r.MonthsToRepeat IS NOT NULL THEN r.MonthsToRepeat*1.0 END), 0), 'N2') AS Avg_Months_to_Repeat,

    FORMAT(COUNT(a.Order_id), 'N0') AS Total_Orders_Cohort_Customers,
    FORMAT(ROUND(SUM(a.Total_amount), 0), 'C0', 'hi-IN') AS Total_Revenue_Cohort_Customers,

    COUNT(CASE WHEN r.Customer_id IS NOT NULL THEN a.Order_id END) AS Total_Orders_Repeat_Customers,
    FORMAT(ISNULL(ROUND(SUM(CASE WHEN r.Customer_id IS NOT NULL THEN a.Total_amount END), 0), 0), 'C0', 'hi-IN') AS Total_Revenue_Repeat_Customers
FROM FirstPurchase f
JOIN AllOrdersWithCohort a ON f.Customer_id = a.Customer_id
LEFT JOIN Repeaters r ON f.Customer_id = r.Customer_id
GROUP BY f.CohortMonth
ORDER BY f.CohortMonth;




-- COHORT ANALYSIS -> RETENTION BY MONTH
WITH FirstPurchase AS (
    SELECT
        Customer_id,
        MIN(DATEFROMPARTS(YEAR(Order_datetime), MONTH(Order_datetime), 1)) AS CohortMonth
    FROM Orders360
    GROUP BY Customer_id
), TransactionsWithCohort AS (
    SELECT 
        o.Customer_id,
        f.CohortMonth,
        DATEFROMPARTS(YEAR(o.Order_datetime), MONTH(o.Order_datetime), 1) AS OrderMonth
    FROM Orders360 o
    JOIN FirstPurchase f ON o.Customer_id = f.Customer_id
), WithCohortIndex AS (
    SELECT
        Customer_id,
        CohortMonth,
        OrderMonth,
        DATEDIFF(MONTH, CohortMonth, OrderMonth) AS CohortIndex
    FROM TransactionsWithCohort
), CohortCounts AS (
    SELECT
        CohortMonth,
        CohortIndex,
        COUNT(DISTINCT Customer_id) AS RetainedUsers
    FROM WithCohortIndex
    GROUP BY CohortMonth, CohortIndex
)
SELECT 
    CohortMonth,
    ISNULL([0], 0) AS Month_0,
    ISNULL([1], 0) AS Month_1,
    ISNULL([2], 0) AS Month_2,
    ISNULL([3], 0) AS Month_3,
    ISNULL([4], 0) AS Month_4,
    ISNULL([5], 0) AS Month_5,
    ISNULL([6], 0) AS Month_6,
    ISNULL([7], 0) AS Month_7,
    ISNULL([8], 0) AS Month_8,
    ISNULL([9], 0) AS Month_9,
    ISNULL([10], 0) AS Month_10,
    ISNULL([11], 0) AS Month_11,
    ISNULL([12], 0) AS Month_12
FROM (
    SELECT CohortMonth, CohortIndex, RetainedUsers
    FROM CohortCounts
) AS SourceTable
PIVOT (
    SUM(RetainedUsers)
    FOR CohortIndex IN (
        [0], [1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12]
    )
) AS PivotTable
ORDER BY CohortMonth;



-- CUSTOMER SEGMENT COHORT ANALYSIS (REGION WISE)
-- Step 1: Get first purchase month for each customer
WITH FirstPurchase AS (
    SELECT 
        o.Customer_id,
        MIN(DATEFROMPARTS(YEAR(Order_datetime), MONTH(Order_datetime), 1)) AS CohortMonth
    FROM Orders360 o
    GROUP BY o.Customer_id
), -- Step 2: Join Sales + FirstPurchase + Customer Segment
OrdersWithCohortSegment AS (
    SELECT 
        o.Customer_id,
        c.Region,              -- Segment (e.g., Region)
        f.CohortMonth,
        DATEFROMPARTS(YEAR(o.Order_datetime), MONTH(o.Order_datetime), 1) AS OrderMonth
    FROM Orders360 o
    JOIN FirstPurchase f ON o.Customer_id = f.Customer_id
    JOIN Customer360 c ON o.Customer_id = c.Customer_id
), -- Step 3: Calculate CohortIndex (months since cohort)
CohortData AS (
    SELECT 
        Customer_id,
        Region,
        CohortMonth,
        OrderMonth,
        DATEDIFF(MONTH, CohortMonth, OrderMonth) AS CohortIndex
    FROM OrdersWithCohortSegment
), -- Step 4: Aggregate by CohortMonth + Segment + CohortIndex
CohortCounts AS (
    SELECT 
        Region,
        CohortMonth,
        CohortIndex,
        COUNT(DISTINCT Customer_id) AS RetainedUsers
    FROM CohortData
    GROUP BY Region, CohortMonth, CohortIndex
)
SELECT 
    Region,
    CohortMonth,
    ISNULL([0], 0) AS Month_0,
    ISNULL([1], 0) AS Month_1,
    ISNULL([2], 0) AS Month_2,
    ISNULL([3], 0) AS Month_3,
    ISNULL([4], 0) AS Month_4,
    ISNULL([5], 0) AS Month_5,
    ISNULL([6], 0) AS Month_6,
    ISNULL([7], 0) AS Month_7,
    ISNULL([8], 0) AS Month_8,
    ISNULL([9], 0) AS Month_9,
    ISNULL([10], 0) AS Month_10,
    ISNULL([11], 0) AS Month_11,
    ISNULL([12], 0) AS Month_12
FROM CohortCounts
PIVOT (
    SUM(RetainedUsers)
    FOR CohortIndex IN (
        [0], [1], [2], [3], [4], [5], [6],
        [7], [8], [9], [10], [11], [12]
    )
) AS PivotTable
ORDER BY Region, CohortMonth;



-- CUSTOMER SEGMENT COHORT ANALYSIS (REGION WISE)
-- Step 1: Get first purchase month for each customer
WITH FirstPurchase AS (
    SELECT 
        o.Customer_id,
        MIN(DATEFROMPARTS(YEAR(Order_datetime), MONTH(Order_datetime), 1)) AS CohortMonth
    FROM Orders360 o
    GROUP BY o.Customer_id
), -- Step 2: Join Sales + FirstPurchase + Customer Segment
OrdersWithCohortSegment AS (
    SELECT 
        o.Customer_id,
        c.Customer_Segment,              -- Segment (e.g., Region)
        f.CohortMonth,
        DATEFROMPARTS(YEAR(o.Order_datetime), MONTH(o.Order_datetime), 1) AS OrderMonth
    FROM Orders360 o
    JOIN FirstPurchase f ON o.Customer_id = f.Customer_id
    JOIN Customer360 c ON o.Customer_id = c.Customer_id
), -- Step 3: Calculate CohortIndex (months since cohort)
CohortData AS (
    SELECT 
        Customer_id,
        Customer_Segment,
        CohortMonth,
        OrderMonth,
        DATEDIFF(MONTH, CohortMonth, OrderMonth) AS CohortIndex
    FROM OrdersWithCohortSegment
), -- Step 4: Aggregate by CohortMonth + Segment + CohortIndex
CohortCount AS (
    SELECT 
        Customer_Segment,
        CohortMonth,
        CohortIndex,
        COUNT(DISTINCT Customer_id) AS RetainedUsers
    FROM CohortData
    GROUP BY Customer_Segment, CohortMonth, CohortIndex
)
SELECT 
    Customer_Segment,
    CohortMonth,
    ISNULL([0], 0) AS Month_0,
    ISNULL([1], 0) AS Month_1,
    ISNULL([2], 0) AS Month_2,
    ISNULL([3], 0) AS Month_3,
    ISNULL([4], 0) AS Month_4,
    ISNULL([5], 0) AS Month_5,
    ISNULL([6], 0) AS Month_6,
    ISNULL([7], 0) AS Month_7,
    ISNULL([8], 0) AS Month_8,
    ISNULL([9], 0) AS Month_9,
    ISNULL([10], 0) AS Month_10,
    ISNULL([11], 0) AS Month_11,
    ISNULL([12], 0) AS Month_12
FROM CohortCount
PIVOT (
    SUM(RetainedUsers)
    FOR CohortIndex IN (
        [0], [1], [2], [3], [4], [5], [6],
        [7], [8], [9], [10], [11], [12]
    )
) AS PivotTable
ORDER BY Customer_Segment, CohortMonth;


-- CUSTOMER SEGEMENT COHORT ANALYSIS
-- Step 1: Get the first purchase month (CohortMonth) per customer
WITH FirstPurchase AS (
    SELECT 
        Customer_id,
        MIN(DATEFROMPARTS(YEAR(Order_datetime), MONTH(Order_datetime), 1)) AS CohortMonth
    FROM Orders360
    GROUP BY Customer_id
), -- Step 2: Join with all orders and customer segment (e.g., Region)
AllOrdersWithCohortSegment AS (
    SELECT 
        o.Customer_id,
        o.order_id,
        o.Order_datetime,
        o.Total_amount,
        f.CohortMonth,
        DATEFROMPARTS(YEAR(o.Order_datetime), MONTH(o.Order_datetime), 1) AS OrderMonth,
        c.Customer_Segment  -- Change this to Tier, Gender, etc. if needed
    FROM Orders360 o
    JOIN FirstPurchase f ON o.Customer_id = f.Customer_id
    JOIN Customer360 c ON o.Customer_id = c.Customer_id
), -- Step 3: Aggregate per customer: total orders, revenue, months to repeat
OrderStats AS (
    SELECT 
        CohortMonth,
        Customer_Segment,
        Customer_id,
        COUNT(*) AS TotalOrders,
        SUM(Total_amount) AS TotalRevenue,
        MIN(CASE 
            WHEN DATEDIFF(MONTH, CohortMonth, Order_datetime) > 0 
            THEN DATEDIFF(MONTH, CohortMonth, Order_datetime)
        END) AS MonthsToRepeat
    FROM AllOrdersWithCohortSegment
    GROUP BY CohortMonth, Customer_Segment, Customer_id
), -- Step 4: Identify repeat customers
Repeaters AS (
    SELECT 
        CohortMonth,
        Customer_Segment,
        Customer_id,
        MonthsToRepeat
    FROM OrderStats
    WHERE TotalOrders > 1 AND MonthsToRepeat IS NOT NULL
) -- Step 5: Final cohort analysis grouped by CohortMonth and Region
SELECT 
    f.CohortMonth,
    a.Customer_Segment,
    COUNT(DISTINCT f.Customer_id) AS Cohort_Customers,
    COUNT(DISTINCT r.Customer_id) AS Repeat_Customers,
    FORMAT(1.0 * COUNT(DISTINCT r.Customer_id) / NULLIF(COUNT(DISTINCT f.Customer_id), 0), 'P3') AS Retention_Rate,
    ISNULL(AVG(r.MonthsToRepeat), 0) AS Avg_Months_to_Repeat,

    COUNT(a.order_id) AS Total_Orders_Cohort_Customers,
    FORMAT(SUM(a.Total_amount), 'C0', 'hi-IN') AS Total_Revenue_Cohort_Customers,

    COUNT(CASE WHEN r.Customer_id IS NOT NULL THEN a.order_id END) AS Total_Orders_Repeat_Customers,
    FORMAT(ISNULL(SUM(CASE WHEN r.Customer_id IS NOT NULL THEN a.Total_amount END), 0), 'C0', 'hi-IN') AS Total_Revenue_Repeat_Customers

FROM FirstPurchase f
JOIN AllOrdersWithCohortSegment a ON f.Customer_id = a.Customer_id
LEFT JOIN Repeaters r ON f.Customer_id = r.Customer_id AND a.Customer_Segment = r.Customer_Segment
GROUP BY f.CohortMonth, a.Customer_Segment
ORDER BY a.Customer_Segment, f.CohortMonth;




-- REGION WISE COHORT ANALYSIS
-- Step 1: Get the first purchase month (CohortMonth) per customer
WITH FirstPurchase AS (
    SELECT 
        Customer_id,
        MIN(DATEFROMPARTS(YEAR(Order_datetime), MONTH(Order_datetime), 1)) AS CohortMonth
    FROM Orders360
    GROUP BY Customer_id
), -- Step 2: Join with all orders and customer segment (e.g., Region)
AllOrdersWithCohortSegment AS (
    SELECT 
        o.Customer_id,
        o.order_id,
        o.Order_datetime,
        o.Total_amount,
        f.CohortMonth,
        DATEFROMPARTS(YEAR(o.Order_datetime), MONTH(o.Order_datetime), 1) AS OrderMonth,
        c.Region  -- Change this to Tier, Gender, etc. if needed
    FROM Orders360 o
    JOIN FirstPurchase f ON o.Customer_id = f.Customer_id
    JOIN Customer360 c ON o.Customer_id = c.Customer_id
), -- Step 3: Aggregate per customer: total orders, revenue, months to repeat
OrderStats AS (
    SELECT 
        CohortMonth,
        Region,
        Customer_id,
        COUNT(*) AS TotalOrders,
        SUM(Total_amount) AS TotalRevenue,
        MIN(CASE 
            WHEN DATEDIFF(MONTH, CohortMonth, Order_datetime) > 0 
            THEN DATEDIFF(MONTH, CohortMonth, Order_datetime)
        END) AS MonthsToRepeat
    FROM AllOrdersWithCohortSegment
    GROUP BY CohortMonth, Region, Customer_id
), -- Step 4: Identify repeat customers
Repeaters AS (
    SELECT 
        CohortMonth,
        Region,
        Customer_id,
        MonthsToRepeat
    FROM OrderStats
    WHERE TotalOrders > 1 AND MonthsToRepeat IS NOT NULL
) -- Step 5: Final cohort analysis grouped by CohortMonth and Region
SELECT 
    f.CohortMonth,
    a.Region,
    COUNT(DISTINCT f.Customer_id) AS Cohort_Customers,
    COUNT(DISTINCT r.Customer_id) AS Repeat_Customers,
    FORMAT(1.0 * COUNT(DISTINCT r.Customer_id) / NULLIF(COUNT(DISTINCT f.Customer_id), 0), 'P3') AS Retention_Rate,
    ISNULL(AVG(r.MonthsToRepeat), 0) AS Avg_Months_to_Repeat,

    COUNT(a.order_id) AS Total_Orders_Cohort_Customers,
    FORMAT(SUM(a.Total_amount), 'C0', 'hi-IN') AS Total_Revenue_Cohort_Customers,

    COUNT(CASE WHEN r.Customer_id IS NOT NULL THEN a.order_id END) AS Total_Orders_Repeat_Customers,
    FORMAT(ISNULL(SUM(CASE WHEN r.Customer_id IS NOT NULL THEN a.Total_amount END), 0), 'C0', 'hi-IN') AS Total_Revenue_Repeat_Customers

FROM FirstPurchase f
JOIN AllOrdersWithCohortSegment a ON f.Customer_id = a.Customer_id
LEFT JOIN Repeaters r ON f.Customer_id = r.Customer_id AND a.Region = r.Region
GROUP BY f.CohortMonth, a.Region
ORDER BY f.CohortMonth, a.Region;
 

