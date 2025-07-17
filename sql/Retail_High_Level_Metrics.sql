-- HIGH LEVEL METRICS

-- 1. Total number of Orders
select count(order_id) as Total_Orders from Orders360;

-- 2. Total Discount given
select sum(Total_discount) as Total_Discount from Orders360;

-- 3. Average discount per Customer
select avg(Total_Discount*1.0) as Avg_Discount_per_Customer from Customer360;

-- 4. Average discount per Order
select avg(Total_Discount*1.0) as Avg_Discount_per_Order from Orders360;

-- 5. Average order value
select round(avg(Total_amount), 2) as Average_order_value from Orders360;

-- 6. Average sale per customer
select round(avg(Total_Spend), 2) as Average_sale_per_customer from Customer360;

-- 7. Average profit per customer
select round(avg(Total_Profit), 2) as Average_profit_per_customer from Customer360;

-- 8. Average categories per order
select avg(Total_categories*1.0) as Avg_categories_per_order from Orders360;

-- 9. Average number of items per order
select avg(Total_Qty*1.0) as Avg_items_per_order from Orders360;

-- 10. Number of Customers
select count(*) as Total_Customers from Customer360;

-- 11. Average Transactions per Customer
select avg(Total_Transactions*1.0) as Average_trans_per_customer from Customer360;

-- 12. Total Revenue 
select round(sum(Total_Revenue), 2) as Total_Revenue from Stores360;

-- 13. Total Profit
select round(sum(Total_Profit), 2) as Total_Profit from Stores360;

-- 14 . Total Cost
select round(sum(Total_cost), 2) as Total_Profit from Stores360;

-- 15. Total Quantity
select sum(Total_Qty) as Total_Qty from Stores360;

-- 16. Total Products 
select count(distinct product_id) as Total_Products from Finalised_Records_1;

-- 17. Total Categories 
select count(distinct Category) as Total_Categories from Finalised_Records_1;
select distinct Category from Finalised_Records_1;

-- 18. Total Stores
select count(Delivered_StoreID) as Total_stores from Stores360;

-- 19. Total Channels
select distinct Channel from Finalised_Records_1;

-- 20. Total region 
select distinct Region from StoresInfo;

-- 21. Total Payment methods
select distinct payment_type from OrderPayments;

-- 22. Total Customers locations
select count(distinct Cust_city) as Total_cities, count(distinct Cust_State) Total_states from Customer360;

-- 23. Average number of days between two transactions
WITH OrderedTransactions AS (
    SELECT
    Customer_id,
    Bill_datetime,
    LAG(Bill_datetime) OVER (PARTITION BY Customer_id ORDER BY Bill_datetime) AS PreviousOrderDate
    FROM Finalised_Records_1
),
TransactionDiffs AS (
    SELECT
    Customer_id,
    DATEDIFF(Day ,PreviousOrderDate, Bill_datetime) AS DaysBetween
    FROM OrderedTransactions
    WHERE PreviousOrderDate IS NOT NULL
)
SELECT
AVG(DaysBetween*1.0) AS AvgDaysBetweenTransactions
FROM TransactionDiffs;

-- 24. Percentage of Profit
select round(sum(Total_Profit) / sum(Total_Revenue) * 100, 2) Profit_Percentage from Stores360;

-- 25. Percentage Discount
select round(sum(Total_Discount) / sum(Total_Revenue) * 100, 2) Discount_Percentage from Stores360;
select round(sum(discount) / sum(MRP) * 100, 2) Discount_Percentage from Finalised_Records_1;

-- 26. Repeat Customer rate
select 
(count(case when Total_Transactions > 1 then 1 end) * 100.0) / count(Customer_id) as Repeat_Cust_perct
from Customer360; -- there are only 36 repeating customers

select * from Finalised_Records_1 where customer_id = 1318738406;

-- 27. One Time Buyers
select 
(count(case when Total_Transactions = 1 then 1 end) * 100.0) / count(Customer_id) as OneTime_Cust_perct
from Customer360;

-- 29. New customers every month (customer accusiton per month)
WITH FirstOrders AS (
    SELECT
    Customer_id,
    MIN(Bill_datetime) AS FirstOrderDate
    FROM Finalised_Records_1
    GROUP BY Customer_id
)
SELECT
    CAST(YEAR(FirstOrderDate) AS VARCHAR(4)) + '-' + 
    RIGHT('0' + CAST(MONTH(FirstOrderDate) AS VARCHAR(2)), 2) AS [Month],
    COUNT(*) AS CustomersAcquired
