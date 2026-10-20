# Task 3 - getOrders: Postman test plan

`GET https://127.0.0.1:8083/api/integration/getOrders?user_id=...` returns the orders for one `user_id` from `customer_orders`.

## How to run

1. Run `task3-seed.sql` on the local DB. It inserts the 7 rows these tests rely on and checks `AES99999` does not exist.
2. Import `task3-getOrders.postman_collection.json` and run folders 1-5 in order. SEC03 re-checks the table after the injection attempts in SEC01-02.
3. Cases marked **[Assumed]** or **Not in spec** encode my guess. A failure there is a question for the spec owner, not necessarily a bug.

No file staging is needed here, unlike Task 2.

## Seed data

| user_id | Rows | Used by |
|---|---|---|
| `AES45678` | 1 (2021-02-12 23:02:00, Confirmed, 1200.00) | TC01, TC06, SEC03, HTTP01-04 |
| `AES4 5679` | 1 (Cancelled, 2500.00) | TC04 |
| `AES45680` | 1 (2021-02-12 18:02:00, Confirmed, 5100.00) | TC05 |
| `MULTI001` | 3 (100.00, 250.75, 3000.00) | TC02 |
| `DEC00001` | 1 (1200.50) | TC03 |
| `AES99999` | none | TC07 |

## Assumptions

| # | Assumption | Why it matters |
|---|---|---|
| 1 | Not-found status code is 200 or 404 | The spec shows only the body |
| 2 | Output timestamp is the DB `datetime` printed as UTC with a trailing `Z` (no timezone conversion) | Spec example: `2021-02-12T23:02:00Z` |
| 3 | `order_total` is a JSON number (`1200`, `1200.5`), not a string | Spec example shows `1200` |
| 4 | `orders` order is not defined, so tests compare sorted values | Add `ORDER BY order_timestamp` if you want a fixed order |
| 5 | Missing / empty / whitespace `user_id` returns 400 | Spec is silent |
| 6 | Only GET is allowed (405 otherwise) | Same pattern as Task 2 |

## Test matrix

### 1 - Found

| ID | Case | Request | Expect | Notes |
|---|---|---|---|---|
| TC01 | Sample user - exact body from the spec | `GET /api/integration/getOrders?user_id=AES45678` | 200 | Seeded row 2021-02-12 23:02:00 / Confirmed / 1200.00 returns exactly the spec's example. |
| TC02 | User with 3 orders - all returned | `GET /api/integration/getOrders?user_id=MULTI001` | 200 | Needs `orders` as an array with one entry per row, not just the first row. |
| TC03 | Decimal total keeps its decimals (1200.50) | `GET /api/integration/getOrders?user_id=DEC00001` | 200 | decimal(10,2) must not be rounded to an integer or turned into a string such as "1200.50". |
| TC04 | user_id with an internal space (AES4 5679 from Task 2) | `GET /api/integration/getOrders?user_id=AES4 5679` | 200 | Space is URL-encoded as %20 or + on the wire. Postman encodes it for you. |
| TC05 | Second sample user | `GET /api/integration/getOrders?user_id=AES45680` | 200 | Second timestamp check: 6 PM stays 18:02, no timezone shift. |
| TC06 | Extra unknown query param is ignored | `GET /api/integration/getOrders?user_id=AES45678&foo=bar` | 200 | Assumption: unknown params do not cause a 400. |

### 2 - Not found

| ID | Case | Request | Expect | Notes |
|---|---|---|---|---|
| TC07 | Unknown user - exact message from the spec | `GET /api/integration/getOrders?user_id=AES99999` | 200 or 404 | Spec gives the body only. The status code is open - see the questions list. |
| TC08 | Not-found message echoes ids with spaces / symbols | `GET /api/integration/getOrders?user_id=ZZZ 999` | 200 or 404 | The message must show the id as sent, decoded (not `ZZZ%20999`). |
| TC09 | Partial id must not match (AES456) | `GET /api/integration/getOrders?user_id=AES456` | 200 or 404 | Catches a `LIKE 'AES456%'` query. Exact match only. |
| TC10 | Lower-case id (aes45678) | `GET /api/integration/getOrders?user_id=aes45678` | 200 or 404 | Not in spec. MySQL's default collation is case-insensitive, so this probably FINDS the user. Decide whether that is acceptable, then tighten this test. |

