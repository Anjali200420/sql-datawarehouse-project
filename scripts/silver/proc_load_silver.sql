/*
================================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
================================================================================
Script Purpose:
  This stored procedure performs the ETL (Extract, Transform, Load) process to
  populate the 'silver' schema tables from the 'bronze' schema.
Actions Performed:
  - Truncated Silver Tables.
  - Inserts transformed and cleansed data from Bronze into Silver Table

Parameters:
  None. 
  This stored procedure does not accept any parameters or return any value.

Usage Example:
  EXEC silver.load_silver;
================================================================================
*/
-- Creating the Stored Procedure
CREATE OR ALTER PROCEDURE silver.load_silver AS 
BEGIN
    DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME
    DECLARE @start_time DATETIME, @end_time DATETIME

    BEGIN TRY
            SET @batch_start_time = GETDATE()

            PRINT '=========================================================';
            PRINT 'Loading Silver Layer';
            PRINT '=========================================================';

            PRINT '---------------------------------------------------------';
            PRINT 'Loading CRM Tables';
            PRINT '---------------------------------------------------------';

        -- crm_cust_info Silver Table
        SET @start_time = GETDATE();
        PRINT 'Truncating Table : crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT 'Inserting Data Into : crm_cust_info table';
        INSERT INTO silver.crm_cust_info (
            cst_id, 
            cst_key, 
            cst_firstname, 
            cst_lastname, 
            cst_marital_status, 
            cst_gndr, 
            cst_create_date)

        SELECT
            cst_id, 
            cst_key,
            -- Transformation: Removing Unwanted Space
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,
            -- Transformation: Data Normalization & Consistency
            CASE 
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                -- Transformation: Handling Missing Data
                ELSE 'n/a' 
            END cst_marital_status,
            CASE 
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                ELSE 'n/a'
            END cst_gndr,
            cst_create_date
        FROM
            -- Transformation: Revoming the Duplicates
            (SELECT 
                *,
                ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag
            FROM bronze.crm_cust_info
            ) t 
            WHERE t.flag = 1 AND t.cst_id IS NOT NULL;
        SET @end_time = GETDATE();
        PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------'


        -- crm_prd_info Silver Table
        SET @start_time = GETDATE();
        PRINT 'Truncating Table : crm_prd_info ';
        TRUNCATE TABLE silver.crm_prd_info ;

        PRINT 'Inserting Data Into : crm_prd_info  table';
        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT 
            prd_id,
            -- Transformation: Derived Columns
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
            prd_nm,
            -- Transformation: Handling NULL Values
            ISNULL(prd_cost, 0) AS prd_cost,
            -- Transformation: Data Standardization & Consistency
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                -- Transformation: Handling Missing Data
                ELSE 'n/a'
            END prd_line,
            -- Transformation: Data Type Casting
            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            -- Transformation: Data Enrichment
            CAST(
                LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) - 1
            AS DATE 
            ) AS prd_end_dt
        FROM bronze.crm_prd_info;
        SET @end_time = GETDATE();
        PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------'

        -- crm_sales_details Silver Table
        SET @start_time = GETDATE();
        PRINT 'Truncating Table : crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT 'Inserting Data Into : crm_csales_details table';

        INSERT INTO silver.crm_sales_details(
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT 
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            -- Transformations: Casting Integer to Date
            CASE 
                -- Transformations: Handling Invalid Date
                WHEN (sls_order_dt = 0 OR LEN(sls_order_dt) != 8) THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) 
            END AS sls_order_dt,
            CASE 
                WHEN (sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8) THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) 
            END AS sls_ship_dt,
            CASE 
                WHEN (sls_due_dt = 0 OR LEN(sls_due_dt) != 8) THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) 
            END AS sls_due_dt,
            -- Tranformations: Business Rules
            CASE 
                WHEN (sls_sales IS NULL OR sls_sales <= 0 OR sls_sales <> (ABS(sls_price)*sls_quantity)) 
                THEN ABS(sls_price)*sls_quantity
                ELSE sls_price
            END AS sls_price,
            sls_quantity,
            CASE 
                WHEN (sls_price IS NULL OR sls_price <= 0) 
                THEN (sls_sales/NULLIF(sls_quantity, 0))
                ELSE sls_price
            END AS sls_quantity
        FROM bronze.crm_sales_details
        SET @end_time = GETDATE();
        PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------'

        PRINT '---------------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '---------------------------------------------------------';

        -- erp_cust_az12 Silver Table
        SET @start_time = GETDATE();
        PRINT 'Truncating Table : erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT 'Inserting Data Into : erp_cust_az12 table';
        INSERT INTO silver.erp_cust_az12(
            cid,
            bdate,
            gen
        )
        SELECT 
            -- Transformations: Handling Invalid Values
            CASE 
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid 
            END AS cid,
            -- Transfromations: Handling Invalid Dates
            CASE 
                WHEN bdate > GETDATE() THEN NULL 
                ELSE bdate 
            END AS bdate,
            -- Transformations: Data Standardization and Consistency
            CASE 
                WHEN gen LIKE 'M%' THEN 'Male'
                WHEN gen LIKE 'F%' THEN 'Female'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;
        SET @end_time = GETDATE();
        PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------'

        -- erp_loc_a101 Silver Table
        SET @start_time = GETDATE();
        PRINT 'Truncating Table : erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT 'Inserting Data Into : erp_loc_a101 table';
        INSERT INTO silver.erp_loc_a101 (
            cid, 
            cntry
        )
        SELECT 
            REPLACE(cid, '-', '') AS cid, 
            CASE 
                WHEN cntry LIKE 'US%' OR cntry LIKE 'United States%' THEN 'United States'
                WHEN cntry LIKE 'United Kingdom%' THEN 'United Kingdom' 
                WHEN cntry LIKE 'DE%' OR cntry LIKE 'Germany%' THEN 'Germany'
                WHEN cntry LIKE 'France%' THEN 'France'
                WHEN cntry LIKE 'Canada%' THEN 'Canada'
                WHEN cntry LIKE 'Australia%' THEN 'Australia'
                ELSE 'n/a'
            END AS cntry
        FROM bronze.erp_loc_a101;
        SET @end_time = GETDATE();
        PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------'


        -- erp_px_cat_g1v2 Silver Table
        SET @start_time = GETDATE();
        PRINT 'Truncating Table : erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2 ;

        PRINT 'Inserting Data Into : erp_px_cat_g1v2 table';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat, 
            subcat,
            maintenance
        )
        SELECT 
            id,
            cat,
            subcat,
            -- Transfromations: Data Standardization & Consistency
            CASE 
                WHEN maintenance LIKE 'Yes%' THEN 'Yes'
                WHEN maintenance LIKE 'No%' THEN 'No'
                ELSE 'n/a'
            END AS maintenance
        FROM bronze.erp_px_cat_g1v2; 
        SET @end_time = GETDATE();
        PRINT 'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------'

        SET @batch_end_time = GETDATE();
        PRINT '=========================================================';
        PRINT 'Loading Silver Layer is Completed';
        PRINT ' - Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '=========================================================';
    END TRY
    BEGIN CATCH
        PRINT '=========================================================';
        PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() as NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() as NVARCHAR);
        PRINT '=========================================================';
    END CATCH
END;

-- EXEC silver.load_silver;
