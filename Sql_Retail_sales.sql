-- =============================================================================================
-- Project: Retail Sales Analysis
-- Description: A complete script for cleaning, exploring, and analyzing retail sales data.
-- =============================================================================================


-- ---------------------------------------------------------------------------------------------
-- STEP 1: DATABASE AND TABLE SETUP
-- ---------------------------------------------------------------------------------------------

-- Create the database if it doesn't already exist to avoid errors.
CREATE DATABASE IF NOT EXISTS sql_project_p2;

-- Select the database to use for all subsequent commands.
USE sql_project_p2;

-- Drop the table if it already exists to ensure a fresh start.
DROP TABLE IF EXISTS retail_sales;

-- Create the table structure to hold the sales data.
CREATE TABLE retail_sales (
    transaction_id INT PRIMARY KEY,
    sale_date DATE,
    sale_time TIME,
    customer_id INT,
    gender VARCHAR(15),
    age INT,
    category VARCHAR(15),
    quantity INT,
    price_per_unit FLOAT,
    cogs FLOAT,
    total_sale FLOAT
);


-- ---------------------------------------------------------------------------------------------
-- STEP 2: DATA LOADING
-- ---------------------------------------------------------------------------------------------
-- To load your data from the CSV file using MySQL Workbench:
-- 1. Right-click on the `retail_sales` table in the SCHEMAS panel on the left.
-- 2. Select "Table Data Import Wizard".
-- 3. Browse and select your 'SQL - Retail Sales Analysis_utf .csv' file.
-- 4. Follow the steps, ensuring the columns from your CSV match the table columns.
-- 5. Execute the import.
--
-- After importing, you can run the SELECT query below to verify the data is loaded.

SELECT * FROM retail_sales LIMIT 10;


-- ---------------------------------------------------------------------------------------------
-- STEP 3: DATA CLEANING
-- ---------------------------------------------------------------------------------------------

-- Temporarily disable safe update mode
SET SQL_SAFE_UPDATES = 0;

-- Run your original DELETE command
DELETE FROM retail_sales
WHERE 
    transaction_id IS NULL OR
    sale_date IS NULL OR 
    sale_time IS NULL OR
    gender IS NULL OR
    category IS NULL OR
    quantity IS NULL OR
    cogs IS NULL OR
    total_sale IS NULL;

-- Re-enable safe update mode for future safety
SET SQL_SAFE_UPDATES = 1;

-- ---------------------------------------------------------------------------------------------
-- STEP 4: DATA EXPLORATION & ANALYSIS (ORIGINAL 10 QUERIES)
-- ---------------------------------------------------------------------------------------------

-- Q1: Retrieve all columns for sales made on '2022-11-05'.
SELECT *
FROM retail_sales
WHERE sale_date = '2022-11-05';

-- Q2: Retrieve all transactions in 'Clothing' with a quantity of 4 or more in Nov 2022.
-- Note: Replaced TO_CHAR with DATE_FORMAT for MySQL compatibility.
SELECT *
FROM retail_sales
WHERE
    category = 'Clothing'
    AND DATE_FORMAT(sale_date, '%Y-%m') = '2022-11'
    AND quantity >= 4;

-- Q3: Calculate the total sales and total orders for each category.
SELECT
    category,
    SUM(total_sale) AS net_sale,
    COUNT(*) AS total_orders
FROM retail_sales
GROUP BY category;

-- Q4: Find the average age of customers who purchased from the 'Beauty' category.
SELECT
    ROUND(AVG(age), 2) AS avg_age
FROM retail_sales
WHERE category = 'Beauty';

-- Q5: Find all transactions where the total_sale is greater than 1000.
SELECT * FROM retail_sales
WHERE total_sale > 1000;

-- Q6: Find the total number of transactions made by each gender in each category.
SELECT
    category,
    gender,
    COUNT(transaction_id) AS total_transactions
FROM retail_sales
GROUP BY category, gender
ORDER BY category, gender;

-- Q7: Find the month with the highest average sale for each year.
-- Note: EXTRACT() works in MySQL, so no change was needed here.
SELECT
    `year`,
    `month`,
    avg_sale
