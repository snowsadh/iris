import { redirectActions, redirectContext } from "./redirect.js";
import { recoveryActions } from "./recovery.js";
import { physicalActions, physicalHistory } from "./physical.js";
import { readLocal, earliest } from "../time.js";
import {
  append,
  el,
  link,
  heading,
  empty,
  tag,
  facts,
  time,
  boxCount,
  holdingLabel,
  labels,
  checkedAbsent,
  custody,
  partnerName,
  siteFacts,
  notice,
} from "../render.js";
import { field, actionForm, confirm, dateTimeField } from "../forms.js";

export const collectionState = (record) =>
  ({
    held: ["Invitation waiting for reply", "warning"],
    accepted: [
      record.collector_id
        ? "Collector assigned · trip not confirmed"
        : "Food reserved · collector needed",
      "warning",
    ],
    ready: [
      record.recovery?.trip_needs_confirmation
        ? "Instructions changed · collector must confirm"
        : "Pickup agreed",
      record.recovery?.trip_needs_confirmation ? "warning" : "",
    ],
    collected: [
      record.recovery?.redirect?.parent_allocation_id
        ? record.transport_confirmed && !record.recovery.trip_needs_confirmation
          ? "Onward delivery agreed · count on arrival"
          : "Food reserved onward · collector must agree arrival"
        : "Collected · receiving count needed",
      "warning",
    ],
    destination_issue: [
      "Receiving point unavailable · collector has food",
      "warning",
    ],
    redirected: ["Food reassigned in linked collections", ""],
    received: ["Receipt confirmed", "success"],
    receipt_issue: ["Receiving count needs a check", "error"],
    released: ["Invitation released", ""],
    cancelled: ["Commitment cancelled · no food handed over", ""],
    partial_closed: ["Revised commitment accounted for", "success"],
    closed_unconfirmed: [
      "Expected arrival closed · physical outcome unknown",
      "warning",
    ],
    custody_review: ["Physical reports need a check", "error"],
  })[record.state] || ["Review needed", "warning"];
const title = (record) =>
  `${boxCount(record.quantity)} for ${partnerName(record.need, "receiving partner")}`;
const reference = (record) => `Collection ${record.id}`;

export function collectionList(ctx) {
  const role = ctx.user.role;
  const page = el(
    "div",
    {},
    heading(
      role === "recipient"
        ? "Food invitations and arrivals"
        : "Your food collections",
      role === "collector"
        ? "Confirm only the trips you can carry. A planned arrival is not a receiving count."
        : "An invitation holds food for a reply. A collection and a receipt need their own confirmation.",
      ctx.organization,
    ),
  );
  if (!ctx.records.length)
    return el(
      "div",
      {},
      page,
      empty(
        "No collections yet",
        role === "collector"
          ? "Assigned collections appear here. The coordinator or receiving partner must assign you before you can confirm a trip."
          : "Food invitations and collection agreements addressed to your organization appear here.",
      ),
    );
  append(
    page,
    el(
      "section",
      { className: "surface list" },
      ctx.records.map((record) => {
        const [state, tone] = collectionState(record);
        return link(
          el(
            "div",
            {},
            el(
              "div",
              { className: "row-top" },
              tag(state, tone),
              el("span", { className: "record-ref" }, reference(record)),
            ),
            el("h2", {}, title(record)),
            el(
              "p",
              {},
              `${partnerName(record.offer, "Kitchen")} · ${record.offer.description}`,
            ),
            el(
              "p",
              {},
              record.state === "held"
                ? `Reply by ${time(record.hold_until, record.need.site?.time_zone)}`
                : record.recovery?.redirect?.parent_allocation_id
                  ? record.transport_confirmed &&
                    !record.recovery.trip_needs_confirmation
                    ? `${record.collector_name} · onward arrival agreed by ${time(record.arrival_by, record.need.site?.time_zone)}`
                    : `Food already with ${record.collector_name || "the assigned collector"}; onward arrival still needs their agreement`
                  : record.transport_confirmed
                    ? `${record.collector_name} · agreed pickup ${time(record.pickup_at, record.offer.site?.time_zone)}`
                    : "Collector and trip still need confirmation",
            ),
          ),
          `/allocations/${record.id}`,
          "record-row",
        );
      }),
    ),
  );
  return page;
}

