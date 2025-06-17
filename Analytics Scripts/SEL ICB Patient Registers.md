 ## SEL ICB Patient Registers
<!-- no toc -->
- [Intro](#intro)
- [1. Initialising Patient Register](#1-initialising-patient-register)
- [2. Register Stored Procedures](#2-register-stored-procedures)
- [3. Register Scheduled Task](#3-register-scheduled-task)
- [4. LTC Register Staging](#4-ltc-register-staging)
- [5. LTC Register Function](#5-ltc-register-function)
- [6. LTC Scheduled tasks](#6-ltc-scheduled-tasks)
- [7. SEL Register \& LTC View](#7-sel-register--ltc-view)


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

## 1. Initialising Patient Register

We currently use a script that is written as a UDF (user defined function) in snowflake, that given a date parameter will return the patients registered to SEL practice at that date. It is also given a "report type" parameter which when "direct care" is provided to this, will include Type 1 opt out patients, otherwise these patients will be excluded

The function is as follows
```sql
-- Define a function with 2 variables - the Date of snapshot, and the report type. 
CREATE OR REPLACE FUNCTION DATA_LAB_SEL.STAGING.FN_RETURN_SEL_REGISTERED_POP (
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
    -- CTE brings thro- [Intro](#intro)
- [1. Building Patient Cohort](#1-building-patient-cohort)
- [2. Scheduled Procedures](#2-scheduled-procedures)
- [3. Scheduled Task](#3-scheduled-task)
ugh registration data from the episode_of_care table a list of patients who are registered prior to the VAR_DATE. 
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

## 2. Register Stored Procedures
We then have Stored procedures set up to create tables daily (latest view) and monthly (monthly and yearly views). Below see examples of the monthly procedure that runs for the monthly and yearly register views.

```sql 
-- Set up a Stored procedure that can be run in a scheduled task
CREATE OR REPLACE PROCEDURE DATA_LAB_SEL.STAGING.SP_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES()
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
CREATE OR REPLACE TABLE DATA_LAB_SEL.STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY
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
COMMENT ON TABLE DATA_LAB_SEL.STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY IS 'A monthly view going back 36 months of the SEL Registered Population, derived from Discovery data. The DATE_RUN shows the end of month date which has the relevant snapshot of the population at that date.';

-- Loop through the last 36 end of month positions. 
BEGIN
    LET dat := LAST_DAY(DATEADD(year, -3, CURRENT_DATE()));
    WHILE (dat <= CURRENT_DATE())
    DO
    INSERT INTO DATA_LAB_SEL.STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY
    SELECT * FROM TABLE(DATA_LAB_SEL.STAGING.FN_RETURN_SEL_REGISTERED_POP(DATE(:dat), 'direct care'));
    
    dat := ADD_MONTHS(dat, 1);
    END WHILE;
END;

-- YEARLY REGISTER
CREATE OR REPLACE TABLE DATA_LAB_SEL.STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY
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
COMMENT ON TABLE DATA_LAB_SEL.STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY IS 'A yearly view going back to 2018-03-31 of the SEL Registered Population, derived from Discovery data. The DATE_RUN shows the end of financial year date, as well as the latest end of month date for the current financial year which has the relevant snapshot of the population at that date.';

-- Loop through all financial year end of march dates up until the latest full financial year.
BEGIN
    LET dat := DATE('2018-03-31');
    WHILE (dat <= CURRENT_DATE())
    DO
    INSERT INTO DATA_LAB_SEL.STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY
    SELECT * FROM TABLE(DATA_LAB_SEL.STAGING.FN_RETURN_SEL_REGISTERED_POP(DATE(:dat), 'direct care'));

    dat := DATEADD(YEAR, 1, dat);
    END WHILE;
END;

-- Final statement to import the latest months register into the yearly table.
INSERT INTO DATA_LAB_SEL.STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY
SELECT * FROM TABLE(DATA_LAB_SEL.STAGING.FN_RETURN_SEL_REGISTERED_POP(DATE(LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1))), 'direct care'))
WHERE (SELECT MAX(DATE_RUN) FROM DATA_LAB_SEL.STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY) <> LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1));

RETURN 'SEL Monthly and Yearly Registers Update Completed';
END    

```

## 3. Register Scheduled Task
This is then scheduled as a task that runs on the 3rd day of every month to re-create these tables.
```sql
CREATE OR REPLACE TASK DATA_LAB_SEL.FINAL.TASK_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES
    WAREHOUSE = SEL_ANALYTICS_XS
    SCHEDULE = 'USING CRON 0 7 3 * * Europe/London' -- Runs at 07:00 UTC on the 3rd day of each month avoiding weekends. Europe/London format accounts for BST/GMT changes.
    USER_TASK_TIMEOUT_MS = 1800000
    COMMENT = 'Task to run the SP_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES on the 3rd day of each month'
	AS CALL DATA_LAB_SEL.STAGING.SP_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES();
```
## 4. LTC Register Staging

Along side the update to the standard patient register, we also create a register of Long term conditions for patients, with flags as 1 or 0 to indicate if a patient has a LTC such as Asthma or Cancer. This is combined with the above register to create the aforementioned views.

For these to be created this is done in 2 steps.

The first is a Stored Procedure that creates a staging table DATA_LAB_SEL.STAGING.PC_LTC_OBSERVATION_MEDICATION that list out various diagnosis/conditions/resolved diagnosis observations, and relevant medications to be queried in the next step.

```sql
CREATE OR REPLACE PROCEDURE DATA_LAB_SEL.STAGING.SP_UPDATE_PC_LTC_OBSERVATION_MEDICATION()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER 
AS 

--============================================================================================================================
--Populate staging table for SNOMED PCD Refset, with SNOMED codes cast to varchar datatype------------------------------------
--============================================================================================================================
-- User Created - Mo Davies

-- Object purpose - To stage diagnosis, resolved diagnosis and medication codes into an initial table for the use in creating the LTC tables.

--============================================================================================================================

BEGIN

CREATE OR REPLACE TABLE DATA_LAB_SEL.STAGING.PC_LTC_OBSERVATION_MEDICATION 
(
	TABLE_NAME VARCHAR -- Either RESOLVED, MEDICATION_ORDER or DIAGNOSIS
	,PERSON_ID BIGINT
	,DATE_OBSERVATION DATE
	,CLUSTER_ID VARCHAR
    ,RESULT_VALUE FLOAT
)
COMMENT = 'Reduced discovery observation table that contains only observations and medications related to QOF LTCs. Updated monthly through the SP SP_UPDATE_PC_LTC_OBSERVATION_MEDICATION';

INSERT INTO DATA_LAB_SEL.STAGING.PC_LTC_OBSERVATION_MEDICATION 

SELECT
    'RESOLVED' AS TABLE_NAME
	,OBS."person_id" AS PERSON_ID
	,OBS."clinical_effective_date" AS DATE_OBSERVATION
	,REF.CLUSTER_ID
    ,OBS."result_value" AS RESULT_VALUE

FROM "Discovery"."DDS"."observation" OBS
LEFT JOIN "Discovery"."DDS"."concept_map" AS MAP
	ON MAP."legacy" = OBS."non_core_concept_id"	    -- mapping non_core to core Id to get SNOMED IDs from Old "Read" Codes IDs
LEFT JOIN "Discovery"."DDS"."concept" AS CON	
	ON CON."dbid" = MAP."core"					    -- bring through SNOMED codes and terms
LEFT JOIN DATA_LAB_SEL.FINAL.VW_LOOKUP_PRIMARY_CARE_DOMAIN_REF_SET AS REF
	ON CON."code" = REF.SNOMED_CODE						-- View on the PCD Refset Dictionary Item that takes only the latest relevant ruleset for each CLUSTER_ID.  Gets PCD Refset Cluster IDs for QOF Groupings
WHERE 
		CLUSTER_ID IN
			('AFIBRES_COD' -- Atrial Fibrillation
			,'ASTRES_COD' -- Asthma
			,'CKD1AND2_COD', 'CKDRES_COD' -- CKD
			,'COPDRES_COD' -- COPD
			,'DEPRES_COD' -- Depression
			,'DMRES_COD' -- Diabetes
			,'EPILRES_COD' -- Epilepsy
			,'HFRES_COD'-- Heart Failure
			,'HYPRES_COD' -- Hypertension
			,'MHREM_COD' -- Mental Health
			,'ADHDREM_COD' -- ADHD (non-ltc)
			,'EXSMOK_COD' -- Exsmoker (non-LTC)
			) 													-- all relevant "diagnosis resolved" codes
		AND OBS."clinical_effective_date" <= LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1 ))	-- up to the last day of last completed month
;

--============================================================================================================================
--Populate staging table for medication orders--------------------------------------------------------------------------------
--============================================================================================================================

INSERT INTO DATA_LAB_SEL.STAGING.PC_LTC_OBSERVATION_MEDICATION

SELECT 
	 'MEDICATION_ORDER' AS TABLE_NAME
	,MED."person_id" AS PERSON_ID
	,MED."clinical_effective_date" AS DATE_OBSERVATION
	,CASE WHEN BNF.BNF_SECTION_NAME = 'Antiepileptic drugs' THEN 'EPILDRUG_COD'
			   WHEN BNF.BNF_CHEMICAL_SUBSTANCE_NAME IN ('Lithium citrate', 'Lithium carbonate') THEN 'LIT_COD'
               WHEN REF.CODE_GROUP = 'Asthma Medication' THEN 'ASTTRT_COD'
	END AS CLUSTER_ID
    ,NULL AS RESULT_VALUE -- not needed in medications
FROM "Discovery"."DDS"."medication_order" AS MED			-- Note: medication_Statement appeared to give wrong results, using medication_order instead gives figures closer to those in EMIS.
				
LEFT JOIN "Discovery"."DDS"."concept" AS CON				
	ON CON."dbid" = MED."core_concept_id"
LEFT JOIN DATA_LAB_SEL.FINAL.LOOKUP_SEL_CONCEPT_GROUPS AS REF
	ON CON."code" = REF.SNOMED_CODE			-- SEL defined SNOMED/DM+D groupings.
LEFT JOIN DATA_LAB_SEL.FINAL.VW_LOOKUP_PRESCRIBING_SNOMED_BNF_MAP AS MAP
	ON CON."code" = MAP.SNOMED_CODE 		-- BNF to SNOMED mapping from NHSBSA
LEFT JOIN DATA_LAB_SEL.FINAL.VW_LOOKUP_PRESCRIBING_BNF AS BNF -- BNF Hierarchy Reference table from ePACT
	ON MAP.BNF_PRESENTATION_CODE = BNF.BNF_PRESENTATION_CODE
WHERE
		(      REF.CODE_GROUP = 'Asthma Medication' 
            OR BNF.BNF_SECTION_NAME = 'Antiepileptic drugs' 
			OR BNF.BNF_CHEMICAL_SUBSTANCE_NAME IN ('Lithium citrate', 'Lithium carbonate') 
        )
		AND "MED"."clinical_effective_date" <= LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1 ))	-- up to the last day of last completed month
