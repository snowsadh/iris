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
  labels,
  holdingLabel,
  field,
  dateTimeField,
  actionForm,
  confirm,
  checklist,
  allergens,
  holding,
  partnerName,
  notice,
  siteFacts,
} from "../render.js";
import { localValue, readLocal } from "../time.js";

function needState(record) {
  if (record.state === "expired")
    return ["Receiving confirmation ended", "warning"];
  if (record.state === "review_required")
    return ["Changed receiving facts need review", "warning"];
  if (record.state === "needs_details")
    return ["Partner details needed", "warning"];
  if (Number(record.requested_quantity) === 0)
    return ["No meals needed for this window", ""];
  return [`${boxCount(record.remaining_quantity)} still needed`, ""];
}

export function needList(ctx) {
  const recipient = ctx.user.role === "recipient";
  const page = el(
    "div",
    {},
    heading(
      recipient ? "What your team can use" : "Current receiving needs",
      "Each total includes food already held and reserved across all kitchens. A fulfilled collection does not silently create room for more food.",
      ctx.organization,
    ),
  );
  if (recipient)
    append(
      page,
      el(
        "div",
        { className: "page-actions" },
        link("Add a receiving need", "/needs/new", "button"),
        link(
          ctx.site ? "Your receiving location" : "Set up receiving location",
          "/site",
        ),
      ),
    );
  if (!ctx.records.length)
    append(
      page,
      empty(
        "No receiving need recorded",
        recipient
          ? "Record the total for a receiving window, the food your team can handle and how long those details remain current."
          : "Receiving contacts must confirm their own quantities and handling. There are no current entries to plan against.",
      ),
    );
  else
    append(
      page,
      el(
        "section",
        { className: "surface list" },
        ctx.records.map((record) =>
          link(
            el(
              "div",
              {},
              el(
                "div",
                { className: "row-top" },
                tag(...needState(record)),
                el(
                  "span",
                  { className: "record-ref" },
                  `Receiving need ${record.id}`,
                ),
              ),
              el("h2", {}, partnerName(record, "Receiving partner")),
              el(
                "p",
                {},
                `${record.requested_quantity} total · ${record.held_quantity} held for replies · ${record.committed_quantity} reserved`,
              ),
              el(
                "p",
                {},
                `Receiving before ${time(record.receiving_until, record.site?.time_zone)}`,
              ),
            ),
            `/needs/${record.id}`,
            "record-row",
          ),
        ),
      ),
    );
  return page;
}

function needForm(ctx, record) {
  const editing = Boolean(record);
  const zone = ctx.site.time_zone;
  const known = allergens.map(([label]) => label);
  return actionForm({
    title: editing
      ? "Update the whole receiving need"
      : "Add a receiving window",
    description: editing
      ? "Enter the whole total, including food already reserved. Existing promises stay recorded if the total falls."
      : "Use an existing entry to change the same need. A new entry counts as additional receiving capacity.",
    submit: editing ? "Update receiving need" : "Confirm receiving need",
    fields: [
      !editing &&
        ctx.currentNeeds?.length > 0 &&
        confirm(
          "This is additional receiving capacity. It does not replace or update any current entry above.",
        ),
      editing &&
        Number(record.held_quantity) + Number(record.committed_quantity) > 0 &&
        notice(
          `This entry includes existing promises for the window ending ${time(record.receiving_until, zone)}. A different day or separate service window needs its own entry; updating this record keeps those promises.`,
          "warning",
        ),
      field("Total whole meal boxes for this window", {
        id: "need-quantity",
        name: "quantity",
        type: "number",
        min: editing ? 0 : 1,
        max: 999999,
        value: record?.requested_quantity || "",
        required: true,
      }),
      dateTimeField("Receiving door open until", {
        id: "need-receiving",
        name: "receiving_until",
        zone,
        value: localValue(record?.receiving_until, zone),
        required: true,
      }),
      dateTimeField("These need details remain confirmed until", {
        id: "need-confirmed",
        name: "confirmed_until",
        zone,
        value: localValue(record?.confirmed_until, zone),
        required: true,
        help: "After this point, the coordinator must ask for a fresh confirmation before sending more food invitations.",
      }),
      checklist(
        "Food holding types your team can receive",
        "accepted_holding",
        holding,
        {
          selected: record?.accepted_holding || [],
          help: "Leave a type unchecked if your team has not confirmed it can handle that food. No checked types means an invitation cannot be planned yet.",
        },
      ),
      checklist(
        "Allergens your team must exclude",
        "excluded_allergens",
        allergens,
        { selected: record?.excluded_allergens || [] },
      ),
      field("Other excluded allergens", {
        id: "need-other-allergens",
        name: "other_allergens",
        value: (record?.excluded_allergens || [])
          .filter((value) => !known.includes(value))
          .join(", "),
        help: "Use exact kitchen labels, separated by commas. These common choices do not cover every possible restriction.",
      }),
      confirm(
        "I confirm this total and the receiving requirements for our team.",
      ),
    ],
    onSubmit: (data, error) => {
      if (error)
        return ctx.mutate(
          editing ? "update_need" : "create_need",
          null,
          error,
          { path: (result) => `/needs/${result.need_id}` },
        );
      const exclusions = [
        ...new Set([
          ...data.getAll("excluded_allergens"),
          ...data
            .get("other_allergens")
            .split(",")
            .map((value) => value.trim().toLowerCase())
            .filter(Boolean),
        ]),
      ];
      const payload = {
        ...(editing ? { need_id: record.id, revision: record.revision } : {}),
        quantity: data.get("quantity"),
        unit: "meal_box",
        receiving_until: readLocal(data, "receiving_until", zone),
        confirmed_until: readLocal(data, "confirmed_until", zone),
        excluded_allergens: exclusions,
        accepted_holding: data.getAll("accepted_holding"),
        event_at: ctx.now(),
      };
      return ctx.mutate(
        editing ? "update_need" : "create_need",
        payload,
        null,
        {
          path: (result) => `/needs/${result.need_id}`,
          message:
            "Receiving need saved. Existing held and reserved food remains part of the total.",
        },
      );
    },
  });
}

