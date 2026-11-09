import { collectionState } from "./collections.js";
import {
  append,
  el,
  link,
  heading,
  tag,
  empty,
  facts,
  time,
  boxCount,
  labels,
  checkedAbsent,
  holdingLabel,
  field,
  dateTimeField,
  actionForm,
  confirm,
  allergenFields,
  readAllergens,
  notice,
  partnerName,
  siteFacts,
  custody,
} from "../render.js";
import { readLocal, localValue } from "../time.js";

export function foodState(record) {
  return record.state === "expired"
    ? ["Collection or holding window ended", "warning"]
    : record.state === "needs_details"
      ? ["Kitchen details needed", "warning"]
      : record.state === "review_required"
        ? ["Changed count · coordinator review", "error"]
        : Number(record.available_quantity) > 0
          ? ["Food available", ""]
          : ["No unassigned food", ""];
}

export function offerList(ctx) {
  const kitchen = ctx.user.role === "kitchen";
  const page = el(
    "div",
    {},
    heading(
      kitchen ? "Your food offers" : "Food ready for a plan",
      kitchen
        ? "Share what you can confirm. A named collector still needs to agree before food changes hands."
        : "Read the kitchen’s food facts and current receiving needs before sending invitations.",
      ctx.organization,
    ),
  );
  append(
    page,
    el(
      "div",
      { className: "page-actions" },
      kitchen
        ? link("Share today’s food", "/offers/new", "button")
        : el(
            "p",
            { className: "help" },
            "Plans are suggestions until you review and send them.",
          ),
      kitchen &&
        link(
          ctx.site ? "Your pickup location" : "Set up pickup location",
          "/site",
        ),
    ),
  );
  if (!ctx.records.length)
    append(
      page,
      empty(
        "No food offers yet",
        kitchen
          ? "Start with the food you have actually counted. The team sees the confirmed details and asks about any missing facts."
          : "Kitchen contacts confirm their own food. New offers appear here after their submission.",
      ),
    );
  else
    append(
      page,
      el(
        "section",
        { className: "surface list" },
        ctx.records.map((record) => {
          const [state, tone] = foodState(record);
          return link(
            el(
              "div",
              {},
              el(
                "div",
                { className: "row-top" },
                tag(state, tone),
                el(
                  "span",
                  { className: "record-ref" },
                  `Food offer ${record.id}`,
                ),
              ),
              el("h2", {}, record.description),
              el(
                "p",
                {},
                `${partnerName(record, "Kitchen")} · ${boxCount(record.current_quantity)} counted · ${boxCount(record.available_quantity)} unassigned`,
              ),
              el(
                "p",
                {},
                `Ready ${time(record.ready_at, record.site?.time_zone)} · collect before ${time(record.collect_by, record.site?.time_zone)}`,
              ),
            ),
            `/offers/${record.id}`,
            "record-row",
          );
        }),
      ),
    );
  return page;
}

