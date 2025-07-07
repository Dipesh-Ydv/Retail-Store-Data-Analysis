create database Retail_DB;

select top 5 * from Customers;
select top 5 * from Orders;
select top 5 * from ProductsInfo;
select top 5 * from StoresInfo;
select top 5 * from OrderPayments;
select top 5 * from OrderReview_Ratings;

-- CUSTOMERS TABLE 
select top 5 * from Customers;

-- Total records
select count(*) as total_records from Customers;    -- 99441

-- Total distinct Customers
select count(distinct Custid) as distinct_cust from Customers; -- 99441

-- Total cust states
select distinct customer_state from Customers;

-- Distinct gender
select distinct gender from Customers;

-- Distinct city(4,119)
select distinct customer_city from Customers;

-- checking blanks for gender
select * from Customers where Gender = '' or Gender is null; -- no empty or null values

-- checking blanks for state
select * from Customers where customer_state = '' or customer_state is null; -- no empty or null values

-- Checking is there any record of customer in orders table which is not present in customers table
select * 
from Customers as C
right join Orders as O on C.Custid = O.Customer_id
where C.Custid is null; -- There no such record

-- Checking is there any record of customer which has not placed any order 
select count(*) as cust_with_no_purchase 
from Customers as C
left join Orders as O on C.Custid = O.Customer_id
where O.Customer_id is null;    -- There 866 customers which has not purchased anything





-- ProductInfo Table
select top 5 * from ProductsInfo;

-- Total records
select count(*) as total_records from ProductsInfo; -- 32951

-- Total unique products
select count(distinct product_id) from ProductsInfo; -- each product has unique product id

-- Distinct product categories 
select distinct Category from ProductsInfo; -- 14 distinct category in which one is #N/A

select count(*) from ProductsInfo where Category = '#N/A'; -- 623

-- empty or null values
select * from ProductsInfo 
where Category is null or Category = ''; -- 0 records 

-- Outliers in Weight column
select min(product_weight_g), max(product_weight_g) from ProductsInfo;

-- Any product id in orders table which is not present in productInfo table
select * 
from Orders as O
left join ProductsInfo as P on O.product_id = P.product_id
where P.product_id is null; -- There is no such record

-- Product id which is not present in Orders table
select * 
from Orders as O
right join ProductsInfo as P on O.product_id = P.product_id
where O.product_id is null; -- There is no such record





-- STORE_INFO TABLE
select top 5 * from StoresInfo;

-- Total records 
select count(storeID) as total_records from StoresInfo; -- 535

-- Distinct store id's
select count(distinct storeID) as dist_storeId from StoresInfo; -- 534 one is duplicate

select storeID from StoresInfo group by storeID having count(*) > 1;

-- distinct store states
select distinct seller_state from StoresInfo;   -- 19 no null or empty values

-- distinct store city
select distinct seller_city from StoresInfo;    -- 534, implies there is no 2 stores in 1 city

-- distinct region
select distinct region from StoresInfo; -- 4 

-- is any order which has multiple store_id
select order_id, count(Delivered_StoreID) as cnt_storeId 
from Orders
group by order_id
having count(Delivered_StoreID) > 1
order by cnt_storeId desc;      -- There are order_id (9,803) which have multiple store_id.

-- Store_id which are present in Orders table but are absent in StoreInfo table
select * 
from StoresInfo as S
right join Orders as O on S.StoreID = O.Delivered_StoreID
where S.StoreID is null;    -- There are no such orders

-- store_id which are present in StoreInfo table but not present in  Orders table
select * 
from StoresInfo as S
left join Orders as O on S.StoreID = O.Delivered_StoreID
where O.Delivered_StoreID is null; -- 497 stores had recieved 0 orders








-- ORDER_PAYMENTS TABLE
select top 5 * from OrderPayments;

-- Total records
select count(*) as total_records from OrderPayments;    -- 103,886

