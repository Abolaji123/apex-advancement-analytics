CREATE DATABASE Apex_Advancement_DW;
USE Apex_Advancement_DW;

-- DATA IMPORT  

-- Defining schema manually to ensure financial precision. (giving table)
DROP TABLE IF EXISTS fact_giving_raw;
CREATE TABLE fact_giving_raw (
    Gift_ID INT,
    Donor_ID INT,
    Gift_Date TEXT,              
    Designation VARCHAR(255),
    Gift_Type VARCHAR(100),
    Campaign_Year VARCHAR (50),
    Anonymous INT
);

-- Using Local infile to load data cos table import wizard is taking too much time 
--  Turning on the loading permission 
SET GLOBAL local_infile = 1;

TRUNCATE TABLE fact_giving_raw;

-- High-Speed Load
LOAD DATA LOCAL INFILE '"C:\Users\admin\Desktop\Advancement Data\kaggle_dataset\giving.csv"'
INTO TABLE fact_giving_raw
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS; -- 

-- For the next table (donors), used a quick python script (Pandas) to read the CSV headers and generate
 -- the CREATE TABLE statement. Then tweaked the financial columns to be decimal instead of float

-- Create the Table Skeleton

DROP TABLE IF EXISTS donors_raw;

CREATE TABLE donors_raw (
    ID INT,
    First_Name VARCHAR(255),
    Last_Name VARCHAR(255),
    Full_Name VARCHAR(255),
    Gender VARCHAR(50),
    donor_type VARCHAR(100),         
    Constituent_Type_2 VARCHAR(100),
    Class_Year VARCHAR(50),
    Parent_Year VARCHAR(50),
    Primary_Manager VARCHAR(255),
    Rating VARCHAR(50),
    Prospect_Stage VARCHAR(100),
    Lifetime_Giving DECIMAL(15,2),
    Last_Gift DECIMAL(15,2),
    Last_Gift_Designation VARCHAR(255),
    Last_Gift_Date VARCHAR(50),      
    Consecutive_Yr_Giving_Count INT,
    Total_Yr_Giving_Count INT,
    Rating_Giving_Alignment VARCHAR(100),
    Family_ID VARCHAR(50),
    Relationship_Type VARCHAR(100),
    Family_Giving_Potential VARCHAR(100),
    region VARCHAR(100),
    Professional_Background VARCHAR(255),
    Interest_Keywords TEXT,
    Engagement_Score DECIMAL(10,2),
    Legacy_Intent_Probability DECIMAL(10,4),
    Legacy_Intent_Binary INT,
    Board_Affiliations TEXT,
    Estimated_Age VARCHAR(50),
    total_relationships INT,
    outgoing_relationships INT,
    incoming_relationships INT,
    relationship_diversity DECIMAL(10,2),
    avg_relationship_strength DECIMAL(10,2),
    max_relationship_strength DECIMAL(10,2),
    professional_network_size INT,
    social_network_size INT,
    alumni_network_size INT,
    family_network_size INT,
    philanthropic_network_size INT,
    geographic_network_size INT,
    network_avg_giving DECIMAL(15,2),
    network_max_giving DECIMAL(15,2),
    network_total_giving DECIMAL(15,2),
    high_value_connections INT,
    idx_col INT,                      
    gifts_per_year DECIMAL(10,2),
    gift_frequency DECIMAL(10,2),
    last_gift_amount DECIMAL(15,2),
    frequency_score DECIMAL(10,2),
    gift_count INT,
    giving_years INT,
    total_gifts INT,
    years_active INT,
    consecutive_years INT,
    recency_score DECIMAL(10,2),
    running_avg_last_3 DECIMAL(15,2),
    days_since_last_gift INT,
    rfm_score DECIMAL(10,2),
    time_weighted_giving DECIMAL(15,2),
    is_multi_year INT,
    gift_frequency_variability DECIMAL(10,2),
    giving_velocity DECIMAL(10,2),
    years_since_first_gift INT,
    monetary_score DECIMAL(10,2),
    is_loyal_donor INT,
    gave_in_24mo INT,
    gifts_last_24mo INT,
    gift_consistency DECIMAL(10,2),
    avg_gift_amount DECIMAL(15,2),
    avg_gift_size DECIMAL(15,2),
    total_lifetime_giving DECIMAL(15,2),
    total_amount DECIMAL(15,2),
    giving_consistency DECIMAL(10,2),
    engagement_score_alt DECIMAL(10,2), 
    gifts_last_12mo INT,
    gave_in_12mo INT,
    years_inactive INT,
    recent_giving_amount DECIMAL(15,2),
    recently_engaged INT,
    gave_in_6mo INT,
    gifts_last_6mo INT,
    engagement_giving_interaction DECIMAL(15,2),
    giving_momentum DECIMAL(10,2),
    other_region INT,
    is_recent_donor INT,
    senior_age INT,
    young_age INT,
    medium_capacity_industry INT,
    high_capacity_industry INT,
    qualified_rating INT,
    wealthy_region INT,
    other_industry INT,
    mid_career_age INT,
    net_giving_interaction DECIMAL(15,2),
    pagerank DECIMAL(10,6),
    has_network INT,
    has_board_role INT,
    community_id INT,
    community_size INT,
    role_giving_interaction DECIMAL(15,2),
    Gave_Again_In_2024 INT,
    Gave_Again_In_2025 INT,
    high_rating INT,
    network_size INT,
    degree_centrality DECIMAL(10,6),
    influence_score DECIMAL(10,2),
    high_influence_role INT,
    clustering_coefficient DECIMAL(10,6),
    has_estate_capacity INT,
    Will_Give_Again_Probability DECIMAL(10,4)
);

