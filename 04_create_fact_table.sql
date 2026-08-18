-- 1. xóa Fact cũ đi
DROP TABLE IF EXISTS fact_housing CASCADE;

-- 2. Khởi tạo bảng Fact mới (chỉ chứa ID, loại bỏ hoàn toàn các cột Text cồng kềnh)
CREATE TABLE fact_housing (
    property_id SERIAL PRIMARY KEY,
    location_id INT,
    direction_id INT,
    legal_id INT,
    furniture_id INT,
    address VARCHAR(128),
    area_sqm REAL,
    frontage_m REAL,
    floors INT,
    bedrooms INT,
    bathrooms INT,
    price_billion_vnd FLOAT,
    price_per_sqm_million FLOAT,
    area_suspect BOOLEAN,
    CONSTRAINT fk_location
        FOREIGN KEY(location_id) REFERENCES dim_location(location_id),
    CONSTRAINT fk_direction
        FOREIGN KEY(direction_id) REFERENCES dim_direction(direction_id),
    CONSTRAINT fk_legal
        FOREIGN KEY(legal_id) REFERENCES dim_legal(legal_id),
    CONSTRAINT fk_furniture
        FOREIGN KEY(furniture_id) REFERENCES dim_furniture(furniture_id)
);

-- 3. Nạp dữ liệu vào bảng Fact bằng cách JOIN với 4 bảng Dimension
INSERT INTO fact_housing(
    location_id, 
    direction_id,
    legal_id,
    furniture_id,
    address, 
    area_sqm, 
    frontage_m, 
    floors, 
    bedrooms, 
    bathrooms, 
    price_billion_vnd, 
    price_per_sqm_million, 
    area_suspect
)
SELECT 
    loc.location_id,
    dir.direction_id,
    leg.legal_id,
    fur.furniture_id,
    s.address, 
    s.area_sqm, 
    s.frontage_m, 
    s.floors, 
    s.bedrooms, 
    s.bathrooms, 
    s.price_billion_vnd, 
    s.price_per_sqm_million, 
    s.area_suspect
FROM stage_housing s 
-- Mapping mã khu vực
LEFT JOIN dim_location loc 
    ON s.city = loc.city AND s.district = loc.district
-- Mapping mã hướng nhà (tạm bỏ qua hướng ban công cho gọn)
LEFT JOIN dim_direction dir
    ON s.house_direction = dir.direction_name
-- Mapping mã pháp lý
LEFT JOIN dim_legal leg
    ON s.legal_status = leg.legal_status
-- Mapping mã nội thất
LEFT JOIN dim_furniture fur
    ON s.furniture_state = fur.furniture_state;

-- 4. Kiểm tra thành quả cuối cùng
SELECT * FROM fact_housing LIMIT 100;

select * from fact_housing
limit 100;

select * from stage_housing sh 
limit 100;

select distinct dl.city , dl.district  
from dim_location dl 
;

select distinct dd.direction_name 
from dim_direction dd ;

select distinct df.furniture_state 
from dim_furniture df ;

select distinct dl.legal_status 
from dim_legal dl ;