-- Customer segmentation based on revenue
-- Creating new column for Revenue Segmentation
ALTER TABLE Customer360
ADD RevenueSegment VARCHAR(20);

WITH CTE AS (
SELECT 
    Customer_Id,
    CASE
        WHEN Total_Spend < PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY Total_Spend) OVER () THEN 'Low Revenue'
        WHEN Total_Spend < PERCENTILE_CONT(0.66) WITHIN GROUP (ORDER BY Total_Spend) OVER () THEN 'Medium Revenue'
        ELSE 'High Revenue'
    END AS RS
    FROM Customer360
) 
UPDATE C1
SET C1.RevenueSegment = C2.RS
FROM Customer360 C1
JOIN CTE C2 ON C1.Customer_Id = C2.Customer_Id;

--
SELECT 
RevenueSegment,
COUNT(*) Total_Customers,
SUM(CASE WHEN Gender = 'M' THEN 1 ELSE 0 END) AS Male_Cust,
SUM(CASE WHEN Gender = 'F' THEN 1 ELSE 0 END) AS Female_Cust,
SUM(CASE WHEN Gender = 'M' THEN Total_Spend END) AS Male_Revenue,
SUM(CASE WHEN Gender = 'F' THEN Total_Spend END) AS Female_Revenue,
SUM(Total_Spend) Revenue,
AVG(Total_Spend) Avg_Spend,
AVG(Total_Quantity*1.0) Avg_Qty,
AVG(Average_Rating) Avg_Rating
FROM Customer360
GROUP BY RevenueSegment;

select * from Customer360;
select * from Orders360;

-- RFM Segmentation
ALTER TABLE Customer360
ADD Customer_Segment VARCHAR(10);

SELECT 
    Customer_id,
    Cust_city,
    Cust_State,
    Gender,
    Total_Transactions,
    Total_Spend,
    DATEDIFF(DAY, CAST(Last_trans_date AS DATE), '2023-10-31') AS Recency,
    NTILE(4) OVER (ORDER BY DATEDIFF(DAY, CAST(Last_trans_date AS DATE), CAST('2023/10/31' AS DATE)) ASC) AS R_Score,
    NTILE(4) OVER (ORDER BY Total_Transactions DESC) AS F_Score,
    NTILE(4) OVER (ORDER BY Total_Spend DESC) AS M_Score
INTO #RFM_Scores
FROM Customer360;

SELECT * FROM #RFM_Scores;

-- Now assign segments based on total RFM score (R+F+M)
WITH CTE AS (
    SELECT *,
        (R_Score + F_Score + M_Score) AS RFM_Total,
        CASE
            WHEN (R_Score + F_Score + M_Score) >= 10 THEN 'Premium'
            WHEN (R_Score + F_Score + M_Score) >= 8 THEN 'Gold'
            WHEN (R_Score + F_Score + M_Score) >= 5 THEN 'Silver'
            ELSE 'Standard'
        END AS CS
    FROM #RFM_Scores
) 
UPDATE C
SET C.Customer_Segment = CTE.CS
FROM Customer360 C 
JOIN CTE ON C.Customer_id = CTE.Customer_id;

-- Customer Segment Analysis
SELECT
Customer_Segment, 
COUNT(*) Total_Customers,
SUM(CASE WHEN Gender = 'M' THEN 1 ELSE 0 END) AS Male_Cust,
SUM(CASE WHEN Gender = 'F' THEN 1 ELSE 0 END) AS Female_Cust,
SUM(CASE WHEN Gender = 'M' THEN Total_Spend END) AS Male_Revenue,
SUM(CASE WHEN Gender = 'F' THEN Total_Spend END) AS Female_Revenue,
SUM(Total_Spend) Revenue,
AVG(Total_Quantity*1.0) Average_Quanity,
AVG(Total_unique_categories*1.0) Average_Categories,
AVG(Total_unique_products*1.0) Average_Products,
AVG(Total_Spend) Average_Spend,
AVG(Total_Discount*1.0) Average_Discount,
AVG(Total_Profit) Average_Profit,
AVG(Average_rating*1.0) as Average_Rating
FROM Customer360
GROUP BY Customer_Segment; 

-- Region wise Revenue distribution by Customer Segment
SELECT
Region,
Customer_Segment,
SUM(Total_Spend) AS Revenue
FROM Customer360
GROUP BY Region, Customer_Segment
ORDER BY Region;

-- Trend Analysis by Customer Segment
SELECT 
CAST(YEAR(First_trans_date) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH(First_trans_date) AS VARCHAR(2)), 2) AS [Month],
Customer_Segment,
SUM(Total_Spend)
FROM Customer360
GROUP BY CAST(YEAR(First_trans_date) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH(First_trans_date) AS VARCHAR(2)), 2), Customer_Segment
ORDER BY [Month];

-- Customers who have purchased from all channels
select * from Customer360
where Unique_Channels = 3;      -- Only 1 customer

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
        DATEDIFF(DAY, CAST(Last_trans_date AS DATE), '2023-10-31') AS Recency_Days,
        Preferred_pay_type
    FROM Customer360
)
SELECT 
    Category_Type,
    COUNT(*) AS Customer_Count,
    AVG(Total_Spend) AS Avg_Spend,
    AVG(Total_Transactions*1.0) AS Avg_Transactions,
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

-- Discount vs Non-Discount Seekers
-- Creating a column to store that flag value
ALTER TABLE Customer360
ADD Discount_Seeker_Flag VARCHAR(20);

