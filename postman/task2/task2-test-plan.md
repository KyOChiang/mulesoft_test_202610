# Task 2 - insertOrders: Postman test plan

`POST https://127.0.0.1:8083/api/integration/insertOrders` reads a CSV from `C:/mule-training/input/`, so every case needs a fixture staged **before** the request is sent. Postman asserts the HTTP result; the DB and folder effects below are checked by hand (or with the SQL further down).

## How to run a case

1. Reset the tables (SQL below) and empty `input/`, `output/`, `error/`.
2. Copy the fixture from `fixtures/` to `C:/mule-training/input/orders.csv` (see the **Stage** line in each request).
3. Send the request in Postman and check the test results.
4. Check the DB rows and where the file ended up.

Copy fixtures as-is (binary). Several depend on exact bytes: CRLF line endings, the UTF-8 BOM and the 5 MB boundary sizes.

## Assumptions

| # | Assumption | Why it matters |
|---|---|---|
| 1 | The endpoint takes no parameters and picks up `orders.csv` from `input/` | The spec shows no body or query params |
| 2 | Timestamps are `MM/dd/yyyy hh:mm:ss a` and output is ISO 8601 without a zone, e.g. `2021-12-02T23:02:00` | `12/02/2021` is ambiguous (2 Dec or 12 Feb); TC05 row TS0005 (`12/31/2021`) only parses month-first |
| 3 | "Larger than 5 MB" means more than 5,242,880 bytes | Decides BVA01 / BVA02 / NEG04; a 5,000,000-byte limit would flip BVA02 |
| 4 | Header-only and whitespace-only files count as empty | Spec only says "empty" |
| 5 | Trimming removes edge whitespace only, so `AES4 5679` keeps its internal space | Likely a deliberate data-quality trap in the sample file; confirm whether it should be rejected or cleaned |
| 6 | Schema: `customer_orders(id, user_id varchar(20), order_timestamp datetime, order_status varchar(20), order_total decimal(10,2))`, all NOT NULL; `order_errors(id, user_id varchar(20), error_message, timestamp)` | Insert failures must come from length / range limits. An empty `user_id` is `''`, not NULL, so it inserts fine |

## Test matrix

### 1 - Happy path

| ID | Case | Fixture (stage as) | Expect | Verify manually |
|---|---|---|---|---|
| TC01 | Sample file processed | `tc01_sample.csv` (as `orders.csv`) | 200 | 3 rows in `customer_orders` (AES45678, `AES4 5679`, AES45680); totals 1200 / 2500 / 5100 as numbers; timestamps ISO 8601 (2021-12-02T23:02:00, T09:11:00, T18:02:00); 0 rows in `order_errors`; file moved to `output/`; `file_audit_log` = SUCCESS |
| TC02 | CRLF line endings (Windows file) | `tc02_crlf.csv` (as `orders.csv`) | 200 | 3 rows (CRL0001-0003); `order_total` stored as 1200 / 2500 / 5100 with no trailing carriage return; file in `output/`; SUCCESS |
| TC03 | 1000-row file (loop under volume) | `tc03_bulk_1000.csv` (as `orders.csv`) | 200 | 1000 rows (BULK0001-BULK1000); 0 in `order_errors`; file in `output/`; exactly one SUCCESS audit row |

### 2 - Cleansing

