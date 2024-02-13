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


-- Calculating the Fequency and monetary
FM_table as 
(
  SELECT 
    main_data.customerid,
    MAX(transaction_date) AS last_purchase_date,
    COUNT(DISTINCT(main_data.unique_transaction_id)) AS frequency,
    ROUND(SUM(main_data.invoice_value),2) AS monetary
  FROM main_data
  GROUP BY 1
),

-- Calculating recency 
R_table AS 
(
  SELECT
    customerid,
    frequency,
    monetary,
    DATE_DIFF(reference_day,last_purchase_date,day) as recency
  FROM 
    (SELECT 
      *,
      MAX(last_purchase_date) OVER() as reference_day
      FROM FM_table
      )
),

-- Calculating the percentiles 

quantiles AS (
  SELECT R_table.*,
  -- All Recency quantiles
    R_percentiles.percentiles[offset(25)] AS r25,
    R_percentiles.percentiles[offset(50)] AS r50,
    R_percentiles.percentiles[offset(75)] AS r75,
    R_percentiles.percentiles[offset(100)] AS r100,
  -- all Frequency Quantiles
    F_percentiles.percentiles[offset(25)] AS f25,
    F_percentiles.percentiles[offset(50)] AS f50,
    F_percentiles.percentiles[offset(75)] AS f75,
    F_percentiles.percentiles[offset(100)] AS f100,
  -- All Monetary Quatiles
    M_percentiles.percentiles[offset(25)] AS m25,
    M_percentiles.percentiles[offset(50)] AS m50,
    M_percentiles.percentiles[offset(75)] AS m75,
    M_percentiles.percentiles[offset(100)] AS m100
  FROM R_table,
  (SELECT approx_quantiles(recency, 100) AS percentiles FROM R_table) as R_percentiles,
  (SELECT approx_quantiles(frequency, 100) AS percentiles FROM R_table) as F_percentiles,
  (SELECT approx_quantiles(monetary, 100) AS percentiles FROM R_table) as M_percentiles
),


-- Assigning the sroces for the quantiles 
scores_assigned AS (
  SELECT
    *,
    CAST(ROUND((f_score + m_score) / 2, 0) AS INT64) as fm_score
  FROM 
    ( SELECT *,
      CASE 
        WHEN monetary <= m25 THEN 1
        WHEN monetary <= m50 AND monetary > m25 THEN 2
        WHEN monetary <= m75 AND monetary > m50 THEN 3
        WHEN monetary <= m100 AND monetary > m75 THEN 4
      END AS m_score,
      CASE 
        WHEN frequency <= f25 THEN 1
        WHEN frequency <= f50 AND frequency > f25 THEN 2
        WHEN frequency <= f75 AND frequency > f50 THEN 3
        WHEN frequency <= f100 AND frequency > f75 THEN 4
      END AS f_score,

      -- Recency scoring is reversed
      CASE 
        WHEN recency <= r25 THEN 4
        WHEN recency <= r50 AND recency > r25 THEN 3
        WHEN recency <= r75 AND recency > r50 THEN 2
        WHEN recency <= r100 AND recency > r75 THEN 1
      END AS r_score, 
      FROM quantiles
    )
),

-- Creating customers segments by assigning the scores 
customers_segments AS(
SELECT 
        customerid,
        CASE WHEN (r_score = 4 AND fm_score = 4) 
          THEN 'Top Customers'
        WHEN (r_score = 4 AND fm_score =3) 
            OR (r_score = 3 AND fm_score = 4)
          THEN 'Loyal Customers'
        WHEN (r_score = 4 AND fm_score = 2) 
            OR (r_score = 4 AND fm_score = 2)
            OR (r_score = 3 AND fm_score = 3)
            OR (r_score = 4 AND fm_score = 3)
          THEN 'Potential Loyalists'
        WHEN (r_score = 4 AND fm_score = 1)
            OR (r_score = 3 AND fm_score = 1)
          THEN 'Recent Customers'
        WHEN (r_score = 3 AND fm_score = 2) 
            OR (r_score = 2 AND fm_score = 3)
            OR (r_score = 2 AND fm_score = 2)
          THEN 'Customers Needing Attention'
        WHEN (r_score = 2 AND fm_score = 5) 
            OR (r_score = 2 AND fm_score = 4)
            OR (r_score = 1 AND fm_score = 3)
          THEN 'At Risk'
        WHEN (r_score = 1 AND fm_score = 4)        
          THEN 'Cant Lose Them'
        WHEN (r_score = 2 AND fm_score = 1) 
            OR (r_score = 1 AND fm_score = 2) 
          THEN 'Hibernating'
        WHEN r_score = 1 AND fm_score = 1 
          THEN 'Lost'
        END AS customer_segment 
    FROM scores_assigned
)

--joining the main data and the customers segments for the futher analysis 

SELECT 
main_data.*,
customers_segments.customer_segment
FROM main_data
JOIN customers_segments
ON main_data.customerid = customers_segments.customerid
