%dw 2.0
import MD5 from dw::Crypto
import try, fail from dw::Runtime
ns customer http://acme.com/customer

// =====================================================================
// transformUtils.dwl  ->  src/main/resources/dwl/transformUtils.dwl
// import with:  import <fn> from dwl::transformUtils
// =====================================================================

// ---------- lookups ----------
var originationMap = { INDV: "INDIVIDUAL", CORP: "CORPORATE" }
var customerMap    = { M: "Male", F: "Female" }
var MAX_FILE_BYTES = 5 * 1024 * 1024

// ---------- null-safety helpers ----------
fun isBlank(v) = v == null or (v is String and trim(v) == "")

fun mapValue(lookup: Object, key) =
  if (isBlank(key)) null
  else (lookup[key as String] default key)

// null when ANY part is missing/blank, otherwise the parts joined by sep
fun joinIfPresent(parts: Array, sep: String) =
  if (sizeOf(parts filter isBlank($)) > 0) null
  else parts joinBy sep

// =====================================================================
// Task 1 / 6 / 9 : /transform
// =====================================================================
fun orderCount(orders) = if (orders is Array) sizeOf(orders) else null

fun orderTotal(orders) =
  if (orders is Array) ((orders map ((o) -> o.amount default 0)) reduce ((a, acc = 0) -> acc + a))
  else null

fun orderIds(orders) =
  if (orders is Array) (orders map ((o) -> o.orderId)) filter ((id) -> id != null)
  else null

fun buildData(p) = {
  fullName:            joinIfPresent([p.firstName, p.lastName], " "),
  fullAddress:         joinIfPresent([p.address, p.poscode], ", "),
  "orgnFormRefId-1":   if (p.orgnFormRefId is Number) floor(p.orgnFormRefId) else null,
  "originationType-1": mapValue(originationMap, p.originationType),
  "customerType-1":    mapValue(customerMap, p.customerType),
  sourcePartyAcct:     joinIfPresent([p.sourceSystemId, p.partyAcctRelationship], "-"),
  customerId:          joinIfPresent([p.customerType, p.sourceSystemId, p.originationType], ""),
  totalOrders:         orderCount(p.orders),
  totalAmounts:        orderTotal(p.orders),
  allOrdersIds:        orderIds(p.orders)
}

fun metadata() = {
  processedAt: (now() >> "UTC") as String { format: "yyyy-MM-dd'T'HH:mm:ss'Z'" },
  version: "1.0"
}

// withMeta = false -> Task 1 shape (/v1/transform): flat fields, no wrapper
// withMeta = true  -> Task 6 shape (/transform): { metadata, data }
fun jsonResponse(p, withMeta: Boolean) =
  if (withMeta) { metadata: metadata(), data: buildData(p) }
  else buildData(p)

