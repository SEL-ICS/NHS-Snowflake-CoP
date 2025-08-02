## 📊 Credit Consumption

Snowflake uses a credit-based system to measure and bill for the resources consumed.

Official Snowflake documentation to understand overall costs can be found here: [Snowflake Documentation](https://docs.snowflake.com/en/user-guide/cost-understanding-overall).

Credits are incurred from the following:

### Compute

- **Virtual Warehouses**: Billed per second, with a 60 second minimum. Each time a warehouse is started or resumed, the warehouse is billed for at least 1 minute of usage, with any subsequent billing being by the second if the warehouse runs continuously.
- **Serverless**
- **Compute Pool**: Used by Snowpark Container Services.
- **Cloud Services**: Metadata management, authentication, and other services. Calculated daily and only charged if this exceeds 10% of the daily warehouse usage.

### Storage

### Data Transfer
- This may be free of charge or incur costs depending on whether data is being transferred across different Cloud Providers and Regions



## Using monitoring views to understand credit consumption and costs

There are several views that can be used to monitor credit consumption, and each breaks down to different levels of detail, making it a multi-step process to determine how credits consumed equate to actual final billing, and how to generate insights on how costs can be optimised, which must involve further analysis than simply looking at user and query credit consumption.

These are the key objects to be used to understand the high level warehouse credit consumption and billing:

__warehouse_metering_daily_history__ view - this shows the total warehouse credits consumed in a given day

__warehouse_usage_in_currency_daily__ view - this shows the daily credit consumption as well as the cost of that usage in the organisation's currency

__warehouse_metering_history__ view - this shows the total warehouse credits consumed on an hourly basis. It is broken down by warehouse and start/end times. It includes the fields:
- CREDITS_USED (the total of warehouse credits used, which is the sum of CREDITS_USED_COMPUTE and CREDITS_USED_CLOUD_SERVICES )
- CREDITS_USED_COMPUTE, and 
- CREDITS_USED_CLOUD_SERVICES
- CREDITS_ATTRIBUTED_COMPUTE_QUERIES (this is a subset of the CREDITS_USED_COMPUTE field and denotes the compute credits incurred that are attributable to queries executed)

__Idle credits__ can be calculated by subtracting CREDITS_ATTRIBUTED_COMPUTE_QUERIES from CREDITS_USED_COMPUTE 

__query_attribution_history__ view - this shows the compute credits incurred in the field CREDITS_ATTRIBUTED_COMPUTE, and it is broken down by query, warehouse, user name and start/end times. It also includes the field CREDITS_USED_QUERY_ACCELERATION


## 💡 Cost Management Tips

To manage costs efficiently in Snowflake, consider the following best practices:
- **Warehouse Sizing**: Choose the right size for your warehouses based on workload requirements. When in doubt, start with a smaller warehouse and gradually increase if you come across run-time errors frequently for particular queries.
- **Resource Monitoring**: Regularly monitor resource usage and adjust configurations as needed. This will include understanding your consumption of **idle credits**, and considering the adjusting the warehouse auto-suspend time.
- **Query Optimization**: Optimize queries to reduce compute time and resource consumption.
- **Data Retention**: Implement data retention policies to manage storage costs.
