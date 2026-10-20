# Task 10: `POST /insertOrders` with Batch Job

Batch job (commit size 10), failed-record step, on-complete audit, async response with job id.

URL: `{{baseUrl}}/insertOrders?filename=orders.csv` (no body)

The response returns **immediately**; inserts and the audit row happen a moment later, so check the DB after 2 to 3 seconds.

## Test files (copy into `data\input\` before every run)

- `orders.csv`, `orders-bad.csv`, `empty.csv`, `header-only.csv`, `big.csv`: same as Task 8.
- `orders-25.csv`: 25 valid rows, to prove the commit size of 10. Generate with PowerShell:

```powershell
$f = "C:\this\FA\AS\assessment-workspace\data\input\orders-25.csv"
'"user_id","order_timestamp","order_status","order_total"' | Out-File $f -Encoding ascii
1..25 | ForEach-Object { '"BAT{0:D5}","12/02/2021 11:02:00 PM","Confirmed","{1}"' -f $_, (100*$_) } | Out-File $f -Append -Encoding ascii
```

## Requests

### T10-01 Submit 3-row file

Reset tables first.

```javascript
pm.test("200", () => pm.response.to.have.status(200));
const j = pm.response.json();
pm.test("message", () => pm.expect(j.message).to.eql("Batch job submitted"));
pm.test("job id", () => pm.expect(j.batchJobId).to.be.a("string").and.not.empty);
pm.test("fast (async)", () => pm.expect(pm.response.responseTime).to.be.below(5000));
```

After 3 seconds:

```sql
SELECT COUNT(*) FROM customer_orders;                                  -- 3
SELECT file_name, status, reason FROM file_audit_log ORDER BY id DESC LIMIT 1;
```

| Column | Expected |
|---|---|
| `file_name` | `ord*****sv` |
| `status` | `SUCCESS` |
| `reason` | `{"fileName":"ord*****sv","totalRecords":3,"successCount":3,"failedCount":0,"processingTimeMs":<number>}` |

File is moved to `output\`.

### T10-02 Commit size 10

`?filename=orders-25.csv`. Console log shows three commits:

```
Committed 10 record(s)
Committed 10 record(s)
Committed 5 record(s)
```

Audit reason: `totalRecords 25, successCount 25`. `SELECT COUNT(*) FROM customer_orders WHERE user_id LIKE 'BAT%'` = 25.

### T10-03 Submit the same file again: upsert, no duplicates

Copy `orders-25.csv` back, call again. Then:

```sql
SELECT user_id, COUNT(*) c FROM customer_orders GROUP BY user_id HAVING c > 1;   -- no rows
```

### T10-04 Bad record does not stop the job

`?filename=orders-bad.csv`

- Audit row: `status FAILED`, reason JSON `totalRecords 3, successCount 2, failedCount 1`.
- `order_errors`: one row, `user_id` masked (`BAD***02`), message `Record failed in batch step`.
- Log: `Record failed for user_id BAD***02` (no raw id).
- Other two rows are in `customer_orders`.

### T10-05 Empty file returns 400

`?filename=empty.csv` expects `{ "error": "File validation failed", "reason": "File is empty" }`, file in `error\`, audit `FAILED`.

### T10-06 Over 5 MB returns 400

`?filename=big.csv` expects `reason: "File size exceeds 5 MB"`.

### T10-07 Header only returns 400

`?filename=header-only.csv` expects `{ "error": "Bad request", "message": "File contains no records" }`.

### T10-08 Missing file returns 404

`?filename=nofile.csv` expects `{ "error": "File not found", "message": "nofile.csv does not exist in the input folder" }`.

### T10-09 No filename returns 400

`POST {{baseUrl}}/insertOrders` expects 400 `{error, message}`.

### T10-10 Two submissions give two job ids

Submit twice (copy the file back between runs). `batchJobId` values must differ.

## Notes

- The batch runs update-then-insert-if-missing inside each aggregator block, because `customer_orders.user_id` has no UNIQUE key in your SQL script. Do not add a UNIQUE key: `/v1/insertOrders` (Task 2) inserts plain rows and would fail on a rerun.
- Rows with the same `user_id` twice in one file: the second is ignored (first one wins).
