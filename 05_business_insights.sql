-- Bài toán 1: Nhận diện Outlier giá bất động sản theo từng khu vực (Z-Score)
WITH District_Stats AS (
    SELECT 
        f.property_id,
        l.district,
        f.price_per_sqm_million,
        AVG(f.price_per_sqm_million) OVER(PARTITION BY l.district) AS avg_price,
        STDDEV(f.price_per_sqm_million) OVER(PARTITION BY l.district) AS stddev_price
    FROM fact_housing f
    JOIN dim_location l 
        ON f.location_id = l.location_id
    WHERE f.area_suspect = FALSE 
        AND f.price_per_sqm_million IS NOT NULL
),
Z_Score_Calculation AS (
    SELECT 
        property_id,
        district,
        price_per_sqm_million,
        ROUND(avg_price::numeric, 2) AS district_avg,
        ROUND(stddev_price::numeric, 2) AS district_stddev,
        ROUND(((price_per_sqm_million - avg_price) / NULLIF(stddev_price, 0))::numeric, 2) AS z_score
    FROM District_Stats
)
SELECT * 
FROM Z_Score_Calculation
WHERE ABS(z_score) > 3
ORDER BY z_score DESC;

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

-- Bài toán 4: Phân tích Hướng nhà ảnh hưởng tới giá
SELECT 
    d.direction_name,
    COUNT(d.direction_name) AS total_direction_house, 
    ROUND(AVG(f.price_per_sqm_million)::numeric,2) AS average_price_per_sqm
FROM fact_housing f
INNER JOIN dim_direction d 
    ON f.direction_id = d.direction_id 
WHERE f.direction_id IS NOT NULL 
    AND f.area_suspect = FALSE 
GROUP BY d.direction_name
ORDER BY average_price_per_sqm DESC;

-- Bài toán 5.1: Phân tích cấu trúc Phòng ngủ - Phòng tắm
SELECT 
    fh.bedrooms, 
    fh.bathrooms,
    COUNT(fh.property_id) AS total_house,
    ROUND(AVG(fh.area_sqm)::numeric,2) AS average_sqm,
    ROUND(AVG(fh.price_billion_vnd)::numeric,2) AS average_price_billion
FROM fact_housing fh
WHERE fh.area_suspect = FALSE 
    AND fh.bedrooms IS NOT NULL  
    AND fh.bathrooms IS NOT NULL
GROUP BY 
    fh.bedrooms,
    fh.bathrooms
HAVING fh.bedrooms <= 5 
    AND fh.bathrooms <= 5
ORDER BY 
    fh.bathrooms DESC,
    fh.bedrooms DESC;

-- Bài toán 5.2: Phân cụm Diện tích (Area Bucketing)
WITH area_tier AS (
    SELECT 
        property_id,
        price_billion_vnd,
        CASE 
            WHEN area_sqm < 30 THEN '< 30 m2'
            WHEN area_sqm >= 30 AND area_sqm < 50 THEN '30 - 50 m2'
            WHEN area_sqm >= 50 AND area_sqm < 80 THEN '50 - 80 m2'
            WHEN area_sqm >= 80 AND area_sqm < 120 THEN '80 - 120 m2'
            ELSE '> 120 m2'
        END AS area_group,
        CASE 
            WHEN area_sqm < 30 THEN 1
            WHEN area_sqm >= 30 AND area_sqm < 50 THEN 2
            WHEN area_sqm >= 50 AND area_sqm < 80 THEN 3
            WHEN area_sqm >= 80 AND area_sqm < 120 THEN 4
            ELSE 5
        END AS sort_order
    FROM fact_housing
    WHERE area_suspect = FALSE
)
SELECT 
    area_group,
    COUNT(property_id) AS total_house,
    ROUND(AVG(price_billion_vnd)::numeric, 2) AS avg_price_billion
FROM area_tier
GROUP BY 
    area_group, 
    sort_order
ORDER BY 
    sort_order ASC;

-- Bài toán 6: Báo cáo gộp Top 10 Khu vực Đắt nhất và Rẻ nhất
WITH AVG_DIST_PRICE AS (
    SELECT 
        l.district,
        ROUND(AVG(f.price_per_sqm_million)::numeric, 2) AS avg_price_per_sqm
    FROM fact_housing f 
    JOIN dim_location l 
        ON f.location_id = l.location_id 
    WHERE l.district IS NOT NULL 
        AND f.area_suspect = FALSE
    GROUP BY l.district
),
ranked_expensive AS (
    SELECT 
        district,
        avg_price_per_sqm, 
        DENSE_RANK() OVER(ORDER BY avg_price_per_sqm DESC) AS ranking
    FROM AVG_DIST_PRICE 
),
ranked_cheapest AS (
    SELECT 
        district,
        avg_price_per_sqm,
        DENSE_RANK() OVER(ORDER BY avg_price_per_sqm ASC) AS ranking
    FROM AVG_DIST_PRICE
)
SELECT 
    'Top 10 Đắt Nhất' AS category,
    district,
    avg_price_per_sqm,
    ranking
FROM ranked_expensive 
WHERE ranking <= 10
UNION ALL
SELECT 
    'Top 10 Rẻ Nhất' AS category,
    district,
    avg_price_per_sqm,
    ranking
FROM ranked_cheapest
WHERE ranking <= 10;