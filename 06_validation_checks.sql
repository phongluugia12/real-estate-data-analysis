-- 06_validation_checks.sql
-- Kiểm tra dữ liệu sau khi hoàn tất pipeline 01–04.

-- 1. Kiểm tra địa điểm thiếu thông tin.
SELECT
    location_id,
    city,
    district
FROM public.dim_location
WHERE city IS NULL
   OR BTRIM(city) IN ('', 'Unknown', 'N/A')
   OR district IS NULL
   OR BTRIM(district) IN ('', 'Unknown', 'N/A')
ORDER BY location_id;


-- 2. Tổng số dòng và khóa ngoại NULL.
SELECT
    (SELECT COUNT(*) FROM public.stage_housing) AS stage_rows,
    COUNT(*) AS fact_rows,
    COUNT(*) FILTER (
        WHERE location_id IS NULL
    ) AS null_location_fk,
    COUNT(*) FILTER (
        WHERE direction_id IS NULL
    ) AS null_direction_fk,
    COUNT(*) FILTER (
        WHERE legal_id IS NULL
    ) AS null_legal_fk,
    COUNT(*) FILTER (
        WHERE furniture_id IS NULL
    ) AS null_furniture_fk,
    COUNT(*) FILTER (
        WHERE area_suspect IS TRUE
    ) AS area_suspect_rows,
    COUNT(*) FILTER (
        WHERE area_suspect IS NULL
    ) AS null_area_suspect_rows
FROM public.fact_housing;


-- 3. Đối chiếu số lượng raw → staging → fact.
SELECT
    COUNT(*) AS raw_rows,
    COUNT(*) FILTER (
        WHERE (
            ARRAY_LENGTH(STRING_TO_ARRAY("Address", ','), 1) >= 2
        ) IS NOT TRUE
    ) AS excluded_by_address,
    (SELECT COUNT(*)
     FROM public.stage_housing) AS stage_rows,
    (SELECT COUNT(*)
     FROM public.fact_housing) AS fact_rows,
    (SELECT COUNT(*)
     FROM public.fact_housing
     WHERE area_suspect IS TRUE) AS area_suspect_rows,
    (SELECT COUNT(*)
     FROM public.fact_housing
     WHERE area_suspect IS FALSE) AS analysis_rows
FROM public.raw_housing;


-- 4. Kiểm tra khóa ngoại có giá trị nhưng không tồn tại trong dimension.
SELECT
    COUNT(*) FILTER (
        WHERE f.location_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM public.dim_location l
              WHERE l.location_id = f.location_id
          )
    ) AS orphan_location_fk,
    COUNT(*) FILTER (
        WHERE f.direction_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM public.dim_direction d
              WHERE d.direction_id = f.direction_id
          )
    ) AS orphan_direction_fk,
    COUNT(*) FILTER (
        WHERE f.legal_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM public.dim_legal lg
              WHERE lg.legal_id = f.legal_id
          )
    ) AS orphan_legal_fk,
    COUNT(*) FILTER (
        WHERE f.furniture_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM public.dim_furniture fur
              WHERE fur.furniture_id = f.furniture_id
          )
    ) AS orphan_furniture_fk
FROM public.fact_housing f;


-- 5. Rà soát cách phân loại địa điểm giữa staging và fact.
WITH location_check AS (
    SELECT
        'stage' AS source,
        city,
        district,
        address
    FROM public.stage_housing

    UNION ALL

    SELECT
        'fact' AS source,
        l.city,
        l.district,
        f.address
    FROM public.fact_housing f
    LEFT JOIN public.dim_location l
        ON f.location_id = l.location_id
)
SELECT
    source,
    city,
    district,
    COUNT(*) AS listing_count,
    MIN(address) AS example_address
FROM location_check
WHERE district ~ '^(Quận )?[0-9]+$'
   OR address ILIKE '%Quận Nam Từ Liêm%'
   OR address ILIKE '%Quận Bình Thạnh%'
   OR address ILIKE '%TP. Cam Ranh%'
GROUP BY source, city, district
ORDER BY city, district, source;


-- 6. Rà soát số listing liên kết với các địa điểm đã kiểm tra.
SELECT
    l.location_id,
    l.city,
    l.district,
    COUNT(f.property_id) AS linked_listings
FROM public.dim_location l
LEFT JOIN public.fact_housing f
    ON f.location_id = l.location_id
WHERE (
        l.city = 'Hà Nội'
        AND l.district IN ('Đại Mỗ', 'Nam Từ Liêm')
    )
   OR (
        l.city = 'Khánh Hòa'
        AND l.district IN ('Cam Nghĩa', 'Cam Ranh')
    )
   OR (
        l.city = 'Hồ Chí Minh'
        AND l.district ~ '^(Quận )?[0-9]+$'
    )
GROUP BY l.location_id, l.city, l.district
ORDER BY l.city, l.district, l.location_id;