function agreementActions(ctx, record) {
  const role = ctx.user.role;
  const identifier = { allocation_id: record.id, revision: record.revision };
  const expired = new Date(record.hold_until) <= new Date(ctx.now());
  const inTransit = Boolean(record.recovery?.redirect?.parent_allocation_id);
  const foodUnavailable = inTransit
    ? !record.offer.holding ||
      !record.offer.handling_until ||
      new Date(record.offer.handling_until) <= new Date(ctx.now()) ||
      record.need.state !== "open"
    : record.offer.state !== "open" || record.need.state !== "open";
  const loadUnconfirmed =
    !record.offer.packaging ||
    !record.offer.site?.time_zone ||
    !record.need.site?.time_zone;

  const mutation = (action, data, error, message) =>
    ctx.mutate(action, data, error, { message });
  const forms = el("aside");
  if (record.state === "held" && role === "recipient") {
    if (expired || foodUnavailable)
      append(
        forms,
        notice(
          "The reply window ended or current food/receiving facts need review. This invitation cannot be accepted from these facts. Ask the coordinator.",
          "warning",
        ),
      );
    else {
      append(
        forms,
        actionForm({
          title: "Reserve food for your team",
          expiresAt: earliest(
            record.hold_until,
            !inTransit && record.offer.collect_by,
            record.offer.handling_until,
            record.need.confirmed_until,
            record.need.receiving_until,
          ),
          now: ctx.now,
          description: inTransit
            ? `The food is already with ${record.collector_name || "the assigned collector"}. Choose the amount your team can receive. That collector still needs to agree the changed destination and arrival.`
            : "Choose the amount you can receive. A collector must still be assigned and confirm the trip.",
          submit: "Reserve these meal boxes",
          fields: [
            field("Meal boxes to reserve", {
              id: "accept-quantity",
              name: "quantity",
              type: "number",
              min: 1,
              max: record.quantity,
              value: record.quantity,
              required: true,
            }),
            confirm(
              "I confirm our team can receive this food under the recorded requirements.",
            ),
          ],
          onSubmit: (data, error) =>
            mutation(
              "accept",
              data && {
                ...identifier,
                quantity: data.get("quantity"),
                context_key: record.recovery.current_context.context_key,
              },
              error,
              inTransit
                ? "Food reserved from the existing carried load. The assigned collector still needs to agree the onward arrival."
                : "Food reserved. Collector assignment and transport confirmation are still needed.",
            ),
        }),
      );
    }
    append(
      forms,
      el(
        "details",
        {},
        el("summary", {}, "We cannot use this food"),
        actionForm({
          title: "Decline this invitation",
          description:
            "The hold will be released. This does not cancel any other food already reserved.",
          submit: "Decline the invitation",
          fields: [
            field("Reason for the coordinator", {
              id: "decline-reason",
              name: "reason",
              type: "textarea",
              required: true,
              maxLength: 500,
            }),
          ],
          onSubmit: (data, error) =>
            mutation(
              "decline",
              data && { ...identifier, reason: data.get("reason") },
              error,
              "Invitation declined. Its temporary hold has been released.",
            ),
        }),
      ),
    );
  }
  if (
    record.state === "accepted" &&
    !inTransit &&
    ["coordinator", "recipient"].includes(role)
  ) {
    if (!ctx.collectors?.length)
      append(
        forms,
        notice(
          "No approved collectors are available to choose from. Contact the food-rescue coordinator; this food is reserved but no pickup is agreed.",
          "warning",
        ),
      );
    else
      append(
        forms,
        actionForm({
          title: record.collector_id
            ? "Change the assigned collector"
            : "Assign an approved collector",
          description:
            "Assignment asks this person to take responsibility. Only that collector can confirm the trip.",
          submit: "Assign collector",
          fields: [
            field("Collector", {
              id: "collector-choice",
              name: "collector",
              required: true,
              options: [
                ["", "Choose a collector"],
                ...ctx.collectors.map((actor) => [actor.id, actor.name]),
              ],
              value: record.collector_id || "",
            }),
          ],
          onSubmit: (data, error) =>
            mutation(
              "assign_collector",
              data && {
                ...identifier,
                collector_actor_id: data.get("collector"),
              },
              error,
              "Collector assigned. They still need to confirm their own trip.",
            ),
        }),
      );
  }
  if (
    record.state === "accepted" &&
    !inTransit &&
    role === "collector" &&
    record.collector_id === ctx.user.id
  ) {
    if (
      foodUnavailable ||
      loadUnconfirmed ||
      record.recovery?.recipient_needs_confirmation
    ) {
      append(
        forms,
        notice(
          "The kitchen’s food window, packing details and both partner locations must be confirmed before you can agree this trip. Ask the coordinator to follow up.",
          "warning",
        ),
      );
    } else
      append(
        forms,
        actionForm({
          title: "Confirm your collection",
          expiresAt: earliest(
            !inTransit && record.offer.collect_by,
            record.offer.handling_until,
            record.need.confirmed_until,
            record.need.receiving_until,
          ),
          now: ctx.now,
          description:
            "Check the physical load and handling with the kitchen. These times must fit both partners’ windows.",
          submit: "Confirm my trip",
          fields: [
            dateTimeField("Pickup date and time", {
              id: "trip-pickup",
              name: "pickup",
              zone: record.offer.site?.time_zone,
              required: true,
            }),
            dateTimeField("Arrive at the receiving partner by", {
              id: "trip-arrival",
              name: "arrival",
              zone: record.need.site?.time_zone,
              required: true,
            }),
            field("Meal boxes I can carry", {
              id: "trip-capacity",
              name: "capacity",
              type: "number",
              min: record.quantity,
              max: 999999,
              required: true,
              help: "Check how many of the packed meal boxes your vehicle can actually carry.",
            }),
            el(
              "label",
              { className: "check confirmation" },
              el("input", {
                type: "checkbox",
                name: "handling",
                required: true,
              }),
              "I have checked the load and can maintain the recorded food handling requirements.",
            ),
          ],
          onSubmit: (data, error) =>
            mutation(
              "confirm_transport",
              data && {
                ...identifier,
                context_key: record.recovery.current_context.context_key,
                pickup_at: readLocal(
                  data,
                  "pickup",
                  record.offer.site?.time_zone,
                ),
                arrival_by: readLocal(
                  data,
                  "arrival",
                  record.need.site?.time_zone,
                ),
                capacity: data.get("capacity"),
                handling_accepted: data.has("handling"),
              },
              error,
              "Your trip is agreed. The kitchen will record the actual handoff.",
            ),
        }),
      );
  }
  if (record.state === "held" && role === "coordinator" && expired)
    append(
      forms,
      actionForm({
        title: "Release the expired invitation",
        description:
          "The receiving partner did not accept before the deadline. Release only this temporary hold; accepted food remains committed.",
        submit: "Release this expired hold",
        fields: [],
        onSubmit: (_, error) =>
          mutation(
            "expire_hold",
            identifier,
            error,
            "The expired invitation hold is released. No accepted collection was cancelled.",
          ),
      }),
    );
  append(
    forms,
    redirectActions(ctx, record),
    physicalActions(ctx, record),
    recoveryActions(ctx, record),
  );
  if (!forms.childNodes.length)
    append(
      forms,
      notice(
        record.state === "receipt_issue"
          ? "The food-rescue coordinator needs to check the recorded difference with the kitchen, collector and receiving contact. The missing quantity remains unresolved."
          : record.state === "redirected"
            ? "This original case continues in linked collections. Each receiving team records its own accepted quantity."
            : record.state === "received"
              ? "The receiving contact has accounted for the full collection."
              : record.state === "released"
                ? "This invitation no longer holds food."
                : record.state === "ready"
                  ? "The named collector has confirmed the trip. The kitchen records the physical handoff when it happens."
                  : "The next responsible person must confirm this step. A message or planned time is not proof the food moved.",
      ),
    );
  return forms;
}

