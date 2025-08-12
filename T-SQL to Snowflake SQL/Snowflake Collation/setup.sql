USE ACCOUNTADMIN;

-- For new databases
CREATE DATABASE IF NOT EXISTS <databasename>;
CREATE SCHEMA IF NOT EXISTS <databasename>.<schemaname>;
USE DATABASE <databasename>;
USE SCHEMA <databasename>.<schemaname>;

-- For existing databases
USE DATABASE <databasename>;
USE SCHEMA <databasename>.<schemaname>;

-- Create collation role

CREATE ROLE IF NOT EXISTS COLLATION_ADMIN;

-- Grant privileges to the collation role

GRANT USAGE ON DATABASE <databasename> TO ROLE COLLATION_ADMIN;

GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA <databasename>.<schemaname> TO ROLE COLLATION_ADMIN;

GRANT SELECT ON ALL TABLES IN SCHEMA <databasename>.<schemaname> TO ROLE COLLATION_ADMIN;

GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA <databasename>.<schemaname>  TO ROLE COLLATION_ADMIN;

CREATE SCHEMA IF NOT EXISTS <databasename>.CONTROL;

GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA <databasename>.CONTROL TO ROLE COLLATION_ADMIN;

GRANT ROLE COLLATION_ADMIN TO USER <SnowflakeUser>;
GRANT ROLE COLLATION_ADMIN TO ROLE ACCOUNTADMIN;

USE SCHEMA <databasename>.CONTROL;

-- Create control and log tables for collation

CREATE TABLE IF NOT EXISTS CONTROL.COLLATION_CONTROL_TABLE (
    DATABASE_NAME VARCHAR,
    SCHEMA_NAME VARCHAR,
    COLLATION_TABLE_NAME VARCHAR,
    COLUMN_NAME VARCHAR,
    DATATYPE VARCHAR,
    TARGET_COLLATION VARCHAR,
    STATUS VARCHAR,
    ORIGINAL_TABLE_NAME VARCHAR,
    LAST_UPDATED VARCHAR
);

CREATE TABLE IF NOT EXISTS CONTROL.COLLATION_LOG_TABLE (
    DATABASE_NAME VARCHAR,
    SCHEMA_NAME VARCHAR,
    SOURCE_TABLE_NAME VARCHAR,
    TARGET_TABLE_NAME VARCHAR,
    MD5_MATCH_CHECK VARCHAR,
    ROW_COUNT_CHECK VARCHAR,
    COUNT_COLS_CHECK VARCHAR,
    LAST_UPDATED VARCHAR
);

--store procedure to create collation table
CREATE OR REPLACE PROCEDURE CONTROL.CREATE_COLLATION_TABLE("DATABASE" VARCHAR, "SCHEMA_NAME" VARCHAR, "TABLE_NAME" VARCHAR, "SOURCE_ROLE" VARCHAR, "COLLATION" VARCHAR)
RETURNS VARCHAR(16777216)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'create_collation_table'
EXECUTE AS CALLER
AS
$$
from datetime import datetime
import random
import string
import re
import snowflake.snowpark as snowpark
from snowflake.snowpark import Session

