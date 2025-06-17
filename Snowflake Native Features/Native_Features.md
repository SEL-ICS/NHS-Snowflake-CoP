## ✨ Novel Features

| Feature            | Description |
|--------------------|-------------|
| 📝 **Auto-save**   | Automatically saves worksheet edits in real-time, helping prevent data loss. |
| 🔗 **Sharing**     | Generate secure, shareable worksheet links for easy collaboration—no file exports required. |
| 📊 **Visual Query Results** | Interactive result grid with filtering, export to CSV/Excel, and charting to visualize your data quickly. |
| 📁 **Cloning**     | Create instant, zero-copy clones of databases, schemas, or tables—ideal for testing and backups. |

---

## ⚙️ Snow SQL Innovations

| Command / Feature         | What It Does |
|---------------------------|--------------|
| 🔁 **CREATE OR REPLACE**  | Replaces objects (`TABLE`, `VIEW`, `PROC`, etc.) without a `DROP`.
| 🧮 **GROUP BY ALL**       | Automatically groups by all non-aggregated columns in `SELECT`, saving time and avoiding syntax errors.
| 🔍 **QUALIFY Clause**     | Filters window function results (`RANK()`, `ROW_NUMBER()`, etc.) directly in the query—no subqueries needed. |

---

## 🛠️ Example: QUALIFY Clause

```sql
SELECT 
    patient_id,
    activity_volume,
    RANK() OVER (PARTITION BY patient_id ORDER BY activity_volume DESC) AS order_rank
FROM orders
QUALIFY order_rank = 1;
```
---

We hope these tips help you get the most out of Snowsight. If you have suggestions or additional tips, feel free to contribute or open a discussion!
