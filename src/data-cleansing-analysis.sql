/* Project: Data Analysis for a Real Estate Agency
 * Part 2. Solving ad hoc tasks
 *
 * Author: Vorobyeva T.
*/

--TASK 1: ANALYSIS OF ADVERTISEMENT ACTIVITY IN THE REAL ESTATE MARKET OF ST. PETERSBURG AND LENINGRAD OBLAST IN 2015-2018

--Create a temporary table to filter anomalies in the flats table:
DROP TABLE IF EXISTS temp_flats_filtered;
CREATE TEMP TABLE temp_flats_filtered AS

--CTE Define anomalous values (outliers) based on percentile values:
WITH limits AS (
    SELECT  
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats)

    -- Find ad IDs that do not contain outliers, keeping missing data as well:
SELECT DISTINCT f.*
    FROM real_estate.flats AS f 
     CROSS JOIN limits AS l 
       WHERE 
        f.total_area < l.total_area_limit
        AND (f.rooms < l.rooms_limit OR f.rooms IS NULL)
        AND (f.balcony < l.balcony_limit OR f.balcony IS NULL)
        AND (f.ceiling_height < l.ceiling_height_limit_h OR f.ceiling_height IS NULL)
        AND (f.ceiling_height > l.ceiling_height_limit_l OR f.ceiling_height IS NULL);

--Output the result:
DROP TABLE IF EXISTS temp_ads_filtered;
CREATE TEMP TABLE temp_ads_filtered AS

--Create a second temporary table to clean the advertisement table from anomalies. 

--CTE Define anomalous duration values (outliers) based on percentile values:
WITH ad_limits AS (SELECT
PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY days_exposition) AS expdate_limit_h,
PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY days_exposition) AS expdate_limit_l
FROM real_estate.advertisement)

--Find ad IDs that do not contain outliers:
SELECT DISTINCT a.id, days_exposition, a.first_day_exposition, a.last_price 
FROM real_estate.advertisement AS a
CROSS JOIN ad_limits AS al 
WHERE a.days_exposition < al.expdate_limit_h
  AND a.days_exposition > al.expdate_limit_l;

--Combine two temporary tables into a data mart:
DROP TABLE IF EXISTS filtered_data;
CREATE TEMP TABLE filtered_data AS
SELECT 
    DISTINCT tf.id, tf.city_id, tf.type_id, tf.total_area, tf.rooms, tf.ceiling_height, 
    tf.floors_total, tf.floor, tf.is_apartment, tf.open_plan, tf.balcony, ta.last_price, 
    ta.days_exposition, ta.first_day_exposition
FROM temp_flats_filtered AS tf
INNER JOIN temp_ads_filtered AS ta ON tf.id = ta.id
WHERE EXTRACT(YEAR FROM (first_day_exposition::date + days_exposition * INTERVAL '1 day')) BETWEEN 2015 and 2018 AND days_exposition IS NOT NULL;

--Use ad IDs that do not contain outliers during data analysis:
SELECT * 
FROM filtered_data
ORDER BY first_day_exposition DESC;

--Check how the outlier filtering worked after cleansing the first table (flats)
--SELECT COUNT(*) FROM temp_flats_filtered; --19,118 rows (instead of 23,650 initially)
--Check how the outlier filtering worked after cleansing the second table (advertisement)
--SELECT COUNT(*) FROM temp_ads_filtered; --19,928 rows (instead of 23,650 initially)
--Check how the joining of the two tables (based on matching rows) and the time filter worked:
--SELECT COUNT(id) FROM filtered_data;
--14,231 rows (instead of 23,650 initially)


--TASK 1: ADVERTISEMENT ACTIVITY TIME IN THE REAL ESTATE MARKET OF ST. PETERSBURG AND LENINGRAD OBLAST IN 2015-2018
--CALCULATIONS

--CTE1 Calculate price per meter and the sum of "rooms+balconies" as a base for further calculations:
WITH feature_calc AS (
	SELECT fd.*, a.last_price / fd.total_area AS meterprice,
	(rooms + COALESCE(balcony, 0)) AS roomsbalcony
	FROM filtered_data AS fd
	LEFT JOIN real_estate.advertisement AS a ON fd.id=a.id),
	