export function needEntry(ctx) {
  if (!ctx.site)
    return empty(
      "Confirm your receiving place first",
      "Food collectors need your actual address, entrance, contact and time zone.",
      link("Set up receiving location", "/site", "button"),
    );

  if (!ctx.record && ctx.currentNeeds?.length) {
    return el(
      "section",
      {},
      heading(
        "Update an existing window, or add a separate one.",
        "Changing tonight’s total should update the matching entry. A new entry adds receiving capacity alongside the existing ones.",
        ctx.site.name,
      ),
      el(
        "section",
        { className: "surface list" },
        ctx.currentNeeds.map((need) =>
          el(
            "article",
            { className: "record-row" },
            tag(...needState(need)),
            el(
              "h2",
              {},
              `Receiving before ${time(need.receiving_until, need.site?.time_zone)}`,
            ),
            el(
              "p",
              {},
              `${need.requested_quantity} total · ${need.held_quantity} held · ${need.committed_quantity} reserved`,
            ),
            link(
              "Update this window’s total",
              `/needs/${need.id}/edit`,
              "button secondary section-gap",
            ),
          ),
        ),
      ),
      el(
        "details",
        { className: "section-gap" },
        el("summary", {}, "Add separate receiving capacity"),
        needForm(ctx, null),
      ),
      link(
        "View all receiving entries, including earlier windows",
        "/needs",
        "back-link section-gap",
      ),
    );
  }
  return el(
    "section",
    { className: "entry-layout" },
    el(
      "aside",
      { className: "entry-context" },
      heading(
        "Tell the team what you can use.",
        "The total includes all food already held and reserved for this receiving window.",
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
            el("strong", {}, "Keep the whole need current."),
            "Changing a need does not erase existing promises.",
          ),
        ),
        el(
          "li",
          {},
          el(
            "div",
            {},
            el("strong", {}, "Review food invitations."),
            "Reserve only what your team can actually receive.",
          ),
        ),
        el(
          "li",
          {},
          el(
            "div",
            {},
            el("strong", {}, "Count the arrival."),
            "Record actual accepted food, including any difference.",
          ),
        ),
      ),
    ),
    needForm(ctx, ctx.record),
  );
}

export function needDetail(ctx) {
  const record = ctx.record;
  const gap = Math.max(
    0,
    Number(record.held_quantity) +
      Number(record.committed_quantity) -
      Number(record.requested_quantity),
  );
  const main = el(
    "article",
    { className: "surface detail-main" },
    tag(...needState(record)),
    el(
      "h2",
      { className: "section-gap" },
      partnerName(record, "Receiving partner"),
    ),
    record.state !== "open" &&
      notice(
        "Current receiving facts need a fresh review. Existing promises remain recorded; no new invitation can use this capacity yet.",
        "warning",
      ),
    facts([
      ["Whole window’s need", boxCount(record.requested_quantity)],
      ["Held for replies", boxCount(record.held_quantity)],
      [
        "Reserved, including fulfilled food",
        boxCount(record.committed_quantity),
      ],
      ["Still needed", boxCount(record.remaining_quantity)],
    ]),
    gap > 0 &&
      notice(
        `${boxCount(gap)} exceed the updated total. Existing promises remain recorded. The coordinator needs to review them with your team.`,
        "warning",
      ),
    facts([
      ["Receiving until", time(record.receiving_until, record.site?.time_zone)],
      [
        "Need details confirmed until",
        time(record.confirmed_until, record.site?.time_zone),
      ],
      [
        "Excluded allergens",
        record.excluded_allergens.length
          ? labels(record.excluded_allergens)
          : "None excluded by the receiving team",
      ],
      [
        "Accepted food holding",
        record.accepted_holding.length
          ? record.accepted_holding.map(holdingLabel).join(", ")
          : "Not confirmed",
      ],
    ]),
    siteFacts(record, "Receiving place"),
    link(
      "View this need’s food invitations",
      `/allocations?need_id=${record.id}`,
      "button secondary",
    ),
  );
  return el(
    "div",
    {},
    link("← Back to receiving needs", "/needs", "back-link"),
    heading(
      "The whole receiving need",
      "This capacity is shared by food from every kitchen.",
      `Receiving need ${record.id}`,
    ),
    el(
      "div",
      { className: "detail-layout" },
      main,
      ctx.user.role === "recipient"
        ? el(
            "aside",
            {},
            link(
              "Update this receiving need",
              `/needs/${record.id}/edit`,
              "button",
            ),
          )
        : el(
            "aside",
            {},
            notice(
              "The receiving contact confirms their own current need. The coordinator can plan invitations from these saved facts.",
            ),
          ),
    ),
  );
}