-- fast load command
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/admin/Desktop/Advancement Data/kaggle_dataset/donors.csv' 
INTO TABLE donors_raw
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- DATA CLEANING 

--- Inspection for Data Quality issues
-- I'm particularly concerned about the money column to see if it made it through the import safely
-- Checking for zeros error
SELECT 
    COUNT(*) as Total_Rows,
    SUM(CASE WHEN Gift_Amount = 0 THEN 1 ELSE 0 END) as Zero_Value_Gifts,
    (SUM(CASE WHEN Gift_Amount = 0 THEN 1 ELSE 0 END) / COUNT(*)) * 100 as Percent_Zero
FROM fact_giving_raw;
-- Percent zero is 11.11642 
-- Investigating further to understand why
SELECT 
    Gift_Type, 
    COUNT(*) as Zero_Count 
FROM fact_giving_raw 
WHERE Gift_Amount = 0 
GROUP BY Gift_Type;
-- this begs questions and cannot be accepted in real life scenarios beacuse how can cash gifts = 86078 zero_counts,
-- the ghost gifts of about 86,000 rows will be excluded from the final fact_giving table

-- the "decimal" check (did the 15 cents gifts survive? Or did they all get rounded to integers?
SELECT Gift_Amount 
FROM fact_giving_raw 
WHERE Gift_Amount - FLOOR(Gift_Amount) > 0 
LIMIT 5;
-- got values like 2444.57, 4105.36 so the precision is safe

-- the "null" check to see if any rows got completely rejected
SELECT COUNT(*) as Null_Amounts 
FROM fact_giving_raw 
WHERE Gift_Amount IS NULL;
-- Ans: 0. 

-- Checking for Date Integrity 
SELECT 
    COUNT(*) as Total_Rows,
    SUM(CASE WHEN Gift_Date IS NULL OR Gift_Date = '' THEN 1 ELSE 0 END) as Missing_Dates,
    MIN(Gift_Date) as Earliest_Date_Text,
    MAX(Gift_Date) as Latest_Date_Text
FROM fact_giving_raw;
-- Ans: no missing dates 


-- Checking to ensure every gift in the giving table points to a valid donor in the donors table
SELECT 
    COUNT(*) as Orphan_Transactions,
    SUM(g.Gift_Amount) as Orphan_Money
FROM fact_giving_raw g
LEFT JOIN donors_raw d ON g.Donor_ID = d.ID
WHERE d.ID IS NULL;
-- Ans: 0. Awesome! The database has perfect referential integrity

-- CLEANING UP / TRANSFORMING THE fact_giving_raw
DROP TABLE IF EXISTS fact_giving;

CREATE TABLE fact_giving AS
SELECT
    Gift_ID,
    Donor_ID,
    CASE 
        WHEN Gift_Date = '' OR Gift_Date IS NULL THEN NULL 
        ELSE STR_TO_DATE(Gift_Date, '%Y-%m-%d') 
    END as Gift_Date,
        
    Gift_Amount,
    
    -- STRATEGIC PILLARS: Mapping the specific list to the 5 Big Goals I want to track
    CASE 
        -- Engineering & Interdisciplinarity
        WHEN Designation IN ('Engineering Department', 'Computer Science Department', 'Finance Club', 'Faculty Support') 
            THEN 'Engineering & Interdisciplinarity'
            
        -- Democracy & Technology (Civic Engagement)
        WHEN Designation IN ('Community Service Center', 'Veterans Center', 'Debate Team', 'History Department') 
            THEN 'Democracy & Technology'
            
        -- Liberal Arts & Humanities
        WHEN Designation IN ('Theatre Arts', 'Music Department', 'Library', 'Art') 
            THEN 'Liberal Arts & Humanities'
            
        -- Access & Affordability
        WHEN Designation IN ('Scholarships', 'DEI Initiatives', 'Student Health Center', 'Career Development Center', 'Study Abroad') 
            THEN 'Access & Affordability'
            
        -- Athletics
        WHEN Designation IN ('Men''s Basketball', 'Men''s Soccer', 'Women''s Soccer', 'Women''s Volleyball', 'Aquatic Center', 'Club Sports') 
            THEN 'Athletics'
            
        -- Everything else goes to the General Pot
        ELSE 'Unrestricted / Annual Fund'
    END as Strategic_Pillar,
    
    Gift_Type,
    Campaign_Year
    
FROM fact_giving_raw
WHERE Gift_Amount > 0;


-- Inspecting the donors dataset (especially the columns needed for analysis e.g. last_gift_date)

SELECT 
    d.ID, 
    d.Last_Gift_Date as Donor_Table_Says,
    MAX(g.Gift_Date) as Giving_Table_Says,
    -- Check if they match
    CASE 
        WHEN d.Last_Gift_Date = MAX(g.Gift_Date) THEN 'Match'
        ELSE 'MISMATCH' 
    END as Verdict
FROM donors_raw d
JOIN fact_giving_raw g ON d.ID = g.Donor_ID
GROUP BY d.ID, d.Last_Gift_Date
LIMIT 10;
-- Ans: there are mismatches! 
-- Action: I eventually calculated a reliable Real_Last_Gift_Date column based on MAX(Gift_Date) from the fact_giving table


DROP TABLE IF EXISTS dim_bio;
DROP TABLE IF EXISTS dim_prospect;

-- 2. CREATE dim_bio (The "Person")
CREATE TABLE dim_bio AS
SELECT
    ID as Entity_ID,
    First_Name,
    Last_Name,
    Full_Name,
    Gender,
    region as Region,
    Estimated_Age,
    
    -- SEGMENTATION
    donor_type as Entity_Type,
    CASE 
        WHEN Class_Year LIKE '%.0' THEN REPLACE(Class_Year, '.0', '')
        ELSE Class_Year
    END as Class_Year,
    
    -- HYGIENE (Do we have their job info?)
    CASE 
        WHEN Professional_Background IS NOT NULL AND Professional_Background != '' 
        THEN 1 ELSE 0 
    END as Has_Employment_Info

FROM donors_raw;




DROP TABLE IF EXISTS dim_prospect;

CREATE TABLE dim_prospect AS
SELECT
    d.ID as Entity_ID,
    
    -- WEALTH & STRATEGY
    d.Rating as Wealth_Rating,
    d.Professional_Background,
    d.Primary_Manager,
    d.Prospect_Stage,
    
    -- SCORES
    d.Engagement_Score,
    d.Legacy_Intent_Probability,
    d.Influence_Score,
    d.Network_Size,
    g.Real_Last_Gift_Date,
    DATEDIFF(NOW(), g.Real_Last_Gift_Date) as Days_Since_Last_Gift, 

    -- BENCHMARKS
    d.giving_velocity,
    d.rfm_score as Vendor_RFM_Score

FROM donors_raw d
LEFT JOIN (
    SELECT 
        Donor_ID, 
        MAX(Gift_Date) as Real_Last_Gift_Date,
        SUM(Gift_Amount) as Total_Lifetime_Giving,
        COUNT(*) as Total_Gift_Count 
    FROM fact_giving
    GROUP BY Donor_ID
) g ON d.ID = g.Donor_ID

WHERE d.Rating IS NOT NULL 
   OR d.Primary_Manager IS NOT NULL 
   OR d.Engagement_Score IS NOT NULL;
   
   
-- Stress Test (to see if the missing data will be captured live on Power BI. It worked!
UPDATE apex_advancement_dw.dim_prospect
SET Professional_Background = NULL
WHERE Wealth_Rating = 'M';

SET SQL_SAFE_UPDATES = 0;