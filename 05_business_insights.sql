-- Bài toán 3: Nhận diện Outlier giá bất động sản theo từng khu vực (Z-Score)
WITH District_Stats AS (
    -- Tầng 1: Tính Mean và Standard Deviation cho từng quận
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
    -- Không dùng GROUP BY vì Window Function tự động giữ nguyên số dòng của bảng Fact
),
Z_Score_Calculation AS (
    -- Tầng 2: Áp dụng công thức Z-score
    SELECT 
        property_id,
        district,
        price_per_sqm_million,
        ROUND(avg_price::numeric, 2) AS district_avg,
        ROUND(stddev_price::numeric, 2) AS district_stddev,
        ROUND(((price_per_sqm_million - avg_price) / NULLIF(stddev_price, 0))::numeric, 2) AS z_score
    FROM District_Stats
)
-- Tầng 3: Lọc ra các dòng siêu dị biệt (|Z| > 3)
SELECT * 
FROM Z_Score_Calculation
WHERE ABS(z_score) > 3
ORDER BY z_score DESC;

with AVG_DIST_PRICE as(
select 
l.district,
round(avg(f.price_per_sqm_million )::numeric,2) as avg_price_per_sqm
from fact_housing f 
join dim_location l 
	on f.location_id = l.location_id 
where l.district is not null 
	and f.area_suspect = FALSE
group by l.district
),
ranked_expensive as(
select district,
avg_price_per_sqm, 
dense_rank()OVER(order by avg_price_per_sqm desc) as ranking_expensive
from AVG_DIST_PRICE 
),
ranked_cheapest as(
select district,
avg_price_per_sqm,
dense_rank()OVER(order by avg_price_per_sqm asc) as ranking_cheap
from AVG_DIST_PRICE
)
select * 
from ranked_cheapest
where ranking_cheap <= 10;

select d.legal_status,
count(f.property_id ) as total_property,
round(avg(f.price_per_sqm_million)::numeric,2) as avg_price
from dim_legal d
inner join fact_housing f 
	on d.legal_id = f.legal_id 
where f.area_suspect = false 
group by d.legal_status 
order by avg_price desc;


select d.direction_name,
	count(d.direction_name) as total_direction_house, 
	round(avg(f.price_per_sqm_million)::numeric,2) as average_price_per_sqm
from fact_housing f
inner join dim_direction d 
	on f.direction_id = d.direction_id 
where f.direction_id is not null and
	f.area_suspect = false 
group by d.direction_name
order by average_price_per_sqm desc;

with furniture_stat as(
select df.furniture_state ,
	count(f.property_id) as total_house,
	round(avg(f.price_per_sqm_million)::numeric,2) as average_price_per_sqm
from fact_housing f
inner join dim_furniture df 
	on f.furniture_id = df.furniture_id 
where f.area_suspect = false
group by df.furniture_state
),
baseline as(
select average_price_per_sqm as baseline_price
from furniture_stat
where furniture_state = 'Unknown'
)
select fs.furniture_state,
	fs.total_house,
	fs.average_price_per_sqm,
	ROUND(((fs.average_price_per_sqm - b.baseline_price) / b.baseline_price * 100)::numeric, 2) AS diff_vs_baseline_pct
from furniture_stat fs
cross join baseline b 
order by fs.average_price_per_sqm desc;

with legal_stat as(
select dl.legal_status ,
	count(f.property_id) as total_house,
	round(avg(f.price_per_sqm_million)::numeric,2) as average_price_per_sqm
from fact_housing f
inner join dim_legal dl 
	on f.legal_id  = dl.legal_id
where f.area_suspect = false
group by dl.legal_status 
),
baseline as(
select average_price_per_sqm as baseline_price
from legal_stat
where legal_status = 'Have certificate'
)
select ls.legal_status ,
	ls.total_house,
	ls.average_price_per_sqm,
	ROUND(((ls.average_price_per_sqm - b.baseline_price) / b.baseline_price * 100)::numeric, 2) AS diff_vs_baseline_pct
from legal_stat ls
cross join baseline b 
order by ls.average_price_per_sqm desc;


select fh.bedrooms , fh.bathrooms ,
	count(fh.property_id ) as total_house,
	round(avg(fh.area_sqm)::numeric,2) as average_sqm,
	round(avg(fh.price_billion_vnd )::numeric,2) as average_price_billion
from fact_housing fh
where fh.area_suspect = false 
	and fh.bedrooms is not null  
	and fh.bathrooms is not null
group by fh.bedrooms,
		fh.bathrooms
having fh.bedrooms <= 5 
	and fh.bathrooms <= 5
order by 
	fh.bathrooms desc,
	fh.bedrooms desc;

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