-- Total distinct order_id 
select count(distinct order_id) as distinct_orderid_cnt from OrderPayments; -- 99,440

select distinct order_id, payment_type from OrderPayments;  -- 101,686

select distinct order_id, payment_type, payment_value from OrderPayments; -- 103,271

-- distinct payment_type
select distinct payment_type from OrderPayments;

-- min payment value
select min(payment_value) from OrderPayments; -- 0 which is not possible

select * from OrderPayments where payment_value = 0 and payment_type != 'voucher';   -- only 3 orders 

select * from OrderPayments where payment_value = 0 and payment_type = 'voucher';   -- only 6 orders

select * from OrderPayments where payment_value = 0; -- only 9 rows

-- Total distinct order_id and payment_type combinations
select count(*) pair_orderId_payType from (
    select distinct order_id, payment_type from OrderPayments
) as T; -- 101686

-- order_id from OrderPayments table which are not present in Orders table
select count(*)  
from OrderPayments as OP
left join Orders as O on OP.order_id = O.order_id
where O.order_id is null;   -- 830 records 

-- orders whose payment details are not present in OrderPayments table
select count(*)  
from OrderPayments as OP
right join Orders as O on OP.order_id = O.order_id
where OP.order_id is null; -- 3 records

select *,
ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY payment_value) as payment_type_count
from OrderPayments
where order_id in (
    select order_id
    from OrderPayments
    group by order_id
    having count(payment_type) > 1
);









-- ORDER_REVIEW_RATINGS TABLE
select top 5 * from OrderReview_Ratings;

-- Total record
select count(*) as total_records from OrderReview_Ratings;  -- 100,000

-- distinct order_id 
select count(distinct order_id) from OrderReview_Ratings;   -- 99,441

-- distinct order_id and rating combination
select count(*) from (
    select distinct order_id, Customer_Satisfaction_Score from OrderReview_Ratings
) as T; -- 99,650

-- records which are present in Orders table but are not present in rating table
select * 
from OrderReview_Ratings as R 
right join Orders as O on R.order_id = O.order_id
where R.order_id is null;   -- no record

-- ratings of records which are present in rating table but not in orders table
select count(*)
from OrderReview_Ratings as R 
left join Orders as O on R.order_id = O.order_id
where O.order_id is null;   -- 778 records 

select *,
ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Customer_Satisfaction_Score) 
from OrderReview_Ratings;







-- ORDERS TABLE

select top 5 * from Orders;

-- Total records
select count(*) from Orders;    -- 112650d

-- Total distinct order_id and product_id combo
select distinct order_id, product_id from Orders;   -- 102,425

select distinct order_id, product_id, Customer_id from Orders;      -- 102,430

select distinct order_id, Customer_id from Orders;  -- 98,671

-- Total distinct orders
select count(distinct order_id) from Orders; -- 98,666

-- Data Disperancies between orders and payments table
select *
from Orders O 
join OrderPayments P on O.order_id = P.order_id
order by O.order_id;

-- MRP and Quantity discrepancy
select *, 
ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Quantity) 
from Orders;

-- Orders with same order_id but different Store_ID
select *,
ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Delivered_StoreID) AS order_count
from Orders 
where order_id in (
    select order_id
    from Orders
    where Channel = 'Instore'
    group by order_id 
    having count(distinct Delivered_StoreID) > 1
);



select *
from Orders as O 
left join StoresInfo S on O.Delivered_StoreID = S.StoreID
where S.StoreID is null;    -- 0 record

select *
from Orders O 
left join ProductsInfo P on O.product_id = P.product_id
where P.product_id is null;     -- 0 record

select *
from Orders O 
left join Customers C on O.Customer_id = C.Custid
where C.Custid is null;     -- 0 record

select * 
from Orders O
left join OrderPayments as P on O.order_id = P.order_id
where P.order_id is null;   -- 3 records but 1 order id 

select * from 
Orders O 
left join OrderReview_Ratings R on O.order_id = R.order_id
where R.order_id is null;   -- 0 records