export function collectionDetail(ctx) {
  const record = ctx.record;
  const [state, tone] = collectionState(record);
  const zone = record.offer.site?.time_zone;
  const receivingZone = record.need.site?.time_zone;
  const receiving = partnerName(record.need, "Receiving partner");
  const onward = record.recovery?.redirect;
  const inTransit = Boolean(onward?.parent_allocation_id);
  const isReceipt = [
    "received",
    "receipt_issue",
    "custody_review",
    "partial_closed",
    "closed_unconfirmed",
    "destination_issue",
    "redirected",
  ].includes(record.state);
  const summary = el(
    "article",
    { className: "surface detail-main collection-summary" },
    tag(state, tone),
  );
  let pageTitle = title(record);
  if (record.state === "held") pageTitle = `Invitation for ${receiving}`;
  if (record.state === "collected")
    pageTitle = inTransit
      ? `Food already carried for ${receiving}`
      : `Count what arrived at ${receiving}`;
  if (record.state === "destination_issue")
    pageTitle = "The receiving point is unavailable";
  if (record.state === "redirected")
    pageTitle = "This food continues in linked collections";
  if (record.state === "receipt_issue")
    pageTitle = `The receiving count needs a check`;
  if (record.state === "received")
    pageTitle = `${boxCount(record.received_quantity)} accepted at ${receiving}`;
  if (record.state === "released")
    pageTitle = "This food invitation was released";
  append(
    summary,
    el("h2", { className: "section-gap" }, record.offer.description),
  );
  if (record.recovery.review_issue)
    append(summary, notice(record.recovery.review_issue, "warning"));
  append(summary, redirectContext(ctx, record));
  if (isReceipt) {
    append(summary, custody(record));
  } else if (record.state === "collected") {
    append(
      summary,
      facts([
        ["Reserved for this partner", boxCount(record.quantity)],
        [
          inTransit
            ? "Already in the collector’s custody from the original collection"
            : "Kitchen recorded handing over",
          boxCount(record.collected_quantity),
        ],
        ["Collector", record.collector_name],
        ["Receiving contact", record.need.contact_name || "Receiving team"],
      ]),
      el(
        "p",
        {},
        inTransit && !record.transport_confirmed
          ? "The assigned collector needs to agree the changed destination and arrival. Record accepted food only when it actually arrives."
          : "The receiving contact records what actually arrived and explains any difference.",
      ),
    );
  } else if (record.state === "ready" && ctx.user.role === "kitchen") {
    append(
      summary,
      el(
        "p",
        {},
        `${record.collector_name} has agreed to collect this food. Count the actual boxes with the named collector before recording the handoff.`,
      ),
      facts([
        ["Collector", record.collector_name],
        ["Agreed pickup", time(record.pickup_at, zone)],
        ["Reserved quantity", boxCount(record.quantity)],
        ["Receiving partner", receiving],
      ]),
    );
  } else {
    append(
      summary,
      facts([
        [
          record.state === "held" ? "Offered quantity" : "Reserved quantity",
          boxCount(record.quantity),
        ],
        ["Kitchen", partnerName(record.offer, "Kitchen")],
        ["Holding method", holdingLabel(record.offer.holding)],
        [
          "Contains",
          record.offer.present_allergens.length
            ? labels(record.offer.present_allergens)
            : "No confirmed-present labels",
        ],
        [
          "Checked and not present",
          checkedAbsent(record.offer).length
            ? labels(checkedAbsent(record.offer))
            : "No confirmed-absent labels",
        ],
        ...(!inTransit
          ? [["Collect before", time(record.offer.collect_by, zone)]]
          : []),
        ["Receiving opens", time(record.need.receiving_from, receivingZone)],
        ["Receiving closes", time(record.need.receiving_until, receivingZone)],
        ...(record.state === "held"
          ? [["Reply before", time(record.hold_until, receivingZone)]]
          : [["Collector", record.collector_name || "Not assigned"]]),
      ]),
    );
    if (ctx.user.role === "collector")
      append(
        summary,
        facts([
          ...(!inTransit
            ? [["Food ready", time(record.offer.ready_at, zone)]]
            : []),
          ["Holding confirmed until", time(record.offer.handling_until, zone)],
          [
            "Kitchen’s whole-lot packing",
            record.offer.packaging || "Not confirmed",
          ],
        ]),
      );
  }
  if (record.note)
    append(
      summary,
      el(
        "div",
        { className: "source" },
        el("strong", {}, "Recorded handoff / receiving note"),
        el("p", {}, record.note),
      ),
    );
  if (record.recovery.agreed_trip) {
    const trip = record.recovery.agreed_trip;
    append(
      summary,
      el(
        "details",
        {
          className: "section-gap",
          ...(ctx.user.role === "collector" &&
          ![
            "destination_issue",
            "redirected",
            "received",
            "partial_closed",
            "closed_unconfirmed",
          ].includes(record.state)
            ? { open: true }
            : {}),
        },
        el("summary", {}, "Collector’s agreed ticket"),
        el(
          "div",
          { className: "panel" },
          record.recovery.trip_needs_confirmation &&
            notice(
              "Current instructions changed. Do not use this old ticket for a new handoff. The assigned collector must confirm the current instructions.",
              "warning",
            ),
          facts([
            ["Collector", trip.collector_name],
            ["Agreed at", time(trip.agreed_at, trip.details.pickup.time_zone)],
            ...(!inTransit
              ? [
                  [
                    "Agreed pickup",
                    time(trip.pickup_at, trip.details.pickup.time_zone),
                  ],
                ]
              : []),
            [
              "Agreed arrival by",
              time(trip.arrival_by, trip.details.destination.time_zone),
            ],
            ["Agreed quantity", boxCount(trip.details.quantity)],
            ["Packing", trip.details.food.packaging],
          ]),
          !inTransit
            ? siteFacts({ site: trip.details.pickup }, "Agreed pickup place")
            : trip.details.custody?.location &&
                facts([
                  [
                    "Collector’s reported starting place",
                    trip.details.custody.location,
                  ],
                  [
                    "Place confirmed at",
                    time(
                      trip.details.custody.confirmed_at,
                      trip.details.pickup.time_zone,
                    ),
                  ],
                ]),
          siteFacts(
            { site: trip.details.destination },
            "Agreed receiving place",
          ),
        ),
      ),
    );
  }

  append(summary, physicalHistory(ctx, record));
  const actions = agreementActions(ctx, record);
  actions.classList.add("collection-actions");
  const secondary = el(
    "details",
    { className: "collection-secondary" },
    el("summary", {}, "Food facts, times and partner contacts"),
    el(
      "div",
      { className: "panel" },
      facts([
        ["Kitchen", partnerName(record.offer, "Kitchen")],
        ["Receiving partner", receiving],
        ["Collector", record.collector_name || "Not assigned"],
        ...(!inTransit
          ? [["Food ready", time(record.offer.ready_at, zone)]]
          : []),
        ...(!inTransit
          ? [["Collect before", time(record.offer.collect_by, zone)]]
          : []),
        ["Receiving opens", time(record.need.receiving_from, receivingZone)],
        ["Receiving closes", time(record.need.receiving_until, receivingZone)],
        ["Holding method", holdingLabel(record.offer.holding)],
        ["Holding confirmed until", time(record.offer.handling_until, zone)],
        [
          "Contains",
          record.offer.present_allergens.length
            ? labels(record.offer.present_allergens)
            : "No confirmed-present labels",
        ],
        [
          "Checked and not present",
          checkedAbsent(record.offer).length
            ? labels(checkedAbsent(record.offer))
            : "No confirmed-absent labels",
        ],
        [
          "Kitchen’s whole-lot packing",
          record.offer.packaging || "Not confirmed",
        ],
        ...(record.transport_confirmed
          ? [
              ...(!inTransit
                ? [["Agreed pickup", time(record.pickup_at, zone)]]
                : []),
              ["Agreed arrival by", time(record.arrival_by, receivingZone)],
            ]
          : []),
      ]),
      siteFacts(
        record.offer,
        inTransit ? "Food origin" : "Current pickup place",
      ),
      siteFacts(record.need, "Current receiving place"),
    ),
  );
  return el(
    "div",
    {},
    link("← Back to collections", "/allocations", "back-link"),
    heading(
      pageTitle,
      record.state === "redirected"
        ? `${boxCount(record.recovery.original_promise_quantity)} originally reserved for ${receiving}. ${boxCount(onward.transferred_out_quantity)} reassigned to linked collections.`
        : `${partnerName(record.offer, "Kitchen")} to ${receiving} · ${boxCount(record.quantity)} ${record.state === "held" ? "offered" : record.state === "released" ? "previously offered" : "reserved"}.`,
      reference(record),
    ),
    el("div", { className: "collection-layout" }, summary, actions, secondary),
  );
}
