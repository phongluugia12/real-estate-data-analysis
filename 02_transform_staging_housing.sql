update stage_housing
set legal_status = COALESCE(legal_status,'Unknown'),
	furniture_state = COALESCE(furniture_state,'Unknown');

select sh.legal_status ,sh.furniture_state 
from stage_housing sh
limit 100;

alter table stage_housing
add column price_per_sqm_million numeric;

update stage_housing
set price_per_sqm_million = ROUND( ((price_billion_vnd * 1000) / nullif(area_sqm,0))::numeric,1); 

select price_per_sqm_million 
from stage_housing
limit 100;

alter table stage_housing
add column area_suspect boolean;

UPDATE stage_housing
SET area_suspect = CASE 
                      WHEN area_sqm <= 5 THEN true
                      ELSE false 
                   END;

select area_suspect,count(*)
from stage_housing
group by area_suspect
limit 100;

delete from stage_housing 
where ctid IN( 
select ctid 
from (select ctid,
		row_number()over(
		partition by address, price_billion_vnd , area_sqm 
		order by ctid
		) as row_num
	from stage_housing
	) as ranked_housing
	where row_num > 1
);

select * from stage_housing sh 
limit 100;

SELECT COUNT(*) AS total_clean_houses
FROM stage_housing;

SELECT 
    MIN(price_billion_vnd) AS gia_thap_nhat,
    MAX(price_billion_vnd) AS gia_cao_nhat,
    MIN(area_sqm) AS dien_tich_thap_nhat,
    MAX(area_sqm) AS dien_tich_cao_nhat
FROM stage_housing
WHERE area_suspect = false;


select city,district,count(*) as frequency
from stage_housing sh 
group by city,district
order by frequency DESC;

update stage_housing
set city = trim(city),
	district = trim(district);

select city,district 
from stage_housing
where city like ' %' or city like '% '
	or district like ' %' or district like '% ';

update stage_housing 
set district = 'Tp. ' || district
where city = district;

update stage_housing 
set district = 'Quận ' || district
where district in ('1','2','3','4','5','6','7','8','9','10','11','12');

UPDATE stage_housing 
SET city = 'Hà Nội'
WHERE (city = '' OR city IS NULL) 
  AND district = 'Hai Bà Trưng';


UPDATE stage_housing 
SET city = 'Hồ Chí Minh' 
WHERE city IN ('TpHCM', 'TPHCM', 'TP Hồ Chí Minh', 'TP. HCM', 'Hồ Chí Mính',
'Hồ Chí Minh giá 2tỷ380');

update stage_housing 
set city = 'Hồ Chí Minh' , district = 'Quận 8'
where city = 'Quận 8';

UPDATE stage_housing 
SET city = 'Hà Nội' 
WHERE city = 'HN';

UPDATE stage_housing
SET city = CASE 
    WHEN city = 'Quận Nam Từ Liêm' THEN 'Hà Nội'
    WHEN city = 'Quận Bình Thạnh' THEN 'Hồ Chí Minh'
    WHEN city = 'TP. Cam Ranh' THEN 'Khánh Hòa'
    ELSE city 
END;

UPDATE stage_housing
SET district = TRIM(REPLACE(REPLACE(district, 'Phường ', ''), 'quận ', ''))
WHERE district ILIKE 'Phường %' OR district ILIKE 'quận %';

UPDATE stage_housing SET city = 'Bình Dương' WHERE city ILIKE 'Bình Dương (gần cafe%';
UPDATE stage_housing SET city = 'Quảng Ninh' WHERE city ILIKE 'Quảng Ninh (Ngã 3%';
UPDATE stage_housing SET city = 'Unknown', district = 'Unknown' WHERE city = 'giá 6ty';

UPDATE stage_housing 
SET district = REPLACE(district, 'Quận. ', 'Quận ') 
WHERE district LIKE 'Quận. %';

UPDATE stage_housing 
SET city = 'Hà Nội' 
WHERE city IN ('Hà Nội', 'Hà Nội');

select distinct city,district 
from stage_housing;

update stage_housing
set city = normalize(city,NFC),
	district = normalize(district,NFC);

update stage_housing
set district = TRIM(REGEXP_REPLACE(district, '(?i)^(huyện|quận|thị xã|thành phố)\s+(?!\d+$)', ''));

update stage_housing
set city = REGEXP_REPLACE(city, '\s+', ' ', 'g'),
	district = REGEXP_REPLACE(district, '\s+', ' ', 'g');

select * from stage_housing
limit 100;