FROM (
    SELECT
        EXTRACT(YEAR FROM sale_date) AS `year`,
        EXTRACT(MONTH FROM sale_date) AS `month`,
        AVG(total_sale) AS avg_sale,
        RANK() OVER(PARTITION BY EXTRACT(YEAR FROM sale_date) ORDER BY AVG(total_sale) DESC) AS `rank`
    FROM retail_sales
    GROUP BY 1, 2
) AS ranked_sales
WHERE `rank` = 1;

-- Q8: Find the top 5 customers based on the highest total sales.
SELECT
    customer_id,
    SUM(total_sale) AS total_sales
FROM retail_sales
GROUP BY customer_id
ORDER BY total_sales DESC
LIMIT 5;

-- Q9: Find the number of unique customers who purchased from each category.
SELECT
    category,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM retail_sales
GROUP BY category;

-- Q10: Count the number of orders in each shift (Morning, Afternoon, Evening).
SELECT
    shift,
    COUNT(*) AS total_orders
FROM (
    SELECT
        *,
        CASE
            WHEN EXTRACT(HOUR FROM sale_time) < 12 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM sale_time) BETWEEN 12 AND 16 THEN 'Afternoon'
            ELSE 'Evening'
        END AS shift
    FROM retail_sales
) AS sales_with_shift
GROUP BY shift;


-- ---------------------------------------------------------------------------------------------
-- STEP 5: ADVANCED ANALYSIS (3 NEW QUERIES)
-- ---------------------------------------------------------------------------------------------

-- Query 11: Month-over-Month (MoM) Sales Growth
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(sale_date, '%Y-%m-01') AS sales_month,
        SUM(total_sale) AS current_month_sales
    FROM retail_sales
    GROUP BY 1
),
sales_with_lag AS (
    SELECT
        sales_month,
        current_month_sales,
        LAG(current_month_sales, 1, 0) OVER (ORDER BY sales_month) AS previous_month_sales
    FROM monthly_sales
)
SELECT
    DATE_FORMAT(sales_month, '%Y-%m') AS sales_month,
    current_month_sales,
    previous_month_sales,
    (current_month_sales - previous_month_sales) / NULLIF(previous_month_sales, 0) AS month_over_month_growth
FROM sales_with_lag
ORDER BY sales_month;

-- Query 12: Top 3 Selling Categories by Month
WITH monthly_category_sales AS (
    SELECT
        DATE_FORMAT(sale_date, '%Y-%m-01') AS sales_month,
        category,
        SUM(total_sale) AS total_sales
    FROM retail_sales
    GROUP BY 1, 2
),
ranked_category_sales AS (
    SELECT
        sales_month,
        category,
        total_sales,
        RANK() OVER (PARTITION BY sales_month ORDER BY total_sales DESC) AS sales_rank
    FROM monthly_category_sales
)
SELECT
    DATE_FORMAT(sales_month, '%Y-%m') AS sales_month,
    category,
    total_sales,
    sales_rank
FROM ranked_category_sales
WHERE sales_rank <= 3
ORDER BY sales_month, sales_rank;

-- Query 13: Customer Segmentation using RFM (Recency, Frequency, Monetary) Analysis
WITH rfm_base AS (
    SELECT
        customer_id,
        DATEDIFF('2023-01-01', MAX(sale_date)) AS recency,
        COUNT(DISTINCT transaction_id) AS frequency,
        SUM(total_sale) AS monetary
    FROM retail_sales
    GROUP BY customer_id
)
SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    NTILE(4) OVER (ORDER BY recency DESC) AS recency_score, -- 4 = most recent
    NTILE(4) OVER (ORDER BY frequency ASC) AS frequency_score, -- 4 = most frequent
    NTILE(4) OVER (ORDER BY monetary ASC) AS monetary_score -- 4 = highest spender
FROM rfm_base
ORDER BY
    frequency_score DESC,
    monetary_score DESC,
    recency_score DESC;

-- ---------------------------------------------------------------------------------------------
-- STEP 6: DEEPER BUSINESS INSIGHTS
-- ---------------------------------------------------------------------------------------------

-- Query 14: Profitability Analysis by Category
SELECT
    category,
    SUM(total_sale) AS total_revenue,
    SUM(cogs) AS total_cost,
    SUM(total_sale - cogs) AS total_profit,
    (SUM(total_sale - cogs) / SUM(total_sale)) * 100 AS profit_margin_percentage
