# Task 9: `POST /transform` governance

Schema validation (APIKit), rate limit 100 per minute, response cache.

URL: `{{baseUrl}}/transform`

Same body as Task 6. Order inside the flow: APIKit validation, then rate limit, then cache.
So a rejected 400 request is **not** counted by the rate limiter.

## A. Schema validation

| ID | Body change | Expected |
|---|---|---|
| T9-A1 | remove `firstName` | 400 |
| T9-A2 | remove `orders` | 400 |
| T9-A3 | `"originationType": "XXXX"` | 400 |
| T9-A4 | `"orgnFormRefId": "45"` | 400 |
| T9-A5 | `orders[0]` without `amount` | 400 |
| T9-A6 | omit `responseType` (optional) | 200, JSON |
| T9-A7 | not JSON, `Content-Type: text/plain` | 415 |

```javascript
pm.test("400 before the flow", () => pm.response.to.have.status(400));
pm.test("error shape", () => pm.expect(pm.response.json()).to.have.keys("error","message"));
pm.test("not rate limited", () => pm.expect(pm.response.headers.has("Retry-After")).to.be.false);
```

## B. Cache (X-Cache)

Use a new `sourceSystemId` for a fresh key (e.g. `CACHE-<timestamp>`).

### T9-B1 First call is a MISS

```javascript
pm.test("MISS", () => pm.response.to.have.header("X-Cache", "MISS"));
pm.collectionVariables.set("t9_processedAt", pm.response.json().metadata.processedAt);
```

### T9-B2 Same body again is a HIT, same content

```javascript
pm.test("HIT", () => pm.response.to.have.header("X-Cache", "HIT"));
pm.test("identical (same processedAt)", () =>
  pm.expect(pm.response.json().metadata.processedAt).to.eql(pm.collectionVariables.get("t9_processedAt")));
```

### T9-B3 Changed field is a MISS

Change `lastName` to `Smith`: expect `X-Cache: MISS`.

### T9-B4 XML is cached separately

`"responseType": "XML"`: first call MISS, second HIT, `Content-Type` is xml both times, namespace present.

### T9-B5 Key ignores JSON key order

Same data with the keys in a different order than the first call: expect HIT.

### T9-B6 TTL 5 minutes

Wait 5 min 30 s, resend T9-B1's body: expect MISS again (`processedAt` is new).

## C. Rate limit (100 per minute)

**For testing, set global property `rateLimitPerMinute` to `3` in the XML and redeploy. Restore to `100` after.**

### T9-C1 Burst of 4 in one minute

Send the same valid body 4 times quickly (Collection Runner, 4 iterations, delay 0). Counting is before the cache, so HITs count too.

```javascript
const it = pm.info.iteration + 1;         // 1-based
if (it <= 3) {
  pm.test("allowed #" + it, () => pm.response.to.have.status(200));
} else {
  pm.test("429 on #" + it, () => pm.response.to.have.status(429));
  pm.test("body", () => pm.expect(pm.response.json()).to.eql({ error: "Rate limit exceeded", retryAfter: 60 }));
  pm.test("Retry-After header", () => pm.response.to.have.header("Retry-After", "60"));
}
```

### T9-C2 Counter resets

Wait until the next clock minute (the key is `rate-limit-yyyy-MM-dd-HH-mm` in UTC) and send again: expect 200.
Entries also expire 65 s after the last write.

### T9-C3 At the real limit

With `rateLimitPerMinute = 100`: Collection Runner, 101 iterations, delay 0. Iteration 101 expects 429. Start right after a minute boundary to avoid the counter splitting across two minutes.

## Notes

- Check the Object Store keys while testing: log or debug `vars.rateKey` / `vars.rateCount`.
- `X-Cache` is also sent on 200 only; 429 and 400 do not carry it.