--CTE2 Segment the database by advertisement duration:
active_days_calc AS (SELECT
	CASE WHEN days_exposition <= 30 THEN 'около одного месяца'
	WHEN days_exposition >= 31 AND days_exposition <= 90 THEN 'от одного до трёх месяцев'
	WHEN days_exposition >= 91 AND days_exposition <= 180 THEN 'от трёх месяцев до полугода'
	WHEN days_exposition >= 181 THEN 'более полугода'
	ELSE 'non-category'
	END AS active_days,
	*
	FROM feature_calc AS fc),
	
--CTE3 Add information about the locality type, as well as: St. Petersburg/Leningrad Oblast:
locality_type_calc AS (SELECT *, t.type_id,
    CASE 
        WHEN fc.city_id = '6X8I' THEN fc.city_id 
        ELSE 'others' 
    END AS group_city_id,
    CASE 
        WHEN fc.city_id = '6X8I' THEN c.city 
        ELSE 'Ленинградская обл.' 
    END AS group_city_name
FROM active_days_calc AS fc
LEFT JOIN real_estate.city AS c ON fc.city_id = c.city_id
LEFT JOIN real_estate.type AS t ON fc.type_id=t.type_id
WHERE t.type_id = 'F8EM'),

--CTE4 Calculate average price per sq.m., average property area, number of rooms and balconies by advertisement duration and city (St. Petersburg/Leningrad Oblast):
average_metric_calc AS (
	SELECT active_days, group_city_name,
	COUNT(id) AS flat_amount,
	ROUND(AVG(meterprice::numeric), 2) AS avg_meterprice, 
	ROUND(AVG(total_area::numeric), 2) AS avg_totalarea, 
	ROUND(AVG(roomsbalcony)::numeric, 2) AS avg_roomsbalcony
	FROM locality_type_calc
	GROUP BY active_days, group_city_name)

--Main query:
SELECT *,
ROUND(flat_amount::numeric * 100 / SUM(flat_amount) OVER (), 2) AS segment_share
FROM average_metric_calc
ORDER BY active_days, group_city_name;

--METHODOLOGY NOTES:
--Applied conditions/filters (excluding anomaly cleaning):
--Locality type "city";
--Advertisements already removed from sale (days_exposition IS NOT NULL);
--Dataset from 2015–2018, including those posted in 2014 and removed in 2015-2018.
--Final sample size based on the above conditions: 11,771.
--Segment share is calculated based on the number of apartments sold in the final sample (St. Petersburg + Leningrad Oblast).


--TASK 2: SEASONALITY OF ADVERTISEMENTS IN THE REAL ESTATE MARKET OF ST. PETERSBURG AND LENINGRAD OBLAST IN 2015-2018
--PART 1 (PUBLICATION OF ADVERTISEMENTS) 
--TEMPORARY TABLE FOR FILTERING ANOMALIES FOR THE FIRST PART OF THE TASK:

DROP TABLE IF EXISTS temp_saisonality_filtered;
CREATE TEMP TABLE temp_saisonality_filtered AS

--CTE1 Define anomalous values (outliers) based on percentile values:
WITH limits AS (
SELECT 
PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY days_exposition) AS limit_h,
PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY days_exposition) AS limit_l
FROM real_estate.advertisement),

--CTE2 Find ad IDs that do not contain outliers, keeping missing data as well:
join_calc AS (SELECT DISTINCT a.*
    FROM real_estate.advertisement AS a 
     CROSS JOIN limits AS l 
       WHERE 
        (a.days_exposition < l.limit_h AND a.days_exposition > l.limit_l)
        OR a.days_exposition IS NULL)

--Use ad IDs that do not contain outliers during data analysis and fall within the time period:
SELECT * FROM join_calc
WHERE EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018;

SELECT * FROM temp_saisonality_filtered;

--Check sample size:
--SELECT COUNT(*) FROM temp_saisonality_filtered;

--Notes:
--The sample size after cleansing is 17,083 rows, which is higher than in the first task because ads currently on sale (days_exposition IS NULL) were included.


--TASK 2 PART 1 MONTHLY DYNAMICS OF ADVERTISEMENT PUBLICATIONS BY MAIN CHARACTERISTICS FOR ST. PETERSBURG AND LENINGRAD OBLAST IN 2015-2018
--CALCULATIONS

