# Data Quality & Cleaning Log

## 1. Overview
- **Raw Table (`raw_housing`):** 30,229 rows.
- **Staging Table (`stage_housing`):** 27,527 rows after cleaning.
- **Retention Rate:** 91%.

## 2. Identified Data Issues & Solutions

### Issue 1: Concatenated Address Structure & Unicode Encoding Inconsistencies
- **Observation:** 
  - *Surface Level:* The original `address` column is a long, unstandardized text string across listings.
  - *System Level:* Hidden Vietnamese Unicode encoding conflicts. (e.g., "Hà Nội" typed with precomposed vs. decomposed characters look identical but possess different byte sequences, causing the database to treat them as two distinct locations).
- **Solution:** 
  - *Structuring:* Applied string manipulation functions (string_to_array, REGEXP_REPLACE, REPLACE) in PostgreSQL to parse the raw string, accurately extract `city` and `district`, and clean up garbage prefixes (e.g., "Thành phố", "Tỉnh").
  - *Synchronization:* Applied Unicode normalization (NFC standard) to unify all hidden variants of province/city names into a single unique identifier.
- **Rationale:** 
  - **Business Value:** "Location" is the backbone of real estate valuation. Without extracting the District level, we cannot use `GROUP BY` to answer core business questions like: *"How much does the average house price in Cau Giay differ from the market average?"*.
  - **Data Architecture:** Resolving the Unicode issue is a prerequisite for accurately assigning Foreign Keys when building the `dim_location` table (Star Schema) in Phase 2. Skipping this step would result in missing data (NULLs) or database bloat due to phantom locations during future `JOIN` operations.

### Issue 2: Missing Values in Categorical and Numerical Columns
- **Observation:** Numerous listings omitted critical information such as Legal Status (`legal_status`), Furniture (`furniture_state`), House Direction (`house_direction`), and dimensional metrics (`frontage_m`, `floors`, etc.).
- **Solution:** 
  - Used `COALESCE` to assign 'Unknown' to categorical columns (`legal_status` and `furniture_state`).
  - Retained `NULL` values for numerical columns and specific categorical attributes (`house_direction`, `balcony_direction`).
- **Rationale:** 
  - **Why not delete rows:** Missing legal info does not invalidate the listing's core value (Price and Area). Hard deleting these would remove a massive sample size needed for calculating general market prices.
  - **Why group as 'Unknown': Unknown indicates that the source listing did not provide explicit information about the property's legal status or furniture condition. It was retained as a separate category to distinguish missing information from actual states such as Basic, Full, or Have certificate. This allows the analysis to quantify data completeness while preventing missing values from being misinterpreted as a real property characteristic."**.
  - **Why not apply to numerical columns:** Never replace `NULL` with `0` for metrics like frontage or floors, as it would severely skew average calculations in visualization tools. Leaving them as `NULL` allows the system to automatically exclude them during aggregations.

### Issue 3: Outliers - Micro-Houses
- **Observation:** Detected houses with highly illogical areas (<= 5m2).
- **Solution:** Used a `CASE WHEN` statement to create a boolean flag column (`area_suspect`) instead of using a `DELETE` command for physical removal.
- **Rationale:** 
  - **Lack of Absolute Proof:** A 5m2 area could be a typo (50m2 entered as 5m2), intentionally fake, or an actual micro-kiosk. Unlike duplicate data, there isn't a "smoking gun" to justify complete deletion.
  - **Data Integrity:** "Flagging" preserves the realistic picture of the market (including noisy listings). 

### Issue 4: Spam / Deduplication
- **Observation:** Identified 2,699 copy-pasted listings with identical core criteria: Address (`address`), Price (`price_billion_vnd`), and Area (`area_sqm`).
- **Solution:** Utilized a CTE combined with the `ROW_NUMBER() OVER(PARTITION BY...)` Window Function to rank rows within identical groups, then executed a `DELETE` on duplicates (`row_num > 1`), retaining only 1 master record.
- **Rationale:** Unlike Issue 3, an exact match across these 3 core fields is undeniable proof of broker "spamming". A Hard Delete here is mandatory to ensure the accuracy of aggregate metrics (especially average price per area).

## 3. Lessons Learned
Through processing and standardizing this real-world dataset, I derived three core analytical takeaways:
- **Never fully trust Raw Data:** Manual review cannot detect all "inflated prices" or numerical typos. It is imperative to apply statistical distribution techniques (like Window Functions combined with Z-Scores) to establish automated gates for identifying Outliers.
- **The Power of Baseline Techniques:** Instead of merely reporting dry averages, utilizing CTEs to establish a baseline (e.g., using specific groups like 'Basic' furniture or 'Have certificate' legal status as a benchmark) automates the quantification of percentage differences, making the data more comparative and intuitive.
- **Business Impact Outweighs Pure Code:** Complex SQL skills are foundational, but the true value of an analytical project lies in translating queried numbers (e.g., price differences based on house direction or furniture) into practical, actionable business strategies.