| ID | Case | Fixture (stage as) | Expect | Verify manually |
|---|---|---|---|---|
| TC04 | Whitespace trimmed on all string fields | `tc04_trim.csv` (as `orders.csv`) | 200 | 3 rows: `WSP0001`, `WSP0002`, `WSP 0003`; leading/trailing spaces and tabs removed from every field; the internal space in `WSP 0003` is kept; totals 1200 / 2500 / 5100 numeric; file in `output/` |
| TC05 | Timestamps converted to ISO 8601 (AM/PM edges) | `tc05_timestamps.csv` (as `orders.csv`) | 200 | 6 rows (TS0001-TS0006): 2021-12-02T00:00:00 (12:00 AM), 2021-12-02T12:00:00 (12:00 PM), 2021-12-02T23:59:59, 2021-12-02T01:05:00, 2021-12-31T23:00:00, 2024-02-29T08:30:00. Assumes MM/dd/yyyy - TS0005 (12/31) only parses month-first |
| TC06 | Totals parsed as numbers | `tc06_totals.csv` (as `orders.csv`) | 200 | 5 rows (TOT0001-TOT0005); totals stored numerically: 1200, 1200.50, 0, 99999999.99, 2500.75 (last one had surrounding spaces); decimals not rounded or truncated |
| TC07 | Quoted comma, unicode, quote characters | `tc07_special_chars.csv` (as `orders.csv`) | 200 | 4 rows stored literally: embedded comma kept in `Paid, pending`; Chinese text intact; doubled quotes unescaped to `Cancelled "by user"`; the `' OR '1'='1` value stored as plain text. A SQL error here means the insert builds SQL by concatenation (use parameters). Run on a local DB only |

### 3 - Insert failures

| ID | Case | Fixture (stage as) | Expect | Verify manually |
|---|---|---|---|---|
| TC08 | One bad record does not stop the loop | `tc08_partial_failure.csv` (as `orders.csv`) | 200 | 3 rows inserted (PRT0001, PRT0003, PRT0005); 2 rows in `order_errors` (PRT0002: `order_status` is 26 chars but the column is varchar(20); PRT0004: `order_total` 99999999999 is out of range for decimal(10,2)); file in `output/`; SUCCESS |
| TC08B | Failed row whose user_id is too long for order_errors | `tc08b_long_user_id.csv` (as `orders.csv`) | 200 | The 300-char `user_id` fails the insert AND would fail the `order_errors` insert (varchar(20)) unless truncated. Expect LUI0001 and LUI0003 inserted; 1 row in `order_errors` with `user_id` cut to 20 chars (or NULL) and the full error in `error_message`; the loop finishes; file in `output/`; SUCCESS |
| TC09 | [Assumed] All records fail - still 200 per spec | `tc09_all_fail.csv` (as `orders.csv`) | 200 | 0 rows in `customer_orders`; 3 rows in `order_errors` (ALF0001-0003, status too long); file in `output/`; SUCCESS (literal reading of steps 5-8) - confirm this is intended |
| TC10 | [Not in spec] Non-numeric order_total | `tc10_invalid_total.csv` (as `orders.csv`) | 200 or 400 | Cleansing failure, not an insert failure, so the spec is silent. Either 400 + file in `error/` + FAILED, or 200 with INV0002 in `order_errors` and INV0001 / INV0003 inserted. Agree which and tighten this assertion |

### 4 - File validation (400)

| ID | Case | Fixture (stage as) | Expect | Verify manually |
|---|---|---|---|---|
| NEG01 | Empty (0 byte) file | `neg01_empty.csv` (as `orders.csv`) | 400 | 0 rows inserted; file moved to `error/`; `file_audit_log` = FAILED; nothing in `output/` |
| NEG02 (CANT TEST)| [Assumed] Header-only file counts as empty | `neg02_header_only.csv` (as `orders.csv`) | 400 | Same as NEG01. Assumes a file with no data rows is "empty" - confirm |
| NEG03 (CANT TEST) | [Assumed] Whitespace-only file counts as empty | `neg03_whitespace_only.csv` (as `orders.csv`) | 400 | Same as NEG01. Assumes no content after trimming is "empty" - confirm |
| NEG04 | File 1 byte over 5 MB | `neg04_5mb_plus1.csv` (as `orders.csv`) | 400 | 5,242,881 bytes; 0 rows inserted; file moved to `error/`; FAILED |
| BVA01 | File 1 byte under 5 MB is accepted | `bva01_5mb_minus1.csv` (as `orders.csv`) | 200 | 5,242,879 bytes; 3 rows inserted (BVM0001-0003); file in `output/`; SUCCESS |
| BVA02 | [Assumed] File of exactly 5 MB is accepted | `bva02_5mb_exact.csv` (as `orders.csv`) | 200 | 5,242,880 bytes (5 x 1024 x 1024); only "larger than" 5 MB is rejected, so 3 rows inserted (BVE0001-0003); file in `output/`; SUCCESS. If the service uses 5,000,000 bytes this case will fail |