-- Discrepancy between Orders and OrderPayments table
select T.order_id,T.product_id, T.Quantity, T.MRP, T.Discount, T.Total_Amount, T.amt_rank, P.payment_type, P.payment_value,
ROW_NUMBER() OVER(PARTITION BY T.order_id ORDER BY payment_value)
from 
(
    select *,
    ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Total_Amount DESC) amt_rank
    from Orders
) as T 
join OrderPayments P on T.order_id = P.order_id
where T.amt_rank = 1 and T.Total_Amount != P.payment_value;     -- There are orders with different total_Amount having different payment_value


-- Multiple date for same order_id with different product_id and store_id
select *,
ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Bill_date_timestamp) as Bill_date_count 
from Orders 
where order_id in (
    select order_id
    from Orders 
    group by order_id
    having count(distinct Bill_date_timestamp) > 1
);

-- Discrepancy between Orders Table and OrderReview_Ratings
select * 
from Orders O 
join OrderReview_Ratings R on O.order_id = R.order_id;  -- NOT FOUND

-- Orders whose payment_value is zero
select *
from OrderPayments
where payment_value = 0;

-- Customer from other state doing purchase from seller from another state while the channel is Instore OR Phone Delivery
select O.Customer_id, O.order_id, O.Channel, O.product_id, O.Delivered_StoreID, C.customer_state, S.seller_state,
ROW_NUMBER() OVER(PARTITION BY O.Customer_id ORDER BY O.Total_Amount)
from Orders O
join Customers C on O.Customer_id = C.Custid
join StoresInfo S on O.Delivered_StoreID = S.StoreID;


select O.order_id, O.product_id, O.Channel, O.Delivered_StoreID, O.Bill_date_timestamp, O.Quantity, O.MRP, O.Total_Amount, P.payment_type, P.payment_value, R.Customer_Satisfaction_Score 
from Orders O 
join OrderPayments P on O.order_id = P.order_id
join OrderReview_Ratings R on O.order_id = R.order_id;


-- Same order is paid multiple time with different amount using same payment method
select P.*, O.Channel, O.Delivered_StoreID, O.Bill_date_timestamp, O.MRP, O.Quantity, O.Total_Amount,
ROW_NUMBER() OVER(PARTITION BY P.order_id order by P.payment_value)
from OrderPayments P 
join (
    select order_id, count(payment_type) payment_method_cnt
    from OrderPayments
    where payment_type <> 'voucher'
    group by order_id
    having count(payment_type) > 1
) as T on P.order_id = T.order_id
join Orders O on P.order_id = O.order_id;

select * from OrderPayments where order_id = '4069c489933782af79afcd3a0e4d693c';

select *,
ROW_NUMBER() OVER(PARTITION BY order_id order by payment_value)
from OrderPayments 
where payment_type != 'voucher' and order_id in (
    select order_id
    from OrderPayments 
    group by order_id
    having count(*) > 1
);

select order_id, count(payment_type) payment_count
from OrderPayments 
group by order_id
having count(*) > 1
order by payment_count desc;


-- Single order_id is associated with multiple customers
select order_id, count(distinct Customer_id) as cust_count
from Orders  
group by order_id
order by cust_count desc;

select * from Orders where order_id = '005d9a5423d47281ac463a968b3936fb';

-- Discrepancy in Date column(09-2021 to 10-2023)
select min(converted_date) min_date, max(converted_date) max_date 
from (
    select Bill_date_timestamp, cast(Bill_date_timestamp as datetime) as converted_date
    from Orders
) as T;

select * 
from (
    select *, cast(Bill_date_timestamp as datetime) as converted_date
    from Orders
) as T
where converted_date not BETWEEN '2021-09-01' and '2023-10-31'; -- 4 Records are out of Date Range


-- Data is taken from 39 random stores but we have only 37 different stores order data present in Orders table
select distinct Delivered_StoreID from Orders;      -- 37, should be 39

