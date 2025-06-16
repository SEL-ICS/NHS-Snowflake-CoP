### SEL ICB Patient Registers

## Intro 

In SEL, we use build our Patient GP register through the Primary Care data (currently Discovery). These are currently split up into 3 views based on different snapshots of the SEL register, each with a range of demographic data and long term condition flags;

1. DATA_LAB_SEL.FINAL.VW_SEL_REGISTERED_PATIENTS_LATEST
   - A live snapshot of the population, which is updated daily.

* DATA_LAB_SEL.FINAL.VW_SEL_REGISTERED_PATIENTS_MONTHLY
    - A series of monthly snapshots, showing the end of month register (i.e. 31st March 2025). 
    - Snapshots are on a rolling 36 month basis. 
    - Refreshed monthly on the 3rd day of the month.
* DATA_LAB_SEL.FINAL.VW_SEL_REGISTERED_PATIENTS_YEARLY
    - A series of yearly snapshots, showing the end of financial year register (i.e. 31st March 2025), with the exception of the latest financial year, which is in line with the latest end of month snapshot.
    - Snapshots are set to go back to 2017/18 (31st March 2018)
    - Refreshed monthly on the 3rd day of the month.





See below steps and scripts we've set up in Snowflake for creating these

## 1. Building Patient Cohort

We currently use a script that is written as a UDF (user defined function) in snowflake, that given a date parameter will return the patients registered to SEL practice at that date. It is also given a "report type" parameter which when "direct care" is provided to this, will include Type 1 opt out patients, otherwise these patients will be excluded

