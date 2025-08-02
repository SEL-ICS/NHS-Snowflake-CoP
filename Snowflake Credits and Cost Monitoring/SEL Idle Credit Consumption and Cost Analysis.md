## 📊 Introduction

This section contains an in-depth analysis of **idle credit consumption and associated costs** within the Snowflake data platform, conducted by the **Analytics team at South East London Integrated Care Board (SEL ICB)**.

As part of our ongoing efforts to optimize cloud data infrastructure and ensure cost-effective use of resources, we investigated patterns of compute credit usage across our virtual warehouses. Our focus was on identifying **idle credits**—credits consumed by compute resources that were not directly attributable to query execution—and understanding their financial impact.

You can adapt our queries and analysis that follow as a tool to:

- Quantify idle credit usage across different time periods and warehouses.
- Highlight inefficiencies in compute resource allocation.
- Provide actionable insights to reduce unnecessary costs.
- Support data-driven decision-making for platform optimization.

The findings and tools shared here are intended to benefit other NHS organizations and public sector teams using Snowflake, by promoting transparency and encouraging best practices in cloud cost management.

## 🕒 Idle Credits

Idle credits are accrued when compute resources are allocated but not actively used. It's important to monitor and manage idle credits to avoid unnecessary costs.

- The script below is suggested in Snowflake's documentation here https://docs.snowflake.com/en/release-notes/bcr-bundles/2024_08/bcr-1714 as the mechanism by which idle credits can be identified (in this example for the last 10 days)

```sql 
SELECT (
   SUM(credits_used_compute) -
   SUM(credits_attributed_compute_queries)
) AS idle_cost,
    warehouse_name
 FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE start_time >= DATEADD('days', -10, CURRENT_DATE())
          AND end_time < CURRENT_DATE()
    GROUP BY warehouse_name;
```

And here's a modified version of the above script that focuses on a single day (__28th April 20205__) and a single warehouse in the SEL ICB platform and that groups the costs by hour. 

```sql 
-- idle and query costs by hour for 2025-04-28
-- for warehouse SEL_ANALYTICS_XS
SELECT
    date_part(hour, start_time) as date_hour,
    (
        SUM(credits_used_compute) - SUM(credits_attributed_compute_queries)
    ) AS idle_cost,
    SUM(credits_attributed_compute_queries) as query_cost,
    warehouse_name
FROM
    SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE
    start_time >= '2025-04-28'
    and start_time <= '2025-04-29'
    AND warehouse_name = 'SEL_ANALYTICS_XS'
GROUP BY
    warehouse_name,
    date_hour
order by
    date_hour;
```

The script below is another version Snowflake's original script, adapted to calculate the percentage of total compute credits consumed that are __idle credits__. It is restricted to the same date __28th April 2025__ and to the __SEL_ANALYTICS_XS__ warehouse. Each row represents a one hour time slot, from the earliest time this warehouse was active on that day, to the latest time. From this data we can see that in all except one row, by far the biggest percentage of compute credits incurred relates to __idle credits__. 

```sql
SELECT
    *,
    credits_used_compute - credits_attributed_compute_queries AS idle_credits,
(
        credits_used_compute - credits_attributed_compute_queries
    ) / credits_used_compute * 100 AS percentage_idle_credits
FROM
    SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE
    warehouse_name = 'SEL_ANALYTICS_XS'
    AND start_time >= '2025-04-28'
    AND start_time <= '2025-04-29'
ORDER BY
    percentage_idle_credits;
```

| START_TIME | END_TIME | WAREHOUSE_ID | WAREHOUSE_NAME | CREDITS_USED | CREDITS_USED_COMPUTE | CREDITS_USED_CLOUD_SERVICES | CREDITS_ATTRIBUTED_COMPUTE_QUERIES | IDLE_CREDITS | PERCENTAGE_IDLE_CREDITS |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025-04-28T07:00:00.000Z | 2025-04-28T08:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.089575555 | 0.088333333 | 0.001242222 | 0.054154495 | 0.034178838 | 38.7 |
| 2025-04-28T15:00:00.000Z | 2025-04-28T16:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.742973609 | 0.723055557 | 0.019918052 | 0.309076916 | 0.413978641 | 57.3 |
| 2025-04-28T14:00:00.000Z | 2025-04-28T15:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.890077219 | 0.863333334 | 0.026743885 | 0.364640556 | 0.498692778 | 57.8 |
| 2025-04-28T13:00:00.000Z | 2025-04-28T14:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.751477776 | 0.735 | 0.016477776 | 0.254702459 | 0.480297541 | 65.3 |
| 2025-04-28T16:00:00.000Z | 2025-04-28T17:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.206093892 | 0.194722222 | 0.01137167 | 0.063574573 | 0.131147649 | 67.4 |
| 2025-04-28T12:00:00.000Z | 2025-04-28T13:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.500847779 | 0.48388889 | 0.016958889 | 0.112230778 | 0.371658112 | 76.8 |
| 2025-04-28T10:00:00.000Z | 2025-04-28T11:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.735608334 | 0.722222223 | 0.013386111 | 0.156510989 | 0.565711234 | 78.3 |
| 2025-04-28T11:00:00.000Z | 2025-04-28T12:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.671317505 | 0.655 | 0.016317505 | 0.137034847 | 0.517965153 | 79.1 |
| 2025-04-28T08:00:00.000Z | 2025-04-28T09:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.275273056 | 0.269166667 | 0.006106389 | 0.055309227 | 0.21385744 | 79.5 |
| 2025-04-28T20:00:00.000Z | 2025-04-28T21:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.140206385 | 0.138611111 | 0.001595274 | 0.014910037 | 0.123701074 | 89.2 |
| 2025-04-28T09:00:00.000Z | 2025-04-28T10:00:00.000Z | 1 | SEL_ANALYTICS_XS | 0.346506117 | 0.335833333 | 0.010672784 | 0.027529594 | 0.308303739 | 91.8 |