UPDATE Customer360
SET Discount_Seeker_Flag = CASE WHEN (Total_Trans_with_Discount/Total_Transactions) >= 0.7 THEN 'Discount Seeker' ELSE 'Non-Discount Seeker' END;

SELECT
Discount_Seeker_Flag, 
COUNT(*) Total_Customers,
SUM(CASE WHEN Gender = 'M' THEN 1 ELSE 0 END) AS Male_Cust,
SUM(CASE WHEN Gender = 'F' THEN 1 ELSE 0 END) AS Female_Cust,
SUM(CASE WHEN Gender = 'M' THEN Total_Spend END) AS Male_Revenue,
SUM(CASE WHEN Gender = 'F' THEN Total_Spend END) AS Female_Revenue,
SUM(Total_Spend) Revenue,
AVG(Total_Quantity*1.0) Average_Quanity,
AVG(Total_unique_categories*1.0) Average_Categories,
AVG(Total_unique_products*1.0) Average_Products,
AVG(Total_Spend) Average_Spend,
AVG(Total_Discount*1.0) Average_Discount,
AVG(Total_Profit) Average_Profit,
AVG(Average_rating*1.0) as Average_Rating
FROM Customer360
GROUP BY Discount_Seeker_Flag; 

-- Revenue by Discount Seeker Flag
SELECT Discount_Seeker_Flag, SUM(Total_Spend)
FROM Customer360
GROUP BY Discount_Seeker_Flag;

-- Trend Analysis by Discount vs Non-Discount Seekers
SELECT 
CAST(YEAR(First_trans_date) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH(First_trans_date) AS VARCHAR(2)), 2) AS [Month],
Discount_Seeker_Flag,
SUM(Total_Spend)
FROM Customer360
GROUP BY CAST(YEAR(First_trans_date) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH(First_trans_date) AS VARCHAR(2)), 2), Discount_Seeker_Flag
ORDER BY [Month];

-- Region wise distribution Discount vs Non-Discount Seekers
SELECT
Region,
Discount_Seeker_Flag,
SUM(Total_Spend) AS Revenue
FROM Customer360
GROUP BY Region, Discount_Seeker_Flag
ORDER BY Region;


-- Trend Analysis
SELECT 
CAST(YEAR(Order_datetime) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH(Order_datetime) AS VARCHAR(2)), 2) AS [Month],
Category,
SUM(Total_amount)
FROM Orders360
GROUP BY CAST(YEAR(Order_datetime) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH(Order_datetime) AS VARCHAR(2)), 2), Category
ORDER BY [Month];

SELECT YEAR(Order_datetime) AS Year_, MONTH(Order_datetime) Month_, Category, SUM(Total_amount) 
FROM Orders360
GROUP BY YEAR(Order_datetime), MONTH(Order_datetime), Category
ORDER BY Year_, Month_;

-- Revenue by Category in each region
SELECT
Region,
Category,
SUM(Total_amount)
FROM Orders360
GROUP BY Region, Category
ORDER BY Region;

select * from Orders360;
select * from Customer360; 

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

-- Top 5 Categories and their revenue contribution by seller state
WITH CTE AS (
    SELECT 
    seller_state,
    Category,
    SUM(Total_amount) Revenue,
    SUM(Total_Amount) / SUM(SUM(Total_amount)) OVER(PARTITION BY seller_state) AS PERCENT_CONTRIBUTION,
    ROW_NUMBER() OVER(PARTITION BY seller_state ORDER BY SUM(Total_Amount) DESC) AS rnk
    FROM Orders360
    GROUP BY seller_state, Category
) 
SELECT *
FROM CTE
WHERE rnk <= 5;

-- Top 5 Categories and their revenue contribution by REGION
WITH CTE AS (
    SELECT 
    Region,
    Category,
    SUM(Total_amount) Revenue,
    SUM(Total_Amount) / SUM(SUM(Total_amount)) OVER(PARTITION BY Region) AS PERCENT_CONTRIBUTION,
    ROW_NUMBER() OVER(PARTITION BY Region ORDER BY SUM(Total_Amount) DESC) AS rnk
    FROM Orders360
    GROUP BY Region, Category
) 
SELECT *
FROM CTE
WHERE rnk <= 5;

-- -- Top 1 Category and their revenue contribution by Store Id
WITH CTE AS (
    SELECT 
    Delivered_StoreID,
    Category,
    SUM(Total_amount) Revenue,
    SUM(Total_Amount) / SUM(SUM(Total_amount)) OVER(PARTITION BY Delivered_StoreID) AS PERCENT_CONTRIBUTION,
    ROW_NUMBER() OVER(PARTITION BY Delivered_StoreID ORDER BY SUM(Total_Amount) DESC) AS rnk
    FROM Finalised_Records_1
    GROUP BY Delivered_StoreID, Category
) 
SELECT *
FROM CTE
WHERE rnk <= 1;

SELECT 
Day_of_Week,
SUM(Total_Amount) Total_Revenue,
SUM(Total_Amount)/ (SELECT SUM(Total_Amount) FROM Orders360) Perct_Contribution
FROM Orders360
GROUP BY Day_of_Week;

SELECT 
Time_of_Day,
SUM(Total_Amount) Total_Revenue,
SUM(Total_Amount)/ (SELECT SUM(Total_Amount) FROM Orders360) Perct_Contribution
FROM Orders360
GROUP BY Time_of_Day;


select * from Customer360;
select * from Orders360;
select * from Stores360;
select * from Finalised_Records_1;