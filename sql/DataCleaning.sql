Create Database Retail_Project;

--________________________________________________ DATA CLEANING ___ (Slide No. 16-18)___________________________________________________


---------- STEP 1 ---
/*
Cust_order CTE: Aggregates customer order information by summing up the total amount (Total_Amount) for each Customer_id and Order_id, and rounding it off to the nearest integer.

Orderpayment_grouped CTE: Aggregates payment data from the Orders_Payement table by summing up the payment_value for each Order_id and rounding it to the nearest integer.

Match_order CTE: Performs an inner join between Cust_order and Orderpayment_grouped based on Order_id and ensures that the total amount matches the total payment value.

Final Selection: Inserts the results of the Match_order CTE (where total order amount equals payment value) into a new table called Matched_order_1.
*/
---
with   Cust_order as (select A.Customer_id, A.Order_id, round(sum(A.Total_Amount),0) as Total_amt from Orders A
group by A.Customer_id, A.Order_id),

Orderpayment_grouped as(select  A.order_ID, round(sum(A.payment_value),0) as pay_value_total from orderpayments 
A group by A.Order_id),

Match_order as (select A.* from Cust_order as A inner join Orderpayment_grouped as B 
on A.Order_id =B.order_ID and A.Total_amt=B.pay_value_total)
 

select * into Matched_order_1 from Match_order;

-------- STEP 2------
/*
i. Cust_order CTE: This Common Table Expression (CTE) aggregates the total amount spent per customer for each order in the `Orders` table, rounding the total amount to the nearest integer.

ii. Orderpayment_grouped CTE: This CTE calculates the total payment value for each order from the `Orders_Payment` table, grouping by the order and rounding the total payment value.

iii. Null_list CTE: A right join is performed between `Cust_order` and `Orderpayment_grouped` to find orders where the total amount from `Orders` doesn't match the payment amount from `Orders_Payment`. It filters for cases where no matching customer ID is found, meaning the total order amount is not equal to the payment amount.

iv. Remaining_ids CTE: This part joins the mismatched payment orders from `Null_list` with the `Orders` table to retrieve the correct customer ID and order information where there are discrepancies in payment values.

v. Final Output: The result from `Remaining_ids`, which contains orders with mismatched payment and total amounts, is stored into a new table named `Remaining_orders_1`.
*/
WITH Cust_order AS (
    SELECT 
        A.Customer_id, 
        A.Order_id, 
        Round(sum(A.Total_Amount),0) AS Total_amt 
    FROM 
        Orders A
    GROUP BY 
        A.Customer_id, 
        A.Order_id
),

Orderpayment_grouped AS (
    SELECT 
        A.Order_ID, 
        Round(sum(A.payment_value ),0) AS pay_value_total 
    FROM 
        orderpayments A
    GROUP BY 
        A.Order_ID
),
--- We are right joining as we are having null values 
Null_list AS (
    SELECT 
        B.* 
    FROM 
        Cust_order AS A 
    RIGHT JOIN 
        Orderpayment_grouped AS B 
    ON 
        A.Order_id = B.Order_ID 
        AND A.Total_amt = B.pay_value_total
    WHERE 
        A.Customer_id IS NULL
) ,
Remaining_ids as (SELECT 
    B.Customer_id ,B.Order_id,A.pay_value_total
FROM 
    Null_list  A inner join Orders B on A.Order_ID =B.Order_id and  A.pay_value_total = round(B.Total_Amount,0))	 

select * into Remaining_orders_1 from Remaining_ids;
----------
with T1 as (select B.* from Matched_order_1 A inner join Orders B on A.Customer_id=B.Customer_id and A.Order_id =B.Order_id),
	T2 as (select B.* from Remaining_orders_1 A inner join  Orders B on A.Customer_id=B.Customer_id and A.Order_id =B.Order_id and A.pay_value_total=round(B.Total_Amount,0) ),

	T as (select * from T1 union all select * from T2 )

	Select * into NEW_ORDER_TABLE_1 from T;

------

Select * into Integrated_Table_1 from (select A.*, D.Category ,C.Avg_rating,E.seller_city ,E.seller_state,E.Region,F.customer_city,F.customer_state,F.Gender from NEW_ORDER_TABLE_1 A  
	inner join (select A.ORDER_id,avg(A.Customer_Satisfaction_Score) as Avg_rating from orderreview_ratings A group by A.ORDER_id) as C on C.ORDER_id =A.Order_id 
	inner join productsinfo as D on A.product_id =D.product_id
	inner join (Select distinct * from storesinfo) as E on A.Delivered_StoreID =E.StoreID
	inner join Customers as F on A.Customer_id =F.Custid) as T;

