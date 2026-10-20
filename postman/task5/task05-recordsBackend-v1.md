# Task 5: `POST /v1/recordsBackend`

Object Store check, backend call, store `User Id` (TTL 1 hour), mapped response.
(Task 11 lives on `/recordsBackend`, so this one stays on `/v1`.)

URL: `{{baseUrl}}/v1/recordsBackend`

## Collection pre-request script (new User Id every run)

The store is persistent for 1 hour, so a fixed id gives 409 on the second day of testing.

```javascript
if (!pm.collectionVariables.get("t5_uid")) {
  pm.collectionVariables.set("t5_uid", Math.floor(Date.now() / 1000) % 1000000);
}
```

Delete the `t5_uid` variable to get a fresh id.

## Requests

### T5-01 New User Id returns 200 + mapped response

```json
{ "User Id": {{t5_uid}}, "First Name": "Will", "Last Name": "Smith", "Current Salary": 1200 }
```

```javascript
pm.test("200", () => pm.response.to.have.status(200));
const j = pm.response.json();
pm.test("mapped keys", () =>
  ["User Id","Full Name","The Tier","Tax Applied","Total Tax","Date"].forEach(k => pm.expect(j).to.have.property(k)));
pm.test("Date is dd-MM-yyyy", () => pm.expect(j.Date).to.match(/^\d{2}-\d{2}-\d{4}$/));
```

### T5-02 Same User Id again returns 409

Same body as T5-01, send immediately.

```javascript
pm.test("409", () => pm.response.to.have.status(409));
pm.test("message", () => pm.expect(pm.response.json())
  .to.eql({ error: "User ID is already in use. Please use a different User ID." }));
```

### T5-03 Different User Id returns 200

Same body, `"User Id": {{$randomInt}}` (any unused number).

### T5-04 Missing field returns 400 (APIKit)

```json
{ "User Id": 9001, "First Name": "Will", "Current Salary": 1200 }
```

```javascript
pm.test("400", () => pm.response.to.have.status(400));
pm.test("error shape", () => { const j = pm.response.json(); pm.expect(j).to.have.keys("error","message"); });
```

### T5-05 Wrong type returns 400

```json
{ "User Id": "abc", "First Name": "Will", "Last Name": "Smith", "Current Salary": 1200 }
```

### T5-06 Wrong method returns 405

`GET {{baseUrl}}/v1/recordsBackend` expects 405 `{error:"Method not allowed",...}`.

## Notes

- A failed backend call (timeout 90 s, 401/403/5xx) does **not** store the id, so you can retry the same id. Expected 502 `{"error":"Backend call failed",...}` or 504 `{"error":"Backend timed out"}`.
- To re-test 409 after the hour, use a new id (or stop the app and delete the persistent store under `.mule`).
