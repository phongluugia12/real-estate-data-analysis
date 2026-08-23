-- Dọn dẹp bảng cũ
DROP TABLE IF EXISTS dim_direction CASCADE;
DROP TABLE IF EXISTS dim_legal CASCADE;
DROP TABLE IF EXISTS dim_furniture CASCADE;
DROP TABLE IF EXISTS dim_location CASCADE;
-- 1. BẢNG DIM_DIRECTION
CREATE TABLE IF NOT EXISTS dim_direction(
	direction_id SERIAL PRIMARY KEY,
	direction_name VARCHAR(50)
);

INSERT INTO dim_direction(direction_name)
SELECT DISTINCT house_direction 
FROM stage_housing 
WHERE house_direction IS NOT NULL AND house_direction != '';

-- 2. BẢNG DIM_LEGAL
CREATE TABLE IF NOT EXISTS dim_legal(
	legal_id SERIAL PRIMARY KEY,
	legal_status VARCHAR(50)
);

INSERT INTO dim_legal(legal_status)
SELECT DISTINCT legal_status 
FROM stage_housing 
WHERE legal_status IS NOT NULL AND legal_status != '';

-- 3. BẢNG DIM_FURNITURE
CREATE TABLE IF NOT EXISTS dim_furniture(
	furniture_id SERIAL PRIMARY KEY,
	furniture_state VARCHAR(50)
);

INSERT INTO dim_furniture(furniture_state)
SELECT DISTINCT furniture_state
FROM stage_housing 
WHERE furniture_state IS NOT NULL AND furniture_state != '';


-- 4. Khởi tạo bảng dim_location
CREATE TABLE dim_location(
    location_id SERIAL PRIMARY KEY,
    city text,
    district text
);


INSERT INTO dim_location(city, district)
SELECT DISTINCT city, district
FROM stage_housing 
WHERE city IS NOT NULL AND district IS NOT NULL;


SELECT COUNT(*) AS missing_information 
FROM dim_location 
WHERE (city IN ('', 'Unknown', 'N/A') OR city IS NULL)
  AND (district IN ('', 'Unknown', 'N/A') OR district IS NULL);

-- 5. Xem thử thành quả
SELECT * FROM dim_location
LIMIT 100;