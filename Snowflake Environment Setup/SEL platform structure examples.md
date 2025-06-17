# ⚙️ Platform Structure Examples – South East London ICB

This section demonstrates how the **Test, Dev, and Prod** environments are used in practice, and how the separation between the **RAW, STAGING, and FINAL** schemas is effectively applied.

## 🧾 Example 1: Creating a table to hold Prescribing Data 
| Row | Environment | Object Name                                                |  Analyst Use Case                                                           |
| --- | ----------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------ 
| 1   | DEV         | DATA_LAB_SEL_**DEV**.`RAW.PRESCRIBING_ALL_STAGING_LEGACY`     | Develop new or amended processes (e.g. new data import,  adjust reference tables). May contain outdated data. |
| 2   | PROD        | DATA_LAB_**SEL**`.RAW.PRESCRIBING_ALL_STAGING_LEGACY`         | New or amended object created only after reviewer approval, supports BI reporting, added only by authorised users       |                   
| 3   | TRAINING    | DATA_LAB_SEL_**TRAINING**.`*`                               | Experiment with Snowflake SQL to create tables for learning and trial/error, data may not persist but a safe space for experimentation and testing. |


## 📦 Example 2: CSV Import of Prescribing Data 

> This illustrates the flow of data through the three schemas from `RAW` > `STAGING` > `FINAL`.

| # | Object Type | Object Name                                        | Description                            | Process                                | Schema    |
| - | ----------- | -------------------------------------------------- | -------------------------------------- | -------------------------------------- | --------- |
| 1 | Table       | `DATA_LAB_SEL.RAW.PRESCRIBING_ALL_STAGING_LEGACY`  | Raw prescribing data from CSV (ePACT)  | Monthly CSV import                     | `RAW`     |
| 2 | Table       | `DATA_LAB_SEL.RAW.PRESCRIBING_BNF_REFERENCE_TABLE` | BNF drug code lookup                   | CSV import                             | `RAW`     |
| 3 | Table       | `DATA_LAB_SEL.STAGING.PRESCRIBING_ALL_FINAL`       | Reformatted and cleaned version        | Monthly transformation in staging      | `STAGING` |
| 4 | View        | `DATA_LAB_SEL.FINAL.VW_PRESCRIBING_DERIVED`        | Aggregated and enriched reporting view | Joins and aggregations on FINAL tables | `FINAL`   |

## 🧩 Example 3: High Cost Drugs Data Objects

> A more complex flow of High Cost Drugs data from multiple `RAW` and `STAGING` sources into a `FINAL` reporting view.

| #   | Object Type | Object Name                                           | Description                                       | Process                     | Schema    |
| --- | ----------- | ----------------------------------------------------- | ------------------------------------------------- | --------------------------- | --------- |
| 1   | Table       | `DATA_LAB_SEL.RAW.LOOKUP_DRUG_BRAND_NAME`             | Brand to generic name mapping                     | Manual Excel import         | `RAW`     |
| 2   | Table       | `DATA_LAB_SEL.STAGING.DRPLCM_MASTER`                  | Raw SLAM DrPLCM data                              | Updated by stored procedure | `STAGING` |
| 3   | Table       | `DATA_LAB_SEL.FINAL.DRPLCM_FILTERED`                  | Filtered latest version data                      | Derived from master         | `FINAL`   |
| 4   | Stored Proc | `DATA_LAB_SEL.STAGING.SP_UPDATE_DRPLCM_MASTER`        | Updates master data table                         |                            | `STAGING` |
| 5   | Stored Proc | `DATA_LAB_SEL.FINAL.SP_UPDATE_DRPLCM_FILTERED`        | Updates filtered data                             |                            | `FINAL`   |
| 6   | Table       | `DATA_LAB_SEL.FINAL.LOOKUP_DRUG_INDICATION`           | Maps submitted indications to standardised values | Updated from master table   | `FINAL`   |
| 7   | Table       | `DATA_LAB_SEL.FINAL.LOOKUP_DRUG_SHORT_NAME`           | Standardised drug names                           | Updated from master table   | `FINAL`   |
| 8   | View        | `DATA_LAB_SEL.FINAL.VW_DRUGS_LOOKUP_PATHWAY_GROUP`    | Combines brand/pathway lookups                    |                            | `FINAL`   |
| 9   | Table       | `DATA_LAB_SEL.FINAL.LOOKUP_COMMISSIONER`              | Commissioner lookup                               | Updated via SP              | `FINAL`   |
| 10  | Table       | `DATA_LAB_SEL.FINAL.LOOKUP_ETHNICITY`                 | Ethnic category lookup                            | Updated via SP              | `FINAL`   |
| 11  | Table       | `DATA_LAB_SEL.FINAL.LOOKUP_PROVIDER`                  | Provider lookup                                   | Updated via SP              | `FINAL`   |
| 12  | Stored Proc | `DATA_LAB_SEL.FINAL.SP_UPDATE_LOOKUP_TABLES`          | Updates commissioner/ethnicity/provider lookups   |                            | `FINAL`   |
| 13  | Table       | `DATA_LAB_SEL.FINAL.LOOKUP_ETHNICITY_REGISTER`        | Latest ethnicity across sources                   | Aggregated from datasets    | `FINAL`   |
| 14  | Stored Proc | `DATA_LAB_SEL.FINAL.UPDATE_LOOKUP_ETHNICITY_REGISTER` | Updates ethnicity register                        |                            | `FINAL`   |
| 15  | View        | `DATA_LAB_SEL.FINAL.VW_DRUGS_TREND`                   | Final view for HCD reporting                      |                            | `FINAL`   |

---

We hope this helps you understand our platform structure and supports your own Snowflake practices. If you have suggestions or improvements, feel free to contribute or open a discussion!
