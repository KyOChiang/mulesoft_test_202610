# Task 11: `POST /recordsBackend` reliability

Order inside the flow: idempotency check, circuit breaker, retry, backend.

URL: `{{baseUrl}}/recordsBackend`

Body template (change `User Id` per test):

```json
{ "User Id": {{uid}}, "First Name": "Will", "Last Name": "Smith", "Current Salary": 1200 }
```

Collection pre-request script (new id each time you clear `uid`):

```javascript
if (!pm.collectionVariables.get("uid")) pm.collectionVariables.set("uid", Math.floor(Date.now() / 1000) % 1000000);
```

## A. Idempotency (10 minutes, full response cached)

### T11-A1 First call hits the backend

```javascript
pm.test("200", () => pm.response.to.have.status(200));
const j = pm.response.json();
pm.test("mapped keys", () => ["User Id","Full Name","The Tier","Tax Applied","Total Tax","Date"].forEach(k => pm.expect(j).to.have.property(k)));
pm.collectionVariables.set("t11_first", pm.response.text());
```

### T11-A2 Same User Id within 10 minutes returns the cached response

Send the same body again.

```javascript
pm.test("200 (not 409)", () => pm.response.to.have.status(200));
pm.test("identical to first", () => pm.expect(pm.response.text()).to.eql(pm.collectionVariables.get("t11_first")));
```

Console log shows `Idempotent replay for User Id ...` and **no** new backend call.

### T11-A3 After 10 minutes the backend is called again

Wait 10 min 30 s, resend: log has no `Idempotent replay`, `Date` is recalculated.

### T11-A4 Different User Id is a fresh call

Clear `uid` and resend: 200 with a log line showing the backend call.

### T11-A5 Missing field returns 400

Remove `Last Name`: 400 `{error, message}`.

## B. Retry (3 retries, 1 s, 2 s, 4 s)

Break the backend: in `dev.yaml` set `backend.host` to something unreachable (e.g. `127.0.0.1`, port `9`), redeploy.
Use a **new User Id** for every request in B and C (failures are not cached).

### T11-B1 Retry timing

Send one request. Console log shows:

```
Backend attempt 1 failed: ...
Backend attempt 2 failed: ...
Backend attempt 3 failed: ...
```

then the error. Total response time about 7 s (1 + 2 + 4). Response is 502:

```javascript
pm.test("502", () => pm.response.to.have.status(502));
pm.test("shape", () => pm.expect(pm.response.json().error).to.eql("Backend call failed"));
pm.test("took about 7s", () => pm.expect(pm.response.responseTime).to.be.within(6500, 12000));
```

(A 90 s timeout instead of refused connection gives 504 `Backend timed out` and takes much longer.)

Non-transient errors (backend 400/401/403) are not retried and answer 502 straight away.

## C. Circuit breaker (Object Store: `cb-failure-count`, `cb-opened-at`)

Keep the backend broken. New User Id each time.

| Step | Request | Expected |
|---|---|---|
| C1 | request 1 (about 7 s) | 502, failure count 1 |
| C2 | request 2 | 502, count 2 |
| C3 | request 3 | 502, count 3 and the circuit opens |
| C4 | request 4, immediately | **503 in under 1 s** |
| C5 | request 5, immediately | 503 again |

```javascript
pm.test("503 open", () => pm.response.to.have.status(503));
pm.test("body", () => pm.expect(pm.response.json()).to.eql({ error: "Service temporarily unavailable. Please try again later." }));
pm.test("fails fast", () => pm.expect(pm.response.responseTime).to.be.below(2000));
```

### T11-C6 Half-open probe fails, circuit re-opens

Wait 60+ seconds, send one request: it is allowed through (retries run, about 7 s), 502. Send another straight away: 503 again (timer restarted).

### T11-C7 Half-open probe succeeds, circuit closes

Fix `backend.host`, redeploy (the circuit state is persistent, so it survives the restart; if more than 60 s have passed it is half-open).
Send a new User Id: 200 and failure count reset to 0. Send another new User Id: 200, normal behaviour.

### T11-C8 One probe only

After 60 s of open circuit, send two requests at the same moment (two tabs). One goes to the backend, the other gets 503.

## Reset the circuit manually

Stop the app, delete the persistent Object Store files for `CircuitBreaker_Store` under the project `.mule` folder, or wait until a probe succeeds.

## Notes

- The old Task 5 behaviour (409 on repeated id) is on `/v1/recordsBackend` only. Here a repeated id returns the cached 200.
- Only successful responses are cached, so failures do not poison the idempotency store.
