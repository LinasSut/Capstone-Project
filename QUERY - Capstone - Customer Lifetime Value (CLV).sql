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
    DATE_TRUNC(MIN(Transaction_date),MONTH) AS start_month
  FROM main_data
  GROUP BY 1
),

-- Creating customers transaction month 
transactions AS
(
  SELECT
    customerid,
    gender,
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
    transactions.gender,
    transactions.invoice_value,
    transactions.transaction_month
  FROM cohorts
  LEFT JOIN transactions
    ON cohorts.unique_customers = transactions.customerid

)

-- Main query in which calculating each month customers average order value by inital cohorts size 

SELECT 
  joined_data.start_month AS cohorts_month,
  COUNT(Distinct joined_data.unique_customers) as nr_of_customers,
  SUM(CASE WHEN joined_data.transaction_month = joined_data.start_month THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) as month_0,
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 1 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) as month1,
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 2 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_2,
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 3 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_3,  
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 4 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_4,  
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 5 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_5,  
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 6 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_6,  
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 7 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_7,  
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 8 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_8,  
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 9 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_9,  
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 10 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_10,  
  SUM(CASE WHEN joined_data.transaction_month = DATE_ADD (joined_data.start_month, INTERVAL 11 MONTH) THEN joined_data.invoice_value END) / COUNT(DISTINCT unique_customers) AS month_11
FROM joined_data
/*WHERE gender = "M" */ -- With the added filter it can be filter by all customers cohorts (By Commenting the filter) and using the filter to select AOV by different genders 
GROUP BY 1
ORDER BY 1