# Task 4: Scheduled job with parallel processing

No HTTP endpoint, so Postman is used only to prove the backend credentials work. The rest is file + DB checks.

## Prepare

1. In `assessment-application.xml`, flow `customer-batch-flow`, change the cron to `0/30 * * * * ?` (every 30 s).
   **Restore `0 30 1 * * ?` before submission.**
2. Put `customers.json` in `data\input\`:

```json
[
  { "userId": 1, "firstName": "Will",   "lastName": "Smith",  "salary": 2000,   "status": "Valid" },
  { "userId": 2, "firstName": "Jane",   "lastName": "Smith",  "salary": 12000,  "status": "Valid" },
  { "userId": 3, "firstName": "Jane",   "lastName": "Doe",    "salary": 2000,   "status": "Not Valid" },
  { "userId": 4, "firstName": "Mickey", "lastName": "Mouse",  "salary": 120000, "status": "Valid" },
  { "userId": 5, "firstName": "Muthu",  "lastName": "Robert", "salary": -0.1,   "status": "Error" }
]
```

3. `DELETE FROM customer_info;`

## T4-01 Backend reachable (Postman)

`POST http://mockuserinfo.sg-s1.cloudhub.io/api/assessment`

Headers: `client_id: 24d518848643453fa5b4aaa0b41822c8`, `client_secret: 3417688c0d8e4aAb9a8bFD1Bf4Dc947E`, `Content-Type: application/json`

```json
{ "userId": 4, "firstName": "Will", "lastName": "Hunter", "salary": 34567 }
```

Tests tab:

```javascript
pm.test("200", () => pm.response.to.have.status(200));
pm.test("has enrichment fields", () => {
  const j = pm.response.json();
  ["userId","fullName","tier","tax","totalTax"].forEach(k => pm.expect(j).to.have.property(k));
});
pm.test("under 90s", () => pm.expect(pm.response.responseTime).to.be.below(90000));
```

## T4-02 Run the job and check

Start the app, wait about 30 s, then check:

| # | Check | Expected |
|---|---|---|
| 1 | Console log | `Valid: 3, Invalid: 2` then `Selected 3 rows from customer_info` then `Customer batch finished` |
| 2 | `data\error\invalid-customers.csv` | exactly the content below |
| 3 | `SELECT * FROM customer_info;` | 3 rows: user_id 1, 2, 4 (not 3, 5) |
| 4 | Same rows | `full_name`, `tier`, `tax`, `total_tax` filled, `updated_at` set |
| 5 | Parallel proof | log lines for the 3 backend calls come from different threads (`[_parallel-foreach...]`) |

```
"User ID","First Name","Last Name","Salary","Status"
3,"Jane","Doe",2000,"Not Valid"
5,"Muthu","Robert",-0.1,"Error"
```

## T4-03 Edge cases

| Case | How | Expected |
|---|---|---|
| File missing | delete `customers.json` | WARN `customers.json not found in input folder`, no crash |
| All invalid | change every status to `"Error"` | error CSV written, log `No valid records to process`, no DB insert |
| All valid | change every status to `"Valid"` | no error CSV written (old file stays), log `No invalid records` |
| Re-run | leave the file, wait for the next tick | no duplicate rows (insert skips existing `user_id`), rows re-enriched |
| Backend down | wrong `backend.host` | log `Enrich failed for id ...`, other rows still processed |

## Notes

- The flow does **not** move or delete `customers.json`, so with the 30 s test cron it re-runs on the same file every tick. Remove the file when done testing.
- The stale `invalid-customers.csv` is overwritten on each run that has invalid rows.