function foodForm(ctx, record) {
  const editing = Boolean(record);
  const zone = ctx.site.time_zone;
  const fields = [
    el(
      "section",
      { className: "form-section" },
      el("h3", {}, "What is available?"),
      !editing &&
        field("Food description", {
          id: "food-description",
          name: "description",
          required: true,
          maxLength: 500,
          placeholder: "For example: baked vegetable rice in sealed meal boxes",
        }),
      !editing &&
        field("Whole meal boxes actually counted", {
          id: "food-quantity",
          name: "quantity",
          type: "number",
          min: 1,
          max: 999999,
          required: true,
          help: "This release handles sealed whole meal boxes. It does not turn trays, bags or weight into meals.",
        }),
      field("How is the food being held?", {
        id: "food-holding",
        name: "holding",
        value: record?.holding || "",
        options: [
          ["", "Not confirmed yet"],
          ["chilled", "Chilled"],
          ["hot", "Hot held"],
          ["ambient", "At room temperature"],
        ],
        help: "An unknown holding condition keeps the offer out of invitation planning until you confirm it.",
      }),
      dateTimeField("Holding conditions confirmed until", {
        id: "handling-until",
        name: "handling_until",
        zone,
        value: localValue(record?.handling_until, zone),
        help: "The last time the kitchen confirms these conditions remain valid. This differs from staff availability for collection.",
      }),
    ),
    el(
      "section",
      { className: "form-section" },
      el("h3", {}, "When and where can someone collect?"),
      dateTimeField("Ready for collection", {
        id: "food-ready",
        name: "ready_at",
        zone,
        value: localValue(record?.ready_at, zone),
        required: true,
      }),
      dateTimeField("Final collection time", {
        id: "food-cutoff",
        name: "collect_by",
        zone,
        value: localValue(record?.collect_by, zone),
        required: true,
      }),
      siteFacts({ site: ctx.site }, "Your saved pickup place"),
      link("Change pickup location", "/site"),
    ),
    el(
      "section",
      { className: "form-section" },
      el("h3", {}, "What needs to fit in the vehicle?"),
      field("Packing and carry containers", {
        id: "food-packaging",
        name: "packaging",
        type: "textarea",
        value: record?.packaging || "",
        maxLength: 1000,
        help: "For example: 6 carry cartons, 5 sealed meal boxes each. Leave blank if unknown. A collector cannot confirm a trip until the load is described.",
      }),
    ),
    el(
      "section",
      { className: "form-section" },
      el("h3", {}, "What has the kitchen checked?"),
      el(
        "p",
        {},
        "Use the food label and the kitchen’s actual confirmation. Unchecked items remain unassessed.",
      ),
      allergenFields(
        record?.present_allergens || [],
        record?.assessed_allergens || [],
      ),
    ),
    confirm(
      "These details reflect what our kitchen can confirm. I will report changes before collection.",
    ),
  ];
  return actionForm({
    title: editing ? "Confirm the current food details" : "Share today’s food",
    description:
      "The coordinator can plan only from confirmed facts. Missing details stay visible for follow-up.",
    submit: editing ? "Save food confirmation" : "Send food details for review",
    fields,
    onSubmit: (data, error) => {
      if (error)
        return ctx.mutate(
          editing ? "confirm_food" : "create_offer",
          null,
          error,
          { path: (result) => `/offers/${result.offer_id}` },
        );
      const food = {
        ready_at: readLocal(data, "ready_at", zone),
        collect_by: readLocal(data, "collect_by", zone),
        holding: data.get("holding") || null,
        handling_until: data.get("handling_until")
          ? readLocal(data, "handling_until", zone)
          : null,
        packaging: data.get("packaging"),
        ...readAllergens(data),
        event_at: ctx.now(),
      };
      const payload = editing
        ? { offer_id: record.id, revision: record.revision, ...food }
        : {
            description: data.get("description"),
            quantity: data.get("quantity"),
            unit: "meal_box",
            ...food,
          };
      return ctx.mutate(
        editing ? "confirm_food" : "create_offer",
        payload,
        null,
        {
          path: (result) => `/offers/${result.offer_id}`,
          message:
            "Kitchen facts saved. Food reservation and collection still need their own agreement.",
        },
      );
    },
  });
}

export function offerEntry(ctx) {
  if (!ctx.site)
    return empty(
      "Confirm your pickup location first",
      "The coordinator and collector need your actual address, entrance and time zone.",
      link("Set up pickup location", "/site", "button"),
    );
  return el(
    "section",
    { className: "entry-layout" },
    el(
      "aside",
      { className: "entry-context" },
      heading(
        ctx.record
          ? "Keep the food facts current."
          : "Food left over? Let’s find its next table.",
        "The coordinator reviews the kitchen’s confirmed facts, checks receiving needs and sends invitations.",
        ctx.site.name,
      ),
      el(
        "ol",
        { className: "steps" },
        el(
          "li",
          {},
          el(
            "div",
            {},
            el("strong", {}, "You confirm the food."),
            "Unknown details stay marked for follow-up.",
          ),
        ),
        el(
          "li",
          {},
          el(
            "div",
            {},
            el("strong", {}, "The receiving partner reserves a quantity."),
            "That still does not confirm a trip.",
          ),
        ),
        el(
          "li",
          {},
          el(
            "div",
            {},
            el("strong", {}, "A named collector confirms."),
            "Count the actual food at handoff.",
          ),
        ),
      ),
    ),
    foodForm(ctx, ctx.record),
  );
}