The function is as follows
```sql
-- Define a function with 2 variables - the Date of snapshot, and the report type. 
CREATE OR REPLACE FUNCTION STAGING.FN_RETURN_SEL_REGISTERED_POP (
    VAR_DATE DATE -- Date of Snapshot  
    ,VAR_REPORT_TYPE VARCHAR
)
-- Define the table columns that will be returned in the output
RETURNS TABLE 
(
    DATE_TIME_EXTRACT TIMESTAMP_LTZ(9)
	,DATE_RUN DATE
	,PATIENT_ID BIGINT
	,PERSON_ID BIGINT
	,SK_PATIENT_ID BIGINT
	,PRACTICE_CODE VARCHAR
	,GENDER_NAME VARCHAR
	,DATE_OF_BIRTH DATE
	,AGE INT
	,ETHNIC_CATEGORY_CODE VARCHAR
	,ETHNIC_CATEGORY_NAME VARCHAR
	,LSOA_CODE VARCHAR
	,UPRN_RALF_CODE VARCHAR
	,IS_TYPE1_OPT_OUT INT 
	,FINANCIAL_YEAR VARCHAR
)
AS
     $$
    -- CTE brings through registration data from the episode_of_care table a list of patients who are registered prior to the VAR_DATE. 
    -- This also checks that the registration end date either is NULL or is after the VAR_DATE.
    WITH CTE_ACTIVE AS (
	SELECT 
         E1."person_id" 
		,E1."patient_id"
		,E1."date_registered"
		,E1."dt_change"
	FROM "Discovery"."DDS"."episode_of_care" AS E1
		inner join "Discovery"."DDS"."concept" AS C1 
			ON C1."dbid" = E1."registration_type_concept_id"
	WHERE E1."date_registered" <= VAR_DATE
		AND (E1."date_registered_end"  > VAR_DATE
			OR E1."date_registered_end" IS NULL)
		AND C1."id" = 'FHIR_RT_R' -- Regular/GMS registration types
    )

    -- CTE to filter the active list to only the latest patient_ids for each person_id where there are multiple registrations for a person_id that appear as an active registration
    ,CTE_LATEST AS (
    SELECT DISTINCT
        E1."patient_id" -- Distinct list of patient_ids

    FROM CTE_ACTIVE AS E1
    WHERE NOT EXISTS ( -- in combination with the not exist operator, this filters give the latest only.
	   SELECT 1 
	   FROM CTE_ACTIVE AS E2
	   WHERE E1."person_id" = E2."person_id"
      -- 1) Patients with no date registered end dates for multiple practice.
	   	AND (E2."date_registered" > E1."date_registered"	
      -- 2) Patient with same date registered date, both will NULL end date.
	   		OR (E2."dt_change" > E1."dt_change"				
	   			AND E2."date_registered" = E1."date_registered")
	   	   )
	   )
    )
    --Putting into temp table the list of patient and person ids, with their latest type 1 dissented and consented dates as at the snapshot date_run
    ,CTE_TYPE1S AS (
    SELECT 
	   PERSON_ID
	   ,PATIENT_ID
	   ,MAX(CASE WHEN CONCEPT_GROUP = 'Dissent' THEN DATE_OBSERVATION ELSE NULL END) AS DATE_LATEST_DISSENT
	   ,MAX(CASE WHEN CONCEPT_GROUP = 'Consent' THEN DATE_OBSERVATION ELSE NULL END) AS DATE_LATEST_CONSENT

    FROM STAGING.PC_DISSENTING_PATIENT_REGISTER -- A register that tracks patients opt in and opt out codes, updated daily.

    WHERE DATE_OBSERVATION <= VAR_DATE

    GROUP BY PERSON_ID
	       ,PATIENT_ID
	)
    
    SELECT DISTINCT
	CURRENT_TIMESTAMP()                 AS DATE_TIME_EXTRACT
	,VAR_DATE                           AS DATE_RUN
	,PAT."id"                           AS PATIENT_ID
	,PAT."person_id"                    AS PERSON_ID
	,PSU."SK_PatientID"                 AS SK_PATIENT_ID
	,ORG."ods_code"                     AS PRACTICE_CODE
	,CON3."name"                        AS GENDER_NAME
	,DATE(PAT."date_of_birth")          AS DATE_OF_BIRTH
	,FLOOR(DATEDIFF(Month
                   ,PAT."date_of_birth"
                   ,VAR_DATE)/12)       AS AGE
	,IFNULL(CON4."code", '99')          AS ETHNIC_CATEGORY_CODE
	,IFNULL(CON4."name" , 'Not stated') AS ETHNIC_CATEGORY_NAME
	,PAD."lsoa_2011_code"               AS LSOA_CODE
	,MAX(RALF."ralf") OVER (PARTITION BY PAT."person_id") AS UPRN_RALF_CODE
	,CASE WHEN DATE_LATEST_DISSENT IS NULL OR DATE_LATEST_DISSENT < DATE_LATEST_CONSENT THEN 0 -- no dissent date found, or dissent date < constent date, conimplicit consent
		ELSE 1 --only dissent date found, or dissent date >= consent date, dissented
		END                             AS IS_TYPE1_OPT_OUT
	,DATA_LAB_SEL.FINAL.FN_DATE_TO_FINANCIAL_YEAR(VAR_DATE) AS FINANCIAL_YEAR
	--,T1.Latest_Dissent_Date
	--,T1.Latest_Consent_Date

    FROM "Discovery"."DDS"."patient" AS PAT
	INNER JOIN CTE_LATEST AS LAT
		ON LAT."patient_id" = PAT."id"
	INNER JOIN "Discovery"."DDS"."organization" AS ORG
		ON ORG."id" = PAT."organization_id"
	LEFT JOIN "Discovery"."DDS"."patient_address" AS PAD
		ON PAT."current_address_id" = PAD."id"
		AND PAT."id" = PAD."patient_id"
	LEFT JOIN "Discovery"."DDS"."patient_address_ralf" AS RALF
		ON RALF."patient_address_id" = PAD."id"
	LEFT JOIN "Discovery"."DDS"."patient_pseudo_id" AS PSU
		ON PSU."patient_id" = PAT."id"

	LEFT JOIN "Discovery"."DDS"."concept" AS CON3
		ON CON3."dbid" = PAT."gender_concept_id"
	LEFT JOIN "Discovery"."DDS"."concept" AS CON4
		ON CON4."dbid" = PAT."ethnic_code_concept_id"
		
	LEFT JOIN CTE_TYPE1S AS T1
		ON PAT."id" = T1.PATIENT_ID

	LEFT JOIN "Data_Store_Registries"."Deaths"."Deaths" AS MORT
		ON PSU."SK_PatientID" = MORT."Pseudo NHS Number"

    --Excludes patients if they have died on or before the snapshot date       
    WHERE COALESCE(PAT."date_of_death", MORT."REG_DATE_OF_DEATH", '2999-12-31') >= VAR_DATE -- DOD derived from Primary Care and Deaths registry is later than or equals to snapshot date
	  AND PAT."date_of_birth" <= VAR_DATE -- added to remove any negative ages due to data quality errors that might occur in the primary care data
      AND ORG."ods_code" <> 'G83024' -- Manually exclude Ingleton from all views stemming from this
      
	  -- report_type = 'direct care' will ignore type 1 objections
      AND (
		      VAR_REPORT_TYPE = 'direct care'
		      OR
		      (	--other report_types will apply type 1 objections
			     (COALESCE(VAR_REPORT_TYPE, 'N/A') <> 'direct care')
			     AND (
				      T1.DATE_LATEST_DISSENT IS NULL OR  T1.DATE_LATEST_DISSENT < T1.DATE_LATEST_CONSENT
				     )
		      )		
	      )

    $$

```

## 2. Scheduled Procedures
We then have Stored procedures set up to create tables daily (latest view) and monthly (monthly and yearly views). Below see examples of the monthly procedure that runs for the monthly and yearly register views.

