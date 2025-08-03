# Snowflake Collation Project

This project provides code to collate case sensitive text in Snowflake tables to case insensitive using the target collation of 'en-ci'.

## Overview

The code provides store procedures to:
- Collate a single Snowflake table as long as it has TEXT/VARCHAR columns
- Collate a schema of Snowflake tables as long as they have TEXT/VARCHAR columns

## How It Works

The collation store procedure(s) are written in Python and will transform the TEXT/VARCHAR data, in a Snowflake table, from case sensitive to case insensitive. A knowledge of Python however is not required to run the code.

The diagram of what happens when the collation code is run can be seen here:

[Collation Diagram](flowchart.png)

## Prerequisites

Snowflake account with ACCOUNTADMIN rights required to create new schemas and execute store procedures

## Setup Instructions

The setup.sql script will create the necessary Snowflake objects (roles, schemas, store procedures etc) necessary to run the collation code.

**Note**: Edit setup.sql and find/replace 'databasename'. with YOUR DATABASE NAME, 'schemaname'. with YOUR SCHEMA NAME e.g. USE SCHEMA "Test"."Fin&Sales" which means use the schema "Fin&Sales" on database "Test". Also replace 'SnowflakeUser' with the person that will be running the collation code <b>(please note that this person must have access to the role ACCOUNTADMIN)</b>

1. Execute the `setup.sql` script as `ACCOUNTADMIN`

### Created Snowflake Objects On The Target Database
- **Roles**: A new collation role named COLLATION_ADMIN
- **Schemas**: A new schema on the target database named CONTROL
- **Tables**: Control and Log tables created under the CONTROL schema
- **Store Procedures**: Two stored procedures named create_collation_table and create_collation_tables created under the CONTROL schema
- **Warehouse**: A new warehouse named COLLATION_WH assigned to the new role, COLLATION_ADMIN
- **Grants**: Complete set of grants assigned to the COLLATION_ADMIN role




