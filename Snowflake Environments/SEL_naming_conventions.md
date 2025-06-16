# Database Object Naming Conventions
## Object Type Naming Rules

| **Type**             | **Rule**                        | **Example**                                |
|----------------------|----------------------------------|---------------------------------------------|
| Table                | SCREAMING_SNAKE_CASE            | `ENCOUNTER_INPATIENT`                       |
| Stored Procedures    | `SP_`                           | `SP_ACUTE_SUS_SLAM_RECONCILIATION`          |
| Functions            | `FN_<DomainName>_<Action>`      | `FN_PATIENT_GET_ALL_ADMISSIONS`             |
| Triggers             | `TR_<DomainName>_<Action>`      | `TR_PATIENT_UPDATE_COMMISSIONER`            |
| Views                | `VW_`                           | `VW_ACUTE_SLAM_DrPLCM_PATHWAY_SPEND`        |
| Index                | `IX_<TableName>_<LogicalName>`  | `IX_ENCOUNTER_INPATIENT_HRG_ORDER`          |
| Date fields          | `DATE_<FieldName>`              | `DATE_ADMISSION`                            |
| DateTime fields      | `DATETIME_<FieldName>`          | `DATETIME_DISCHARGE`                        |
| Boolean fields       | `IS_<Characteristic>`           | `IS_ADULT`                                  |
| Identifier fields    | `<Table>_ID`                    | `ROW_ID`, `RECORD_ID`                       |
| Code fields          | `<Subject>_CODE`                | `GP_PRACTICE_CODE`, `HRG_CODE`              |
| Name fields          | `<Subject>_NAME`                | `GP_PRACTICE_NAME`, `HRG_NAME`              |
| Code + Name fields   | `<Subject>_CODE_AND_NAME`       | `GP_PRACTICE_CODE_AND_NAME`, `HRG_CODE_AND_NAME` |
| Reference fields     | `[FIELD_NAME]_<LIST_NAME>_CODE` | `PATIENT_GENDER_CODE`                       |

> Use `SK_` prefix only for National/NECS/ISL datasets if required.

---

## Object Naming Convention (Structure)

Use meaningful names for objects. The object name should consist of a series of elements separated by underscores (`_`), applied in the order below. Examples are available in the *SEL BI SQL Naming Conventions – Examples* spreadsheet.

### Object Name Structure

| **Order** | **Element**     | **Description**                                                                                     | **Examples**                          | **Required**              |
|-----------|------------------|-----------------------------------------------------------------------------------------------------|---------------------------------------|---------------------------|
| 1         | Object Type       | Prefix for object type (not required for tables)                                                    | `VW`, `SP`, `FN`                      | ✅ Where applicable        |
| 2         | Category          | Used to distinguish specific categories                                                             | `LOOKUP`, `REGISTER`, `PROCESSING`    | ✅ Where applicable        |
| 3         | Care Setting      | Name/abbreviation of the care setting                                                               | `ACUTE`, `COMM`, `MH`, `PC`           | ✅ Where applicable        |
| 4         | Data Source       | Name/abbreviation of the data source or component                                                   | `SUS`, `SLAM`, `ECDS`, `SUS_OP`       | ✅ Where applicable        |
| 5         | Specific Name     | Concise name of the object                                                                          | `UPDATE`,             | ✅ Mandatory               |
| 6         | Financial Year    | If the object is specific to one financial year                                                     | `202223`, `202324`, `202425`          | ✅ Where applicable        |

---

## General Naming Rules

- ❌ **No spaces** — use underscores `_`  
- ❌ **No symbols** — e.g., use `AE` instead of `A&E`
- ✅ Use **screaming snake case** (`ALL_CAPS_WITH_UNDERSCORES`)
- ❌ Do **not** use SQL reserved keywords
- ❌ Do **not** prefix tables with numbers
- ❌ Do **not** suffix names with `_dev`, `_test`, initials, or version numbers
- ✅ Add `created_date`, `modified_date`, and `modified_user` columns to reference tables
- ✅ Use **UK spelling** (`Organisation`, not `Organization`)
- ✅ Align with **NHS Data Dictionary** when possible
- ✅ Prefix **reference tables** with `LOOKUP_`  
  - Field names should use `_CODE` and `_NAME` suffixes

---

## Example Object Name

```text
VW_LOOKUP_ACUTE_SUS_IP_HRG_CODES_202425