def create_collation_table(
  session: Session,
  database_py: str,
  schema_name_py: str,
  table_name_py: str,
  source_role_py: str,
  collation_py: str
) -> str:

    """
    Function creates a collation table for the specified table in the specified 
    schema and database, applying the specified collation to text columns
    and ensuring that the table is properly backed up and grants are applied
    
    Args:
        session (Session): Snowflake session object
        database_py (str): Name of the database
        schema_name_py (str): Name of the schema
        table_name_py (str): Name of the table to be collated
        source_role_py (str): Role to be used for the source table
        collation_py (str): Collation to be applied
        
    Returns:
        str: Message indicating the result of the collation process
    """     

    pattern = f"[{re.escape(string.punctuation)}_]"
    last_updated = datetime.now().strftime('%d%m%Y')
    
    def clean_characters(session, value, pattern=pattern):
        no_punct = re.sub(pattern, '_', value) 
        cleaned_value = re.sub(r'[\s]', '', no_punct)
        return cleaned_value.upper()

    def check_for_lowercase(session, value):
        return value.upper()

    new_table_name = clean_characters(session, table_name_py) if re.search(pattern, table_name_py) else check_for_lowercase(session, table_name_py)
    cleaned_source_name = f'"{table_name_py}"' if re.search(pattern, table_name_py) else table_name_py
    schema_name = f'"{schema_name_py}"' if re.search(r'[a-z&\-\.,/\'\"()#]', schema_name_py) else schema_name_py
    database_name = f'"{database_py}"' if re.search(r'[a-z&\-\.,/\'\"()#]', database_py) else database_py
    collated = [f"{re.sub(r'[""]', '', new_table_name)}", "_COLLATED"]
    
    if re.search(pattern, table_name_py):
       source_table = f'{database_name}.{schema_name}.{cleaned_source_name}'
       collated_table = f"{database_name}.{schema_name}.{"".join(collated)}" 
       backup = [f'"{table_name_py}_{last_updated}_BACKUP"']
       backup_table =  f"{database_name}.{schema_name}.{"".join(backup)}"
    elif re.search(r'[A-Z][a-z]', table_name_py):
       source_table = f'{database_name}.{schema_name}."{table_name_py}"'
       collated_table = f'{database_name}.{schema_name}.{new_table_name}_COLLATED'
       backup_table = f'{database_name}.{schema_name}."{table_name_py}_{last_updated}_BACKUP"'
    else:
       source_table = f'{database_name}.{schema_name}.{table_name_py}'
       collated_table = f"{database_name}.{schema_name}.{new_table_name}_COLLATED"
       backup = [f"{cleaned_source_name}", f"_{last_updated}", "_BACKUP"]
       backup_table =  f"{database_name}.{schema_name}.{"".join(backup)}"

    result_table_check = session.sql(f"""
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA ILIKE '{schema_name_py}' AND TABLE_NAME ILIKE '{table_name_py}' AND COLLATION_NAME = '{collation_py}'
    """).collect()
    if result_table_check:
        return f"Table: {table_name_py} has already been collated"

    try:
        session.sql(f"CREATE OR REPLACE TRANSIENT TABLE {backup_table} CLONE {source_table}").collect()
    except Exception as e:
        return f"Error creating clone: {e}, CREATE OR REPLACE TRANSIENT TABLE {backup_table} CLONE {source_table}"
    

    def apply_grants(session, source_table, backup_table):
        grants = session.sql(f"""
            SHOW GRANTS ON TABLE {source_table}
        """).collect()

        original_owner_role = None
        for grant in grants:
            privilege = grant['privilege']
            grantee_name = grant['grantee_name']
            if privilege == 'OWNERSHIP':
                original_owner_role = grantee_name 
            else:
                session.sql(f"""
                    GRANT {privilege} ON TABLE {backup_table} TO ROLE {grantee_name}
                """).collect()
        
        if original_owner_role:
            try:
                session.sql(f"""
                    GRANT OWNERSHIP ON TABLE {backup_table} TO ROLE {original_owner_role} COPY CURRENT GRANTS
                """).collect()
            except Exception as e:
                return "Unable to determine original owner of table"
        return
        
    apply_grants(session, source_table, backup_table)

    columns_meta = session.sql(f"""
        SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA ILIKE '{schema_name_py}' AND 
        TABLE_NAME ILIKE '{table_name_py}'
    """).collect()

    select_expr = []
    hash_cols = []
    for col in columns_meta:
        col_name = col['COLUMN_NAME']
        if col['DATA_TYPE'] in ('TEXT', 'VARCHAR'):
            select_expr.append(f'''"{col_name}" COLLATE '{collation_py}' AS "{col_name}"''')    
            hash_cols.append(f'LOWER("{col_name}")')
        else:
            select_expr.append(f'"{col_name}"') 

    select_expr_str = ', '.join(select_expr)
    hash_concat_str = ', '.join(hash_cols)
    hash_expr = f"{hash_cols[0]}, MD5(CONCAT({hash_concat_str})) AS HASH"
    
    try:
        session.sql(f"CREATE OR REPLACE TABLE {collated_table} AS SELECT {select_expr_str} FROM {source_table}").collect()
    except Exception as e:
        return f"Error creating collation table: {e} using expression: CREATE OR REPLACE TABLE {collated_table} AS SELECT {select_expr_str} FROM {source_table}"
    
    control_check = session.sql(f"""
        SELECT 1 FROM CONTROL.COLLATION_CONTROL_TABLE
        WHERE SCHEMA_NAME ILIKE '{schema_name_py}' AND COLLATION_TABLE_NAME ILIKE '{table_name_py}_COLLATED'
    """).collect()
    
    try:
        collated_meta = session.sql(f"""
        SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, TABLE_CATALOG, COLLATION_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA ILIKE '{schema_name_py}' AND TABLE_NAME ILIKE '{new_table_name}_COLLATED'
        """).collect()
    except Exception as e:
        return f"Unable to query information columns with {e} using: {table_name_py}_COLLATED"
    
    today = datetime.now().strftime('%Y-%m-%d %H:%M:%S')  
    if not control_check:
        for Row in collated_meta:
           if Row['DATA_TYPE'] in ('TEXT', 'VARCHAR'):
              session.sql(f"""
              INSERT INTO CONTROL.COLLATION_CONTROL_TABLE(DATABASE_NAME, SCHEMA_NAME, COLLATION_TABLE_NAME, COLUMN_NAME, DATATYPE, TARGET_COLLATION, STATUS, ORIGINAL_TABLE_NAME, LAST_UPDATED
                   )
               VALUES(
               '{Row['TABLE_CATALOG']}', 
               '{Row['TABLE_SCHEMA']}', 
               '{Row['TABLE_NAME']}', 
               '{Row['COLUMN_NAME']}', 
               '{Row['DATA_TYPE']}', 
               '{Row['COLLATION_NAME']}', 
               'Success', 
               '{table_name_py}',
               '{today}')""").collect()
           else:
              session.sql(f"""
              INSERT INTO CONTROL.COLLATION_CONTROL_TABLE(DATABASE_NAME, SCHEMA_NAME, COLLATION_TABLE_NAME, COLUMN_NAME, DATATYPE, TARGET_COLLATION, STATUS, ORIGINAL_TABLE_NAME, LAST_UPDATED
                  )
               VALUES(
               '{Row['TABLE_CATALOG']}', 
               '{Row['TABLE_SCHEMA']}',
               '{Row['TABLE_NAME']}', 
               '{Row['COLUMN_NAME']}', 
               '{Row['DATA_TYPE']}', 
               '{Row['COLLATION_NAME']}', 
               'not applicable for non-TEXT columns',
               '{table_name_py}',
               '{today}')""").collect()
            
        sample_filter = f"MOD(ABS(HASH(CONCAT({hash_concat_str}))), 1000000) = 0"

        test_results = {}
        md5_sample_orig = session.sql(f"SELECT {hash_expr} FROM {source_table} WHERE {sample_filter}").collect()
        md5_sample_collated = session.sql(f"SELECT {hash_expr} FROM {collated_table} WHERE {sample_filter}").collect()
        
        count_cols_orig = len(columns_meta)
        count_cols_collated = len(collated_meta)

        row_count_orig = session.table(source_table).count()
        row_count_collated = session.table(collated_table).count()

        test_results['md5_hash'] = 'Pass' if md5_sample_orig == md5_sample_collated else 'Fail'
        test_results['row_count'] = 'Pass' if row_count_orig == row_count_collated else 'Fail'
        test_results['count_cols'] = 'Pass' if count_cols_orig == count_cols_collated else 'Fail'

        try:
            session.sql(f"""
            INSERT INTO CONTROL.COLLATION_LOG_TABLE(
            DATABASE_NAME, SCHEMA_NAME, SOURCE_TABLE_NAME, TARGET_TABLE_NAME, MD5_MATCH_CHECK, ROW_COUNT_CHECK, COUNT_COLS_CHECK, LAST_UPDATED
            ) VALUES (
            '{database_py}', '{schema_name_py}', '{table_name_py}', '{table_name_py}_COLLATED',
            '{test_results['md5_hash']}', '{test_results['row_count']}', '{test_results['count_cols']}',
            '{today}'
            )
            """).collect()
        except Exception as e:
             return f"Error inserting values into log table, {e} for collated table: {collated_table}"

        if (md5_sample_orig == md5_sample_collated and
            count_cols_orig == count_cols_collated and
            row_count_orig == row_count_collated):

            session.sql(f"DROP TABLE {source_table}").collect()
            session.sql(f'ALTER TABLE {collated_table} RENAME TO {source_table}').collect()
            try:
                session.sql(f"""
                UPDATE CONTROL.COLLATION_CONTROL_TABLE
                SET COLLATION_TABLE_NAME = '{table_name_py}'
                WHERE DATABASE_NAME = '{database_py}' AND SCHEMA_NAME ILIKE '{schema_name_py}'
                AND COLLATION_TABLE_NAME ILIKE '{new_table_name}_COLLATED'
                """).collect()
            except Exception as e:
               return f"Failure in updating control table with table name: {table_name_py}"
            apply_grants(session, backup_table, source_table)   
            return f"Table: {table_name_py} collated"
        else:
            session.sql(f"DELETE FROM CONTROL.COLLATION_CONTROL_TABLE WHERE COLLATION_TABLE_NAME = '{new_table_name}_COLLATED'").collect()
            session.sql(f"DROP TABLE IF EXISTS {collated_table}").collect()
            session.sql(f"DROP TABLE IF EXISTS {backup_table}").collect()
            return f"Table: {table_name_py} not collated"

    else:
        return f"Table: {table_name_py} already exists in CONTROL.COLLATION_CONTROL_TABLE"
