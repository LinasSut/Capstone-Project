-- Creating the first CTE with main data which is going to be used for the futher analysis

WITH main_data AS (
  SELECT 
    sales.*,
    CONCAT(sales.CustomerID, '-', Transaction_ID) AS unique_transaction_id,
    CASE
      WHEN Coupon_Status != 'Used' OR Coupon_code IS NULL 
        THEN ROUND((((Quantity * Avg_Price)*(1+tax.GST)) + Delivery_Charges),2)
        ELSE ROUND((((Quantity * Avg_Price)*(1-(Discount_pct/100))*(1+tax.GST)) + Delivery_Charges),2)
    END AS invoice_value,
    discounts.coupon_code,
    tax.gst,
    customers.gender,
    customers.location
  FROM `Capstone_Project.online_sales` AS sales
  LEFT JOIN `Capstone_Project.tax_amount` AS tax
    ON sales.Product_Category = tax.Product_Category
  LEFT JOIN `Capstone_Project.discount_coupon` AS discounts
    ON FORMAT_DATE('%b', Transaction_Date) = discounts.Month AND sales.Product_Category = discounts.Product_Category
  JOIN `Capstone_Project.customers_data` AS customers
    ON sales.CustomerID = customers.CustomerID
),

-- Assining row number for each of the product on unique transaction per product for most valuable product by their unit price (avg_price)

Product_ranking AS (
  SELECT 
    customerid,
    unique_transaction_id,
    product_SKU,
    product_description,
    avg_price,
    ROW_NUMBER() OVER (PARTITION BY unique_transaction_id ORDER BY avg_price, product_SKU, product_description) AS product_ranks
  FROM main_data
),

-- Checking the assigned row number for each transaction, and returning the product names to get 2 nad 3 layer of products

products AS (
  SELECT 
    Customerid, 
    Product_ranking.unique_transaction_id,
    MAX(CASE WHEN product_ranks = 1 THEN product_description ELSE NULL END) AS Product1,
    MAX(CASE WHEN product_ranks = 2 THEN product_description ELSE NULL END) AS Product2,
    MAX(CASE WHEN product_ranks = 3 THEN product_description ELSE NULL END) AS Product3
  FROM Product_ranking
  GROUP BY 1,2
),

-- Concatinating the product to get the variations of the basket by checking if the product contains names and assigning different layers 

Market_basket as (
  SELECT
  CONCAT( IFNULL(Product1, ''), IFNULL(CONCAT(' -> ', Product2), ''), IFNULL(CONCAT(' -> ', Product3), '')) AS Market_basket_name,
  CASE
    WHEN Product3 IS NOT NULL THEN '3 Product Combination'
    WHEN Product2 IS NOT NULL THEN '2 Product Combination'
    ELSE '1 Product'
  END AS product_combinations,
  COUNT(*) AS Occurrence
FROM products
GROUP BY 1,2
ORDER BY Occurrence DESC
)

-- Filtering only Layer 2 and Layer 3 for the market basket analysis 

SELECT * 
FROM Market_basket
WHERE product_combinations IN( '3 Product Combination', '2 Product Combination') 