;

--============================================================================================================================
--Populate staging table for PCD Refset defined diagnosis observations---------------------------------------------------------------------------
--============================================================================================================================

INSERT INTO DATA_LAB_SEL.STAGING.PC_LTC_OBSERVATION_MEDICATION

SELECT
	'DIAGNOSIS' AS TABLE_NAME
	, OBS."person_id" AS PERSON_ID
	, OBS."clinical_effective_date" AS DATE_OBSERVATION
	, REF.CLUSTER_ID
	, OBS."result_value" AS RESULT_VALUE					

FROM "Discovery"."DDS"."observation" OBS
LEFT JOIN "Discovery"."DDS"."concept_map" AS MAP
	ON MAP."legacy" = OBS."non_core_concept_id"	    -- mapping non_core to core Id to get SNOMED IDs from Old "Read" Codes IDs
LEFT JOIN "Discovery"."DDS"."concept" AS CON	
	ON CON."dbid" = MAP."core"					    -- bring through SNOMED codes and terms
LEFT JOIN DATA_LAB_SEL.FINAL.VW_LOOKUP_PRIMARY_CARE_DOMAIN_REF_SET AS REF
	ON CON."code" = REF.SNOMED_CODE						-- Get PCD Refset Cluster IDs for QOF Groupings

	WHERE
		CLUSTER_ID IN
			('AFIB_COD' -- Atrial Fibrillation
			,'AST_COD' -- Asthma
			,'CAN_COD' -- Cancer
			,'CHD_COD' -- CHD
			,'CKD_COD' -- CKD
			,'COPD_COD',  'FEV1FVC_COD', 'FEV1FVCL70_COD' -- COPD
			,'DEM_COD' -- Dementia
			,'DEPR_COD' -- Depression
			,'DM_COD'-- Diabetes
			,'EPIL_COD' -- Epilepsy
			,'HF_COD', 'HFLVSD_COD', 'REDEJCFRAC_COD' -- Heart Failure
			,'HYP_COD' -- Hypertension
			,'LD_COD' -- LD
			,'MH_COD', 'LITSTP_COD' -- Mental Health
			,'NDH_COD', 'PRD_COD', 'IGT_COD' -- NDH
			,'FF_COD', 'OSTEO_COD', 'DXA_COD', 'DXA2_COD'-- Osteoporosis (inc frailty fracture)
			,'PAD_COD' -- PAD
			,'PALCARE_COD' -- Palliative Care
			,'RARTH_COD' -- Rheumatoid arthritis register
			,'STRK_COD','TIA_COD' -- Stroke & TIA
			,'ADHD_COD' -- ADHD (non-LTC)
			,'LSMOK_COD' -- Smoker (non-LTC)
			,'BMI_COD' ,'BMI30_COD' ,'BMIOBESE_COD' -- Obesity (non-LTC)
			) 
		AND "OBS"."clinical_effective_date" <= LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1 ))	-- up to the last day of last completed month
;

--============================================================================================================================
-- Populate staging table for additional non-PCD refset diagnosis observations. The CODE_GROUPS relative snomed codes are locally derived by SEL with aid of clinicians and existing EMIS searches.------------------------------------------------
--============================================================================================================================

INSERT INTO DATA_LAB_SEL.STAGING.PC_LTC_OBSERVATION_MEDICATION
SELECT
	'DIAGNOSIS' AS TABLE_NAME
	,OBS."person_id" AS PERSON_ID
	,OBS."clinical_effective_date" AS DATE_OBSERVATION
	,GRP.CODE_GROUP AS CLUSTER_ID
	,OBS."result_value" AS RESULT_VALUE	
    