--CTE1 Add information about the locality type (filter only cities), and define categories "St. Petersburg"/"Leningrad Oblast":
WITH locality_type_calc AS (SELECT *, t.type_id,
    CASE 
        WHEN f.city_id = '6X8I' THEN f.city_id 
        ELSE 'others' 
    END AS group_city_id,
    CASE 
        WHEN f.city_id = '6X8I' THEN c.city 
        ELSE 'Ленинградская обл.' 
    END AS group_city_name
	FROM real_estate.flats AS f
	LEFT JOIN real_estate.city AS c ON f.city_id = c.city_id
	LEFT JOIN real_estate.type AS t ON f.type_id=t.type_id
	WHERE t.type_id = 'F8EM'),

--CTE2 Calculate the month the apartments were listed, group publication activity by months and cities (St. Petersburg/Leningrad Oblast):
monthly_attribution AS (SELECT 
	lc.group_city_name,
	EXTRACT(MONTH FROM(sf.first_day_exposition::date)) AS announce_month,
	COUNT(sf.id) AS monthly_count,
	ROUND(SUM((sf.last_price::numeric) / 1000000), 2) AS monthly_value,
	ROUND(AVG(sf.last_price::numeric/lc.total_area::numeric), 2) AS avg_meterprice,
	ROUND(AVG(lc.total_area::numeric), 2) AS avg_totalarea
	FROM temp_saisonality_filtered AS sf
	JOIN locality_type_calc AS lc ON sf.id=lc.id
	WHERE EXTRACT(YEAR FROM (sf.first_day_exposition::date)) BETWEEN 2015 and 2018
	GROUP BY lc.group_city_name, announce_month),
	
--CTE3 Pivot the table by the number of published advertisements:
pivot1 AS (SELECT group_city_name,'Количество объявлений' AS metric,
    SUM(CASE WHEN announce_month = 1 THEN monthly_count END) AS jan,
    SUM(CASE WHEN announce_month = 2 THEN monthly_count END) AS feb,
    SUM(CASE WHEN announce_month = 3 THEN monthly_count END) AS mar,
    SUM(CASE WHEN announce_month = 4 THEN monthly_count END) AS apr,
    SUM(CASE WHEN announce_month = 5 THEN monthly_count END) AS may,
    SUM(CASE WHEN announce_month = 6 THEN monthly_count END) AS jun,
    SUM(CASE WHEN announce_month = 7 THEN monthly_count END) AS jul,
    SUM(CASE WHEN announce_month = 8 THEN monthly_count END) AS aug,
    SUM(CASE WHEN announce_month = 9 THEN monthly_count END) AS sep,
    SUM(CASE WHEN announce_month = 10 THEN monthly_count END) AS oct,
    SUM(CASE WHEN announce_month = 11 THEN monthly_count END) AS nov,
    SUM(CASE WHEN announce_month = 12 THEN monthly_count END) AS dec
FROM monthly_attribution
GROUP BY group_city_name),