fun xmlData(d) = {
  customer#fullName:            d.fullName,
  customer#fullAddress:         d.fullAddress,
  customer#"orgnFormRefId-1":   d."orgnFormRefId-1",
  customer#"originationType-1": d."originationType-1",
  customer#"customerType-1":    d."customerType-1",
  customer#sourcePartyAcct:     d.sourcePartyAcct,
  customer#customerId:          d.customerId,
  customer#totalOrders:         d.totalOrders,
  customer#totalAmounts:        d.totalAmounts,
  customer#allOrdersIds:
    if (d.allOrdersIds == null) null
    else { (d.allOrdersIds map (id) -> { customer#orderId: id }) }
}

fun xmlResponse(p, withMeta: Boolean) = do {
  var m = metadata()
  var d = buildData(p)
  ---
  if (withMeta)
    { customer#customerData: {
        customer#metadata: { customer#processedAt: m.processedAt, customer#version: m.version },
        customer#data: xmlData(d)
    } }
  else
    { customer#customerData: xmlData(d) }
}

// Same request content -> same key (fixed field order, so JSON key order doesn't matter)
fun cacheKey(p) = do {
  var canonical = write({
    firstName:             p.firstName,
    lastName:              p.lastName,
    address:               p.address,
    poscode:               p.poscode,
    orgnFormRefId:         p.orgnFormRefId,
    originationType:       p.originationType,
    customerType:          p.customerType,
    sourceSystemId:        p.sourceSystemId,
    partyAcctRelationship: p.partyAcctRelationship,
    orders:                p.orders default [],
    responseType:          p.responseType default "JSON"
  }, "application/json", { indent: false })
  ---
  "transform-" ++ MD5(canonical as Binary)
}

// =====================================================================
// Task 2 / 8 / 10 : insertOrders
// =====================================================================

// AES45678 -> AES***78 ; length <= 5 -> unchanged
fun maskId(id) =
  if (isBlank(id)) null
  else do {
    var s = id as String
    ---
    if (sizeOf(s) <= 5) s
    else s[0 to 2] ++ (s[3 to -3] replace /./ with "*") ++ s[-2 to -1]
  }

fun cleanString(v) = if (isBlank(v)) null else trim(v as String)

// what we put in logs / order_errors for a user id
fun displayId(id, mask: Boolean) =
  (if (mask) maskId(cleanString(id)) else cleanString(id)) default "***"

fun cleanAmount(v) =
  if (isBlank(v)) null
  else ((v as String) replace /[^0-9.\-]/ with "") as Number          // "1,250.50" -> 1250.5

// accepts CSV format (12/02/2021 11:02:00 PM), "yyyy-MM-dd HH:mm:ss" and ISO "yyyy-MM-dd'T'HH:mm:ss"
fun cleanTimestamp(v) =
  if (isBlank(v)) null
  else do {
    var s  = trim(v as String)
    var r1 = try(() -> s as LocalDateTime { format: "MM/dd/yyyy hh:mm:ss a" })
    var r2 = try(() -> s as LocalDateTime { format: "yyyy-MM-dd HH:mm:ss" })
    var r3 = try(() -> s as LocalDateTime { format: "yyyy-MM-dd'T'HH:mm:ss" })
    ---
    if (r1.success) r1.result
    else if (r2.success) r2.result
    else if (r3.success) r3.result
    else fail("Invalid order_timestamp")
  }

// CSV headers are snake_case: user_id, order_timestamp, order_status, order_total
fun cleanseOrder(r) = {
  userId:         cleanString(r.user_id),
  orderTimestamp: cleanTimestamp(r.order_timestamp),
  orderStatus:    cleanString(r.order_status),
  orderTotal:     cleanAmount(r.order_total)
}

// file validation: null = OK
fun rejectReason(size) =
  if (size == 0) "File is empty"
  else if (size > MAX_FILE_BYTES) "File size exceeds 5 MB"
  else null

fun summaryStatus(total, failed) = if (total == 0 or failed > 0) "FAILED" else "SUCCESS"

fun failureReason(total, failed) =
  if (total == 0) "File contains no records"
  else if (failed > 0) (failed as String) ++ " of " ++ (total as String) ++ " record(s) failed"
  else null

fun buildSummary(fileName, total, inserted, updated, failed) = {
  fileName:  fileName,
  processed: total,
  inserted:  inserted,
  updated:   updated,
  failed:    failed,
  status:    summaryStatus(total, failed)
}

fun auditJson(summary, reason) =
  write(summary ++ (if (reason != null) { error: reason } else {}), "application/json")

// =====================================================================
// Task 4 : scheduled customer job
// =====================================================================
fun isValidCustomer(r) = r.status == "Valid"

// ids are coerced to Number first, so the IN (...) list can't carry SQL
fun customerIdList(rows) = (rows map ("'" ++ ($.userId as Number as String) ++ "'")) joinBy ","

fun quoted(v) = "\"" ++ (((v default "") as String) replace "\"" with "\"\"") ++ "\""

// "User ID","First Name",...  then   3,"Jane","Doe",2000,"Not Valid"
fun invalidCustomersCsv(rows) = do {
  var header = [quoted("User ID"), quoted("First Name"), quoted("Last Name"), quoted("Salary"), quoted("Status")] joinBy ","
  var lines = rows map (r) ->
    ((r.userId default "") as String) ++ "," ++ quoted(r.firstName) ++ "," ++ quoted(r.lastName) ++ "," ++
    ((r.salary default "") as String) ++ "," ++ quoted(r.status)
  ---
  (([header] ++ lines) joinBy "\n") ++ "\n"
}

// =====================================================================
// Task 4 / 5 / 11 : backend mock service
// =====================================================================
fun backendRequestFromApi(p) = {
  userId:    p."User Id",
  firstName: p."First Name",
  lastName:  p."Last Name",
  salary:    p."Current Salary"
}

fun backendRequestFromRow(r) = {
  userId:    r.user_id as Number,
  firstName: r.first_name,
  lastName:  r.last_name,
  salary:    r.salary as Number
}

fun backendResponse(r) = {
  "User Id":     r.userId,
  "Full Name":   r.fullName,
  "The Tier":    r.tier,
  "Tax Applied": r.tax,
  "Total Tax":   r.totalTax,
  "Date":        now() as String { format: "dd-MM-yyyy" }
}

// =====================================================================
// Global error handler : { error, message } + correct HTTP status
// =====================================================================
var simpleErrors = {
  "APIKIT:BAD_REQUEST":           { status: 400, error: "Bad request" },
  "APIKIT:NOT_FOUND":             { status: 404, error: "Resource not found" },
  "APIKIT:METHOD_NOT_ALLOWED":    { status: 405, error: "Method not allowed" },
  "APIKIT:NOT_ACCEPTABLE":        { status: 406, error: "Not acceptable" },
  "APIKIT:UNSUPPORTED_MEDIA_TYPE":{ status: 415, error: "Unsupported media type" },
  "APIKIT:NOT_IMPLEMENTED":       { status: 501, error: "Not implemented" },
  "APP:BAD_REQUEST":              { status: 400, error: "Bad request" }
}

fun reply(status, body, headers = {}) = { status: status, body: body, headers: headers }

fun errorId(err) = (err.errorType.namespace default "") ++ ":" ++ (err.errorType.identifier default "")

fun mapError(err, fileName = "") = do {
  var id   = errorId(err)
  var desc = err.description default ""
  ---
  if (id == "APP:RATE_LIMIT_EXCEEDED")
    reply(429, { error: "Rate limit exceeded", retryAfter: 60 }, { "Retry-After": "60" })
  else if (id == "APP:USER_ID_IN_USE")
    reply(409, { error: "User ID is already in use. Please use a different User ID." })
  else if (id == "APP:CIRCUIT_OPEN")
    reply(503, { error: "Service temporarily unavailable. Please try again later." })
  else if (id == "APP:INVALID_FILE")
    reply(400, { error: "File validation failed", reason: desc })
  else if (id == "FILE:ILLEGAL_PATH" or id == "FILE:FILE_DOESNT_EXIST")
    reply(404, { error: "File not found",
                 message: if (isBlank(fileName)) desc else fileName ++ " does not exist in the input folder" })
  else if (id == "DB:CONNECTIVITY")
    reply(503, { error: "Service unavailable", message: "Database is not reachable" })
  else if (id == "HTTP:TIMEOUT")
    reply(504, { error: "Backend timed out" })
  else if (startsWith(id, "HTTP:"))
    reply(502, { error: "Backend call failed", message: desc })
  else if (simpleErrors[id] != null)
    reply(simpleErrors[id].status, { error: simpleErrors[id].error, message: desc })
  else
    reply(500, { error: err.errorType.identifier default "ERROR", message: desc })
}
