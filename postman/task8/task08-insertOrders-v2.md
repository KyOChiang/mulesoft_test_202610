# Task 8: `POST /v2/insertOrders`

Masking, upsert, cleansing function, summary response. (Task 10 batch version is on `/insertOrders`.)

URL: `{{baseUrl}}/v2/insertOrders?filename=orders.csv` (no body)

## Test files (save in `data\input\`, copy again before every run)

`orders.csv`

```
"user_id","order_timestamp","order_status","order_total"
"AES45678","12/02/2021 11:02:00 PM","Confirmed","1200"
"AES4 5679","12/02/2021 09:11:00 AM","Cancelled","2500"
"AES45680","12/02/2021 06:02:00 PM","Confirmed","5100"
```

`orders-bad.csv` (row 2 has an invalid timestamp, row 3 has padded spaces and amount with comma)

```
"user_id","order_timestamp","order_status","order_total"
"BAD00001","12/02/2021 11:02:00 PM","Confirmed","100"
"BAD00002","not-a-date","Confirmed","200"
"  BAD00003  ","12/02/2021 06:02:00 PM","  Confirmed ","1,250.50"
```

`empty.csv` (0 bytes), `header-only.csv` (header line only), `big.csv` (over 5 MB).

Big file (PowerShell): `fsutil file createnew C:\this\FA\AS\assessment-workspace\data\input\big.csv 6000000`

## Requests

### T8-01 First run, all new

Reset: `DELETE FROM customer_orders; DELETE FROM file_audit_log; DELETE FROM order_errors;`

```javascript
pm.test("200", () => pm.response.to.have.status(200));
pm.test("summary", () => pm.expect(pm.response.json()).to.eql({
  fileName: "orders.csv", processed: 3, inserted: 3, updated: 0, failed: 0, status: "SUCCESS" }));
```

DB: 3 rows in `customer_orders`; `order_status` keeps case (`Confirmed`); `order_timestamp` of AES45678 = `2021-02-12 23:02:00`; file moved to `output\`.

### T8-02 Upsert: 2 inserted, 1 updated (the brief's example)

Reset tables, then insert only the first user: `INSERT INTO customer_orders (user_id,order_timestamp,order_status,order_total) VALUES ('AES45678','2020-01-01 00:00:00','Old',1);`
Copy `orders.csv` in and call.

```javascript
pm.test("2 inserted 1 updated", () => {
  const j = pm.response.json();
  pm.expect(j.processed).to.eql(3); pm.expect(j.inserted).to.eql(2);
  pm.expect(j.updated).to.eql(1);   pm.expect(j.failed).to.eql(0);
  pm.expect(j.status).to.eql("SUCCESS");
});
```

DB: `SELECT COUNT(*) FROM customer_orders WHERE user_id='AES45678'` = **1**, status now `Confirmed`.

### T8-03 Run the same file again: 0 inserted, 3 updated

Copy `orders.csv` back in and call. Expect `inserted 0, updated 3`.

### T8-04 Masking in audit log and logs

```sql
SELECT file_name, status, reason FROM file_audit_log ORDER BY id DESC LIMIT 1;
```

| Column | Expected |
|---|---|
| `file_name` | `ord*****sv` (not `orders.csv`) |
| `status` | `SUCCESS` |
| `reason` | JSON summary with `"fileName":"ord*****sv"` |

Console log lines show `AES***78`, never `AES45678`. `AES4 5679` (9 chars) shows as `AES****79`.

### T8-05 Bad record: failed = 1, run continues

Use `?filename=orders-bad.csv`.

```javascript
pm.test("1 failed, others ok", () => {
  const j = pm.response.json();
  pm.expect(j.processed).to.eql(3); pm.expect(j.inserted).to.eql(2); pm.expect(j.failed).to.eql(1);
  pm.expect(j.status).to.eql("FAILED");
});
```

DB: `order_errors` has one row, `user_id = 'BAD***02'` (masked), `error_message` is only the error type (no raw id). `file_audit_log.reason` JSON contains `"error":"1 of 3 record(s) failed"`. Row 3 is stored trimmed: `user_id = 'BAD00003'`, `order_total = 1250.50`.

### T8-06 Empty file returns 400

`?filename=empty.csv`

```javascript
pm.test("400", () => pm.response.to.have.status(400));
pm.test("body", () => pm.expect(pm.response.json()).to.eql({ error: "File validation failed", reason: "File is empty" }));
```

DB: audit row `FAILED`, reason `File is empty`. File is in `error\`.

### T8-07 Over 5 MB returns 400

`?filename=big.csv` expects `reason: "File size exceeds 5 MB"`, file in `error\`.

### T8-08 Header only

`?filename=header-only.csv` expects 200 with `processed 0` and `status: "FAILED"`, audit reason contains `File contains no records`.

### T8-09 File does not exist returns 404

`?filename=nofile.csv`

```javascript
pm.test("404", () => pm.response.to.have.status(404));
pm.test("body", () => pm.expect(pm.response.json()).to.eql(
  { error: "File not found", message: "nofile.csv does not exist in the input folder" }));
```

### T8-10 No filename returns 400 (APIKit)

`POST {{baseUrl}}/v2/insertOrders` expects 400 with `{error, message}`.

## Notes

- Status is `FAILED` whenever `failed > 0`, even though the HTTP code is 200.
- MySQL Workbench quick check for no duplicate users: `SELECT user_id, COUNT(*) c FROM customer_orders GROUP BY user_id HAVING c > 1;` must return nothing.
