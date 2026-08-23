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
  - *Structuring:* Applied string_to_array to split the address by comma and extract the last two segments as city/district, then normalized administrative prefixes ('Huyện', 'Quận', 'Thị xã', 'Thành phố').
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
  - **Why group as 'Unknown':** Unknown indicates that the source listing did not provide explicit information about the property's legal status or furniture condition. It was retained as a separate category to distinguish missing information from actual states such as Basic, Full, or Have certificate. This allows the analysis to quantify data completeness while preventing missing values from being misinterpreted as a real property characteristic.
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

**1. A blanket regex silently erased meaning.** Running `GROUP BY city, district` filtered to Ho Chi Minh City, I immediately spotted 12 rows that looked wrong: district values reduced to a bare "1", "2"... "12" — no "Quận" prefix — sitting right next to normal names like "Gò Vấp" and "Bình Tân". It turned out the regex I'd written earlier to strip administrative prefixes ("Quận", "Huyện"...) had also stripped the digits off Ho Chi Minh City's 12 numbered inner districts, silently turning "Quận 9" into a bare "9" — over 3,800 rows affected. A number with no context like that is an easy source of confusion in any downstream query or chart. Fixed it by adding a condition: only strip the prefix when what remains isn't a plain number.

**2. `DELETE` alone can't say "keep exactly one."** To remove 2,699 duplicate listings, I realized a plain `DELETE` on matching address/price/area would wipe out an entire duplicate group at once — including the one record I actually wanted to keep — since there's no way to tell SQL "keep just one." Using `ROW_NUMBER() OVER (PARTITION BY...)` to rank rows within each duplicate group, then deleting only rows ranked above 1, guaranteed every group was left with exactly one record — not an arbitrary or complete wipe.

**3. Some bugs are invisible on screen.** Grouping by city, I paused at seeing two separate "Hà Nội" rows that looked completely identical to the eye. Digging in (with some help from Gemini), I found Vietnamese text's invisible trap on digital systems: precomposed vs. decomposed Unicode — the same visual character, stored as two different byte sequences. Running `NORMALIZE(city, NFC)` to force the column into one form, then re-running the same `GROUP BY`, collapsed the two "Hà Nội" rows into one. Checking the scope: only 4 of 30,229 rows were affected, and only in `city` (`district` was clean). Left unfixed, `dim_location` would have carried a phantom duplicate row for the same city, splitting its listings across two different `location_id`s — silently skewing every region-based analysis downstream.