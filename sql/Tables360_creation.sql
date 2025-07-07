-- Need to create customer 360, order 360, store 360 tables for further analysis

-- Customer360 Table
with payment_counts as (
    select customer_id, payment_type, count(*) as payment_count
    from Finalised_Records_1 as F 
    join OrderPayments as P on F.order_id = P.order_id
    group by Customer_id, payment_type
), ranked_payments as (
    select *,
    RANK() OVER(PARTITION BY customer_id ORDER BY payment_count DESC) as rnk
    from payment_counts
), payment_metrics as (
	select F.Customer_Id,
	count(distinct P.payment_type) as Unique_payment_methods,
    sum(case when P.payment_type = 'voucher' then 1 else 0 end) as voucher_payments,
    sum(case when P.payment_type = 'credit_card' then 1 else 0 end) as credit_card_payments,
    sum(case when P.payment_type = 'debit_card' then 1 else 0 end) as debit_card_payments,
    sum(case when P.payment_type = 'UPI/Cash' then 1 else 0 end) as UPI_Cash_payments,
    round(sum(case when P.payment_type = 'voucher' then Total_Amount else 0 end), 0) as voucher_spent,
    round(sum(case when P.payment_type = 'credit_card' then Total_Amount else 0 end), 0) as credit_card_spent,
    round(sum(case when P.payment_type = 'debit_card' then Total_Amount else 0 end), 0) as debit_card_spent,
    round(sum(case when P.payment_type = 'UPI/Cash' then Total_Amount else 0 end), 0) as UPI_spent
    from Finalised_Records_1 as F 
    join OrderPayments as P on F.order_id = P.order_id
    group by F.customer_id
), Final_Customer360 as (
    select 
    F.Customer_id,
    max(customer_city) as Cust_city, 
    max(customer_state) as Cust_State, 
    max(Gender) as Gender,
    min(Bill_datetime) as First_trans_date,
    max(Bill_datetime) as Last_trans_date,
    datediff(day, min(Bill_datetime), max(Bill_datetime)) as Tenure,
    datediff(day, max(Bill_datetime), (select max(Bill_datetime) from Finalised_Records_1)) as Inactive_days,
    count(distinct F.order_id) as Total_Transactions,
    round(sum(Total_Amount), 2) as  Total_Spend,
    sum(Quantity) as Total_Quantity,
    sum(Quantity*Discount) as Total_Discount,
    round(sum(Total_Amount) / count(distinct F.order_id), 2) as Avg_trans_amt,
    avg(Avg_rating*1.0) as Average_rating,
    max(R.payment_type) as Preferred_pay_type,
    round(sum(Total_Amount - (Cost_Per_Unit * Quantity)), 2) as Total_Profit,
    sum(case when Discount > 0 then 1 else 0 end) as Total_Trans_with_Discount,
    count(distinct product_id) as Total_unique_products,
    count(distinct Category) as Total_unique_categories,
    count(distinct F.Channel) as Unique_Channels,
    count(distinct Delivered_StoreID) as Unique_Stores_Purchased,
    count(distinct seller_city) as Unique_city_purchased,
    Max(P.Unique_payment_methods) as Unique_payment_methods,
    Max(P.credit_card_payments) as Credit_card_payments,
    max(P.debit_card_payments) as Debit_card_payments,
    MAX(P.UPI_Cash_payments) as UPI_Cash_payments,
    max(P.voucher_payments) as Voucher_payments,
    max(P.credit_card_spent) as credit_card_spent,
    max(P.debit_card_spent) as debit_card_spent,
    max(P.UPI_spent) as UPI_spent,
    max(P.voucher_spent) as voucher_spent,
    sum(case when datepart(dw, Bill_datetime) in (1, 7) then 1 else 0 end) as Total_Weekend_trans,
    sum(case when datepart(dw, Bill_datetime) in (1, 7) then 0 else 1 end) as Total_Weekday_trans,
    sum(case when (datepart(hour, Bill_datetime) > 0) and (datepart(hour, Bill_datetime) <= 4) then 1 else 0 end) as Total_Early_Morning_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 4) and (datepart(hour, Bill_datetime) <= 8) then 1 else 0 end) as Total_Morning_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 8) and (datepart(hour, Bill_datetime) <= 12) then 1 else 0 end) as Total_Late_Morning_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 12) and (datepart(hour, Bill_datetime) <= 16) then 1 else 0 end) as Total_After_Noon_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 16) and (datepart(hour, Bill_datetime) <= 20) then 1 else 0 end) as Total_Evening_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 20) and (datepart(hour, Bill_datetime) <= 24) then 1 else 0 end) as Total_Night_Trans
    from Finalised_Records_1 as F 
    join ranked_payments as R on F.Customer_id = R.Customer_id
    join payment_metrics as P on F.Customer_id = P.Customer_id
    where R.rnk = 1
    group by F.Customer_id
) 
select * into Customer360 from Final_Customer360;


