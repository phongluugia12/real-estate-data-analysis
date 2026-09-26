# Data Quality & Cleaning Log

## 1. Overview

- **Raw listings:** 30,229.
- **Rows excluded by the address-parsing rule:** 3.
- **Probable duplicate rows removed:** 2,699.
- **Retention rate:** 91.06% (27,527 / 30,229).
- **Area-suspect rows retained:** 3.
- **Rows passing the area-quality filter:** 27,524.

## 2. Identified Data Issues & Solutions

### Issue 1: Concatenated Address Structure & Unicode Encoding Inconsistencies
- **Observation:** 
  - *Surface Level:* The original `address` column is a long, unstandardized text string across listings.
  - *System Level:* Hidden Vietnamese Unicode encoding conflicts. (e.g., "Hà Nội" typed with precomposed vs. decomposed characters look identical but possess different byte sequences, causing the database to treat them as two distinct locations).
- **Solution:** 
  - *Structuring:* Applied string_to_array to split the address by comma and extract the last two segments as city/district, then normalized administrative prefixes ('Huyện', 'Quận', 'Thị xã', 'Thành phố').
  - *Synchronization:* Applied Unicode normalization (NFC standard) to unify all hidden variants of province/city names into a single unique identifier.
  - **Exception handling:** One malformed address ending with price text was verified against the full address and correctly mapped to Gò Vấp, Hồ Chí Minh instead of being assigned to `Unknown`.
- **Rationale:** 
  - **Business Value:** "Location" is the backbone of real estate valuation. Without extracting the District level, we cannot use `GROUP BY` to answer core business questions like: *"How much does the average house price in Cau Giay differ from the market average?"*.
  - **Data Architecture:** Resolving the Unicode issue is a prerequisite for accurately assigning Foreign Keys when building the `dim_location` table (Star Schema) in Phase 2. Skipping this step would result in missing data (NULLs) or database bloat due to phantom locations during future `JOIN` operations.

### Issue 2: Missing Values in Categorical and Numerical Columns
- **Observation:**
  - Numerous listings omitted critical information such as Legal Status (`legal_status`), Furniture (`furniture_state`), House Direction (`house_direction`), and dimensional metrics (`frontage_m`, `floors`, etc.).
  - House direction remained unavailable for 19,468 of 27,527 fact rows (70.72%). Direction-based analysis was therefore restricted to the populated subset and should not be generalized to the full dataset.
- **Solution:** 
  - Used `COALESCE` to assign 'Unknown' to categorical columns (`legal_status` and `furniture_state`).
  - Retained `NULL` values for numerical columns and specific categorical attributes (`house_direction`, `balcony_direction`).
- **Rationale:** 
  - **Why not delete rows:** Missing legal info does not invalidate the listing's core value (Price and Area). Hard deleting these would remove a massive sample size needed for calculating general market prices.
  - **Why group as 'Unknown':** Unknown indicates that the source listing did not provide explicit information about the property's legal status or furniture condition. It was retained as a separate category to distinguish missing information from actual states such as Basic, Full, or Have certificate. This allows the analysis to quantify data completeness while preventing missing values from being misinterpreted as a real property characteristic.
  - **Why not apply to numerical columns:** Never replace `NULL` with `0` for metrics like frontage or floors, as it would severely skew average calculations in visualization tools. Leaving them as `NULL` allows the system to automatically exclude them during aggregations.

### Issue 3: Outliers - Micro-Houses
- **Observation:** Detected houses with highly illogical areas (<= 5m2).
- **Solution:** Created the `area_suspect` boolean flag using `area_sqm IS NULL OR area_sqm <= 5`, preserving suspicious rows while excluding them from price-based analysis.
- **Rationale:** 
  - **Lack of Absolute Proof:** A 5m2 area could be a typo (50m2 entered as 5m2), intentionally fake, or an actual micro-kiosk. Unlike duplicate data, there isn't a "smoking gun" to justify complete deletion.
  - **Data Integrity:** "Flagging" preserves the realistic picture of the market (including noisy listings). 

### Issue 4: Spam / Deduplication
- **Observation:** Identified 2,699 probable duplicate rows using the composite criteria of address, price, and area.
- **Solution:** Utilized a subquery combined with the `ROW_NUMBER() OVER(PARTITION BY...)` Window Function to rank rows within identical groups, then executed a `DELETE` on duplicates (`row_num > 1`), retaining only 1 master record.
- **Rationale:** An exact match across these fields is a strong duplicate signal, although it is not absolute proof that two records represent the same physical property. This project treats them as duplicates to reduce likely listing repetition in aggregate analysis.

### Issue 5: Ward Names Misclassified as Districts

- **Observation:** Two listings had ward names stored in the `district` column instead of their corresponding district-level administrative units.
- **Solution:** Cross-checked the full addresses against the historical administrative hierarchy and corrected Đại Mỗ → Nam Từ Liêm (Hà Nội) and Cam Nghĩa → Cam Ranh (Khánh Hòa). The correction rules were added to `02_transform_staging_housing.sql`.
- **Validation:** Updated two staging rows and the location references of two fact rows. Both tables retained 27,527 rows, and all non-location values remained unchanged. Follow-up checks are included in `06_validation_checks.sql`.

## 3. Lessons Learned

**1. A blanket regex silently erased meaning.** Running `GROUP BY city, district` filtered to Ho Chi Minh City, I immediately spotted 12 rows that looked wrong: district values reduced to a bare "1", "2"... "12" — no "Quận" prefix — sitting right next to normal names like "Gò Vấp" and "Bình Tân". It turned out the regex I'd written earlier to strip administrative prefixes ("Quận", "Huyện"...) had also stripped the prefixes from Ho Chi Minh City's 12 numbered inner districts, silently turning "Quận 9" into a bare "9" — over 3,800 rows affected. A number with no context like that is an easy source of confusion in any downstream query or chart. Fixed it by adding a condition: only strip the prefix when what remains isn't a plain number.

**2. Deduplication needs a rule for choosing which row to keep.** I used ROW_NUMBER() to rank rows sharing the same address, asking price, and area, then deleted rows with row_num > 1. This removed 2,699 probable duplicates while retaining one row per group. The script uses ORDER BY ctid to choose the retained row; it does not assess which listing is more complete or accurate.

**3. Some bugs are invisible on screen.** Grouping by city, I paused at seeing two separate "Hà Nội" rows that looked completely identical to the eye. Digging in (with some help from Gemini), I found Vietnamese text's invisible trap on digital systems: precomposed vs. decomposed Unicode — the same visual character, stored as two different byte sequences. Running `NORMALIZE(city, NFC)` to force the column into one form, then re-running the same `GROUP BY`, collapsed the two "Hà Nội" rows into one. Checking the scope: only 4 of 30,229 rows were affected, and only in `city` (`district` was clean). Left unfixed, `dim_location` would have carried a phantom duplicate row for the same city, splitting its listings across two different `location_id`s — silently skewing every region-based analysis downstream.