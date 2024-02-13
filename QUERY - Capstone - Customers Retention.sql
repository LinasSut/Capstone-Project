-- Creating the first CTE with main data which is going to be used for the futher analysis

WITH main_data as 
(
  SELECT 
    sales.*,
    CONCAT(sales.CustomerID, '-', Transaction_ID) as unique_transaction_id,
    CASE
      WHEN Coupon_Status != 'Used' OR Coupon_code IS NULL 
        THEN ROUND((((Quantity * Avg_Price)*(1+tax.GST)) + Delivery_Charges),2)
        ELSE ROUND((((Quantity * Avg_Price)*(1-(Discount_pct/100))*(1+tax.GST)) + Delivery_Charges),2)
    END as invoice_value,
    discounts.coupon_code,
    tax.gst,
    customers.gender,
    customers.location
  FROM `Capstone_Project.online_sales` as sales
  LEFT JOIN `Capstone_Project.tax_amount` as tax
    ON sales.Product_Category = tax.Product_Category
  LEFT JOIN `Capstone_Project.discount_coupon` as discounts
    ON FORMAT_DATE('%b', Transaction_Date) = discounts.Month AND sales.Product_Category = discounts.Product_Category
  JOIN `Capstone_Project.customers_data`AS customers
    ON sales.CustomerID = customers.CustomerID
),
  
-- Creating customers starting monthly cohorts using their first transaction month
cohorts AS 
(
  SELECT 
    DISTINCT(Customerid) AS unique_customers,
    main_data.gender AS gender,
    DATE_TRUNC(MIN(Transaction_date),MONTH) AS start_month,
    
  FROM main_data
  GROUP BY unique_customers, gender
),

-- Creating customers transaction month 
transactions AS
(
  SELECT
    customerid,
    main_data.gender AS gender,
    invoice_value,
    DATE_TRUNC(Transaction_date,MONTH) AS transaction_month
  FROM main_data
  ORDER BY customerid
),

-- Joining the two CTE togerther for futher calculation 
joined_data AS 
(
  SELECT 
    cohorts.unique_customers,
    cohorts.start_month,
    transactions.invoice_value,
    transactions.transaction_month,
    transactions.gender
  FROM cohorts
  LEFT JOIN transactions
    ON cohorts.unique_customers = transactions.customerid

)

-- Main query in which calculating each month customers gender to gain information about the retention in futher cohorts
SELECT 
  joined_data.start_month AS cohorts_month,
  joined_data.gender AS gender,
  COUNT( DISTINCT joined_data.unique_customers) as number_of_customers,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = joined_data.start_month THEN  unique_customers END)) as month_0,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 1 MONTH) THEN  unique_customers END)) as month1,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 2 MONTH) THEN  unique_customers END)) as month2,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 3 MONTH) THEN  unique_customers END)) as month3,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 4 MONTH) THEN  unique_customers END)) as month4,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 5 MONTH) THEN  unique_customers END)) as month5,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 6 MONTH) THEN  unique_customers END)) as month6,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 7 MONTH) THEN  unique_customers END)) as month7,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 8 MONTH) THEN  unique_customers END)) as month8,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 9 MONTH) THEN  unique_customers END)) as month9,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 10 MONTH) THEN  unique_customers END)) as month10,
  COUNT (DISTINCT (CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 11 MONTH) THEN  unique_customers END)) as month11,
FROM joined_data
GROUP BY cohorts_month, gender
ORDER BY cohorts_month