select * from Customers360;


select distinct payment_type from OrderPayments; 
select distinct Category from ProductsInfo;

update ProductsInfo
set Category = 'Others'
where Category = '#N/A';

update Finalised_Records_1
set Category = 'Others'
where Category = '#N/A';




-- Orders360 table
with A as (
    select 
    order_id,
    count(distinct F.product_id) as Unique_Products,
    sum(Quantity) as Total_Qty,
    count(distinct Category) as Total_categories,
    sum(Total_Amount) as Total_amount,
    sum(Quantity*Discount) as Total_discount,
    sum(Cost_Per_Unit * Quantity) as Total_Cost,
    round(sum(Total_Amount - (Cost_Per_Unit * Quantity)), 2) as Total_Profit,
    max(Bill_datetime) as Order_datetime,
    sum(case when datepart(dw, Bill_datetime) in (1, 7) then 1 else 0 end) as Weekend_trans,
    avg(Total_Amount) as Avg_Order_value,
    case when sum(Total_Amount) > (select avg(Total_Amount) from Finalised_Records_1) then 1 else 0 end as Flag_High_value_order,
    avg(Avg_rating) as Avg_order_rating,
    round(avg(Total_Amount - (Cost_Per_Unit * Quantity)), 2) as Avg_Profit,
    avg(Discount) as Avg_Discount,
    max(case 
        when (datepart(hour, Bill_datetime) <= 4) then 'Early Morning'
        when (datepart(hour, Bill_datetime) <= 8) then 'Morning'
        when (datepart(hour, Bill_datetime) <= 12) then 'Late Morning'
        when (datepart(hour, Bill_datetime) <= 16) then 'Afternoon'
        when (datepart(hour, Bill_datetime) <= 20) then 'Evening'
        when (datepart(hour, Bill_datetime) <= 24) then 'Night'
    end) as Time_of_Day
    from Finalised_Records_1 as F 
    group by order_id
) 
select * into Orders360 from A;


select * from Orders360;

drop table Stores360;
drop table Customers360;
drop table Orders360;

