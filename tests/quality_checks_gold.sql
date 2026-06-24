/*
==============================================================================
Quality Checks
==============================================================================
Scipt Purpose:
    This script performs quality checks to validate the integrity, consitency,
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimensional tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Investigate and resolve any discrepancies found during the checks.
==============================================================================
*/

-- ==============================================================
-- Quality Check for Dimension Customer Gold Table
-- ==============================================================

-- Checking if any duplicates introduced or not
SELECT cst_id, COUNT(*)
FROM (
    SELECT 
        ci.cst_id,
        ci.cst_key,
        ci.cst_firstname,
        ci.cst_lastname,
        ci.cst_marital_status,
        ci.cst_gndr,
        ci.cst_create_date,
        ca.bdate,
        ca.gen
    FROM silver.crm_cust_info ci
    LEFT OUTER JOIN silver.erp_cust_az12 ca  
    ON ci.cst_key = ca.cid
    LEFT OUTER JOIN silver.erp_loc_a101 la
    ON ci.cst_key = la.cid) t  
GROUP BY cst_id
HAVING COUNT(*) > 1;

-- Finding Contrast Rows
SELECT DISTINCT 
    ci.cst_gndr, 
    ca.gen
FROM silver.crm_cust_info ci
LEFT OUTER JOIN silver.erp_cust_az12 ca  
ON ci.cst_key = ca.cid
LEFT OUTER JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

SELECT DISTINCT gender 
FROM gold.dim_customers;

-- ==============================================================
-- Quality Check for Dimension Product Gold Table
-- ==============================================================

-- Checking if any duplicates introduced or not
SELECT prd_id, COUNT(*)
FROM(
SELECT 
    pn.prd_id,
    pn.cat_id,
    pn.prd_key,
    pn.prd_nm,
    pn.prd_cost,
    pn.prd_line,
    pn.prd_start_dt,
    pc.cat,
    pc.subcat,
    pc.maintenance
FROM silver.crm_prd_info pn
JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
-- Filtering out the Historical Record
WHERE prd_end_dt IS NULL) t  
GROUP BY prd_id
HAVING COUNT(*) > 1;

-- ==============================================================
-- Quality Check for Fact Sales Gold Table
-- ==============================================================

-- Fact Checking: Check if all dimension tables can successfully join to the fact table 
SELECT 
    *
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr  
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu 
ON sd.sls_cust_id = cu.customer_id
WHERE pr.product_key IS NULL;

SELECT 
    *
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr  
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu 
ON sd.sls_cust_id = cu.customer_id
WHERE cu.customer_key IS NULL;
