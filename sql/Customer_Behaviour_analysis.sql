-- Customer segmentation based on revenue
WITH RevenuePercentiles AS (
    SELECT 
        PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY Total_Spend) OVER () AS P33,
        PERCENTILE_CONT(0.66) WITHIN GROUP (ORDER BY Total_Spend) OVER () AS P66
    FROM Customers360
), SEGMENTED_CUST AS (
    SELECT 
        Customer_id,
        Cust_city,
        Cust_State,
        Gender,
        Total_Spend,
        CASE
            WHEN Total_Spend < rp.P33 THEN 'Low Revenue'
            WHEN Total_Spend < rp.P66 THEN 'Medium Revenue'
            ELSE 'High Revenue'
        END AS RevenueSegment
    FROM Customers360 c
    CROSS JOIN RevenuePercentiles rp
)
SELECT RevenueSegment, SUM(Total_Spend) AS TOTAL_REVENUE
FROM SEGMENTED_CUST
GROUP BY RevenueSegment;



-- RFM Segmentation
SELECT 
    Customer_id,
    Cust_city,
    Cust_State,
    Gender,
    Total_Transactions,
    Total_Spend,
    DATEDIFF(DAY, CAST(Last_trans_date AS DATE), GETDATE()) AS Recency,
    NTILE(4) OVER (ORDER BY DATEDIFF(DAY, CAST(Last_trans_date AS DATE), CAST('2023/10/31' AS DATE)) ASC) AS R_Score,
    NTILE(4) OVER (ORDER BY Total_Transactions DESC) AS F_Score,
    NTILE(4) OVER (ORDER BY Total_Spend DESC) AS M_Score
INTO #RFM_Scores
FROM Customers360;

