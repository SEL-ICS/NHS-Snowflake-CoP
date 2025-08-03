# Snowflake Collation Project

This project provides code to collate case sensitive text in Snowflake tables to case insensitive using the target collation of 'en-ci'.

The code provides store procedures to:
- Collate a single Snowflake table if it has TEXT/VARCHAR columns
- Collate a schema of Snowflake tables if it has TEXT/VARCHAR columns

# How It Works

The collation store procedure(s) are written in Python and will transform the TEXT/VARCHAR data, in a Snowflake table, from case sensitive to case insensitive. A knowledge of Python however is not required to run the code

# Prerequisites

- Snowflake account with ACCOUNTADMIN privileges required to create new schemas, grant privileges and execute store procedures