-- Store360 Table
with payment_metrics as (
	select F.Delivered_StoreID,
    sum(case when P.payment_type = 'voucher' then 1 else 0 end) as voucher_payments,
    sum(case when P.payment_type = 'credit_card' then 1 else 0 end) as credit_card_payments,
    sum(case when P.payment_type = 'debit_card' then 1 else 0 end) as debit_card_payments,
    sum(case when P.payment_type = 'UPI/Cash' then 1 else 0 end) as UPI_Cash_payments,
    round(sum(case when P.payment_type = 'voucher' then Total_Amount else 0 end), 0) as voucher_payment_amount,
    round(sum(case when P.payment_type = 'credit_card' then Total_Amount else 0 end), 0) as credit_card_payment_amount,
    round(sum(case when P.payment_type = 'debit_card' then Total_Amount else 0 end), 0) as debit_card_payment_amount,
    round(sum(case when P.payment_type = 'UPI/Cash' then Total_Amount else 0 end), 0) as UPI_payment_amount
    from Finalised_Records_1 as F 
    join OrderPayments as P on F.order_id = P.order_id
    group by F.Delivered_StoreID
), Final_Store360 as (
    select 
    F.Delivered_StoreID, 
    max(seller_city) as Store_city, 
    max(seller_state) as Store_state,
    count(distinct product_id) as Number_of_unique_products,
    sum(Quantity) as Total_Qty,
    round(sum(Total_Amount), 0) as Total_Revenue,
    sum(Discount) as Total_Discount,
    round(sum(Cost_Per_Unit*Quantity), 0) as Total_cost,
    round(sum(Total_Amount - (Cost_Per_Unit*Quantity)), 0) as Total_Profit,
    count(order_id) as Total_Transactions,
    sum(case when Total_Amount - (Cost_Per_Unit*Quantity) < 0 then 1 else 0 end) as Loss_making_trans_count,
    round(avg(Avg_rating*1.0), 2) as average_rating,
    count(distinct Category) as Dist_categories,
    sum(case when Discount > 0 then 1 else 0 end) as Products_with_discount,
    sum(case when datepart(dw, Bill_datetime) in (1, 7) then 1 else 0 end) as Total_Weekend_trans,
    sum(case when datepart(dw, Bill_datetime) in (1, 7) then 0 else 1 end) as Total_Weekday_trans,
    sum(case when (datepart(hour, Bill_datetime) > 0) and (datepart(hour, Bill_datetime) <= 4) then 1 else 0 end) as Total_Early_Morning_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 4) and (datepart(hour, Bill_datetime) <= 8) then 1 else 0 end) as Total_Morning_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 8) and (datepart(hour, Bill_datetime) <= 12) then 1 else 0 end) as Total_Late_Morning_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 12) and (datepart(hour, Bill_datetime) <= 16) then 1 else 0 end) as Total_After_Noon_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 16) and (datepart(hour, Bill_datetime) <= 20) then 1 else 0 end) as Total_Evening_Trans,
    sum(case when (datepart(hour, Bill_datetime) > 20) and (datepart(hour, Bill_datetime) <= 24) then 1 else 0 end) as Total_Night_Trans,
    round(sum(case when (datepart(hour, Bill_datetime) > 0) and (datepart(hour, Bill_datetime) <= 4) then Total_Amount else 0 end), 0) as Total_Early_Morning_Revenue,
    round(sum(case when (datepart(hour, Bill_datetime) > 4) and (datepart(hour, Bill_datetime) <= 8) then Total_Amount else 0 end), 0) as Total_Morning_Revenue,
    round(sum(case when (datepart(hour, Bill_datetime) > 8) and (datepart(hour, Bill_datetime) <= 12) then Total_Amount else 0 end), 0) as Total_Late_Morning_Revenue,
    round(sum(case when (datepart(hour, Bill_datetime) > 12) and (datepart(hour, Bill_datetime) <= 16) then Total_Amount else 0 end), 0) as Total_After_Noon_Revenue,
    round(sum(case when (datepart(hour, Bill_datetime) > 16) and (datepart(hour, Bill_datetime) <= 20) then Total_Amount else 0 end), 0) as Total_Evening_Revenue,
    round(sum(case when (datepart(hour, Bill_datetime) > 20) and (datepart(hour, Bill_datetime) <= 24) then Total_Amount else 0 end), 0) as Total_Night_Revenue,
    round(avg(Total_Amount), 2) as Avg_Order_value,
    round(avg(Total_Amount - (Cost_Per_Unit*Quantity)), 2) as Avg_profit,
    count(Customer_id) as Customer_visits,
    sum(case when Channel = 'Instore' then 1 else 0 end) as Total_Instore_Trans,
    sum(case when Channel = 'Online' then 1 else 0 end) as Total_Online_Trans,
    sum(case when Channel = 'Phone Delivery' then 1 else 0 end) as Total_PhoneDelivery_Trans,
    round(sum(case when Channel = 'Online' then Total_Amount else 0 end), 0) as Online_Revenue,
    round(sum(case when Channel = 'Instore' then Total_Amount else 0 end), 0) as Instore_Revenue,
    round(sum(case when Channel = 'Phone Delivery' then Total_Amount else 0 end), 0) as PhoneDelivery_Revenue,
    max(P.credit_card_payments) as Credit_card_payments,
    max(P.debit_card_payments) as Debit_card_payments,
    max(P.UPI_Cash_payments) as UPI_Cash_payments,
    max(P.voucher_payments) as Voucher_payments,
    max(P.credit_card_payment_amount) as credit_card_payment_amount,
    max(P.debit_card_payment_amount) as debit_card_payment_amount,
    max(P.UPI_payment_amount) as UPI_payment_amount,
    max(P.voucher_payment_amount) as voucher_payment_amount
    from Finalised_Records_1 as F
    join payment_metrics as P on F.Delivered_StoreID = P.Delivered_StoreID
    group by F.Delivered_StoreID
) select * into Stores360 from Final_Store360;


select * from Stores360;