__Reconciliation of compute credits between warehouse_metering_history and query_attribution_history views__

The script below is checking the reconciliation between the total compute credits used (using the field CREDITS_ATTRIBUTED_COMPUTE) from the warehouse_metering_history view, and the credits used per query from the query_attribution_history view (using the field CREDITS_ATTRIBUTED_COMPUTE_QUERIES). It shows that the two match, i.e for 28th April 2025 both views are showing the total compute credits as being 1.549674471. However it should be noted that these fields, in both views, relate to credits that exclude __idle credits__.

```sql
-- total credits PER query for a given date
-- only includes costs per query, no idle costs
-- this reconciles with WAREHOUSE_METERING_HISTORY
select *
from SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
where warehouse_name = 'SEL_ANALYTICS_XS'
and start_time >= '2025-04-28' and start_time <= '2025-04-29'
order by start_time;
```
Focussing on a single hour in a single day makes it easier to identify the issue. 

The following three queries can be used to further narrow down the analysis. They look at the time period 10:00 to 11:00 on 2025-04-28 executed by the SEL_ANALYTICS_XS warehouse.

```sql
-- total query cost grouped by hour
select
    date_part(hour, start_time) date_hour
    ,count(query_id) number_of_queries_executed
    ,sum(timediff(seconds, start_time, end_time)) query_duration_seconds
    ,sum(credits_attributed_compute) total_credits_used
from
    SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
where
    warehouse_name = 'SEL_ANALYTICS_XS'
    and start_time >= '2025-04-28'
    and start_time <= '2025-04-29'
    and date_hour = 10
group by
    date_hour
order by
    date_hour;
    
    -- query executions by hour and minute time slots
-- between 10:00 and 11:00
select
    query_id,
    date_part(hour, start_time) date_hour,
    date_part(minute, start_time) date_minute,
    timediff(seconds, start_time, end_time) query_duration_seconds,
    start_time,
    end_time
from
    SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
where
    warehouse_name = 'SEL_ANALYTICS_XS'
    and start_time >= '2025-04-28'
    and start_time <= '2025-04-29'
    and date_hour = 10
order by
    date_hour,
    date_minute;

-- idle and query costs by hour for 2025-04-28 at 10:00
-- for warehouse SEL_ANALYTICS_XS
SELECT
    date_part(HOUR, start_time) AS date_hour,
    (
        SUM(credits_used_compute) - SUM(credits_attributed_compute_queries)
    ) AS idle_cost,
    SUM(credits_attributed_compute_queries) AS query_cost,
    warehouse_name
FROM
    SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE
    start_time >= '2025-04-28'
    AND start_time <= '2025-04-29'
    AND warehouse_name = 'SEL_ANALYTICS_XS'
    AND date_hour = 10
GROUP BY
    warehouse_name,
    date_hour
ORDER BY
    date_hour;
```

## Conclusions and Actionable Insights:
- During the one hour time period analysed, which was typical of average compute credit consumption across most working days for our team using this virtual warehouse, 26 queries were run with a total duration of 129 seconds
- The queries were not executed one after the other and there were considerable time gaps between them, with the warehouse idling between queries. 
- For this time slot >90% of credit usage was for the warehouse idling (before auto-suspend kicks in) and at this point the warehouse idle time was set to 2 minutes.
- **CONCLUSION**: Given the pattern of active use of this virtual warehouse, reducing the idle time in half, to 60 seconds, which is the minimum charge every time a virtual warehouse is started, should significantly help reduce idle credit costs


 Here are some  💡 **tips to optimise idle credit consumption**:
- **Auto-Suspend**: Configure warehouses to auto-suspend when not in use. If your idle credits are currently a big proportion of your total credits, you may want to set the auto-suspend time to the minimum recommended, i.e. 60 seconds.
- **Auto-Resume**: Enable auto-resume to start warehouses only when needed.
- **Scaling Policies**: Use scaling policies to adjust compute resources based on demand.