### 3 - Input validation (not in spec)

| ID | Case | Request | Expect | Notes |
|---|---|---|---|---|
| VAL01 | [Assumed] user_id missing | `GET /api/integration/getOrders` | 500 | Spec is silent. A missing required param should be 400, not an empty-result message or a 500. |
| VAL02 | [Assumed] user_id empty (user_id=) | `GET /api/integration/getOrders?user_id=` |  500 | Same as VAL01. |
| VAL03 | [Assumed] user_id is only spaces | `GET /api/integration/getOrders?user_id=   ` | 200 | Whitespace-only should be treated as empty. |
| VAL04 | user_id with leading/trailing spaces | `GET /api/integration/getOrders?user_id= AES45678 ` | 200 | Not in spec. Task 2 trims ids on the way IN, so trimming on the way out would be consistent. Pick one behaviour and tighten. |
| VAL05 | user_id longer than the column (25 chars) | `GET /api/integration/getOrders?user_id=AAAAAAAAAAAAAAAAAAAAAAAAA` | 200 | Column is varchar(20). Must not crash and must not return orders. |
| VAL06 | user_id sent twice | `GET /api/integration/getOrders?user_id=AES45678&user_id=AES45680` | 500 | Not in spec. Mule not accept repeatable query param. |
| VAL07 | Unicode user_id | `GET /api/integration/getOrders?user_id=中文` | 200 | Must be handled cleanly: not-found message or 400, never a 500. |

### 4 - SQL injection / security

| ID | Case | Request | Expect | Notes |
|---|---|---|---|---|
| SEC01 | Injection: ' OR '1'='1 must not dump all orders | `GET /api/integration/getOrders?user_id=' OR '1'='1` | 200, 400 or 404 | If orders come back, the SQL is built by string concatenation. Use input parameters (`:user_id`) in the Database connector. Local DB only. |
| SEC02 | Injection: stacked DROP TABLE attempt | `GET /api/integration/getOrders?user_id=AES45678'; DROP TABLE customer_orders;--` | 200, 400 or 404 | Run TC01 right after this (SEC03) to prove the table still exists. |
| SEC03 | Table still intact after SEC02 (TC01 again) | `GET /api/integration/getOrders?user_id=AES45678` | 200 | Same request as TC01, placed after the injection attempts. |
| SEC04 | Injection: UNION SELECT attempt | `GET /api/integration/getOrders?user_id=x' UNION SELECT user_id, order_timestamp, order_status, order_total FROM customer_orders-- ` | 200, 400 or 404 | Must not return other users' orders. |

### 5 - HTTP / routing

| ID | Case | Request | Expect | Notes |
|---|---|---|---|---|
| HTTP01 | [Assumed] POST not allowed | `POST /api/integration/getOrders?user_id=AES45678` | 405 | Restrict `allowedMethods` to GET on the listener. |
| HTTP02 | [Assumed] PUT not allowed | `PUT /api/integration/getOrders?user_id=AES45678` | 405 | Same as HTTP01. |
| HTTP03 | [Assumed] DELETE not allowed | `DELETE /api/integration/getOrders?user_id=AES45678` | 405 | Same as HTTP01. Check the order still exists afterwards. |
| HTTP04 | Unknown path returns 404 | `GET /api/integration/getOrder?user_id=AES45678` | 404 | Note the missing trailing `s`. |

## Questions to confirm with the spec owner

1. Not found: should the status be 404 or 200? (TC07-09 accept both.)
2. Is `user_id` matching case-sensitive? MySQL's default is case-insensitive, so `aes45678` finds `AES45678` (TC10).
3. Should surrounding spaces in `user_id` be trimmed (VAL04)?
4. Should a missing or empty `user_id` be 400 (VAL01-03)?
5. Should orders come back in a fixed order (e.g. newest first)?

## Timestamp note for Task 2

The spec example here, `2021-02-12T23:02:00Z`, comes from the Task 2 sample `12/02/2021 11:02:00 PM`. That means the input date is **dd/MM/yyyy** (12 Feb), not MM/dd/yyyy as I assumed in the Task 2 plan.