FROM "Discovery"."DDS"."observation" OBS
LEFT JOIN "Discovery"."DDS"."concept_map" AS MAP
	ON MAP."legacy" = OBS."non_core_concept_id"	    -- mapping non_core to core Id to get SNOMED IDs from Old "Read" Codes IDs
LEFT JOIN "Discovery"."DDS"."concept" AS CON	
	ON CON."dbid" = MAP."core"					    -- bring through SNOMED codes and terms
LEFT JOIN DATA_LAB_SEL.FINAL.LOOKUP_SEL_CONCEPT_GROUPS AS GRP
    ON GRP.SNOMED_CODE = CON."code" -- SEL Defined code groupings.

	WHERE
		(
        CODE_GROUP IN ('Autism', 'Diabetes Type 1', 'Diabetes Type 2 or Other', 'Anxiety', 'Sickle Cell Disease')-- all relevant diagnosis codes
        )
		AND "OBS"."clinical_effective_date" <= LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1 ))	-- up to the last day of last completed month
;
RETURN 'DATA_LAB_SEL.STAGING.PC_LTC_OBSERVATION_MEDICATION created';
END;

```
## 5. LTC Register Function

We then have a UDF that can build the LTC register given a date parameter, and similar to the patient registers we have a stored procedure that is run on this function for Monthly and Yearly snapshots. We don't run this daily due to the size and frequency being too significant for a daily refresh.

The LTC table UDF
```sql
-- Change Schema to FINAL and 

CREATE OR REPLACE FUNCTION STAGING.FN_RETURN_PC_LTC_REGISTER (
    VAR_DATE DATE
)
RETURNS TABLE 
(
	SK_PATIENT_ID BIGINT
	,PERSON_ID BIGINT
	,DATE_RUN DATE 
	,IS_AFIB INT
	,DATE_AFIB DATE
	,IS_ASTHMA INT
	,DATE_ASTHMA DATE
	,IS_CANCER INT
	,DATE_CANCER DATE
	,IS_CHD INT
	,DATE_CHD DATE
	,IS_CKD INT
	,DATE_CKD DATE
	,IS_COPD INT
	,DATE_COPD DATE
	,IS_DEMENTIA INT
	,DATE_DEMENTIA DATE
	,IS_DEPRESSION INT
	,DATE_DEPRESSION DATE
	,IS_DIABETES INT
	,DATE_DIABETES DATE
	,IS_EPILEPSY INT
	,DATE_EPILEPSY DATE
	,IS_HEART_FAILURE INT
	,DATE_HEART_FAILURE DATE
	,IS_HYPERTENSION INT
	,DATE_HYPERTENSION DATE
	,IS_LD INT
	,DATE_LD DATE
	,IS_MH1_DIAGNOSIS INT
	,DATE_MH1_DIAGNOSIS  DATE
	,IS_MH2_LITHIUM INT
	,DATE_MH2_LITHIUM  DATE
	,IS_NDH INT
	,DATE_NDH DATE
	,IS_OSTEOPEROSIS INT
	,DATE_OSTEOPEROSIS DATE
	,IS_PAD INT
	,DATE_PAD DATE
	,IS_PALCARE INT
	,DATE_PALCARE DATE
	,IS_RARTH INT
	,DATE_RARTH DATE
	,IS_STROKE_OR_TIA INT
	,DATE_STROKE_OR_TIA DATE
	,IS_MH_NO_REMISSION INT
	,DATE_MH_NO_REMISSION DATE

    -- All age registers
	,IS_ASTHMA_ALL_AGES INT
	,DATE_ASTHMA_ALL_AGES DATE
	,IS_DEPRESSION_ALL_AGES INT
	,DATE_DEPRESSION_ALL_AGES DATE
	,IS_DIABETES_ALL_AGES INT
	,DATE_DIABETES_ALL_AGES DATE
	,IS_EPILEPSY_ALL_AGES INT
	,DATE_EPILEPSY_ALL_AGES DATE

    -- Non-LTC Registers
	,IS_ADHD INT
	,DATE_ADHD	DATE
	,IS_AUTISM INT
	,DATE_AUTISM DATE
	,IS_DIABETES_TYPE_1 INT
	,DATE_DIABETES_TYPE_1 DATE
	,IS_DIABETES_TYPE_2 INT
	,DATE_DIABETES_TYPE_2 DATE
	,IS_OBESITY INT
	,DATE_OBESITY DATE
	,IS_OBESITY_ALL_AGES INT	
	,DATE_OBESITY_ALL_AGES DATE
	,IS_SMOKER INT
	,DATE_SMOKER DATE

	)
AS
$$

-- CTE that brings through all PERSON_IDs, relevant Ages and Dates related to the Monthly and Yearly register snapshots
WITH CTE_POPULATION AS (
SELECT 
     PERSON_ID
    ,SK_PATIENT_ID
    ,AGE
    ,DATE_RUN
    
FROM STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY AS POP
WHERE VAR_DATE = POP.DATE_RUN

UNION ALL

SELECT 
     PERSON_ID
    ,SK_PATIENT_ID
    ,AGE
    ,DATE_RUN
    
FROM STAGING.PC_SEL_REGISTERED_PATIENTS_YEARLY AS POP
WHERE VAR_DATE < (SELECT MIN(DATE_RUN) FROM STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY)
AND VAR_DATE = POP.DATE_RUN

)

-- CTE to define latest dates of resolved codes where these exist relative to the VAR_DATE
,LTC_RESOLVED AS (  
SELECT 
     OBS.PERSON_ID
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'AFIBRES_COD'  THEN OBS.DATE_OBSERVATION END) AS AFIBRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'ASTRES_COD'   THEN OBS.DATE_OBSERVATION END) AS ASTRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'CKD1AND2_COD' THEN OBS.DATE_OBSERVATION END) AS CKD12LAT_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'CKDRES_COD'   THEN OBS.DATE_OBSERVATION END) AS CKDRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'COPDRES_COD'  THEN OBS.DATE_OBSERVATION END) AS COPDRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'DEPRES_COD' 
        AND OBS.DATE_OBSERVATION >= '2006-04-01'   THEN OBS.DATE_OBSERVATION END) AS DEPRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'DMRES_COD'    THEN OBS.DATE_OBSERVATION END) AS DMRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'EPILRES_COD'  THEN OBS.DATE_OBSERVATION END) AS EPILRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'HFRES_COD'    THEN OBS.DATE_OBSERVATION END) AS HFRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'HYPRES_COD'   THEN OBS.DATE_OBSERVATION END) AS HYPRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'MHREM_COD'    THEN OBS.DATE_OBSERVATION END) AS MHREM_DAT	 
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'ADHDREM_COD'  THEN OBS.DATE_OBSERVATION END) AS ADHDRES_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'EXSMOK_COD'   THEN OBS.DATE_OBSERVATION END) AS EXSMOK_DAT

FROM STAGING.PC_LTC_OBSERVATION_MEDICATION  AS OBS

WHERE OBS.DATE_OBSERVATION <= VAR_DATE-- only dates before achievement date, use earliest_date_included as this is indexed
  AND TABLE_NAME = 'RESOLVED'
GROUP BY OBS.PERSON_ID
)



