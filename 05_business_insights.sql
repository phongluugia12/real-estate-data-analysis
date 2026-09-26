-- Bài toán 1: Nhận diện outlier giá theo từng khu vực
WITH location_stats AS (
    SELECT
        f.property_id,
        l.city,
        l.district,
        f.price_per_sqm_million,
        AVG(f.price_per_sqm_million) OVER (
            PARTITION BY f.location_id
        ) AS avg_price,
        STDDEV(f.price_per_sqm_million) OVER (
            PARTITION BY f.location_id
        ) AS stddev_price
    FROM fact_housing f
    JOIN dim_location l
        ON f.location_id = l.location_id
    WHERE f.area_suspect = FALSE
      AND f.price_per_sqm_million IS NOT NULL
),
z_score_calculation AS (
    SELECT
        property_id,
        city,
        district,
        price_per_sqm_million,
        ROUND(avg_price::NUMERIC, 2) AS location_avg,
        ROUND(stddev_price::NUMERIC, 2) AS location_stddev,
        (price_per_sqm_million - avg_price)
            / NULLIF(stddev_price, 0) AS z_score_raw
    FROM location_stats
)
SELECT
    property_id,
    city,
    district,
    price_per_sqm_million,
    location_avg,
    location_stddev,
    ROUND(z_score_raw::NUMERIC, 2) AS z_score
FROM z_score_calculation
WHERE ABS(z_score_raw) > 3
ORDER BY ABS(z_score_raw) DESC
LIMIT 50;

-- Bài toán 2: Phân tích Tình trạng Nội thất ảnh hưởng tới giá
WITH furniture_stat AS (
    SELECT 
        df.furniture_state,
        COUNT(f.property_id) AS total_house,
        ROUND(AVG(f.price_per_sqm_million)::numeric,2) AS average_price_per_sqm
    FROM fact_housing f
    INNER JOIN dim_furniture df 
        ON f.furniture_id = df.furniture_id 
    WHERE f.area_suspect = FALSE
    GROUP BY df.furniture_state
),
baseline_furniture AS (
    SELECT average_price_per_sqm AS baseline_price
    FROM furniture_stat
    WHERE furniture_state = 'Basic'
)
SELECT 
    fs.furniture_state,
    fs.total_house,
    fs.average_price_per_sqm,
    ROUND(((fs.average_price_per_sqm - b.baseline_price) / b.baseline_price * 100)::numeric, 2) AS diff_vs_baseline_pct
FROM furniture_stat fs
CROSS JOIN baseline_furniture b 
ORDER BY fs.average_price_per_sqm DESC;

-- Bài toán 3: Phân tích Tình trạng Pháp lý ảnh hưởng tới giá
WITH legal_stat AS (
    SELECT 
        dl.legal_status,
        COUNT(f.property_id) AS total_house,
        ROUND(AVG(f.price_per_sqm_million)::numeric,2) AS average_price_per_sqm
    FROM fact_housing f
    INNER JOIN dim_legal dl 
        ON f.legal_id = dl.legal_id
    WHERE f.area_suspect = FALSE
    GROUP BY dl.legal_status 
),
baseline_legal AS (
    SELECT average_price_per_sqm AS baseline_price
    FROM legal_stat
    WHERE legal_status = 'Have certificate'
)
SELECT 
    ls.legal_status,
    ls.total_house,
    ls.average_price_per_sqm,
    ROUND(((ls.average_price_per_sqm - b.baseline_price) / b.baseline_price * 100)::numeric, 2) AS diff_vs_baseline_pct
FROM legal_stat ls
CROSS JOIN baseline_legal b 
ORDER BY ls.average_price_per_sqm DESC;

-- Bài toán 4: Mối liên hệ giữa hướng nhà và giá niêm yết/m²
SELECT
    d.direction_name,
    COUNT(*) AS sample_size,
    ROUND(
        AVG(f.price_per_sqm_million)::NUMERIC,
        2
    ) AS average_price_per_sqm
FROM fact_housing f
INNER JOIN dim_direction d
    ON f.direction_id = d.direction_id
WHERE f.area_suspect IS FALSE
GROUP BY d.direction_name
ORDER BY average_price_per_sqm DESC;

-- Bài toán 5.1: Phân tích cấu trúc phòng ngủ - phòng tắm
SELECT
    fh.bedrooms,
    fh.bathrooms,
    COUNT(*) AS sample_size,
    ROUND(AVG(fh.area_sqm)::NUMERIC, 2) AS average_sqm,
    ROUND(AVG(fh.price_billion_vnd)::NUMERIC, 2) AS average_price_billion
FROM fact_housing fh
WHERE fh.area_suspect IS FALSE
  AND fh.bedrooms > 0
  AND fh.bathrooms > 0
GROUP BY
    fh.bedrooms,
    fh.bathrooms
HAVING COUNT(*) >= 30
ORDER BY
    fh.bathrooms DESC,
    fh.bedrooms DESC;

-- Bài toán 5.2: Phân nhóm diện tích
WITH area_tier AS (
    SELECT
        price_billion_vnd,
        CASE
            WHEN area_sqm < 30  THEN '< 30 m2'
            WHEN area_sqm < 50  THEN '30 - <50 m2'
            WHEN area_sqm < 80  THEN '50 - <80 m2'
            WHEN area_sqm < 120 THEN '80 - <120 m2'
            ELSE '>= 120 m2'
        END AS area_group,
        CASE
            WHEN area_sqm < 30  THEN 1
            WHEN area_sqm < 50  THEN 2
            WHEN area_sqm < 80  THEN 3
            WHEN area_sqm < 120 THEN 4
            ELSE 5
        END AS sort_order
    FROM fact_housing
    WHERE area_suspect IS FALSE
      AND area_sqm IS NOT NULL
)
SELECT
    area_group,
    COUNT(*) AS sample_size,
    ROUND(AVG(price_billion_vnd)::NUMERIC, 2) AS avg_price_billion
FROM area_tier
GROUP BY area_group, sort_order
ORDER BY sort_order;

-- Bài toán 6: Top 10 khu vực theo giá niêm yết trung bình/m²
WITH location_stats AS (
    SELECT
        f.location_id,
        l.city,
        l.district,
        COUNT(*) AS sample_size,
        AVG(f.price_per_sqm_million) AS avg_price_per_sqm
    FROM fact_housing f
    INNER JOIN dim_location l
        ON f.location_id = l.location_id
    WHERE f.area_suspect IS FALSE
      AND f.price_per_sqm_million IS NOT NULL
    GROUP BY
        f.location_id,
        l.city,
        l.district
    HAVING COUNT(*) >= 30
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY avg_price_per_sqm DESC,
                     sample_size DESC,
                     city,
                     district
        ) AS expensive_rank,
        ROW_NUMBER() OVER (
            ORDER BY avg_price_per_sqm ASC,
                     sample_size DESC,
                     city,
                     district
        ) AS cheap_rank
    FROM location_stats
)
SELECT
    'Top 10 Đắt Nhất' AS category,
    city,
    district,
    sample_size,
    ROUND(avg_price_per_sqm::NUMERIC, 2) AS avg_price_per_sqm,
    expensive_rank AS ranking
FROM ranked
WHERE expensive_rank <= 10

UNION ALL

SELECT
    'Top 10 Rẻ Nhất',
    city,
    district,
    sample_size,
    ROUND(avg_price_per_sqm::NUMERIC, 2),
    cheap_rank
FROM ranked
WHERE cheap_rank <= 10

ORDER BY category, ranking;