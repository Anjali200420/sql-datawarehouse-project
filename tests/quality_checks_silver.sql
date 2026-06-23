/*
=====================================================================================
Quality Checks
====================================================================================
Script Purpose:
  This script performs various quality checks for data consistency, accuracy, and
  standarization across the 'silver' layer. It includes checks for:
  - Null or duplicate primary keys.
  - Unwanted spaces in string fields.
  - Data Standarization and cosistency.
  - Invalid date ranges and orders.
  - Data consistency between related fields.

Usage Notes:
  - Run these after data loading Silver Layer.
  - Investigate and resolve any discrepancies found during the checks.
====================================================================================
*/
-- ====================================================================================
-- Quality Check for silver.crm_cust_info
-- ====================================================================================

-- Checking for Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    cst_id,
    COUNT(*) AS TotalCount
FROM silver.crm_cust_info
GROUP BY cst_id  
HAVING COUNT(*) > 1 or cst_id IS NULL;

-- Checking for unwanted space
-- Expectation: No Results
SELECT 
    cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname <> TRIM(cst_firstname);

SELECT 
    cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname <> TRIM(cst_lastname);

SELECT 
    cst_key
FROM silver.crm_cust_info
WHERE cst_key <> TRIM(cst_key);

SELECT 
    cst_marital_status
FROM silver.crm_cust_info
WHERE cst_marital_status <> TRIM(cst_marital_status);

SELECT 
    cst_gndr
FROM silver.crm_cust_info
WHERE cst_gndr <> TRIM(cst_gndr);

-- Data Standarization & Consistency
SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;

SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;

-- ====================================================================================
-- Quality Check for crm_prd_info Table
-- ====================================================================================

-- Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    prd_id,
    COUNT(*) AS TotalCount
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 or prd_id IS NULL;

-- Checking Unwanted Space
-- Expectation: No Results
SELECT 
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm <> TRIM(prd_nm);

-- Checking for NULL and Negative Numbers
-- Expectation: No Results
SELECT 
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data Standardization & Consistency
SELECT 
    DISTINCT prd_line
FROM silver.crm_prd_info;

-- Invalid Date Orders (Start Date > End Date)
-- Expectation: No Results
SELECT 
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ====================================================================================
-- Quality Check for crm_sales_details Table
-- ====================================================================================
 
-- Handling Invalid Value
-- Expectation: No Results
SELECT 
    sls_prd_key
FROM silver.crm_sales_details
WHERE sls_prd_key NOT IN(
    SELECT 
        prd_key
    FROM silver.crm_prd_info
)

SELECT 
    sls_cust_id
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN(
    SELECT 
        cst_id
    FROM silver.crm_cust_info
)

-- Handling Unwanted Spaces
-- Expectation: No Results
SELECT 
    sls_ord_num,
    sls_prd_key
FROM bronze.crm_sales_details
WHERE (sls_ord_num <> TRIM(sls_ord_num) OR (sls_prd_key <> TRIM(sls_prd_key)));

-- Handling Invalid Date Orders
-- Expectation: No Invalid Dates
SELECT 
    NULLIF(sls_order_dt, 0) AS sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 OR sls_order_dt > 20500101 OR sls_order_dt < 19000101;

SELECT 
    sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt < 0 OR sls_ship_dt IS NULL

SELECT 
    sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt < 0 OR sls_due_dt IS NULL

-- Check for Invalid Date Orders (Order Date > Shipping/Due Dates)
-- Expectation: No Results
SELECT 
    *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_due_dt OR sls_order_dt > sls_ship_dt;

-- Business Rules: Checking Data Consistency
-- Expectation: No Results
SELECT 
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE (sls_sales < 0 OR sls_sales IS NULL) OR (sls_quantity < 0 OR sls_quantity IS NULL) OR (sls_price < 0 OR sls_price IS NULL) OR (sls_sales <> (sls_quantity*sls_price))
ORDER BY sls_price, sls_sales, sls_quantity;

SELECT * FROM silver.crm_sales_details
ORDER BY sls_sales;

-- ====================================================================================
-- Quality Check for erp_cust_az12
-- ====================================================================================

-- Handling Invalid Values
-- Checking FK in PK
-- Expectation: No Results
SELECT 
    CASE 
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid
    END cid
FROM silver.erp_cust_az12
WHERE CASE 
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid
    END NOT IN (
    SELECT DISTINCT cst_key
    FROM silver.crm_cust_info )

-- Checking out-of-range Dates
-- Expectation: Birthdates between 1924-01-01 and Today
SELECT bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

-- Data Standardization & Consistency
SELECT DISTINCT gen
FROM silver.erp_cust_az12;

-- ====================================================================================
-- Quality check for erp_loc_a101 Silver Table
-- ====================================================================================

-- Handling Invalid Values
SELECT 
    cid
FROM bronze.erp_loc_a101;

-- FK in PK Table
-- Expectation: No Results
SELECT 
    REPLACE(cid, '-', '') AS cid
FROM bronze.erp_loc_a101
WHERE REPLACE(cid, '-', '') NOT IN (
    SELECT DISTINCT cst_key FROM bronze.crm_cust_info
)

-- Data Standardization & Consistency
SELECT DISTINCT cntry FROM silver.erp_loc_a101;

-- ====================================================================================
-- Quality Check in erp_px_cat_g1v2 Silver Table
-- ====================================================================================

-- FK in PK Table
SELECT id FROM bronze.erp_px_cat_g1v2
WHERE id NOT IN (
    SELECT DISTINCT cat_id FROM silver.crm_prd_info
)

-- Unwanted Spaces
-- Expectation: No Results
SELECT 
    *
FROM silver.erp_px_cat_g1v2
WHERE cat <> TRIM(cat) OR subcat <> TRIM(subcat) OR maintenance <> TRIM(maintenance);

-- Data Standardization and Consistency
SELECT DISTINCT maintenance FROM silver.erp_px_cat_g1v2;