function collectionProgress(record, kitchen) {
  const [state, tone] = collectionState(record);
  const receiver = partnerName(record.need, "Receiving partner");
  let next;
  let action = "Open this collection";
  if (record.state === "held")
    next = `${record.need.site?.contact_name || "The receiving contact"} needs to reply before ${time(record.hold_until, record.need.site?.time_zone)}. A pickup has not been agreed.`;
  else if (record.state === "accepted")
    next = record.collector_name
      ? `${record.collector_name} has been assigned and still needs to confirm the trip.`
      : "The coordinator or receiving team needs to assign an approved collector. No pickup is agreed.";
  else if (record.state === "ready") {
    next = `${record.collector_name} agreed to collect ${time(record.pickup_at, record.offer.site?.time_zone)}. ${record.offer.state === "open" && record.need.state === "open" ? "The kitchen counts and records the actual handoff when the collector arrives." : "Changed food or receiving facts need review before handoff."}`;
    if (
      kitchen &&
      record.offer.state === "open" &&
      record.need.state === "open"
    )
      action = "Open the kitchen handoff";
  } else if (record.state === "collected")
    next = `${record.collector_name} collected ${boxCount(record.collected_quantity)}. ${record.need.site?.contact_name || "The receiving contact"} still needs to record what arrived.`;
  else if (record.state === "receipt_issue")
    next = `The receiving team accepted ${boxCount(record.received_quantity)}. The coordinator needs to check the ${record.unresolved_quantity} unresolved boxes.`;
  else if (record.state === "received")
    next = `${boxCount(record.received_quantity)} were accepted by the receiving team.`;
  else next = "This invitation no longer holds food.";
  return el(
    "section",
    { className: "food-collection" },
    el(
      "div",
      {},
      tag(state, tone),
      el("h3", {}, `${boxCount(record.quantity)} for ${receiver}`),
      el("p", {}, next),
    ),
    link(
      action,
      `/allocations/${record.id}`,
      record.state === "ready" && kitchen ? "button" : "button secondary",
    ),
  );
}