$$;

--store procedure to create schema of collation tables
CREATE OR REPLACE PROCEDURE CONTROL.CREATE_COLLATION_TABLES("DATABASE" VARCHAR, "SCHEMA_NAME" VARCHAR, "SOURCE_ROLE" VARCHAR, "COLLATION" VARCHAR)
RETURNS VARCHAR(16777216)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'create_collation_tables'
EXECUTE AS CALLER
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark import Session
import re

def create_collation_tables(
  session: Session,
  database_py: str,
  schema_name_py: str,
  source_role_py: str,
  collation_py: str
) -> str:

    """
    Function creates collation tables for all tables in the specified schema and database,
    applying the specified collation to text columns and ensuring that the tables are properly backed up and grants are applied.

    Args:
        session (Session): Snowflake session object
        database_py (str): Name of the database
        schema_name_py (str): Name of the schema
        source_role_py (str): Role to be used for the source tables
        collation_py (str): Collation to be applied

    Returns:    
        str: Message indicating the result of the collation process
    """
    existing_collated = []
    to_be_collated = []
    try: 
        table_set = session.sql(f"""
        SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA ILIKE '{schema_name_py}'
        AND TABLE_TYPE = 'BASE TABLE'
        and TABLE_CATALOG ILIKE '{database_py}'
        and TABLE_SCHEMA not in ('INFORMATION_SCHEMA', 'PUBLIC')
        and TABLE_NAME NOT ILIKE '%_BACKUP'
        order by table_name
        """).collect()
    except Exception as e:
        return f"Unable to query information_schema tables, {e} for schema {database_py}.{schema_name_py}"
        
    for Row in table_set:
      table_name = Row["TABLE_NAME"]
      if table_name:
           joined_tables = session.sql(f"""
           SELECT DISTINCT c.TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS c
           INNER JOIN CONTROL.COLLATION_CONTROL_TABLE o 
           ON UPPER(o.COLLATION_TABLE_NAME) = UPPER(c.TABLE_NAME)
           WHERE c.TABLE_SCHEMA ILIKE '{schema_name_py}'
           AND c.COLLATION_NAME = '{collation_py}'
           ORDER BY c.TABLE_NAME
           """).collect()
           if joined_tables:
              for Row in joined_tables:
                  already_collated_table_name = Row["TABLE_NAME"]
                  existing_collated.append(already_collated_table_name)
      to_be_collated.append(table_name)
      collated = set(existing_collated)
      tables_in_schema = set(to_be_collated)
      not_collated = list(collated.symmetric_difference(tables_in_schema))
      filtered_list = [i for i in not_collated if not re.search(r'_\d+_BACKUP', i)]

    for table in filtered_list:
       session.sql(f"""CALL CONTROL.create_collation_table('{database_py}', '{schema_name_py}', '{table}', '{source_role_py}', '{collation_py}')""").collect()
    existing_collated = len(collated) if len(collated) != 0 else 0
    new_collated = len(filtered_list)
    return f"Collation process completed. new collation tables: {new_collated}, existing collated tables: {existing_collated} for schema: {database_py}.{schema_name_py}"
$$;

CREATE OR REPLACE WAREHOUSE COLLATION_WH
  WAREHOUSE_SIZE = 'LARGE'
  AUTO_SUSPEND = 60 
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse for executing collation stored procedures';

GRANT USAGE ON WAREHOUSE COLLATION_WH TO ROLE COLLATION_ADMIN;
GRANT OPERATE ON WAREHOUSE COLLATION_WH TO ROLE COLLATION_ADMIN;

GRANT EXECUTE ON PROCEDURE CONTROL.create_collation_table(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR)
TO ROLE COLLATION_ADMIN;
GRANT EXECUTE ON PROCEDURE CONTROL.create_collation_tables(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR)
TO ROLE COLLATION_ADMIN;

-- to prepare for execution of stored procedures
-- use the following commands to set the role and warehouse:

USE ROLE COLLATION_ADMIN;

USE WAREHOUSE COLLATION_WH;







