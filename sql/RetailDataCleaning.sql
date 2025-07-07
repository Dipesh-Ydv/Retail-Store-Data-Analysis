select top 5 * from Customers;
select top 5 * from Orders;
select top 5 * from ProductsInfo;
select top 5 * from StoresInfo;
select top 5 * from OrderPayments;
select top 5 * from OrderReview_Ratings;


-- To copy only the Structure of table
select * Into Cust from Customers where 1=0;
select * from cust;

-- Coppy structure + Data both
SELECT * INTO Orders_new FROM Orders;
SELECT * INTO Customer_new FROM Customers;
SELECT * INTO ProductsInfo_new FROM ProductsInfo;
SELECT * INTO StoresInfo_new FROM StoresInfo;
SELECT * INTO OrderPayments_new FROM OrderPayments;
select * INTO OrderReviewRatings_new FROM OrderReview_Ratings;

Drop table Orders_new;
Drop table OrderPayments_new;
Drop table OrderReviewRatings_new;
Drop table ProductsInfo_new;
Drop table Customer_new;
Drop table StoresInfo_new;


-- PRODUCT_INFO TABLE


select * from ProductsInfo_new;

-- Updating category to others where category is not present
update ProductsInfo_new 
set Category = 'Others' 
where Category = '#N/A';






-- STORE_INFO TABLE


-- Deleting records with duplicate StoreId 
With T as (
    select *,
    ROW_NUMBER() OVER(PARTITION BY StoreID ORDER BY seller_city) as Id_count
    from StoresInfo_new
)
delete from T 
where Id_count > 1;

select * from StoresInfo_new;






-- ORDER_PAYMENT TABLE 


-- Deleting records whose order_id is not present in Orders table
delete P 
from OrderPayments_new P 
left join Orders_new O on P.order_id = O.order_id
where O.order_id is null;


-- Aggregating payment values i.e only one payment amount for each payment type
with T as (
    select order_id, payment_type, sum(payment_value) total_payment
    from OrderPayments_new 
    group by order_id, payment_type    
)
update P 
set P.payment_value = T.total_payment 
from OrderPayments_new P 
join T on P.order_id = T.order_id and P.payment_type = T.payment_type;


-- Deleting duplicate records after aagregating
with C as (
    select *,
    ROW_NUMBER() OVER(PARTITION BY order_id, payment_type ORDER BY payment_value desc) rn 
    from OrderPayments_new
)
delete from C where rn > 1;


-- Records where payment_value = 0
select * 
from OrderPayments_new 
where payment_value = 0;        -- No such record present


select * from OrderPayments_new;




-- ORDER_REVIEW_RATING TABLE


select * from OrderReviewRatings_new;

-- Deleting records whose order_id is not present in Orders table
delete R 
from OrderReviewRatings_new R 
left join Orders_new O on R.order_id = O.order_id
where O.order_id is null;


-- Replacing each rating with the average rating
with T as (
    select order_id, AVG(Customer_Satisfaction_Score*1.0) average_rating
    from OrderReviewRatings_new 
    group by order_id
)
update R 
set Customer_Satisfaction_Score = T.average_rating
from OrderReviewRatings_new R 
join T on R.order_id = T.order_id;


-- Deleting duplicate records for each order_id 
with CTE as (
    select *,
    ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Customer_Satisfaction_Score) as rn 
    from OrderReviewRatings_new
)
delete from CTE where rn > 1;

select distinct order_id from OrderReviewRatings_new;






-- ORDERS TABLE


-- Bill_date Column in Orders table 

-- Adding new column for converted datetime
alter table Orders_new 
add Bill_datetime datetime;

-- Inserting values in new column of correct data type using type casting
update Orders_new 
set Bill_datetime = CAST(Bill_date_timestamp as datetime);

-- This can also be done
-- Updating the value of the column itself
-- UPDATE Orders_new
-- set Bill_date_timestamp = CAST(Bill_date_timestamp as datetime);

-- Deleting the old Bill_date_timestamp column
alter table Orders_new
drop column Bill_date_timestamp;