FROM FirstOrders
GROUP BY YEAR(FirstOrderDate), MONTH(FirstOrderDate)
ORDER BY [Month];

-- 30. 1. Trend Analysis Over Time
SELECT
    CAST(YEAR(Bill_datetime) AS VARCHAR(4)) + '-' + 
    RIGHT('0' + CAST(MONTH(Bill_datetime) AS VARCHAR(2)), 2) AS [Month],
    round(SUM(Total_Amount), 2) AS TotalSales,
    SUM(Quantity) AS TotalQuantity
FROM Finalised_Records_1
GROUP BY YEAR(Bill_datetime), MONTH(Bill_datetime)
ORDER BY [Month];

-- 2. Sales/Quantity by Category
SELECT
    Category,
    round(SUM(Total_Amount), 2) AS TotalSales,
    SUM(Quantity) AS TotalQuantity
FROM Finalised_Records_1
GROUP BY Category
ORDER BY TotalSales DESC;

-- 3. Sales/Quantity by Region
SELECT
    S.Region,
    round(SUM(Total_Amount), 2) AS TotalSales,
    SUM(Quantity) AS TotalQuantity
FROM Finalised_Records_1 F
join StoresInfo S on F.Delivered_StoreID = S.StoreID
GROUP BY S.Region
ORDER BY TotalSales DESC;

-- 4. Sales/Quantity by Store
select Delivered_StoreID as StoreID, Total_Qty, Total_Revenue 
from Stores360
order by Total_Revenue desc;

-- 5. Sales/Quantity by Channel
SELECT
    Channel,
    round(SUM(Total_Amount), 2) AS TotalSales,
    SUM(Total_Qty) AS TotalQuantity
FROM Orders360
GROUP BY Channel
ORDER BY TotalSales DESC;

-- 6. Sales/Quantity by Payment Method
SELECT
    P.payment_type,
    round(SUM(Total_Amount), 2) AS TotalSales,
    SUM(Quantity) AS TotalQuantity
FROM Finalised_Records_1 as F
join OrderPayments as P on F.order_id = P.order_id
GROUP BY P.Payment_type
ORDER BY TotalSales DESC;

-- 7. Sales by Category per Month:
SELECT
    Category,
    CAST(YEAR(Bill_datetime) AS VARCHAR(4)) + '-' + 
    RIGHT('0' + CAST(MONTH(Bill_datetime) AS VARCHAR(2)), 2) AS [Month],
    round(SUM(Total_Amount), 2) AS TotalSales
FROM Finalised_Records_1
GROUP BY Category, YEAR(Bill_datetime), MONTH(Bill_datetime)
ORDER BY Category, [Month];

-- 31. Revenue from existing and new customers on monthly basis
WITH CustomerFirstPurchase AS (
    SELECT
        Customer_id,
        MIN(Bill_datetime) AS FirstPurchaseDate
    FROM Finalised_Records_1
    GROUP BY Customer_id
),
CustomerOrders AS (
    SELECT
        d.Customer_id,
        d.order_id,
        d.Bill_datetime,
        YEAR(d.Bill_datetime) AS OrderYear,
        MONTH(d.Bill_datetime) AS OrderMonth,
        f.FirstPurchaseDate,
        d.Total_Amount,
        CASE 
            WHEN YEAR(d.Bill_datetime) = YEAR(f.FirstPurchaseDate)
                 AND MONTH(d.Bill_datetime) = MONTH(f.FirstPurchaseDate)
            THEN 'New'
            ELSE 'Existing'
        END AS CustomerType
    FROM Finalised_Records_1 d
    JOIN CustomerFirstPurchase f ON d.Customer_id = f.Customer_id
)
SELECT
    CAST(OrderYear AS VARCHAR(4)) + '-' + 
    RIGHT('0' + CAST(OrderMonth AS VARCHAR(2)), 2) AS [Month],
    CustomerType,
    ROUND(SUM(Total_Amount), 2) AS Revenue
FROM CustomerOrders
GROUP BY OrderYear, OrderMonth, CustomerType
ORDER BY [Month], CustomerType;

