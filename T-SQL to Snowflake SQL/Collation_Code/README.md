
# Snowflake Collation Project

This project provides code to collate case sensitive text in Snowflake tables to case insensitive using the target collation of 'en-ci'.

# Overview

The code provides store procedures to:
- Collate a single Snowflake table as long as it has TEXT/VARCHAR columns
- Collate a schema of Snowflake tables as long as they have TEXT/VARCHAR columns

