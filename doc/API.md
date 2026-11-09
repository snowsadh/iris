# Partner API

An application programming interface (API) lets another known partner system maintain its receiving need, read addressed invitations and report actual outcomes. Allfedo's API lives at `/allfedo/api`.

An operator must provision a native IRIS account and an active [Actor record](../src/Allfedo/Record/Actor.cls). That record defines the account's network, organization, and role. Identity comes from IRIS `$USERNAME`; clients never choose an actor or role in a request. Model credentials stay on the Allfedo server.

Browsers sign in through `/allfedo/` and use the native session cookie. A partner server can use HTTP Basic authentication with its own invited account and retain the session cookie. Keep its credentials on that partner's server. Browser requests must use the same origin; cross-origin browser access is disabled.

## Read saved records

| GET path | What it returns |
| --- | --- |
| `/session` | Current account, role, network, organization, and server time. No session secrets. |
| `/site` | The account's own organization profile, or `null`. |
| `/offers`, `/offers/:id` | Kitchen's own offers; coordinator's network offers. |
| `/needs`, `/needs/:id` | Receiving team's own needs; coordinator's network needs. |
| `/allocations`, `/allocations/:id` | Collections addressed to the receiving team, supplied by the kitchen, or assigned to the collector. Coordinators see their network. |
| `/collectors` | Approved network collectors, for receiving teams and coordinators. |
| `/plans/:offer_id` | Coordinator's latest saved planning run, including its actual model, tool audit, and measured usage when available. |
| `/worklist` | Coordinator's current follow-up items. |

Direct record links enforce the same scope as lists. A private or missing record returns `404`. Linked deliveries include navigation permissions; receiving a child case does not grant access to its parent.

Offers, needs, allocations, and collectors return `records` and `next_after`. Pass that value as `?after=...` for the next page; an empty value means done. Pages contain at most 100 records. Allocation lists also accept `offer_id` and `need_id` filters. The worklist has its own `has_more` flag and is capped at 100 items.

## Send a command

POST JSON to `/commands` with `Content-Type: application/json` and `X-Allfedo-Request: 1`. Supply exactly `request_id`, `action`, and `payload`. Full action fields are defined in [Policy.Normalize](../src/Allfedo/Policy.cls); do not copy identity into the payload.

For example, first GET the allocation. Copy `record.revision` and `record.recovery.current_context.context_key` from the facts the receiving team reviewed. The offered context key is required even when accepting fewer boxes:

```json
{
  "request_id": "partner-accept-312-001",
  "action": "accept",
  "payload": {
    "allocation_id": "312",
    "revision": 1,
    "quantity": "8",
    "context_key": "copy-the-current-offered-context-key"
  }
}
```

Quantities are whole meal-box counts encoded as strings. IDs are strings; revisions are integers; confirmations are JSON booleans. Times need a full date and UTC offset, such as `2026-11-09T18:05:12.123456Z`. Preserve available fractional seconds. `occurred_at` describes the physical event, which can precede the time its report arrives.

For a report made just now, the Allfedo browser reads the current server time from `/session` before constructing the command. This avoids using an estimated device clock to order a handoff against a recent agreement. The command still sends a full timestamp; keep it unchanged when retrying.

Give each new intention a new request ID. Keep its serialized request body until the result is known. If the connection fails or the outcome is uncertain, POST that exact body again with the same ID. This returns the saved outcome or safely retries an unsaved attempt. Refresh the record afterward: later corrections may have changed it.

`accept` confirms a receiving promise; `receive` records actual accepted food. Check `physical_report_saved` and `agreement_issue` on physical reports. An AI suggestion, sent email, or HTTP success alone does not prove collection or receipt.

Coordinators can POST a raw proposal to `/plan-check` before sending it. This creates no hold; `apply_plan` checks current facts again when sending. POST `/logout` with JSON and the same request header to end the native session.

| Status/code | Client action |
| --- | --- |
| `401 SIGN_IN_REQUIRED` | Authenticate again. |
| `403 MEMBERSHIP_REQUIRED` / `FORBIDDEN` | Ask the operator to check the account's role and membership. |
| `403 CROSS_SITE_BLOCKED` | Use the request header and correct browser origin. |
| `409 BUSY` | Retry the unchanged request with the same ID. |
| `409 REQUEST_ID_REUSED` | An existing ID belongs to different input. Use a new ID for the new intention. |
| `422 COMMAND_REJECTED` | Read the message and current record before preparing a corrected intention. |
| `503 NOT_SAVED` / `COMMAND_RESULT_UNKNOWN` | Retry the exact original request with its original ID. |

Malformed JSON or command shapes return `400`; the wrong content type returns `415`. Plan checks can return more specific policy codes, such as `STALE_OFFER`. Responses use `ok` and, on failure, `error.code` plus `error.message`.
