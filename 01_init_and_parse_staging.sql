create table STAGE_HOUSING as
select 
	"Address"             AS address,
    "Area"                AS area_sqm,
    "Frontage"            AS frontage_m,
    "Access Road"         AS access_road_m,
    "House direction"     AS house_direction,
    "Balcony direction"   AS balcony_direction,
    "Floors"              AS floors,
    "Bedrooms"            AS bedrooms,
    "Bathrooms"           AS bathrooms,
    NULLIF(TRIM("Legal status"), '')    AS legal_status,
    NULLIF(TRIM("Furniture state"), '') AS furniture_state,
    "Price" 	as price_billion_vnd
from raw_housing
where array_length(string_to_array("Address", ','),1) >= 2;


ALTER TABLE stage_housing ADD COLUMN city text;
ALTER TABLE stage_housing ADD COLUMN district text;


UPDATE stage_housing 
SET city = RTRIM(TRIM((string_to_array(address, ','))[array_length(string_to_array(address, ','), 1)] ), '.'),
    district = TRIM((string_to_array(address, ','))[array_length(string_to_array(address, ','), 1) - 1]);


UPDATE stage_housing
SET district = TRIM(REGEXP_REPLACE(district, '^(Huyện|Quận|Thị xã|Thành phố)\s+', ''));