--CTE4 Pivot the table by the total value of published advertisements:
pivot2 AS (SELECT group_city_name, 'Объем стоимости, млн.руб.' AS metric,
SUM(CASE WHEN announce_month = 1 THEN monthly_value END) AS jan,
    SUM(CASE WHEN announce_month = 2 THEN monthly_value END) AS feb,
    SUM(CASE WHEN announce_month = 3 THEN monthly_value END) AS mar,
    SUM(CASE WHEN announce_month = 4 THEN monthly_value END) AS apr,
    SUM(CASE WHEN announce_month = 5 THEN monthly_value END) AS may,
    SUM(CASE WHEN announce_month = 6 THEN monthly_value END) AS jun,
    SUM(CASE WHEN announce_month = 7 THEN monthly_value END) AS jul,
    SUM(CASE WHEN announce_month = 8 THEN monthly_value END) AS aug,
    SUM(CASE WHEN announce_month = 9 THEN monthly_value END) AS sep,
    SUM(CASE WHEN announce_month = 10 THEN monthly_value END) AS oct,
    SUM(CASE WHEN announce_month = 11 THEN monthly_value END) AS nov,
    SUM(CASE WHEN announce_month = 12 THEN monthly_value END) AS dec
 FROM monthly_attribution
 GROUP BY group_city_name),
 
 --CTE5 Pivot the table by the average price per sq.m.:
 pivot3 AS (SELECT group_city_name, 'Средн.цена за кв.м.' AS metric,
 	AVG(CASE WHEN announce_month = 1 THEN avg_meterprice END) AS jan,
    AVG(CASE WHEN announce_month = 2 THEN avg_meterprice END) AS feb,
    AVG(CASE WHEN announce_month = 3 THEN avg_meterprice END) AS mar,
    AVG(CASE WHEN announce_month = 4 THEN avg_meterprice END) AS apr,
    AVG(CASE WHEN announce_month = 5 THEN avg_meterprice END) AS may,
    AVG(CASE WHEN announce_month = 6 THEN avg_meterprice END) AS jun,
    AVG(CASE WHEN announce_month = 7 THEN avg_meterprice END) AS jul,
    AVG(CASE WHEN announce_month = 8 THEN avg_meterprice END) AS aug,
    AVG(CASE WHEN announce_month = 9 THEN avg_meterprice END) AS sep,
    AVG(CASE WHEN announce_month = 10 THEN avg_meterprice END) AS oct,
    AVG(CASE WHEN announce_month = 11 THEN avg_meterprice END) AS nov,
    AVG(CASE WHEN announce_month = 12 THEN avg_meterprice END) AS dec
 FROM monthly_attribution
 GROUP BY group_city_name),
 
 --CTE6 Pivot the table by the average total area:
 pivot4 AS (SELECT group_city_name, 'Средняя площадь, кв.м.' AS metric, 
    AVG(CASE WHEN announce_month = 1 THEN avg_totalarea END) AS jan,
    AVG(CASE WHEN announce_month = 2 THEN avg_totalarea END) AS feb,
    AVG(CASE WHEN announce_month = 3 THEN avg_totalarea END) AS mar,
    AVG(CASE WHEN announce_month = 4 THEN avg_totalarea END) AS apr,
    AVG(CASE WHEN announce_month = 5 THEN avg_totalarea END) AS may,
    AVG(CASE WHEN announce_month = 6 THEN avg_totalarea END) AS jun,
    AVG(CASE WHEN announce_month = 7 THEN avg_totalarea END) AS jul,
    AVG(CASE WHEN announce_month = 8 THEN avg_totalarea END) AS aug,
    AVG(CASE WHEN announce_month = 9 THEN avg_totalarea END) AS sep,
    AVG(CASE WHEN announce_month = 10 THEN avg_totalarea END) AS oct,
    AVG(CASE WHEN announce_month = 11 THEN avg_totalarea END) AS nov,
    AVG(CASE WHEN announce_month = 12 THEN avg_totalarea END) AS dec
 FROM monthly_attribution
 GROUP BY group_city_name)
 
 --Main query
  SELECT * FROM pivot1
  UNION
  SELECT * FROM pivot2
  UNION
  SELECT * FROM pivot3
  UNION 
  SELECT * FROM pivot4
  ORDER BY metric, group_city_name;
 
 --METHODOLOGY NOTES:
 --Additionally calculated the total volume of realized value of sold apartments, which can be useful when estimating potential agency commission income (as a rule, agency commission is calculated as a percentage of the transaction price).
 --In accordance with the template for task 2, the sample includes advertisements that lack values for exposure duration in the database, i.e., current sales. 

 
 
--TASK 2 PART 2 MONTHLY DYNAMICS OF APARTMENT SALE TRANSACTIONS BY MAIN INDICATORS FOR ST. PETERSBURG AND LENINGRAD OBLAST IN 2015-2018
--TEMPORARY TABLE FOR FILTERING ANOMALIES FOR THE SECOND PART OF THE TASK:

DROP TABLE IF EXISTS temp_saisonality2_filtered;
CREATE TEMP TABLE temp_saisonality2_filtered AS

--CTE1 Define anomalous values (outliers) based on percentile values:
WITH limits AS (
SELECT 
PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY days_exposition) AS limit_h,
PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY days_exposition) AS limit_l
FROM real_estate.advertisement),

