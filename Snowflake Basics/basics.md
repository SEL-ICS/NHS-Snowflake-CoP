### Understanding case sensitivity and identifier requirements

> [!IMPORTANT]
> Please take a moment to read the official Snowflake documentation on [Identifier requirements](https://docs.snowflake.com/en/sql-reference/identifiers-syntax).

* Snowflake is case sensitive.  
Be aware wrapping a column name in double-quotes (") retains case sensitivity. Specifying a column name without double-quotes defaults to all upper case. For example, `Column_Name` will become `COLUMN_NAME` if you do not use double-quotes. If you use `"Column_Name"`, Snowflake will retain it as `Column_Name`.
* Names without "" need to start with a letter or underscore (_), and can only contain text, numberers, _ and $.
  * FIELD_NAME_123 will work.
  * 123_FIELD_NAME will not work.
  * FIELD_NAME_1+1 will not work.
  * "FIELD NAME" works only enclosed with "
  * "123_FIELD NAME" works only enclosed with "
  * another bullet point