-- Now assign segments based on total RFM score (R+F+M)
WITH CTE AS (
SELECT *,
    (R_Score + F_Score + M_Score) AS RFM_Total,
    CASE
        WHEN (R_Score + F_Score + M_Score) >= 10 THEN 'Premium'
        WHEN (R_Score + F_Score + M_Score) >= 8 THEN 'Gold'
        WHEN (R_Score + F_Score + M_Score) >= 5 THEN 'Silver'
        ELSE 'Standard'
    END AS Customer_Segment
FROM #RFM_Scores) 
SELECT CTE.Customer_Segment, COUNT(*) AS TOTAL_CUST 
FROM Customers360 C 
JOIN CTE ON C.Customer_id = CTE.Customer_id
GROUP BY CTE.Customer_Segment;


-- Customers who have purchased from all channels
select * from Customers360
where Unique_Channels = 3;      -- Only 1 customer

-- DISCOUNT / NON DISCOUNT SEEKERS
WITH CTE AS (
    SELECT Customer_id,
    CASE 
        WHEN Total_Trans_with_Discount/Total_Transactions >= 0.7 THEN 'Discount Seeker' ELSE 'Non-Discount Seeker'
    END AS DiscountBehaviour
    FROM Customers360
)
SELECT CTE.DiscountBehaviour, COUNT(*) TOTAL_CUST, round(AVG(C.Total_Spend),2) as Avg_spend
FROM Customers360 C 
JOIN CTE ON C.Customer_id = CTE.Customer_id
GROUP BY CTE.DiscountBehaviour;


-- Channel used by Customers
SELECT Channel, COUNT(DISTINCT order_id) AS TotalOrders, COUNT(DISTINCT Customer_id) AS TotalCustomers
FROM Finalised_Records_1
GROUP BY Channel;

-- Customer Count by Store
SELECT Delivered_StoreID, COUNT(DISTINCT Customer_id) AS CustomerCount
FROM Finalised_Records_1
GROUP BY Delivered_StoreID;

-- Customer count by Payment Method
SELECT payment_type, COUNT(DISTINCT Customer_id) AS CustomerCount
FROM Finalised_Records_1 F 
JOIN OrderPayments P ON F.order_id = P.order_id
GROUP BY payment_type;


-- Understand the behavior of customers who purchased one category and purchased multiple categories
WITH Category_Behavior AS (
    SELECT 
        CASE 
            WHEN Total_unique_categories = 1 THEN 'Single-Category'
            ELSE 'Multi-Category'
        END AS Category_Type,
        Total_Spend,
        Total_Transactions,
        Avg_trans_amt,
        DATEDIFF(DAY, CAST(Last_trans_date AS DATE), GETDATE()) AS Recency_Days,
        Preferred_pay_type
    FROM Customers360
)
SELECT 
    Category_Type,
    COUNT(*) AS Customer_Count,
    AVG(Total_Spend) AS Avg_Spend,
    AVG(Total_Transactions) AS Avg_Transactions,
    AVG(Avg_trans_amt) AS Avg_Transaction_Value,
    AVG(Recency_Days) AS Avg_Recency_Days,

    -- Most common payment type using a subquery
    (
        SELECT TOP 1 Preferred_pay_type
        FROM Category_Behavior cb2
        WHERE cb1.Category_Type = cb2.Category_Type
        GROUP BY Preferred_pay_type
        ORDER BY COUNT(*) DESC
    ) AS Most_Common_Payment_Type

FROM Category_Behavior cb1
GROUP BY Category_Type;


-- Total Sales & Percentage of sales by category (Perform Pareto Analysis)
WITH CategorySales AS (
    SELECT 
        Category,
        ROUND(SUM(Total_Amount), 2) AS Total_Sales
    FROM Finalised_Records_1
    GROUP BY Category
),
SalesWithPercent AS (
    SELECT 
        Category,
        Total_Sales,
        Total_Sales * 100.0 / SUM(Total_Sales) OVER () AS Sales_Percentage
    FROM CategorySales
),
FinalPareto AS (
    SELECT *,
        SUM(Sales_Percentage) OVER (ORDER BY Total_Sales DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Cumulative_Percentage
    FROM SalesWithPercent
)
SELECT * FROM FinalPareto
ORDER BY Total_Sales DESC;


-- Most profitable category and its contribution
SELECT TOP 1 
    Category,
    ROUND(SUM(Total_Amount), 0) AS Total_Revenue,
    ROUND(SUM(Total_Amount) / (SELECT SUM(Total_Amount) FROM Finalised_Records_1) * 100, 2) as Perct_Contribution
FROM Finalised_Records_1
GROUP BY Category
ORDER BY Total_Revenue DESC;



-- Category Penetration Analysis by month on month (Category Penetration = number of orders containing the category/number of orders)
-- Step 1: Extract Month from order date
WITH OrdersWithMonth AS (
    SELECT 
        order_id,
        Category,
        CONVERT(VARCHAR(7), Bill_datetime, 120) AS OrderMonth
    FROM Finalised_Records_1
),
-- Step 2: Total orders per month
TotalOrders AS (
    SELECT 
        OrderMonth,
        COUNT(DISTINCT order_id) AS Total_Orders
    FROM OrdersWithMonth
    GROUP BY OrderMonth
),
-- Step 3: Orders per category per month
CategoryOrders AS (
    SELECT 
        OrderMonth,
        Category,
        COUNT(DISTINCT order_id) AS Category_Orders
    FROM OrdersWithMonth
    GROUP BY OrderMonth, Category
)
-- Step 4: Final result with penetration calculation
SELECT 
    c.OrderMonth,
    c.Category,
    c.Category_Orders,
    t.Total_Orders,
    CAST(c.Category_Orders * 100.0 / t.Total_Orders AS DECIMAL(5,2)) AS Category_Penetration_Percentage
FROM CategoryOrders c
JOIN TotalOrders t ON c.OrderMonth = t.OrderMonth
ORDER BY c.OrderMonth, Category_Penetration_Percentage DESC;


-- Step 1: Extract Month from Bill date
WITH BaseData AS (
    SELECT 
        order_id,
        Region,
        seller_state,
        CONVERT(VARCHAR(7), Bill_datetime, 120) AS OrderMonth,
        Category
    FROM Finalised_Records_1
),
-- Step 2: Count distinct categories per order
CategoriesPerOrder AS (
    SELECT 
        OrderMonth,
        order_id,
        Region,
        seller_state,
        COUNT(DISTINCT Category) AS NumCategories
    FROM BaseData
    GROUP BY OrderMonth, order_id, Region, seller_state
),
-- Step 3: Calculate average categories per bill (by Region, State, Month)
AvgCategoriesPerBill AS (
    SELECT 
        OrderMonth,
        Region,
        seller_state,
        AVG(CAST(NumCategories AS FLOAT)) AS Avg_Categories_Per_Bill
    FROM CategoriesPerOrder
    GROUP BY OrderMonth, Region, seller_state
)
SELECT * 
FROM AvgCategoriesPerBill
ORDER BY OrderMonth, Region, seller_state;



-- 



select * from Customers360;
select * from Orders360;
select * from Stores360;
select * from Finalised_Records_1;