--CTE to define latest medication dates where these exist relative to the VAR_DATE
,LTC_MEDICATION AS (  
SELECT 
	MED.PERSON_ID
	,MAX(CASE WHEN MED.CLUSTER_ID = 'ASTTRT_COD'   THEN  MED.DATE_OBSERVATION END) AS ASTTRT_DAT
	,MAX(CASE WHEN MED.CLUSTER_ID = 'EPILDRUG_COD' THEN  MED.DATE_OBSERVATION END) AS EPILTRT_DAT
	,MAX(CASE WHEN MED.CLUSTER_ID = 'LIT_COD'      THEN  MED.DATE_OBSERVATION END) AS LIT_DAT

FROM STAGING.PC_LTC_OBSERVATION_MEDICATION AS MED
					
WHERE MED.DATE_OBSERVATION <= VAR_DATE -- only dates before achievement date, use earliest_date_included as this is indexed
    AND MED.DATE_OBSERVATION >= DATEADD(DAY, 1, DATEADD(month,-12, VAR_DATE))
    AND MED.TABLE_NAME = 'MEDICATION_ORDER'

GROUP BY MED.PERSON_ID
)


--CTE to define diagnosis related to LTCs, showing latest date where not proceeded by a resolved code, or other logic applies relative to the VAR_DATE.
,LTC_DIAGNOSIS AS (
    SELECT 
    OBS.PERSON_ID

--Key Date Fields
-- Atrial Fibrillation
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'AFIB_COD' AND OBS.DATE_OBSERVATION > IFNULL(AFIBRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS AFIB_DAT
    
    -- Asthma
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'AST_COD' AND OBS.DATE_OBSERVATION > IFNULL(ASTRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS AST_DAT
    
    -- Cancer 
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'CAN_COD' AND OBS.DATE_OBSERVATION >= '2003-04-01' THEN OBS.DATE_OBSERVATION END) AS CAN_DAT
    
    -- CHD
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'CHD_COD' THEN OBS.DATE_OBSERVATION END) AS CHD_DAT
    
    -- CKD
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'CKD_COD' AND OBS.DATE_OBSERVATION > IFNULL(CKDRES_DAT, '1900-01-01')
    									      AND OBS.DATE_OBSERVATION > IFNULL(CKD12LAT_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS CKD_DAT
    -- COPD
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'COPD_COD' AND OBS.DATE_OBSERVATION > IFNULL(COPDRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS COPD_DAT
    
    -- Dementia
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'DEM_COD' THEN OBS.DATE_OBSERVATION END) AS DEM_DAT
    
    -- Depression
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'DEPR_COD' AND OBS.DATE_OBSERVATION >= '2006-04-01' 
    									       AND OBS.DATE_OBSERVATION > IFNULL(DEPRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS DEPR_DAT
    -- Diabetes
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'DM_COD' AND OBS.DATE_OBSERVATION > IFNULL(DMRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS DM_DAT
    
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'DM_COD' THEN OBS.DATE_OBSERVATION END) AS DMLAT_DAT
    
    -- Epilepsy
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'EPIL_COD' AND OBS.DATE_OBSERVATION > IFNULL(EPILRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS EPIL_DAT
    
    -- Heart Failure
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'HF_COD' AND OBS.DATE_OBSERVATION > IFNULL(HFRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS HF_DAT


    -- Hypertension
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'HYP_COD' AND OBS.DATE_OBSERVATION > IFNULL(HYPRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS HYP_DAT
    
    -- LD
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'LD_COD' THEN OBS.DATE_OBSERVATION END) AS LD_DAT
    
    -- Mental Health (Register 1)
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'MH_COD' THEN OBS.DATE_OBSERVATION END) AS MH_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'LITSTP_COD' THEN OBS.DATE_OBSERVATION END) AS LITSTP_DAT
    
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'MH_COD' AND OBS.DATE_OBSERVATION > IFNULL(MHREM_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS MH_UR_DAT
    
    
    -- Non-Diabetic Hyperglycaemia
    ,MIN(CASE WHEN OBS.CLUSTER_ID IN ('NDH_COD', 'PRD_COD', 'IGT_COD') THEN OBS.DATE_OBSERVATION END) AS NDH_DAT
    
    -- Osteoporosis
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'OSTEO_COD' THEN OBS.DATE_OBSERVATION END) AS OSTEO_DAT
    
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'FF_COD' AND OBS.DATE_OBSERVATION >= '2012-04-01' THEN OBS.DATE_OBSERVATION END) AS FFLAT_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'FF_COD' AND OBS.DATE_OBSERVATION >= '2014-04-01' THEN OBS.DATE_OBSERVATION END) AS FF1LAT_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'DXA_COD' THEN OBS.DATE_OBSERVATION END) AS DXALAT_DAT
    ,MAX(CASE WHEN OBS.CLUSTER_ID = 'DXA2_COD'  -- codes where value recorded by DXA scan
    						AND OBS.RESULT_VALUE <= -2.5 THEN OBS.DATE_OBSERVATION END) AS DXA2LAT_DAT
    
    -- PAD
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'PAD_COD' THEN OBS.DATE_OBSERVATION END) AS PAD_DAT
    
    -- Palliative Care
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'PALCARE_COD' THEN OBS.DATE_OBSERVATION END) AS PALCARE_DAT
    
    -- Rheumatoid arthritis
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'RARTH_COD' THEN OBS.DATE_OBSERVATION END) AS RARTH_DAT
    
    -- Stroke & TIA
    ,MIN(CASE WHEN OBS.CLUSTER_ID IN ('STRK_COD','TIA_COD') THEN OBS.DATE_OBSERVATION END) AS STIA_DAT
    
    -- ADHD
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'ADHD_COD' AND OBS.DATE_OBSERVATION > IFNULL(ADHDRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS ADHD_DAT
    
    -- Autism
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'Autism' THEN OBS.DATE_OBSERVATION END) AS AUT_DAT
    
    -- Diabetes Type 1
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'Diabetes Type 1' THEN OBS.DATE_OBSERVATION END) AS DM1_DAT
    -- Diabetes Type 2
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'Diabetes Type 2 or Other' AND OBS.DATE_OBSERVATION > IFNULL(DMRES_DAT, '1900-01-01') THEN OBS.DATE_OBSERVATION END) AS DM2_DAT
    
    -- Smoker (12 months)
    ,MIN(CASE WHEN OBS.CLUSTER_ID = 'LSMOK_COD' AND OBS.DATE_OBSERVATION > IFNULL(EXSMOK_DAT, '1900-01-01')
    									  AND OBS.DATE_OBSERVATION >= DATEADD(DAY, 1, DATEADD(month,-12, VAR_DATE))
    			THEN OBS.DATE_OBSERVATION END) AS SMOK_DAT
    
    -- Obesity
    ,MIN(CASE WHEN ((OBS.CLUSTER_ID IN ('BMI_COD') 
                    AND RESULT_VALUE >= 30)
    			 OR OBS.CLUSTER_ID IN ('BMI30_COD', 'BMIOBESE_COD')
                 )
    		  AND OBS.DATE_OBSERVATION >= DATEADD(DAY, 1, DATEADD(month,-12, VAR_DATE)) THEN OBS.DATE_OBSERVATION END) AS BMI_DAT


FROM STAGING.PC_LTC_OBSERVATION_MEDICATION AS OBS 
	LEFT JOIN LTC_RESOLVED AS RES 
		ON RES.PERSON_ID = OBS.PERSON_ID				
					