-- 32. Top 10-performing & worst 10 performance stores in terms of sales
select top 10 Delivered_StoreID, Total_Revenue
from Stores360
order by Total_Revenue desc;

select top 10 Delivered_StoreID, Total_Revenue
from Stores360
order by Total_Revenue;

-- 33. Popular categories/Popular Products by store, state, region. 
-- 1)  Popular Categories by Store
SELECT
    Delivered_StoreID,
    Category,
    SUM(Quantity) AS TotalUnitsSold
FROM Finalised_Records_1
GROUP BY Delivered_StoreID, Category
ORDER BY Delivered_StoreID, TotalUnitsSold DESC;

-- 2) Top 3 Category by StoreID
WITH RankedCategories AS (
    SELECT
        Delivered_StoreID,
        Category,
        SUM(Quantity) AS TotalUnitsSold,
        ROW_NUMBER() OVER (PARTITION BY Delivered_StoreID ORDER BY SUM(Quantity) DESC) AS rn
    FROM Finalised_Records_1
    GROUP BY Delivered_StoreID, Category
)
SELECT
    Delivered_StoreID,
    Category,
    TotalUnitsSold
FROM RankedCategories
WHERE rn <= 3
ORDER BY Delivered_StoreID, rn;

-- 3) Top 3 Product by Store
WITH RankedCategories AS (
    SELECT
        Delivered_StoreID,
        product_id,
        SUM(Quantity) AS TotalUnitsSold,
        ROW_NUMBER() OVER (PARTITION BY Delivered_StoreID ORDER BY SUM(Quantity) DESC) AS rn
    FROM Finalised_Records_1
    GROUP BY Delivered_StoreID, product_id
)
SELECT
    Delivered_StoreID,
    product_id,
    TotalUnitsSold
FROM RankedCategories
WHERE rn <= 3
ORDER BY Delivered_StoreID, rn;

-- 4) Top 3 Category by State
WITH RankedCategories AS (
    SELECT
        seller_state,
        Category,
        SUM(Quantity) AS TotalUnitsSold,
        ROUND(SUM(Total_Amount), 2) AS TotalRevenue,
        ROW_NUMBER() OVER (PARTITION BY seller_state ORDER BY SUM(Quantity) DESC) AS rn
    FROM Finalised_Records_1
    GROUP BY seller_state, Category
)
SELECT
    seller_state,
    Category,
    TotalRevenue,
    TotalUnitsSold
FROM RankedCategories
WHERE rn <= 3
ORDER BY seller_state, rn;

-- 5) Top 3 product by State
WITH RankedCategories AS (
    SELECT
        seller_state,
        product_id,
        round(SUM(Total_Amount), 0) AS Revenue,
        ROW_NUMBER() OVER (PARTITION BY seller_state ORDER BY SUM(Total_Amount) DESC) AS rn
    FROM Finalised_Records_1
    GROUP BY seller_state, product_id
)
SELECT
    seller_state,
    product_id,
    Revenue
FROM RankedCategories
WHERE rn <= 3
ORDER BY seller_state, rn;

-- 34. Top 5 product by Quantity
select top 5 product_id, sum(Quantity) as Quantity_Sold
from Finalised_Records_1
group by product_id
order by Quantity_Sold desc;

-- 35. Top 5 product by profit
select top 5
    product_id,
    round(sum(Total_Amount), 2) as Total_Revenue,
    round(sum(Total_Amount - (Quantity*Cost_Per_Unit)), 2) as Total_Profit
from Finalised_Records_1
group by product_id
order by Total_Profit desc;

-- 36. Top 5 Category by Qunatity
select top 5 Category, sum(Quantity) as Quantity_Sold
from Finalised_Records_1
group by Category
order by Quantity_Sold desc;

-- 37. Top 5 Category by profit
select top 5
    Category,
    round(sum(Total_Amount - (Quantity*Cost_Per_Unit)), 2) as Total_Profit
from Finalised_Records_1
group by Category
order by Total_Profit desc;

-- 38. Revenue by Gender 
select 
    Gender,
    round(sum(Total_Spend) , 2) as Total_Revenue
from Customer360
group by Gender;



select count(distinct seller_state) from Finalised_Records_1;

select avg(Total_Qty) from Stores360;