--CTE2 Find ad IDs that do not contain outliers, keeping missing data as well:
join_calc AS (SELECT DISTINCT a.*
    FROM real_estate.advertisement AS a 
     CROSS JOIN limits AS l 
       WHERE 
        (a.days_exposition < l.limit_h AND a.days_exposition > l.limit_l))

--Use ad IDs that do not contain outliers during data analysis and fall within the time period:
SELECT * FROM join_calc
WHERE EXTRACT(YEAR FROM (first_day_exposition::date + days_exposition * INTERVAL '1 day')) BETWEEN 2015 and 2018 AND days_exposition IS NOT NULL;


SELECT * FROM temp_saisonality2_filtered
ORDER BY first_day_exposition;

--Check sample size:
SELECT COUNT(*) FROM temp_saisonality2_filtered;

--Notes:
--The sample size after cleansing is 17,083 rows.
--Advertisements published before 2015 and closed within the target period (2015–2018) were included.
--Unclosed advertisements were excluded.


--TASK 2 PART 2 MONTHLY DYNAMICS OF APARTMENT SALE TRANSACTIONS BY MAIN INDICATORS FOR ST. PETERSBURG AND LENINGRAD OBLAST IN 2015-2018
--CALCULATIONS:
--CTE1 Add information about the locality type (filter only cities), and define categories "St. Petersburg"/"Leningrad Oblast":
WITH locality_type_calc AS (SELECT *, t.type_id,
    CASE 
        WHEN f.city_id = '6X8I' THEN f.city_id 
        ELSE 'others' 
    END AS group_city_id,
    CASE 
        WHEN f.city_id = '6X8I' THEN c.city 
        ELSE 'Ленинградская обл.' 
    END AS group_city_name
	FROM real_estate.flats AS f
	LEFT JOIN real_estate.city AS c ON f.city_id = c.city_id
	LEFT JOIN real_estate.type AS t ON f.type_id=t.type_id
	WHERE t.type_id = 'F8EM'),

--CTE2 Calculate the month the apartments were sold, group listing removal activity by months and cities (St. Petersburg/Leningrad Oblast):
monthly_attribution AS (SELECT 
	lc.group_city_name,
	EXTRACT(MONTH FROM(ts2.first_day_exposition::date + ts2.days_exposition * INTERVAL '1 day')) AS closure_month,
	COUNT(ts2.id) AS monthly_count,
	ROUND(SUM((ts2.last_price::numeric) / 1000000), 2) AS monthly_revenue,
	ROUND(AVG(ts2.last_price::numeric/lc.total_area::numeric), 2) AS avg_meterprice,
	ROUND(AVG(lc.total_area::numeric), 2) AS avg_totalarea
	FROM temp_saisonality2_filtered AS ts2
	JOIN locality_type_calc AS lc ON ts2.id=lc.id
	WHERE ts2.days_exposition IS NOT NULL 
	GROUP BY lc.group_city_name, closure_month),
	
--CTE3 Pivot the table by the number of removed advertisements (corresponds to the number of apartments sold):
pivot1 AS (SELECT group_city_name,'Количество сделок' AS metric,
    SUM(CASE WHEN closure_month = 1 THEN monthly_count END) AS jan,
    SUM(CASE WHEN closure_month = 2 THEN monthly_count END) AS feb,
    SUM(CASE WHEN closure_month = 3 THEN monthly_count END) AS mar,
    SUM(CASE WHEN closure_month = 4 THEN monthly_count END) AS apr,
    SUM(CASE WHEN closure_month = 5 THEN monthly_count END) AS may,
    SUM(CASE WHEN closure_month = 6 THEN monthly_count END) AS jun,
    SUM(CASE WHEN closure_month = 7 THEN monthly_count END) AS jul,
    SUM(CASE WHEN closure_month = 8 THEN monthly_count END) AS aug,
    SUM(CASE WHEN closure_month = 9 THEN monthly_count END) AS sep,
    SUM(CASE WHEN closure_month = 10 THEN monthly_count END) AS oct,
    SUM(CASE WHEN closure_month = 11 THEN monthly_count END) AS nov,
    SUM(CASE WHEN closure_month = 12 THEN monthly_count END) AS dec
FROM monthly_attribution
GROUP BY group_city_name),

