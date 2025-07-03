











CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	------------------------- Clean and Load crm_cust_info --------------------------------
	---------------------------------------------------------------------------------------
	DECLARE @start_time DATETIME, @end_time DATETIME,@start_silver_time DATETIME, @end_silver_time DATETIME;
	BEGIN TRY
		SET @start_silver_time = GETDATE();
		PRINT '=======================================================';
		PRINT 'Loading Silver Layer';
		PRINT '=======================================================';

		PRINT '-------------------------------------------------------';
		PRINT 'Loading CRM Tables'
		PRINT '-------------------------------------------------------';
		 -- CRM TABLES

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;

		PRINT '>> Inserting Data Into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info(
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
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,

			CASE 
				WHEN UPPER(cst_material_status) = 'S' THEN 'Single'
				WHEN UPPER(cst_material_status) = 'M' THEN 'Married'
				ELSE 'n/a'
			END AS cst_material_status, -- Normalize marital status

			CASE 
				WHEN UPPER(cst_gndr) = 'F' THEN 'Female'
				WHEN UPPER(cst_gndr) = 'M' THEN 'Male'
				ELSE 'n/a'
			END AS cst_gndr, -- Normalize gender values to readable format
			cst_create_Date

		FROM (
			SELECT
			* ,
			row_number() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
			) t 
		WHERE flag_last = 1; -- Select the most recent record per customer
		
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ----------'


		------------------------- Clean and Load crm_prd_info ---------------------------------
		---------------------------------------------------------------------------------------
		
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;

		PRINT '>> Inserting Data Into: silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info(
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
			REPLACE(SUBSTRING(prd_key,1,5), '-','_') AS cat_id, -- Extracts a specific part of a string value and replace - with _
			SUBSTRING(prd_key,7, LEN(prd_key)) AS prd_key,
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost,
			CASE 
				WHEN UPPER(prd_line) = 'M' THEN 'Mountain'
				WHEN UPPER(prd_line) = 'R' THEN 'Road'
				WHEN UPPER(prd_line) = 'S' THEN 'Other Sales'
				WHEN UPPER(prd_line) = 'T' THEN 'Touring'
				ELSE 'n/a'
			END AS prd_line, --  Data normalization, map product line to descriptive values
			CAST(prd_start_dt AS DATE) AS prd_start_dt,
			CAST (LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt -- Calculate end date as one day before the next start date
		FROM bronze.crm_prd_info;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ----------'

		------------------------- Clean and Load crm_sales_details ---------------------------------
		--------------------------------------------------------------------------------------------
		
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;

		PRINT '>> Inserting Data Into: silver.crm_sales_details';
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
			CASE 
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8  THEN NULL -- Handling invalid data
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END AS sls_order_dt,
			CASE 
				WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8  THEN NULL
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,
			CASE 
				WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8  THEN NULL
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,
			CASE 
				WHEN sls_sales IS NULL OR sls_sales <= 0  OR sls_sales != sls_quantity * sls_price THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales, -- Recalculate sales if original value is missing or incorrect
			sls_quantity,
			CASE
				WHEN sls_price IS NULL OR sls_price = 0 THEN sls_sales / NULLIF(sls_quantity,0)
				WHEN sls_price < 0 THEN ABS(sls_price)
				ELSE sls_price -- Derive price if original value is invalid
			END AS sls_price 
		FROM bronze.crm_sales_details;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ----------'

		------------------------- Clean and Load erp_cust_az12 ---------------------------------
		--------------------------------------------------------------------------------------------
		
		
		PRINT '-------------------------------------------------------';
		PRINT 'Loading ERP Tables'
		PRINT '-------------------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;

		PRINT '>> Inserting Data Into: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12(
			cid,
			bdate,
			gen
		)
		SELECT
			CASE 
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid)) -- Remove 'NAS' prefix if persent
				ELSE cid
			END AS cid,
			CASE
				WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
			END AS bdate, -- Set future birthdates to NULL
			CASE
				WHEN gen = 'F' THEN 'Female'
				WHEN gen = 'M' THEN 'Male'
				WHEN gen = '' OR gen IS NULL THEN 'n/a'
				ELSE gen
			END AS gen -- Normalize gender values and handle unknown cases
		FROM bronze.erp_cust_az12;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ----------'

		------------------------- Clean and Load erp_loc_a101 ---------------------------------
		--------------------------------------------------------------------------------------------
		
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;

		PRINT '>> Inserting Data Into: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101(
			cid,
			cntry
		)
		SELECT
			REPLACE(cid, '-','') cid,
			CASE 
				WHEN cntry = 'DE' THEN 'Germany'
				WHEN cntry in ('USA', 'US') THEN 'United States'
				WHEN cntry = '' OR cntry IS NULL THEN 'n/a'
				ELSE cntry
			END AS cntry -- Normalize and Handle missing or blank country codes
		from bronze.erp_loc_a101; 

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ----------'


		------------------------- Clean and Load erp_px_cat_g1v2 ---------------------------------
		--------------------------------------------------------------------------------------------
		
		SET @start_time = GETDATE();	
		PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;

		PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2(
			id,
			cat,
			subcat,
			maintenance
		)
		SELECT 
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ----------'

		SET @end_silver_time = GETDATE();
		PRINT '>> Load Duration silver layer: ' + CAST(DATEDIFF(second,@start_silver_time, @end_silver_time) AS NVARCHAR) + 'seconds'
		
	END TRY
	BEGIN CATCH
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
	END CATCH
END