WHERE OBS.DATE_OBSERVATION <= VAR_DATE
  AND OBS.TABLE_NAME = 'DIAGNOSIS'
  
GROUP BY OBS.PERSON_ID
)


-- Creates the table with LTC flags and dates, 1 if the person is on the register, NULL if not.
SELECT 
	 POP.SK_PATIENT_ID
	,POP.PERSON_ID
	,DATE(VAR_DATE) AS VAR_DATE

	-- Atrial Fibrillation
	,IFF(AFIB_DAT IS NOT NULL, 1, NULL) AS IS_AFIB
	,IFF(AFIB_DAT IS NOT NULL, AFIB_DAT, NULL) AS IS_AFIB

	-- Asthma 
	,IFF(AST_DAT IS NOT NULL 
			AND Age >= 6
			AND ASTTRT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-12, VAR_DATE)) AND VAR_DATE
				,1 , NULL) AS IS_ASTHMA
	,IFF(AST_DAT IS NOT NULL 
			AND Age >= 6
			AND ASTTRT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-12, VAR_DATE)) AND VAR_DATE
				,AST_DAT , NULL) AS DATE_ASTHMA

	-- Cancer
	,IFF(CAN_DAT IS NOT NULL, 1, NULL) AS IS_CANCER
	,IFF(CAN_DAT IS NOT NULL, CAN_DAT, NULL) AS DATE_CANCER
	-- CHD
	,IFF(CHD_DAT IS NOT NULL , 1 , NULL) AS IS_CHD
	,IFF(CHD_DAT IS NOT NULL , CHD_DAT , NULL) AS DATE_CHD

	-- CKD  
	,IFF(CKD_DAT IS NOT NULL, 1 , NULL) AS IS_CKD
	,IFF(CKD_DAT IS NOT NULL, CKD_DAT , NULL) AS DATE_CKD

	-- COPD 
	,IFF( COPD_DAT IS NOT NULL, 1 , NULL) AS IS_COPD
	,IFF( COPD_DAT IS NOT NULL, COPD_DAT , NULL) AS DATE_COPD
	-- Dementia
	,IFF( DEM_DAT IS NOT NULL , 1 , NULL) AS IS_DEMENTIA
	,IFF( DEM_DAT IS NOT NULL , DEM_DAT , NULL) AS DATE_DEMENTIA

	--Depression
	,IFF( DEPR_DAT IS NOT NULL 
			AND Age >= 18, 1 , NULL) AS IS_DEPRESSION
	,IFF( DEPR_DAT IS NOT NULL 
			AND Age >= 18, DEPR_DAT , NULL) AS DATE_DEPRESSION

	-- Diabetes
	,IFF( DM_DAT IS NOT NULL
			AND Age >= 17 , 1 , NULL) AS IS_DIABETES -- not a mistake, age is 17 and up!
	,IFF( DM_DAT IS NOT NULL
			AND Age >= 17 , DM_DAT , NULL) AS DATE_DIABETES	

	-- Epilepsy
	,IFF( EPIL_DAT IS NOT NULL 
			AND Age >= 18
			AND EPILTRT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-6, VAR_DATE)) AND VAR_DATE
			, 1 , NULL) AS IS_EPILEPSY
	,IFF( EPIL_DAT IS NOT NULL 
			AND Age >= 18
			AND EPILTRT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-6, VAR_DATE)) AND VAR_DATE
			, EPIL_DAT , NULL) AS DATE_EPILEPSY

	-- Heart Failure ENCOMPASSES HF1 & HF2
	,IFF( HF_DAT IS NOT NULL , 1 , NULL) AS IS_HEART_FAILURE
	,IFF( HF_DAT IS NOT NULL , HF_DAT , NULL) AS DATE_HEART_FAILURE

	-- Hypertension
	,IFF( HYP_DAT IS NOT NULL , 1 , NULL) AS IS_HYPERTENSION
	,IFF( HYP_DAT IS NOT NULL , HYP_DAT , NULL) AS DATE_HYPERTENSION

	-- LD
	,IFF( LD_DAT IS NOT NULL , 1 , NULL) AS IS_LD
	,IFF( LD_DAT IS NOT NULL , LD_DAT , NULL) AS DATE_LD

	-- Mental Health MH1
	,IFF( MH_DAT IS NOT NULL , 1 , NULL) AS IS_MH1_DIAGNOSIS 
	,IFF( MH_DAT IS NOT NULL , MH_DAT , NULL) AS DATE_MH1_DIAGNOSIS 

	-- Mental Health MH2
	,IFF( 
		(LIT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-6, VAR_DATE)) AND VAR_DATE
			AND (LIT_DAT > LITSTP_DAT
				OR LIT_DAT IS NOT NULL AND LITSTP_DAT IS NULL))
			, 1, NULL ) AS IS_MH2_LITHIUM
	,IFF( 
		(LIT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-6, VAR_DATE)) AND VAR_DATE
			AND (LIT_DAT > LITSTP_DAT
				OR LIT_DAT IS NOT NULL AND LITSTP_DAT IS NULL))
			, LIT_DAT, NULL ) AS DATE_MH2_LITHIUM
	-- Mental Health Non-Remission


	-- NHD 
	,IFF( NDH_DAT IS NOT NULL
		AND (DMLAT_DAT >= IFF(MONTH(DATE(VAR_DATE)) IN (1, 2, 3) ---first day of the financial year VAR_DATE falls in
			, DATE_FROM_PARTS(YEAR(DATE(VAR_DATE))-1, '04', '01') 
			, DATE_FROM_PARTS(YEAR(DATE(VAR_DATE)), '04', '01')) OR DMLAT_DAT IS NULL)
		AND Age >= 18 
		, 1 , NULL) AS IS_NDH
	,IFF( NDH_DAT IS NOT NULL
		AND (DMLAT_DAT >= IFF(MONTH(DATE(VAR_DATE)) IN (1, 2, 3) ---first day of the financial year VAR_DATE falls in
			, DATE_FROM_PARTS(YEAR(DATE(VAR_DATE))-1, '04', '01') 
			, DATE_FROM_PARTS(YEAR(DATE(VAR_DATE)), '04', '01'))  OR DMLAT_DAT IS NULL)
		AND Age >= 18 
		, NDH_DAT , NULL) AS DATE_NDH

	-- Osteoporosis is both OSTEO1 and OSTEO2 Registers
	,IFF( OSTEO_DAT IS NOT NULL 
			AND (FF1LAT_DAT IS NOT NULL	AND (Age >= 75)) -- OSTEO2_REG
			OR (FFLAT_DAT IS NOT NULL AND Age BETWEEN 50 AND 74 -- OSTEO_REG
				AND (DXALAT_DAT IS NOT NULL OR DXA2LAT_DAT IS NOT NULL)
				)
			, 1 , NULL) AS IS_OSTEOPEROSIS
	,IFF( OSTEO_DAT IS NOT NULL 
			AND (FF1LAT_DAT IS NOT NULL	AND (Age >= 75)) -- OSTEO2_REG
			OR (FFLAT_DAT IS NOT NULL AND Age BETWEEN 50 AND 74 -- OSTEO_REG
				AND (DXALAT_DAT IS NOT NULL OR DXA2LAT_DAT IS NOT NULL)
				)
			, OSTEO_DAT , NULL) AS DATE_OSTEOPEROSIS

	-- PAD
	,IFF( PAD_DAT IS NOT NULL , 1 , NULL) AS IS_PAD	
	,IFF( PAD_DAT IS NOT NULL , PAD_DAT , NULL) AS DATE_PAD	
	-- PAD
	,IFF( PALCARE_DAT IS NOT NULL , 1 , NULL) AS IS_PALCARE	
	,IFF( PALCARE_DAT IS NOT NULL , PALCARE_DAT , NULL) AS DATE_PALCARE	

	-- RA
	,IFF( Age >= 16 AND RARTH_DAT IS NOT NULL , 1 , NULL) AS IS_RARTH	
	,IFF( Age >= 16 AND RARTH_DAT IS NOT NULL , RARTH_DAT , NULL) AS DATE_RARTH	

	-- Stroke & TIA
	,IFF( STIA_DAT IS NOT NULL , 1 , NULL) AS IS_STROKE_OR_TIA
	,IFF( STIA_DAT IS NOT NULL , STIA_DAT , NULL) AS DATE_STROKE_OR_TIA

	-- Mental Health Unresolved Reg
	,IFF( MH_UR_DAT IS NOT NULL , 1 , NULL) AS IS_MH_NO_REMISSION
	,IFF( MH_UR_DAT IS NOT NULL , MH_UR_DAT , NULL) AS DATE_MH_NO_REMISSION

	-- All Age Registers ignoring age logic.
	-- Asthma
	,IFF( AST_DAT IS NOT NULL 
			AND ASTTRT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-12, VAR_DATE)) AND VAR_DATE
				, 1 , NULL) AS IS_ASTHMA_ALL_AGES
	,IFF( AST_DAT IS NOT NULL 
			AND ASTTRT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-12, VAR_DATE))  AND VAR_DATE
				, AST_DAT , NULL) AS DATE_ASTHMA_ALL_AGES

	--Depression
	,IFF( DEPR_DAT IS NOT NULL
			, 1 , NULL) AS IS_DEPRESSION_ALL_AGES
	,IFF( DEPR_DAT IS NOT NULL
			, DEPR_DAT , NULL) AS DATE_DEPRESSION_ALL_AGES

	-- Diabetes
	,IFF( DM_DAT IS NOT NULL , 1 , NULL) AS IS_DIABETES_ALL_AGES
	,IFF( DM_DAT IS NOT NULL , DM_DAT , NULL) AS DATE_DIABETES_ALL_AGES

	-- Epilepsy
	,IFF( EPIL_DAT IS NOT NULL 
			AND EPILTRT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-6, VAR_DATE)) AND VAR_DATE
			, 1 , NULL) AS IS_EPILEPSY_ALL_AGES
	,IFF( EPIL_DAT IS NOT NULL 
			AND EPILTRT_DAT BETWEEN DATEADD(DAY, 1, DATEADD(month,-6, VAR_DATE)) AND VAR_DATE
			, EPIL_DAT , NULL) AS DATE_EPILEPSY_ALL_AGES

	-- ADHD
	,IFF( ADHD_DAT IS NOT NULL , 1 , NULL) AS IS_ADHD
	,IFF( ADHD_DAT IS NOT NULL , ADHD_DAT , NULL) AS DATE_ADHD

	-- Autism
	,IFF( AUT_DAT IS NOT NULL , 1 , NULL) AS IS_AUTISM
	,IFF( AUT_DAT IS NOT NULL , AUT_DAT , NULL) AS DATE_AUTISM

	-- Diabetes Type 1 all ages
	,IFF( DM1_DAT IS NOT NULL, 1 , NULL) AS IS_DIABETES_TYPE_1
	,IFF( DM1_DAT IS NOT NULL, DM1_DAT , NULL) AS DATE_DIABETES_TYPE_1

	-- Diabetes Type 2 and other all ages
	,IFF( DM2_DAT IS NOT NULL, 1 , NULL) AS IS_DIABETES_TYPE_2
	,IFF( DM2_DAT IS NOT NULL, DM2_DAT , NULL) AS DATE_DIABETES_TYPE_2

	-- Obesity
	,IFF( Age >= 18 AND BMI_DAT IS NOT NULL , 1 , NULL) AS IS_OBESITY	
	,IFF( Age >= 18 AND BMI_DAT IS NOT NULL , BMI_DAT , NULL) AS DATE_OBESITY	

	-- Obesity
	,IFF(BMI_DAT IS NOT NULL , 1 , NULL) AS		  IS_OBESITY_ALL_AGES
	,IFF(BMI_DAT IS NOT NULL , BMI_DAT , NULL) AS DATE_OBESITY_ALL_AGES	

	-- Smoking (12 months)
	,IFF( SMOK_DAT IS NOT NULL , 1 , NULL) AS IS_SMOKER
	,IFF( SMOK_DAT IS NOT NULL , SMOK_DAT , NULL) AS DATE_SMOKER