select avg(Total_Revenue) from Stores360;

select avg(Total_Profit) from Stores360;
select avg(Number_of_unique_products) from Stores360;
select avg(Total_Discount) from Stores360;
select avg(Customer_visits) from Stores360;
select avg(Dist_categories) from Stores360;
select avg(Total_Transactions) from Stores360;
select avg(average_rating*1.0) from Stores360; -- 3.84
select avg(Avg_profit) from Stores360;
select avg(Avg_profit) from Orders360;
select avg(Total_Profit) from Orders360;
select avg(Avg_order_rating*1.0) from Orders360; -- 4.1
select avg(Average_rating*1.0) from Customer360; -- 4.1

select sum(total_spend) from Customer360;
select sum(Total_amount) from Orders360;
select sum(Total_Revenue) from Stores360;

-- sales by state
select seller_state, round(sum(Total_Amount), 2) Total_Revenue
from Finalised_Records_1
group by seller_state
order by Total_Revenue desc;

-- revenue by category
select Category, round(sum(Total_Amount), 2) Total_Revenue 
from Finalised_Records_1
group by Category
order by Total_Revenue desc;

-- Category analysis

-- Average rating for each category
select Category, round(avg(Avg_rating*1.0), 2) as rating
from Finalised_Records_1
group by Category
order by rating desc;

-- Top 5 rated categories
select Top 5
Category, round(avg(Avg_rating*1.0), 2) as rating
from Finalised_Records_1
group by Category
order by rating desc;

-- Bottom 5 rated categories
select Top 5
Category, round(avg(Avg_rating*1.0), 2) as rating
from Finalised_Records_1
group by Category
order by rating ASC;

-- Average rating by region
select
Region, round(avg(Avg_rating*1.0), 2) as rating
from Finalised_Records_1
group by Region
order by rating desc;

-- Average rating by state
select
seller_state, round(avg(Avg_rating*1.0), 2) as rating
from Finalised_Records_1
group by seller_state
order by rating desc;

-- Average rating by state
select
customer_state, round(avg(Avg_rating*1.0), 2) as rating
from Finalised_Records_1
group by customer_state
order by rating desc;

-- Top 10 rated products
select Top 10
product_id, round(avg(Avg_rating*1.0), 2) as rating
from Finalised_Records_1
group by product_id
order by rating desc;

-- Average rating by store
select Delivered_StoreID, average_rating
from Stores360
order by average_rating desc;


-- Step 1: Extract Month, and count distinct categories per order
WITH CategoriesPerOrder AS (
    SELECT 
        CONVERT(VARCHAR(7), Bill_datetime, 120) AS OrderMonth,
        order_id,
        Region,
        seller_state,
        COUNT(DISTINCT Category) AS NumCategories
    FROM Finalised_Records_1
    GROUP BY 
        CONVERT(VARCHAR(7), Bill_datetime, 120),
        order_id,
        Region,
        seller_state
)
-- Step 2: Average number of categories per bill by Region, State, and Month
SELECT 
    OrderMonth,
    Region,
    seller_state,
    AVG(CAST(NumCategories AS FLOAT)) AS Avg_Categories_Per_Bill
FROM CategoriesPerOrder
GROUP BY 
    OrderMonth,
    Region,
    seller_state
ORDER BY 
    OrderMonth,
    Region,
    seller_state;




select sum(Discount)/sum(MRP) from Finalised_Records_1;


select * from Finalised_Records_1; 
select top 5 * from Customer360;
select top 5 * from Orders360;
select top 5 * from Stores360;



select (sum(Total_Profit) / sum(Total_amount)) * 100 from orders360;

select (sum(Total_Amount - (Cost_Per_Unit * Quantity)) / sum(Total_Amount) ) * 100
from Finalised_Records_1;

select count(distinct customer_id) from Orders;
select count(distinct Custid) from Customers;

SELECT CUSTOMER_ID, COUNT(DISTINCT ORDER_ID) ORDER_COUNT
FROM ORDERS 
GROUP BY CUSTOMER_ID
HAVING COUNT(DISTINCT ORDER_ID) > 1
ORDER BY ORDER_COUNT DESC;

SELECT Cust_State, SUM(Total_Spend) Total_Revenue
FROM Customer360
GROUP BY Cust_State
ORDER BY Total_Revenue DESC;
