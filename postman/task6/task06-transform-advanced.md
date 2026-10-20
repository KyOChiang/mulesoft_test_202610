# Task 6: `POST /v2/transform` advanced DataWeave

Module `dwl::transformUtils`, XML namespace, metadata envelope.
No rate limit and no cache here: those are Task 9 on `/transform`. So there is no `X-Cache` header on this endpoint.

URL: `{{baseUrl}}/v2/transform`

## Base body

```json
{
  "firstName": "Jane", "lastName": "Doe",
  "address": "Bangsar, Kuala Lumpur", "poscode": "59100",
  "orgnFormRefId": 45.678, "originationType": "CORP", "customerType": "F",
  "sourceSystemId": "C201", "partyAcctRelationship": "OWNER",
  "orders": [ { "orderId": "A01", "amount": 200 }, { "orderId": "A02", "amount": 100 } ],
  "responseType": "JSON"
}
```

## Requests

### T6-01 JSON with metadata envelope

```javascript
pm.test("200 JSON", () => { pm.response.to.have.status(200); pm.response.to.have.header("Content-Type", /json/); });
const j = pm.response.json();
pm.test("metadata", () => {
  pm.expect(j.metadata.version).to.eql("1.0");
  pm.expect(j.metadata.processedAt).to.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
});
pm.test("data matches Task 1 rules", () => pm.expect(j.data).to.eql({
  fullName: "Jane Doe", fullAddress: "Bangsar, Kuala Lumpur, 59100",
  "orgnFormRefId-1": 45, "originationType-1": "CORPORATE", "customerType-1": "Female",
  sourcePartyAcct: "C201-OWNER", customerId: "FC201CORP",
  totalOrders: 2, totalAmounts: 300, allOrdersIds: ["A01","A02"]
}));
```

### T6-02 XML with namespace

Base body with `"responseType": "XML"` and a new `sourceSystemId` (e.g. `C202`).

```javascript
pm.test("200 XML", () => { pm.response.to.have.status(200); pm.response.to.have.header("Content-Type", /xml/); });
const x = pm.response.text();
pm.test("namespace", () => pm.expect(x).to.include('xmlns:customer="http://acme.com/customer"'));
pm.test("envelope", () => {
  pm.expect(x).to.include("<customer:customerData");
  pm.expect(x).to.include("<customer:metadata>");
  pm.expect(x).to.include("<customer:data>");
  pm.expect(x).to.include("<customer:fullName>Jane Doe</customer:fullName>");
  pm.expect(x).to.include("<customer:orderId>A01</customer:orderId>");
});
```

### T6-03 Mapped values (`M`/`INDV`)

`"customerType": "M", "originationType": "INDV", "sourceSystemId": "C203"`.
Expected `customerType-1 = "Male"`, `originationType-1 = "INDIVIDUAL"`, `customerId = "MC203INDV"`.

### T6-04 Empty orders (null-safe totals)

`"orders": []`, `"sourceSystemId": "C204"`.
Expected `totalOrders: 0`, `totalAmounts: 0`, `allOrdersIds: []`.

### T6-05 Integer part is a floor

`"orgnFormRefId": 45.999` (new `sourceSystemId`) expects `45`. `0.5` expects `0`.

### T6-06 Null safety: missing / null fields give `null`, never an error

This endpoint uses a lenient RAML type (`TransformRequestLenient`: every field optional and nullable), so APIKit lets these through and the DataWeave module returns `null` for the affected field only.

| ID | Body | Expected (HTTP 200) |
|---|---|---|
| T6-06a | base body without `lastName` | `fullName: null`, everything else still mapped |
| T6-06b | `address`, `poscode`, `orgnFormRefId`, `customerType` = `null` | `fullAddress`, `orgnFormRefId-1`, `customerType-1`, `customerId` = `null`; `fullName` ok |
| T6-06c | `{}` | `metadata` present, all 10 `data` fields `null` |
| T6-06d | `"orders": null` | `totalOrders`, `totalAmounts`, `allOrdersIds` = `null` |
| T6-06e | order without `amount` | counts as 0: `totalOrders 2`, `totalAmounts 100` |
| T6-06f | `{ "responseType": "XML" }` | XML with namespace, empty elements |
| T6-06g | `"orgnFormRefId": "abc"` | **400** (wrong type is still rejected) |

```javascript
const d = pm.response.json().data;
pm.test("null, not an error", () => { pm.response.to.have.status(200); pm.expect(d.fullName).to.eql(null); });
```

## Notes

- `/v2/transform` accepts missing/null fields (lenient RAML). `/transform` (Task 9) keeps the strict `TransformRequest`, so a missing field is a 400 there. That is the only difference in validation.