FROM CTE_POPULATION AS POP  

LEFT JOIN LTC_DIAGNOSIS AS OBS
	ON POP.PERSON_ID = OBS.PERSON_ID 
LEFT JOIN LTC_MEDICATION AS MED
	ON OBS.PERSON_ID = MED.PERSON_ID

WHERE POP.DATE_RUN = VAR_DATE

$$
```

See below the function similar to the register to create the monthly and yearly registers

```sql
CREATE OR REPLACE PROCEDURE STAGING.SP_UPDATE_PC_LTC_REGISTER_TABLES()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER -- EXCUTE AS OWNER as an option
AS 

BEGIN

/*	
	==============================
	Author - Cameron Bebbington
	Create Date 25/09/2024
	Description - A monthly snapshot of the SEL registered population, going back 36 months up until the end of the previous month from the point the script is run.
	==============================
    
*/
CREATE OR REPLACE TABLE STAGING.PC_LTC_REGISTER_MONTHLY 
(
	SK_PATIENT_ID BIGINT
	,PERSON_ID BIGINT
	,DATE_RUN DATE 
	,IS_AFIB INT
	,DATE_AFIB DATE
	,IS_ASTHMA INT
	,DATE_ASTHMA DATE
	,IS_CANCER INT
	,DATE_CANCER DATE
	,IS_CHD INT
	,DATE_CHD DATE
	,IS_CKD INT
	,DATE_CKD DATE
	,IS_COPD INT
	,DATE_COPD DATE
	,IS_DEMENTIA INT
	,DATE_DEMENTIA DATE
	,IS_DEPRESSION INT
	,DATE_DEPRESSION DATE
	,IS_DIABETES INT
	,DATE_DIABETES DATE
	,IS_EPILEPSY INT
	,DATE_EPILEPSY DATE
	,IS_HEART_FAILURE INT
	,DATE_HEART_FAILURE DATE
	,IS_HYPERTENSION INT
	,DATE_HYPERTENSION DATE
	,IS_LD INT
	,DATE_LD DATE
	,IS_MH1_DIAGNOSIS INT
	,DATE_MH1_DIAGNOSIS  DATE
	,IS_MH2_LITHIUM INT
	,DATE_MH2_LITHIUM  DATE
	,IS_NDH INT
	,DATE_NDH DATE
	,IS_OSTEOPEROSIS INT
	,DATE_OSTEOPEROSIS DATE
	,IS_PAD INT
	,DATE_PAD DATE
	,IS_PALCARE INT
	,DATE_PALCARE DATE
	,IS_RARTH INT
	,DATE_RARTH DATE
	,IS_STROKE_OR_TIA INT
	,DATE_STROKE_OR_TIA DATE
	,IS_MH_NO_REMISSION INT
	,DATE_MH_NO_REMISSION DATE

    -- All age registers
	,IS_ASTHMA_ALL_AGES INT
	,DATE_ASTHMA_ALL_AGES DATE
	,IS_DEPRESSION_ALL_AGES INT
	,DATE_DEPRESSION_ALL_AGES DATE
	,IS_DIABETES_ALL_AGES INT
	,DATE_DIABETES_ALL_AGES DATE
	,IS_EPILEPSY_ALL_AGES INT
	,DATE_EPILEPSY_ALL_AGES DATE

    -- Non-LTC Registers
	,IS_ADHD INT
	,DATE_ADHD	DATE
	,IS_AUTISM INT
	,DATE_AUTISM DATE
	,IS_DIABETES_TYPE_1 INT
	,DATE_DIABETES_TYPE_1 DATE
	,IS_DIABETES_TYPE_2 INT
	,DATE_DIABETES_TYPE_2 DATE
	,IS_OBESITY INT
	,DATE_OBESITY DATE
	,IS_OBESITY_ALL_AGES INT	
	,DATE_OBESITY_ALL_AGES DATE
	,IS_SMOKER INT
	,DATE_SMOKER DATE

	)
    COMMENT = 'A monthly view going back 36 months of SEL LTC flags, showing a 1 if a patient has a condition as defined by QOF rules. Derived from Discovery data. The DATE_RUN shows the end of month date which has the relevant snapshot of the population at that date. It is updated monthly from the SP STAGING.SP_UPDATE_PC_LTC_REGISTER_TABLES';