FROM retail_sales
GROUP BY category
ORDER BY total_profit DESC;


-- Query 15: Customer Purchase Correlation (Simple Basket Analysis)
SELECT
    r1.category AS category_1,
    r2.category AS category_2,
    COUNT(DISTINCT r1.customer_id) AS number_of_customers
FROM
    retail_sales r1
JOIN
    retail_sales r2 ON r1.customer_id = r2.customer_id AND r1.category < r2.category
GROUP BY
    r1.category, r2.category
ORDER BY
    number_of_customers DESC
LIMIT 10;


-- Query 16: Sales Distribution (ABC Analysis)
WITH CategoryRevenue AS (
    SELECT
        category,
        SUM(total_sale) AS revenue
    FROM retail_sales
    GROUP BY category
),
CumulativeRevenue AS (
    SELECT
        category,
        revenue,
        SUM(revenue) OVER (ORDER BY revenue DESC) AS cumulative_revenue,
        (SELECT SUM(revenue) FROM CategoryRevenue) AS total_revenue
    FROM CategoryRevenue
)
SELECT
    category,
    revenue,
    (cumulative_revenue / total_revenue) * 100 AS cumulative_percentage,
    CASE
        WHEN (cumulative_revenue / total_revenue) <= 0.7 THEN 'A' -- Top 70% of revenue
        WHEN (cumulative_revenue / total_revenue) <= 0.9 THEN 'B' -- Next 20% of revenue
        ELSE 'C' -- Bottom 10% of revenue
    END AS abc_segment
FROM CumulativeRevenue
ORDER BY revenue DESC;

-- ---------------------------------------------------------------------------------------------
-- STEP 7: CUSTOMER BEHAVIOR & DEMOGRAPHIC ANALYSIS
-- ---------------------------------------------------------------------------------------------

-- Query 17: Sales Performance by Day of the Week
SELECT
    DATE_FORMAT(sale_date, '%W') AS day_of_week,
    SUM(total_sale) AS total_sales,
    AVG(total_sale) AS average_sale,
    COUNT(transaction_id) AS number_of_transactions
FROM retail_sales
GROUP BY day_of_week
ORDER BY total_sales DESC;

-- Query 18: Customer Cohort Analysis (Retention by First Purchase Month)
WITH CustomerFirstPurchase AS (
    SELECT
        customer_id,
        MIN(DATE_FORMAT(sale_date, '%Y-%m-01')) AS cohort_month
    FROM retail_sales
    GROUP BY customer_id
),
MonthlyActivity AS (
    SELECT
        DISTINCT
        DATE_FORMAT(s.sale_date, '%Y-%m-01') AS activity_month,
        c.customer_id,
        c.cohort_month
    FROM retail_sales s
    JOIN CustomerFirstPurchase c ON s.customer_id = c.customer_id
)
SELECT
    cohort_month,
    activity_month,
    COUNT(DISTINCT customer_id) AS active_customers
FROM MonthlyActivity
GROUP BY cohort_month, activity_month
ORDER BY cohort_month, activity_month;


-- Query 19: Price Point Analysis by Category
SELECT
    category,
    price_per_unit,
    COUNT(transaction_id) AS number_of_sales,
    SUM(quantity) AS total_quantity_sold
FROM retail_sales
GROUP BY category, price_per_unit
ORDER BY category, number_of_sales DESC;


-- Query 20: Sales Analysis by Customer Age Group
SELECT
    age_group,
    SUM(total_sale) AS total_sales,
    COUNT(DISTINCT customer_id) AS unique_customers,
    AVG(total_sale) AS average_spend_per_transaction
FROM (
    SELECT
        *,
        CASE
            WHEN age < 18 THEN 'Under 18'
            WHEN age BETWEEN 18 AND 24 THEN '18-24'
            WHEN age BETWEEN 25 AND 34 THEN '25-34'
            WHEN age BETWEEN 35 AND 44 THEN '35-44'
            WHEN age BETWEEN 45 AND 54 THEN '45-54'
            WHEN age >= 55 THEN '55+'
            ELSE 'Unknown'
        END AS age_group
    FROM retail_sales
) AS sales_with_age_group
GROUP BY age_group
ORDER BY age_group;

-- End of project