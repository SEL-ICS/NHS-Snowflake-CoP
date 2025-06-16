
# 🛠️ T-SQL to SnowSQL Conversion Tips

Welcome to the **T-SQL to SnowSQL Conversion Tips** section of our repository!

This section provides valuable insights and practical advice for converting your T-SQL scripts to SnowSQL. Whether you're migrating existing queries or starting fresh, these tips will help you avoid common pitfalls and leverage innovative SnowSQL features.

## 📚 Official Documentation

Official Snowflake documentation can be found here: 

## 🚀 Getting Started

### Common Pitfalls to Avoid

1. **Data Type Differences**: Be aware of differences in data types between T-SQL and SnowSQL. For example, `DATETIME` in T-SQL is equivalent to `TIMESTAMP` in SnowSQL.
2. **String Functions**: Some string functions may have different names or behaviors. Ensure you check the SnowSQL equivalents.
3. **Date Functions**: Date manipulation functions can vary. Pay attention to how dates are handled in SnowSQL.
4. **Error Handling**: Error handling mechanisms may differ. Review how SnowSQL handles exceptions and errors.

### Innovative SnowSQL Features

1. **Semi-Structured Data**: SnowSQL provides robust support for semi-structured data formats like JSON, Avro, and Parquet. Utilize functions like `PARSE_JSON` and `FLATTEN` to work with these formats.
2. **Time Travel**: Snowflake's Time Travel feature allows you to query historical data. Use the `AT` clause to access data at a specific point in time.
3. **Cloning**: Snowflake's zero-copy cloning enables you to create clones of databases, schemas, and tables instantly without additional storage costs.
4. **Streams and Tasks**: Leverage Snowflake's streams and tasks for change data capture and automated workflows.

---

We hope these tips help you make the most of SnowSQL and streamline your conversion process. If you have additional tips or questions, feel free to contribute or open a discussion!