BEGIN
    LET dat := LAST_DAY(DATEADD(year, -3, CURRENT_DATE())); -- 12 months test
    WHILE (dat <= CURRENT_DATE())
    DO
    
    INSERT INTO STAGING.PC_LTC_REGISTER_MONTHLY
    SELECT * FROM TABLE(STAGING.FN_RETURN_PC_LTC_REGISTER(DATE(:dat)));
    
    dat := ADD_MONTHS(dat, 1);
    END WHILE;
    -- RETURN 'COMPLETE';
END;

/*	
	==============================
	Author - Cameron Bebbington
	Create Date 25/09/2024
	Description - A monthly snapshot of the SEL registered population, going back 36 months up until the end of the previous month from the point the script is run.
	==============================
    
*/


CREATE OR REPLACE TABLE STAGING.PC_LTC_REGISTER_YEARLY
(
	SK_PATIENT_ID BIGINT
	,PERSON_ID BIGINT
	,DATE_RUN DATE 
	,IS_AFIB INT
	,DATE_AFIB DATE
	,IS_ASTHMA INT
	,DATE_ASTHMA DATE
	,IS_CANCER INT
	,DATE_CANCER DATE
	,IS_CHD INT
	,DATE_CHD DATE
	,IS_CKD INT
	,DATE_CKD DATE
	,IS_COPD INT
	,DATE_COPD DATE
	,IS_DEMENTIA INT
	,DATE_DEMENTIA DATE
	,IS_DEPRESSION INT
	,DATE_DEPRESSION DATE
	,IS_DIABETES INT
	,DATE_DIABETES DATE
	,IS_EPILEPSY INT
	,DATE_EPILEPSY DATE
	,IS_HEART_FAILURE INT
	,DATE_HEART_FAILURE DATE
	,IS_HYPERTENSION INT
	,DATE_HYPERTENSION DATE
	,IS_LD INT
	,DATE_LD DATE
	,IS_MH1_DIAGNOSIS INT
	,DATE_MH1_DIAGNOSIS  DATE
	,IS_MH2_LITHIUM INT
	,DATE_MH2_LITHIUM  DATE
	,IS_NDH INT
	,DATE_NDH DATE
	,IS_OSTEOPEROSIS INT
	,DATE_OSTEOPEROSIS DATE
	,IS_PAD INT
	,DATE_PAD DATE
	,IS_PALCARE INT
	,DATE_PALCARE DATE
	,IS_RARTH INT
	,DATE_RARTH DATE
	,IS_STROKE_OR_TIA INT
	,DATE_STROKE_OR_TIA DATE
	,IS_MH_NO_REMISSION INT
	,DATE_MH_NO_REMISSION DATE

    -- All age registers
	,IS_ASTHMA_ALL_AGES INT
	,DATE_ASTHMA_ALL_AGES DATE
	,IS_DEPRESSION_ALL_AGES INT
	,DATE_DEPRESSION_ALL_AGES DATE
	,IS_DIABETES_ALL_AGES INT
	,DATE_DIABETES_ALL_AGES DATE
	,IS_EPILEPSY_ALL_AGES INT
	,DATE_EPILEPSY_ALL_AGES DATE

    -- Non-LTC Registers
	,IS_ADHD INT
	,DATE_ADHD	DATE
	,IS_AUTISM INT
	,DATE_AUTISM DATE
	,IS_DIABETES_TYPE_1 INT
	,DATE_DIABETES_TYPE_1 DATE
	,IS_DIABETES_TYPE_2 INT
	,DATE_DIABETES_TYPE_2 DATE
	,IS_OBESITY INT
	,DATE_OBESITY DATE
	,IS_OBESITY_ALL_AGES INT	
	,DATE_OBESITY_ALL_AGES DATE
	,IS_SMOKER INT
	,DATE_SMOKER DATE

	)    COMMENT = 'A yearly view going back to 2018-03-31 months of SEL LTC flags, showing a 1 if a patient has a condition as defined by QOF rules. Derived from Discovery data. The DATE_RUN shows the end of fin year date which has the relevant snapshot of the population at that date, with the latest fin year showing the end of the previous months date. It is updated monthly from the SP STAGING.SP_UPDATE_PC_LTC_REGISTER_TABLES';

BEGIN
    LET dat := DATE('2018-03-31'); 
    WHILE (dat <= CURRENT_DATE())
    DO
    
    INSERT INTO STAGING.PC_LTC_REGISTER_YEARLY
    SELECT * FROM TABLE(STAGING.FN_RETURN_PC_LTC_REGISTER(DATE(:dat)));
    
    dat := DATEADD(YEAR, 1, dat);
    END WHILE;
END;

INSERT INTO STAGING.PC_LTC_REGISTER_YEARLY
SELECT * FROM TABLE(STAGING.FN_RETURN_PC_LTC_REGISTER(LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1))))
WHERE (SELECT MAX(DATE_RUN) FROM STAGING.PC_LTC_REGISTER_YEARLY) <> LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1));
RETURN 'SEL Monthly and Yearly LTC Registers Update Completed'
END;

```

## 6. LTC Scheduled tasks
Much like the SEL registers, these are then stages as tasks which follow AFTER the TASK_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES task is complete.

```sql

-- 2.2
CREATE OR REPLACE TASK DATA_LAB_SEL.FINAL.TASK_UPDATE_PC_LTC_OBSERVATION_MEDICATION
    WAREHOUSE = SEL_ANALYTICS_XS
    USER_TASK_TIMEOUT_MS = 1800000
    COMMENT = 'Task to run the SP_UPDATE_PC_LTC_OBSERVATION_MEDICATION on the 3rd day of each month at 7am after TASK_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES'
    AFTER DATA_LAB_SEL.FINAL.TASK_UPDATE_PC_SEL_REGISTERED_PATIENTS_TABLES
	AS CALL DATA_LAB_SEL.STAGING.SP_UPDATE_PC_LTC_OBSERVATION_MEDICATION();