export function offerDetail(ctx) {
  const record = ctx.record;
  const [state, tone] = foodState(record);
  const kitchen = ctx.user.role === "kitchen";
  const collections = ctx.relatedAllocations || [];
  const active = collections.filter(
    (item) => !["received", "released"].includes(item.state),
  );
  const finished = collections.filter((item) =>
    ["received", "released"].includes(item.state),
  );
  const main = el(
    "article",
    { className: "surface detail-main" },
    tag(state, tone),
  );
  if (record.state === "needs_details") {
    append(
      main,
      el(
        "h2",
        { className: "section-gap" },
        "The kitchen needs to confirm a few details",
      ),
      el(
        "p",
        {},
        "The coordinator cannot send an invitation until the holding method, holding deadline and pickup place are confirmed.",
      ),
      kitchen
        ? link(
            "Confirm the food details",
            `/offers/${record.id}/edit`,
            "button",
          )
        : notice(
            "Next owner: the kitchen contact. Ask them to confirm the missing food details.",
            "warning",
          ),
    );
  } else if (record.state === "review_required") {
    append(
      main,
      el(
        "h2",
        { className: "section-gap" },
        "A change needs the coordinator’s review",
      ),
      notice(
        "New invitations and handoffs are paused. Existing promises remain recorded while the coordinator checks what changed.",
        "warning",
      ),
    );
  } else if (active.length) {
    append(main, el("h2", { className: "section-gap" }, "Who acts next"));
  } else if (Number(record.available_quantity) > 0) {
    append(
      main,
      el(
        "h2",
        { className: "section-gap" },
        kitchen
          ? "Waiting for a receiving plan"
          : "Unassigned food needs a receiving plan",
      ),
      el(
        "p",
        {},
        `${boxCount(record.available_quantity)} are still unassigned. ${active.length ? "Existing collection commitments are listed below." : "No collection has been agreed for this food yet."}`,
      ),
      kitchen
        ? el(
            "p",
            { className: "next-owner" },
            "Next owner: your food-rescue coordinator. You will see recipient replies and named collection details here.",
          )
        : link("Review receiving needs", `/offers/${record.id}/plan`, "button"),
    );
  } else if (!active.length && finished.length) {
    append(
      main,
      el(
        "h2",
        { className: "section-gap" },
        "Your collection records are below",
      ),
      el(
        "p",
        {},
        "Check each actual receiving count and any released invitation. New food is never inferred from a missing box.",
      ),
    );
  } else if (record.state === "expired") {
    append(
      main,
      el(
        "h2",
        { className: "section-gap" },
        "The collection or holding window has ended",
      ),
      el(
        "p",
        {},
        "Existing collection records remain below. The kitchen must confirm fresh facts before any new invitation.",
      ),
      kitchen &&
        link(
          "Review the food confirmation",
          `/offers/${record.id}/edit`,
          "button secondary",
        ),
    );
  } else
    append(
      main,
      el("h2", { className: "section-gap" }, "Follow the agreed collections"),
      el(
        "p",
        {},
        "Each receiving partner, collector and actual handoff has its own record.",
      ),
    );

  if (active.length)
    append(
      main,
      el(
        "section",
        { className: "section-gap" },
        ["needs_details", "review_required"].includes(record.state) &&
          el("h3", {}, "Existing collection agreements"),
        active.map((item) => collectionProgress(item, kitchen)),
      ),
    );
  if (active.length && Number(record.available_quantity) > 0)
    append(
      main,
      notice(
        `${boxCount(record.available_quantity)} remain unassigned. The coordinator can review current receiving needs for this remainder.`,
      ),
      !kitchen &&
        record.state === "open" &&
        link(
          "Plan the remaining food",
          `/offers/${record.id}/plan`,
          "button secondary section-gap",
        ),
    );
  const issue = active.find((item) => item.state === "receipt_issue");
  if (issue) append(main, custody(issue));
  if (ctx.moreCollections)
    append(
      main,
      notice(
        "This view shows the first 100 related records. Open the full collection list to read more.",
      ),
    );
  append(
    main,
    link(
      "Open all invitations and collections for this food",
      `/allocations?offer_id=${record.id}`,
      "button secondary section-gap",
    ),
  );
  if (finished.length)
    append(
      main,
      el(
        "details",
        { className: "section-gap" },
        el(
          "summary",
          {},
          `Earlier completed or released records (${finished.length})`,
        ),
        el(
          "div",
          { className: "panel" },
          finished.map((item) => collectionProgress(item, kitchen)),
        ),
      ),
    );

  const foodFacts = el(
    "details",
    { className: "section-gap" },
    el("summary", {}, "Food details and quantity history"),
    el(
      "div",
      { className: "panel" },
      facts([
        ["Originally declared", boxCount(record.declared_quantity)],
        ["Current lot count", boxCount(record.current_quantity)],
        ["Held for replies", boxCount(record.held_quantity)],
        ["Reserved, not collected", boxCount(record.committed_quantity)],
        ["Already handed over", boxCount(record.collected_quantity)],
        ["Currently unassigned", boxCount(record.available_quantity)],
      ]),
      Number(record.shortfall_quantity) > 0 &&
        notice(
          `${boxCount(record.shortfall_quantity)} are missing against current promises.`,
          "warning",
        ),
      facts([
        ["Ready from", time(record.ready_at, record.site?.time_zone)],
        ["Collect before", time(record.collect_by, record.site?.time_zone)],
        ["Holding method", holdingLabel(record.holding)],
        [
          "Holding confirmed until",
          time(record.handling_until, record.site?.time_zone),
        ],
        ["Whole-lot packing", record.packaging || "Not confirmed"],
        [
          "Contains",
          record.present_allergens.length
            ? labels(record.present_allergens)
            : "No confirmed-present labels",
        ],
        [
          "Checked and not present",
          checkedAbsent(record).length
            ? labels(checkedAbsent(record))
            : "No confirmed-absent labels",
        ],
      ]),
      el(
        "p",
        { className: "help" },
        "Allergen facts outside these confirmed lists remain unconfirmed.",
      ),
      siteFacts(record, "Current pickup place"),
    ),
  );
  const actions = el("aside", {}, foodFacts);
  if (kitchen) {
    append(
      actions,
      link(
        "Update the food details",
        `/offers/${record.id}/edit`,
        "button secondary section-gap",
      ),
    );
    append(
      actions,
      el(
        "details",
        { className: "section-gap" },
        el("summary", {}, "Report a changed physical count"),
        actionForm({
          title: "Record a changed count",
          description:
            "Count the original lot total, including boxes already handed over. This pauses new invitations and handoffs for coordinator review.",
          submit: "Report the changed count",
          fields: [
            field("Current total meal boxes for this lot", {
              id: "stock-quantity",
              name: "quantity",
              type: "number",
              min: record.collected_quantity,
              max: 999999,
              required: true,
            }),
            field("When and how was it counted?", {
              id: "stock-note",
              name: "note",
              type: "textarea",
              required: true,
              maxLength: 2000,
            }),
          ],
          onSubmit: (data, error) =>
            ctx.mutate(
              "observe_stock",
              data && {
                offer_id: record.id,
                revision: record.revision,
                quantity: data.get("quantity"),
                note: data.get("note"),
              },
              error,
              {
                message:
                  "Changed count recorded. New invitations and handoffs are paused; existing promises remain visible for review.",
              },
            ),
        }),
      ),
    );
  }
  return el(
    "div",
    {},
    link("← Back to food offers", "/offers", "back-link"),
    heading(
      record.description,
      "See who is collecting this food and what needs to happen next.",
      `Food offer ${record.id}`,
    ),
    el("div", { className: "detail-layout" }, main, actions),
  );
}
