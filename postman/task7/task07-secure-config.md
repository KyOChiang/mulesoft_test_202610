# Task 7: Secure configuration and environment properties

Mostly a configuration check, not an API test. Postman only proves the app boots with encrypted values.

## Checklist

| # | Check | How | Expected |
|---|---|---|---|
| 1 | No plaintext secrets in XML | search `mule-domain-config.xml` and `assessment-application.xml` for the real password / secret / client id | no hit, only `${...}` and `${secure::...}` |
| 2 | Sensitive yaml values encrypted | open `dev.yaml` / `prod.yaml` | `db.password`, `keystore.password`, `keystore.keyPassword`, `backend.clientId`, `backend.clientSecret` all look like `"![xxxx]"` |
| 3 | Not-sensitive values may stay plain | same files | host, port, user, db name plain |
| 4 | dev uses dev DB | run with `-Denv=dev` | log `Active DB: mulesoft_training_dev` |
| 5 | prod uses prod DB | run with `-Denv=prod` | log `Active DB: mulesoft_training_prod` |
| 6 | Wrong key fails fast | wrong `-Dencryption.key` | startup error (decrypt failed), app does not run |
| 7 | Missing env | no `-Denv` | startup error `Could not resolve placeholder 'env'` |
| 8 | Key not shipped | zip contents | the encryption key is in neither the zip nor the yaml |

`env-check-flow` prints the active DB every 5 minutes, which is what check 4 and 5 read.

## Run configuration (Studio > Run Configurations > Arguments > VM arguments)

```
-Denv=dev -Dencryption.key=<16-char-key>
```

## Encrypting a value (Secure Properties Tool jar)

```
java -cp secure-properties-tool.jar com.mulesoft.tools.SecurePropertiesTool string encrypt AES CBC <16-char-key> "<plain value>"
```

Paste the output into the yaml as `db.password: "![<output>]"`. The domain file uses `useRandomIVs="true"`, so the tool call for CBC needs the matching random-IV option for the jar version you use. If the app fails to decrypt, re-encrypt with the option your tool version offers (`--use-random-iv` in newer versions).

## Postman smoke tests (prove DB + keystore + backend creds all decrypted)

### T7-01 `GET {{baseUrl}}/health`

```javascript
pm.test("200 UP", () => { pm.response.to.have.status(200); pm.expect(pm.response.json().status).to.eql("UP"); });
```

### T7-02 `GET {{baseUrl}}/getOrders?user_id=NOPE0001` (needs the DB password to decrypt)

```javascript
pm.test("200 no records", () => {
  pm.response.to.have.status(200);
  pm.expect(pm.response.json().message).to.eql("No records found for user_id: NOPE0001");
});
```

### T7-03 `POST {{baseUrl}}/v1/recordsBackend` with a fresh id (needs backend client id/secret decrypted)

Expect 200. A 502 here usually means the client id / secret decrypted wrongly.

### T7-04 HTTPS works (needs keystore passwords decrypted)

Any of the above over `https://127.0.0.1:8083` with SSL verification off proves the keystore loaded. A plain `http://127.0.0.1:8083` must fail (connection reset).

## Also remember

- `dev_database-setup.sql` only creates `mulesoft_training_dev`. For `-Denv=prod`, run the same script with the database name changed to `mulesoft_training_prod`, or check 5 fails with a DB error.
