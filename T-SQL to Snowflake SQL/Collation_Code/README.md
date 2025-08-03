# Snowflake Collation Project

This project provides code to convert case-sensitive `TEXT`/`VARCHAR` columns in Snowflake tables to case-insensitive using the collation `'en-ci'`.

## Overview

The repository includes two Python-based stored procedures for use in Snowflake:

- Collate a **single table** with `TEXT`/`VARCHAR` columns
- Collate **an entire schema** of tables with `TEXT`/`VARCHAR` columns

## How It Works

The stored procedures are written in Python using Snowflake Snowpark. They transform text-based columns to apply the `'en-ci'` collation, making string comparisons case-insensitive.

> **Note**: No Python knowledge is required to execute the procedures.

A high-level process flow is shown in the diagram:  
📎 [Collation Diagram](flowchart.png)

---

## Prerequisites

- A Snowflake account with **`ACCOUNTADMIN`** role privileges
- Permission to create roles, schemas, warehouses, and stored procedures

---

## Setup Instructions

The `setup.sql` script creates all required Snowflake objects.

### Configuration

Before running `setup.sql`, replace the following placeholders:

- `'databasename'` → your target database
- `'schemaname'` → your schema name  
  _Example: `USE SCHEMA "Test"."Monitoring"`_
- `'SnowflakeUser'` → the user who will execute the collation  
  _**This user must have `ACCOUNTADMIN` access**_

### Execution Steps

1. Log into Snowflake as `ACCOUNTADMIN`
2. Execute the `setup.sql` script in full

---

## Objects Created

- **Role**: `COLLATION_ADMIN`
- **Schema**: `CONTROL`
- **Warehouse**: `COLLATION_WH`
- **Stored Procedures**:
  - `create_collation_table` — for single table collation
  - `create_collation_tables` — for schema-wide collation
- **Tables**: Control and logging tables in the `CONTROL` schema
- **Grants**: All required privileges granted to the `COLLATION_ADMIN` role

---

## Usage

### Collate a Single Table

```sql
CALL CONTROL.create_collation_table(
    'MY_DATABASE',
    'MY_SCHEMA',
    'MY_TABLE',
    'SOURCE_ROLE',
    'en-ci'
);
```

### Collate a Schema of Tables

```sql

CALL CONTROL.create_collation_tables(
    'MY_DATABASE',
    'MY_SCHEMA',
    'SOURCE_ROLE',
    'en-ci'
);
```

`CALL CONTROL.create_collation_table('Test', 'Monitoring', 'COLLATION_ADMIN', 'en-ci')` will generate the following collated and backup tables:

- Database "Test"
 - Schema "Monitoring"
   - THYROID_MONITORING
   - THYROID_MONITORING_01082025_BACKUP


Author
Developed by Angela Ebirim
Senior Data Engineer, NHS North East London Integrated Care Board
email: angela.ebirim4@nhs.net
Date: August 2025

License
MIT License
© 2025 Crown copyright
NHS North East London Integrated Care Board

This software is released under the MIT License.