Select * From Integrated_Table_1;


--------------FINALISED RECORDS AFTER DATA CLEANING -- 98379 DATA RECORDS------------------------

Select * Into Finalised_Records_no from (
Select * From Integrated_Table_1

UNION ALL

(Select T.Customer_id,T.order_id,T.product_id,T.Channel,T.Delivered_StoreID,T.Bill_date_timestamp,Sum(T.Net_QTY)as Quantity,T.Cost_Per_Unit,
T.MRP,T.Discount,SUM(Net_amount) as Total_Amount ,C.Category,F.Customer_Satisfaction_Score as Avg_rating,
G.seller_city,G.seller_state,G.Region,E.customer_city,E.customer_state,E.Gender
from (
Select Distinct A.*,(A.Total_Amount/A.Quantity) as Net_amount, (A.Quantity/A.Quantity) as Net_QTY From Orders A
join Orders B
on A.order_id = B.order_id
where A.Delivered_StoreID <> B.Delivered_StoreID 
) as T
Inner Join productsinfo C
on T.product_id = C.product_id
inner join orderpayments as D
on T.order_id = D.order_id
inner Join Customers As E
on T.Customer_id = E.Custid
inner join orderreview_ratings F
on T.order_id = F.order_id
inner join storesinfo G
on T.Delivered_StoreID = G.StoreID
Group by T.Customer_id,T.order_id,T.product_id,T.Channel,T.Bill_date_timestamp,T.Cost_Per_Unit,T.Delivered_StoreID,
T.Discount,T.MRP,T.Total_Amount,T.Quantity,T.Net_amount,T.Net_QTY,C.Category,F.Customer_Satisfaction_Score,
G.seller_city,G.seller_state,G.Region,E.customer_city,E.customer_state,E.Gender) 
) AS x;


------------ Creating the Table and storing the above Code output to Add_records table------------

Select * into Add_records from (
Select T.Customer_id,T.order_id,T.product_id,T.Channel,T.Delivered_StoreID,T.Bill_date_timestamp,Sum(T.Net_QTY)as Quantity,T.Cost_Per_Unit,
T.MRP,T.Discount,SUM(Net_amount) as Total_Amount ,C.Category,F.Customer_Satisfaction_Score as Avg_rating,
G.seller_city,G.seller_state,G.Region,E.customer_city,E.customer_state,E.Gender
from (
Select Distinct A.*,(A.Total_Amount/A.Quantity) as Net_amount, (A.Quantity/A.Quantity) as Net_QTY From Orders A
join Orders B
on A.order_id = B.order_id
where A.Delivered_StoreID <> B.Delivered_StoreID 
) as T
Inner Join productsinfo C
on T.product_id = C.product_id
inner join orderpayments as D
on T.order_id = D.order_id
inner Join Customers As E
on T.Customer_id = E.Custid
inner join orderreview_ratings F
on T.order_id = F.order_id
inner join storesinfo G
on T.Delivered_StoreID = G.StoreID
Group by T.Customer_id,T.order_id,T.product_id,T.Channel,T.Bill_date_timestamp,T.Cost_Per_Unit,T.Delivered_StoreID,
T.Discount,T.MRP,T.Total_Amount,T.Quantity,T.Net_amount,T.Net_QTY,C.Category,F.Customer_Satisfaction_Score,
G.seller_city,G.seller_state,G.Region,E.customer_city,E.customer_state,E.Gender) a;




Select * Into Finalised_Records_1 From (
Select * From Finalised_Records_no
except
---------------Checking whether the records in Add_records table are also available with Integratable_Table _1 
(Select A.* From Add_records A
inner Join Integrated_Table_1 B
on A.order_id = B.order_id) 
) x;
----- We found some records thus these needed to be deleted so using the Except function from Finalised Records 
----- And storing the data into new table Finalised_Records_1 
Select * From Finalised_Records_1;

Select * from Add_records;

---- Example for you all how to use the data set if you want the distinct Order and calculation
Select Distinct order_id, Sum(Total_Amount) From Finalised_Records_1
Group by order_id;


--Main Table :

Select * From Finalised_Records_1;
-------------------------------------------------------------------------------------------------------------

-- Need to create customer 360, order 360, store 360 tables for further analysis
alter table Finalised_Records_1 
add Bill_datetime datetime;

update Finalised_Records_1 
set Bill_datetime = CAST(Bill_date_timestamp as datetime);

alter table Finalised_Records_1
drop column Bill_date_timestamp;

delete from Finalised_Records_1 
where order_id in (
    select distinct order_id
    from Finalised_Records_1 
    where Bill_datetime not between '2021-09-01' and '2023-10-31'
);
