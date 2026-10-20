The circuit breaker works like a fuse in a house. If the backend keeps failing, Mule stops calling it for a while, so requests fail instantly instead of each one spending about 7 s on retries.

## The 3 states

| State | Meaning | What your API does |
|---|---|---|
| **Closed** | Normal. The fuse is on and calls go through. | Calls the backend (with retries). |
| **Open** | Backend failed too often. The fuse has tripped. | Doesn't call the backend. Returns **503** immediately. |
| **Half-open** | The fuse has been open for 60 s. Mule checks whether the backend is back. | Lets **one** request through as a test (a "probe"). |

## How Mule decides the state

It keeps two values in the Object Store `CircuitBreaker_Store`:
- `cb-failure-count`: how many requests in a row have failed.
- `cb-opened-at`: the time of the last failure, or of the last probe.

```
failures < 3                                   -> CLOSED
failures >= 3 and last failure < 60 s ago      -> OPEN
failures >= 3 and last failure >= 60 s ago     -> HALF-OPEN
```

## What happens to each request

- **Success:** `cb-failure-count` resets to 0. The circuit is closed.
- **Failure:** `cb-failure-count` goes up by 1, and `cb-opened-at` is set to now.
- **One failure counts once.** A request that fails all 4 attempts adds only 1 to the count, not 4.
- **The count is consecutive.** A success in between resets it to 0.

## Timeline with the backend broken

| Time | Request | State before | Result | Count after |
|---|---|---|---|---|
| 0 s | #1 | closed | tries 4 times (about 7 s), then **502** | 1 |
| 8 s | #2 | closed | about 7 s, **502** | 2 |
| 16 s | #3 | closed | about 7 s, **502** | 3, **circuit opens** |
| 17 s | #4 | open | **503 instantly** (backend not called) | 3 |
| 30 s | #5 | open | **503 instantly** | 3 |
| 80 s | #6 | half-open (more than 60 s since #3) | one probe goes through with retries and fails, **502** | 4, timer restarts |
| 81 s | #7 | open again | **503 instantly** | 4 |

A **503** means the circuit is open and the backend was not called. A **502** means the backend was called and failed.

## If the probe succeeds

Say you fix the backend and wait 60 s. The next request is the probe and succeeds, so it returns **200**. The count resets to 0 and the circuit is **closed** again. After that, everything is normal.

## What this means for your Postman testing

1. Break the backend (refused connection).
2. Send 3 requests, each with a **new User Id**. Each should return 502 after about 7 s.
3. Send a 4th request right away. It should return **503 in under 1 s**. This proves the circuit is open.
4. Wait more than 60 s and send another request. This is the half-open probe. It takes about 7 s and returns 502 if the backend is still broken.
5. Fix the backend, wait 60 s, and send a request. It should return **200**. The circuit is closed again.

Use a new User Id each time. The idempotency check from earlier in the task would otherwise return a cached result for a repeated id, and you wouldn't be testing the breaker.

Three things in this design are my choices, because I didn't see them stated in the brief:
- The threshold is 3 failed requests.
- The open period is 60 s.
- A failed request is one that failed after all its retries.

If the Task 11 brief gives different numbers, tell me and I'll change them.