-- 3
CREATE OR REPLACE TASK DATA_LAB_SEL.FINAL.TASK_UPDATE_PC_LTC_REGISTER_TABLES
    WAREHOUSE = SEL_ANALYTICS_XS
    USER_TASK_TIMEOUT_MS = 1800000
    COMMENT = 'Task to run the SP_UPDATE_PC_LTC_REGISTER_TABLES on the 3rd day of each month 7am after TASK_UPDATE_PC_LTC_OBSERVATION_MEDICATION'
    AFTER DATA_LAB_SEL.FINAL.TASK_UPDATE_PC_LTC_OBSERVATION_MEDICATION
	AS CALL DATA_LAB_SEL.STAGING.SP_UPDATE_PC_LTC_REGISTER_TABLES();

```
## 7. SEL Register & LTC View

The Final view that merges these in the latest, monthly and yearly views. The below view is for the monthly register but they are all built in the same way, with the exception of the latest view joining to the latest month view, regardless of what day it is updated in the month.

Note that we have currently taken the decision to remove LTC dates from this view but may decide they are relevant in future.
	
```sql
CREATE OR REPLACE VIEW FINAL.VW_PC_SEL_REGISTERED_PATIENTS_MONTHLY AS

--==================================================================================================================================================
--  AUTHOR:				    Cameron Bebbington
--  CREATE DATE:			01/10/2024
--  DESCRIPTION:			A view combining the PC_SEL_REGISTERED_PATIENTS_MONTHLY and PC_LTC_REGISTER_MONTHLY tables on the DATE_RUN and PERSON_IDs of both objects

------ Consider as a materialised view

--  UPDATE DATE:			
--  UPDATE BY:				
--  UPDATE DESCRIPTION:		
    
--==================================================================================================================================================

SELECT 
    -- POP Fields
     POP.PERSON_ID
    ,POP.SK_PATIENT_ID
    ,PRAC.DERIVED_GP_PRACTICE_CODE 
    ,PRAC.DERIVED_GP_PRACTICE_NAME 
    ,PRAC.PCN_NAME
    ,PRAC.BOROUGH_NAME AS BOROUGH_REGISTRATION
    ,POP.GENDER_NAME
    ,POP.AGE  
    ,POP.DATE_OF_BIRTH
    ,POP.ETHNIC_CATEGORY_CODE 
    ,POP.ETHNIC_CATEGORY_NAME
    ,IFNULL(ETH.ETHNIC_BROAD_GROUP_NAME, 'Unknown') AS ETHNIC_BROAD_GROUP_NAME  
	,POP.LSOA_CODE
	,LSOA."OAName" AS LSOA_NAME
	,CASE WHEN LEFT("OAName", LENGTH("OAName")-5) IN ('Bexley', 'Bromley', 'Greenwich', 'Lambeth', 'Lewisham', 'Southwark') THEN LEFT("OAName", LEN("OAName")-5) 
		ELSE 'Other'
	 END AS BOROUGH_RESIDENCE
	,CASE WHEN LEFT("OAName", LENGTH("OAName")-5) IN ('Bexley', 'Bromley', 'Greenwich', 'Lambeth', 'Lewisham', 'Southwark') THEN 1
		ELSE 0
	 END AS IS_SEL_BOROUGH
	,IMD.IMD_DECILE_NUMBER 
	,IMD.IMD_RANK 
	,IMD.IMD_DECILE_TEXT 
	,WARD.WARD_2020_NAME AS WARD_NAME 
	,WARD.LATITUDE AS WARD_LATITUDE
	,WARD.LONGITUDE AS WARD_LONGITUDE
    ,POP.DATE_RUN 
    ,POP.FINANCIAL_YEAR
    ,POP.IS_TYPE1_OPT_OUT
    
    -- LTCs Registers
	,LTC.IS_AFIB 
	,LTC.IS_ASTHMA 
	,LTC.IS_CANCER 
	,LTC.IS_CHD 
	,LTC.IS_CKD 
	,LTC.IS_COPD 
	,LTC.IS_DEMENTIA 
	,LTC.IS_DEPRESSION 
	,LTC.IS_DIABETES 
	,LTC.IS_EPILEPSY 
	,LTC.IS_HEART_FAILURE 
	,LTC.IS_HYPERTENSION 
	,LTC.IS_LD 
	,LTC.IS_MH1_DIAGNOSIS 
	,LTC.IS_MH2_LITHIUM 
	,LTC.IS_NDH 
	,LTC.IS_OSTEOPEROSIS 
	,LTC.IS_PAD 
	,LTC.IS_PALCARE 
	,LTC.IS_RARTH 
	,LTC.IS_STROKE_OR_TIA 
	,LTC.IS_MH_NO_REMISSION 

    -- All Age Registers
	,LTC.IS_ASTHMA_ALL_AGES 
	,LTC.IS_DEPRESSION_ALL_AGES 
	,LTC.IS_DIABETES_ALL_AGES 
	,LTC.IS_EPILEPSY_ALL_AGES 

    -- Non-LTC Condition Registers
	,LTC.IS_ADHD 
	,LTC.IS_AUTISM 
	,LTC.IS_DIABETES_TYPE_1 
	,LTC.IS_DIABETES_TYPE_2 
	,LTC.IS_OBESITY 
	,LTC.IS_OBESITY_ALL_AGES 	
	,LTC.IS_SMOKER 

    ,1 AS POPULATION 
FROM STAGING.PC_SEL_REGISTERED_PATIENTS_MONTHLY AS POP

  -- Join to SEL derived Practice lookup, accounting for merged practices.
  INNER JOIN FINAL.LOOKUP_SEL_PRACTICE_LIST AS PRAC
	ON POP.PRACTICE_CODE = PRAC.ORIGINAL_GP_PRACTICE_CODE
  -- SEL derived ethnicity groupings
  LEFT JOIN FINAL.LOOKUP_ETHNIC_CATEGORY AS ETH 
	ON POP.ETHNIC_CATEGORY_CODE = ETH.ETHNIC_CATEGORY_CODE 

	-- Below 3 Lookup joins to eventually be replaced by standardised LSOA lookup table for Borough, Ward and IMD of residence.
  LEFT JOIN "Dictionary"."STAGING_GEO"."OutputArea" AS LSOA
	ON POP.LSOA_CODE = LSOA."OACode"
		AND LSOA."CensusYear" = '2011'
  LEFT JOIN FINAL.LOOKUP_IMD_2019_LONDON AS IMD
  	ON LSOA."OACode" = IMD.LSOA_2011_CODE
  LEFT JOIN FINAL.LOOKUP_LSOA_WARD_MAPPING AS WARD
  	ON LSOA."OACode" = WARD.LSOA_2011_CODE

  LEFT JOIN STAGING.PC_LTC_REGISTER_MONTHLY AS LTC
	ON POP.PERSON_ID = LTC.PERSON_ID
    AND LTC.DATE_RUN = POP.DATE_RUN

```

You can then use this view for any work related to Primary Care for easy links for patient LTC registers, as well as demographic information. You can join to various other datasets using SK_PATIENT_ID to do the same matching for datasets like Inpatients, Outpatients, Maternity etc.

[def]: #3-register-scheduled-task