--CTE4 Pivot the table by the realized value of removed advertisements:
pivot2 AS (SELECT group_city_name, 'Выручка (объем стоимости), млн.руб.' AS metric,
	SUM(CASE WHEN closure_month = 1 THEN monthly_revenue END) AS jan,
    SUM(CASE WHEN closure_month = 2 THEN monthly_revenue END) AS feb,
    SUM(CASE WHEN closure_month = 3 THEN monthly_revenue END) AS mar,
    SUM(CASE WHEN closure_month = 4 THEN monthly_revenue END) AS apr,
    SUM(CASE WHEN closure_month = 5 THEN monthly_revenue END) AS may,
    SUM(CASE WHEN closure_month = 6 THEN monthly_revenue END) AS jun,
    SUM(CASE WHEN closure_month = 7 THEN monthly_revenue END) AS jul,
    SUM(CASE WHEN closure_month = 8 THEN monthly_revenue END) AS aug,
    SUM(CASE WHEN closure_month = 9 THEN monthly_revenue END) AS sep,
    SUM(CASE WHEN closure_month = 10 THEN monthly_revenue END) AS oct,
    SUM(CASE WHEN closure_month = 11 THEN monthly_revenue END) AS nov,
    SUM(CASE WHEN closure_month = 12 THEN monthly_revenue END) AS dec
 FROM monthly_attribution
 GROUP BY group_city_name),
 
 --CTE5 Pivot the table by the average price per sq.m.:
 pivot3 AS (SELECT group_city_name, 'Средн.цена за кв.м.' AS metric,
 	AVG(CASE WHEN closure_month = 1 THEN avg_meterprice END) AS jan,
    AVG(CASE WHEN closure_month = 2 THEN avg_meterprice END) AS feb,
    AVG(CASE WHEN closure_month = 3 THEN avg_meterprice END) AS mar,
    AVG(CASE WHEN closure_month = 4 THEN avg_meterprice END) AS apr,
    AVG(CASE WHEN closure_month = 5 THEN avg_meterprice END) AS may,
    AVG(CASE WHEN closure_month = 6 THEN avg_meterprice END) AS jun,
    AVG(CASE WHEN closure_month = 7 THEN avg_meterprice END) AS jul,
    AVG(CASE WHEN closure_month = 8 THEN avg_meterprice END) AS aug,
    AVG(CASE WHEN closure_month = 9 THEN avg_meterprice END) AS sep,
    AVG(CASE WHEN closure_month = 10 THEN avg_meterprice END) AS oct,
    AVG(CASE WHEN closure_month = 11 THEN avg_meterprice END) AS nov,
    AVG(CASE WHEN closure_month = 12 THEN avg_meterprice END) AS dec
 FROM monthly_attribution
 GROUP BY group_city_name),
 
 --CTE6 Pivot the table by the average total area:
 pivot4 AS (SELECT group_city_name, 'Средняя площадь, кв.м.' AS metric, 
    AVG(CASE WHEN closure_month = 1 THEN avg_totalarea END) AS jan,
    AVG(CASE WHEN closure_month = 2 THEN avg_totalarea END) AS feb,
    AVG(CASE WHEN closure_month = 3 THEN avg_totalarea END) AS mar,
    AVG(CASE WHEN closure_month = 4 THEN avg_totalarea END) AS apr,
    AVG(CASE WHEN closure_month = 5 THEN avg_totalarea END) AS may,
    AVG(CASE WHEN closure_month = 6 THEN avg_totalarea END) AS jun,
    AVG(CASE WHEN closure_month = 7 THEN avg_totalarea END) AS jul,
    AVG(CASE WHEN closure_month = 8 THEN avg_totalarea END) AS aug,
    AVG(CASE WHEN closure_month = 9 THEN avg_totalarea END) AS sep,
    AVG(CASE WHEN closure_month = 10 THEN avg_totalarea END) AS oct,
    AVG(CASE WHEN closure_month = 11 THEN avg_totalarea END) AS nov,
    AVG(CASE WHEN closure_month = 12 THEN avg_totalarea END) AS dec
 FROM monthly_attribution
 GROUP BY group_city_name)
 
 --Main query:
  SELECT * FROM pivot1
  UNION
  SELECT * FROM pivot2
  UNION
  SELECT * FROM pivot3
  UNION 
  SELECT * FROM pivot4
  ORDER BY metric, group_city_name;