```sql 
-- Set up a Stored procedure that can be run in a scheduled task
CREATE OR REPLACE PROCEDURE STAGING.SP_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER -- Set to excecute as owner to allow non-admins to run this stored procedure in DATA_LAB_SEL
AS 
BEGIN

/*	
======================================================================================================================================================

	Author - Cameron Bebbington
	Create Date - 25/09/2024
	Description - A procedure that creates monthly and yearly snapshots of the SEL registered population, 
    Monthly goes back 36 months, Yearly goes back to 2018-03-31 up until the end of the previous month from the point the script is run.
    
======================================================================================================================================================   
*/

-- MONTHLY REGISTER
CREATE OR REPLACE TABLE STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY
(
    DATE_TIME_EXTRACT TIMESTAMP_LTZ(9)
	,DATE_RUN DATE
	,PATIENT_ID BIGINT
	,PERSON_ID BIGINT
	,SK_PATIENT_ID BIGINT
	,PRACTICE_CODE VARCHAR
	,GENDER_NAME VARCHAR
	,DATE_OF_BIRTH DATE
	,AGE INT
	,ETHNIC_CATEGORY_CODE VARCHAR
	,ETHNIC_CATEGORY_NAME VARCHAR
	,LSOA_CODE VARCHAR
	,UPRN_RALF_CODE VARCHAR
	,IS_TYPE1_OPT_OUT INT -- 1 is dissent, 0 is consent
	,FINANCIAL_YEAR VARCHAR
);
COMMENT ON TABLE STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY IS 'A monthly view going back 36 months of the SEL Registered Population, derived from Discovery data. The DATE_RUN shows the end of month date which has the relevant snapshot of the population at that date.';

-- Loop through the last 36 end of month positions. 
BEGIN
    LET dat := LAST_DAY(DATEADD(year, -3, CURRENT_DATE()));
    WHILE (dat <= CURRENT_DATE())
    DO
    INSERT INTO STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY
    SELECT * FROM TABLE(STAGING.FN_RETURN_SEL_REGISTERED_POP(DATE(:dat), 'direct care'));
    
    dat := ADD_MONTHS(dat, 1);
    END WHILE;
END;

-- YEARLY REGISTER
CREATE OR REPLACE TABLE STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY
(
    DATE_TIME_EXTRACT TIMESTAMP_LTZ(9)
	,DATE_RUN DATE
	,PATIENT_ID BIGINT
	,PERSON_ID BIGINT
	,SK_PATIENT_ID BIGINT
	,PRACTICE_CODE VARCHAR
	,GENDER_NAME VARCHAR
	,DATE_OF_BIRTH DATE
	,AGE INT
	,ETHNIC_CATEGORY_CODE VARCHAR
	,ETHNIC_CATEGORY_NAME VARCHAR
	,LSOA_CODE VARCHAR
	,UPRN_RALF_CODE VARCHAR
	,IS_TYPE1_OPT_OUT INT -- 1 is dissent, 0 is consent
	,FINANCIAL_YEAR VARCHAR
);
COMMENT ON TABLE STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY IS 'A yearly view going back to 2018-03-31 of the SEL Registered Population, derived from Discovery data. The DATE_RUN shows the end of financial year date, as well as the latest end of month date for the current financial year which has the relevant snapshot of the population at that date.';

-- Loop through all financial year end of march dates up until the latest full financial year.
BEGIN
    LET dat := DATE('2018-03-31');
    WHILE (dat <= CURRENT_DATE())
    DO
    INSERT INTO STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY
    SELECT * FROM TABLE(STAGING.FN_RETURN_SEL_REGISTERED_POP(DATE(:dat), 'direct care'));

    dat := DATEADD(YEAR, 1, dat);
    END WHILE;
END;

-- Final statement to import the latest months register into the yearly table.
INSERT INTO STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY
SELECT * FROM TABLE(STAGING.FN_RETURN_SEL_REGISTERED_POP(DATE(LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1))), 'direct care'))
WHERE (SELECT MAX(DATE_RUN) FROM STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY) <> LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1));

RETURN 'SEL Monthly and Yearly Registers Update Completed';
END    

```

## 3. Scheduled Task
This is then scheduled as a task that runs on the 3rd day of every month to re-create these tables.
```sql
CREATE OR REPLACE TASK FINAL.TASK_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES
    WAREHOUSE = SEL_ANALYTICS_XS
    SCHEDULE = 'USING CRON 0 7 3 * * Europe/London' -- Runs at 07:00 UTC on the 3rd day of each month avoiding weekends. Europe/London format accounts for BST/GMT changes.
    USER_TASK_TIMEOUT_MS = 1800000
    COMMENT = 'Task to run the SP_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES on the 3rd day of each month'
	AS CALL STAGING.SP_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES();
```