-- Deleting records whose date is out of given range
delete from Orders_new 
where order_id in (
    select distinct order_id
    from Orders_new 
    where Bill_datetime not between '2021-09-01' and '2023-10-31'
);

-- Deleting records whose payment details are not preset in Orders_Payment table
delete O
from Orders_new O 
left join OrderPayments_new P on O.order_id = P.order_id
where P.order_id is null;


-- Changing the customer_id to one for orders who has multiple customer_id associated
with TBL as (
    select *, 
    ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Quantity DESC) rn 
    from Orders_new 
)
update O 
set O.customer_id = TBL.customer_id
from Orders_new O 
join TBL on O.order_id = TBL.order_id
where TBL.rn = 1;

-- Checking whether it is changed or not
select * from Orders_new where order_id = '005d9a5423d47281ac463a968b3936fb';


-- Changing store_id to single store_id where channel is instore (replacing with the minimum store_id)
with TBL as (
    select *, 
    ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Delivered_StoreID) rn 
    from Orders_new
    where channel = 'instore' 
)
update O 
set O.Delivered_StoreID = TBL.Delivered_StoreID 
from Orders_new O 
join TBL on O.order_id = TBL.order_id 
where TBL.rn = 1;

-- Checking whether it is changed or not
select * from Orders_new where order_id = '002f98c0f7efd42638ed6100ca699b42';


-- Changing date_timestamp to single date_timestamp for each order (replacing with the minimum date_timestamp)
with TBL as (
    select *, 
    ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY Bill_datetime) rn 
    from Orders_new
)
update O 
set O.Bill_datetime = TBL.Bill_datetime 
from Orders_new O 
join TBL on O.order_id = TBL.order_id 
where TBL.rn = 1;

-- Checking whether it is changed or not
select * from Orders_new where order_id = '01cce1175ac3c4a450e3a0f856d02734';


-- Solving discrepancy in Cumulative (Quantity, Total_Amont), Discount, and MRP
with TBL as (
    select *, 
    ROW_NUMBER() OVER(PARTITION BY order_id, product_id ORDER BY Quantity DESC) as rn 
    from Orders_new
) 
update O
set O.Quantity = TBL.Quantity,  -- (MRP - Discount) * Quantity
O.MRP = TBL.MRP,
O.Total_Amount = TBL.Total_Amount, 
O.Discount = TBL.Discount
from Orders_new O 
join TBL on O.order_id = TBL.order_id and O.product_id = TBL.product_id 
where TBL.rn = 1;

-- deleting the duplicate records
with TBL as (
    select *, 
    ROW_NUMBER() OVER(PARTITION BY order_id, product_id ORDER BY Quantity DESC) as rn 
    from Orders_new
) 
delete from TBL 
where rn > 1;   -- 10,222 records deleted


-- records with different amount in Orders and OrderPayment table
with A as (
    select order_id, round(sum(Total_Amount), 0) as Total_Amount
    from Orders_new
    group by customer_id, order_id 
), 
B as (
    select order_id, round(sum(payment_value), 0) as Payment_value
    from OrderPayments_new
    group by order_id
),
C as (
    select A.order_id
    from A 
    join B on A.order_id = B.order_id
    where A.Total_Amount <> B.Payment_value
) select * from C;
delete from Orders_new
where order_id in (select * from C); -- 3481    -- 7240 rows deleted


select * from Orders_new where order_id = '012a238ab54294a3b365812ccc82b135';
select * from OrderPayments_new where order_id = '012a238ab54294a3b365812ccc82b135';
select * from Orders_new where order_id = '005d9a5423d47281ac463a968b3936fb';
select * from OrderPayments_new where order_id = '005d9a5423d47281ac463a968b3936fb';

select * from Orders_new; --102,421
select * from OrderPayments_new;

-- All have equal number of records
select distinct order_id from Orders_new;
select distinct order_id from OrderPayments_new;
select distinct order_id from OrderReviewRatings_new;

select * from Orders;



select sum(Total_Amount) from Orders_new;



