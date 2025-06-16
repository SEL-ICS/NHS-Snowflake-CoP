### TSQL to SnowSQL Changes
Below you can find a list of changes in syntax, from small changes in spelling of functions, to wider changes in which SnowSQL functions are used in place of TSQL ones.

### Jump to a section
- [IIF to IFF](#iif-to-iff)
- [LIKE to ILIKE](#like-to-ilike)
- [ILIKE ANY](#ilike-any)
- [ISNULL to IFNULL ](#isnull-to-ifnull)
- [Text Concatenation](#text-concatenation)
- [CONCAT_WS New Functions](#concat_ws-new-functions)
- [STRING_AGG to LISTAGG](#string_agg-to-listagg)
- [EOMONTH New Functions](#eomonth-new-functions)
- [Temporary Table Syntax](#temporary-table-syntax)
- [UDF - Functions](#udf---functions)
- [VARCHAR Changes](#varchar-changes)


#### IIF to IFF
* IIF is now IFF and functions the same.
    ```sql
    --SELECT IIF(2 + 2 = 4, 1, 0) -- NO LONGER WORKS
    SELECT IFF(2 + 2 = 4, 1, 0) -- Returns 1 if true, 0 if false.
    ```
    **RESULT:**
    ```
    1
    ```
    However it may be better to use CASE WHEN statements for logical operations which still functions the same in SnowSQL as TSQL.

#### LIKE to ILIKE
* ILIKE should be used instead of LIKE to ignore case sensitivity. LIKE can still be used if case sensitivity is required. 

    With LIKE
    ```sql
    SELECT 'Match' 
    WHERE 'text' LIKE '%TEXT%' -- Since LIKE is case sensitive, text does not match with %TEXT%.
    ```
    **RESULT:**
    ```
    NULL
    ```
    Instead with ILIKE
    ```sql
    SELECT 'Match' 
    WHERE 'text' ILIKE '%TEXT%' -- since ILIKE is case insensitive this will match and return a result
    ```
    **RESULT:**
    ```
    Match
    ```
#### ILIKE ANY
* ILIKE ANY ('%this%', '%that%') can be used to find text containing either of the wildcard string.
    ```sql
    CREATE OR REPLACE TABLE PHRASES (
    PHRASE VARCHAR
    );

    -- Insert test data
    INSERT INTO PHRASES VALUES
    ('This one'),
    ('Or THAT one'),
    ('Something '),
    ('Nothing');

    -- Query using ILIKE ANY
    SELECT PHRASE
    FROM PHRASES
    WHERE PHRASE ILIKE ANY ('%this%', '%that%');
    ```
    **RESULT:**
    ```
    This one
    Or THAT one
    ```
#### ISNULL to IFNULL 
* ISNULL is now IFNULL and functions the same, in that if the field value is NULL it will return the second argument as the value.
    ```sql
    --SELECT ISNULL(NULL, 'Is Null') -- NO LONGER WORKS
    SELECT IFNULL(NULL, 'Is Null') -- Returns 1 if true, 0 if false.
    ```
    **RESULT:**
    ```
    Is Null
    ```
    In General its recommended to use the COALESCE function which is identical but allows for >2 arguments
    ```sql
    SELECT COALESCE(NULL, NULL, NULL 'Is Still Null') -- Returns 1 if true, 0 if false.
    ```
    **RESULT:**
    ```
    Is Still Null
    ```

#### Text Concatenation
* Double Pipe || can be used to concatenate text instead of + which can only be used for simple addition. Alternatively it is better to use the CONCAT('a', 'b',…).
    ```sql
    --SELECT 'a' + 'b' + 'c' -- NO LONGER WORKS
    SELECT 
        'a' || 'b' || 'c' AS MANUAL_CONCAT -- New Manual concatenation each letter
        ,CONCAT('d', 'e','f') FUNCTION_CONCAT-- CONCAT function (recommended)
    ```
    **RESULT:**
    ```
    | MANUAL_CONCAT | FUNCTION_CONCAT |
    |---------------|-----------------|
    | abc           | def             |

    ```

#### CONCAT_WS New Functions
* CONCAT_WS, a function in TSQL that concatenates text with the second variable being a separator ("|" for example), no longer works in Snowflake if NULLS are included. It now only works with a combination of 3 ARRAY functions.
To do this, create the array (ARRAY_CONSTRUCT), removes any NULLS (ARRAY_COMPACT) and returns as a string separated by '|'  or any other text required (ARRAY_TO_STRING).

    ```sql
    SELECT 
    ARRAY_TO_STRING(
        ARRAY_COMPACT(
            ARRAY_CONSTRUCT(
                'a', 'b', NULL, 'c'
            )
        )
    , '|'
    ) -- Combination of these 3 function handles nulls and ignore them. 
    ```
    **RESULT:**
    ```
    a|b|c
    ```

#### STRING_AGG to LISTAGG
* STRING_AGG() is replaced by LISTAGG(DISTINCT FIELD_NAME, '|') which aggregates concatenated text over a field, with the second parameter being the separator. NULLS are also ignored here.
    ```sql
    CREATE OR REPLACE TABLE FIELD_VALUES (
    FIELD_NAME VARCHAR
    );

    -- Insert test data
    INSERT INTO FIELD_VALUES VALUES
    ('A'),
    ('B'),
    (NULL),
    ('C');
    --SELECT STRING_AGG(NULL, NULL, NULL 'Is Still Null') -- No longer works
    SELECT LISTAGG(FIELD_NAME, '|') -- aggregate d
    FROM FIELD_VALUES
    ```
    **RESULT:**
    ```
    A|B|C
    ```

#### EOMONTH New Functions
* EOMONTH no longer works to get end of month, or end of previous month.
For end of previous month previously EOMONTH(DATE_FIELD, -1) it needs a combination of functions.
ADD_MONTHS(LAST_DAY(DATE_FIELD), -1)
LAST_DAY(DATE) will return end of month position by default (can add YEAR as variable to return end of year) 
and ADD_MONTHS() will take into account end of months i.e. ADD_MONTHS('2024-02-28', -1) will return '2024-01-31' as it detects the value is at month end. 

    ```sql
    --SELECT EOMONTH('2025-01-13', -1) -- No Longer Works
    SELECT ADD_MONTHS(LAST_DAY('2025-02-13'), -1) -- Takes the last day of February (28th), selects the previous end of month date (31st Jan)
    ```
    **RESULT:**
    ```
    2025-01-31
    ```
    This can be combined with CURRENT_DATE() to return the latest end of month position

    ```sql
    SELECT ADD_MONTHS(LAST_DAY(CURRENT_DATE()), -1) -- Takes the last day of February (28th), selects the previous end of month date (31st Jan)
    ```
    **RESULT:**
    ```
    2025-05-31 -- (as of time this was written!)
    ```

#### Temporary Table Syntax
* SnowSQL no longer uses the # (#temp_table) and instead is written similar to normal tables, instead defining this in a CREATE OR REPLACE TEMPORARY TABLE statement in the below statement. It will still require a Database and Schema be defined.
    ```sql
    USING 
        DATABASE_NAME
        ,SCHEMA_NAME
    CREATE OR REPLACE TEMPORARY TABLE temp_table -- identical syntax to normal table, with added TEMPORARY
    ```
    Due to speed of Snowflake it is however recommended to use CTEs in place of temporary tables in cases of smaller tables. CTEs are defined in the same way as TSQL.

#### UDF - Functions
* UDFs / Functions currently do not allow dynamic SQL, instead they need to specify a language (i.e. SQL / Python / JavaScript) and script is only in that language. This can make scripts slow if using functions on tables with many rows where function contains subqueries. 

#### VARCHAR Changes 
* Specifying VARCHAR(XXX) length is now not necessary unless you want to create strict limitations on tables, snowflake will only store the bytes needed for the strings within the field. For example a 5 letter string would take up the same space in VARCHAR(5) as VARCHAR(max).
For example, all the below would be of equivalent size unless larger text was inserted into the latter 2 fields.
 
    ```sql
    CREATE OR REPLACE TABLE FIELD_VALUES (
    FIELD_1 VARCHAR(5)
    FIELD_2 VARHCAR(300)
    FIELD_2 VARHCAR(max)
    );
    ```