### 5 - HTTP / routing

| ID | Case | Fixture (stage as) | Expect | Verify manually |
|---|---|---|---|---|
| HTTP01 | [Assumed] GET not allowed | `input/` folder empty | 405 | Nothing processed, no audit row. If the listener allows all methods the flow will run on GET - restrict `allowedMethods` to POST |
| HTTP02 | [Assumed] PUT not allowed | `input/` folder empty | 405 | Same as HTTP01 |
| HTTP03 | [Assumed] DELETE not allowed | `input/` folder empty | 405 | Same as HTTP01 |
| HTTP04 | Unknown path returns 404 | `input/` folder empty | 404 | Nothing processed (note the missing trailing `s`) |

### 6 - Not in spec (confirm expected behaviour)

| ID | Case | Fixture (stage as) | Expect | Verify manually |
|---|---|---|---|---|
| UNK01 | No file in input folder | `input/` folder empty (e.g. re-send right after a successful run) | 4xx / 5xx | Nothing inserted or moved. Expect a 4xx/5xx with a clear message; confirm whether `file_audit_log` should record FAILED |
| UNK02 (CANT TEST) | Non-CSV file (.txt) in input folder | `unk02_not_csv.txt` (as `orders.txt`) | 4xx / 5xx | Spec says read a `.csv`; the .txt should not be processed. Confirm whether it goes to `error/` |
| UNK03 | Rows with missing / extra columns | `unk03_missing_columns.csv` (as `orders.csv`) | 200 or 400 | Either 400 + file in `error/`, or 200 with MIS0001 and MIS0002 in `order_errors` and MIS0003 inserted. Agree which and tighten this assertion |
| UNK04 | UTF-8 BOM at start of file | `unk04_bom.csv` (as `orders.csv`) | 200 | 3 rows (BOM0001-0003). The BOM must not corrupt the `user_id` header / first value |

## Manual-only checks

- **Name collision:** run TC01, then stage the same file again without emptying `output/`. Moving `orders.csv` must not fail silently or log SUCCESS for a file that was not moved.
- **Concurrent calls:** send two requests at the same moment with one file staged. The file should be processed once, not twice.
- **DB unavailable:** stop the DB and send TC01. Expect a non-200 and the file not moved to `output/`.
- **Audit row content:** each `file_audit_log` row should carry the file name, status (SUCCESS / FAILED) and a timestamp.

## SQL helpers (local DB only, adjust names to your schema)

```sql
-- reset between cases
DELETE FROM order_errors;
DELETE FROM file_audit_log;
DELETE FROM customer_orders;

-- inspect after a case: each fixture uses its own id prefix (WSP, TS, TOT, SPC, PRT, BULK, BVM, BVE ...)
SELECT user_id, LENGTH(user_id) AS len, order_timestamp, order_status, order_total
FROM customer_orders WHERE user_id LIKE 'WSP%';   -- untrimmed ids would not match the prefix

SELECT COUNT(*) FROM customer_orders WHERE user_id LIKE 'BULK%';   -- expect 1000 after TC03
SELECT * FROM order_errors;
SELECT * FROM file_audit_log;
```

## Questions to confirm with whoever owns the spec

1. TC10 / UNK03: if cleansing fails on a row (bad number, wrong column count), is it a whole-file failure or a per-row entry in `order_errors`?
2. TC09: when every insert fails, should the file still go to `output/` with SUCCESS?
3. UNK01 / UNK02: what should the response and audit log look like when there is no file, or only a non-CSV file?
4. NEG02 / NEG03: do header-only and whitespace-only files count as empty?
5. BVA02: is the limit 5 MiB (5,242,880) or 5,000,000 bytes?
6. Which date order do the timestamps use (assumption 2)?
