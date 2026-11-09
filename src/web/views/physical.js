/** Actual food movements and their corrections. They never imply a new promise or safe future pickup. */
import { localValue } from "../time.js";
import { append, el, facts, tag, notice, boxCount, time } from "../render.js";
import {
  field,
  actionForm,
  confirm,
  occurrenceFields,
  occurredAt,
  dateTimeField,
} from "../forms.js";

const outcomeLabels = {
  lost: "Lost while in the collector’s custody",
  discarded: "Discarded by the collector",
  returned_to_kitchen: "Physically returned to this kitchen · keep quarantined",
  rejected_at_site: "Rejected and kept at this receiving site",
};

/** Report only physical facts owned by the signed-in partner. */
export function physicalActions(ctx, record) {
  const recovery = record.recovery;
  if (!recovery) return null;
  const role = ctx.user.role;
  const panel = el("section");
  const identifier = { allocation_id: record.id, revision: record.revision };
  const foodUnavailable =
    record.offer.state !== "open" || record.need.state !== "open";
  const mutate = (action, payload, error, message) =>
    ctx.mutate(action, payload, error, { message });

  if (
    role === "kitchen" &&
    record.recovery &&
    !record.recovery.redirect?.parent_allocation_id &&
    !["held", "released", "cancelled"].includes(record.state) &&
    (Number(record.recovery.unhanded_quantity) > 0 ||
      Number(record.recovery.unmatched_report_quantity) > 0)
  ) {
    const normal =
      record.state === "ready" &&
      !record.recovery.trip_needs_confirmation &&
      !foodUnavailable &&
      new Date(ctx.now()) >= new Date(record.offer.ready_at);
    if (!normal)
      append(
        panel,
        notice(
          "Do not hand over on the old ticket. Current food, receiving facts or trip instructions need confirmation. If a handoff already happened, record the actual fact below; it will be checked against the agreement at that time.",
          "warning",
        ),
      );
    const report = actionForm({
      physicalReport: true,
      title: normal
        ? "Record the physical handoff"
        : "Already happened? Record actual handoff",
      description: normal
        ? `Count the actual boxes with ${record.collector_name || "the named collector"}. Only record food that has physically changed hands.`
        : "This records an earlier physical fact. It does not approve a future pickup or erase a missed deadline.",
      submit: "Record actual handoff",
      fields: [
        field("Meal boxes handed to the collector", {
          id: "handoff-count",
          name: "quantity",
          type: "number",
          min: 1,
          max: 999999,
          required: true,
        }),
        occurrenceFields("handoff", record.offer.site?.time_zone),
        field("Handoff note", {
          id: "handoff-note",
          name: "note",
          type: "textarea",
          required: !normal,
          maxLength: 2000,
          help: "Explain a short or extra count, changed instructions or late reporting. Leave unknown outcomes unknown.",
        }),
        confirm(
          normal
            ? "The named collector is here and this quantity has physically changed hands."
            : "This handoff already happened. I am reporting what physically changed hands, not approving a future pickup.",
        ),
      ],
      onSubmit: (data, error) => {
        if (
          data &&
          Number(data.get("quantity")) !==
            Number(record.recovery.unhanded_quantity) &&
          !data.get("note").trim()
        )
          throw new Error(
            "Explain the difference from the unhanded promise before recording this physical fact.",
          );
        return mutate(
          "handoff",
          data && {
            ...identifier,
            quantity: data.get("quantity"),
            occurred_at: occurredAt(
              data,
              record.offer.site?.time_zone,
              ctx.now,
            ),
            note: data.get("note"),
          },
          error,
          "The kitchen handoff is recorded. The receiving contact still needs to count what arrives; any agreement problem remains visible.",
        );
      },
    });
    append(
      panel,
      normal
        ? report
        : el(
            "details",
            { className: "section-gap" },
            el("summary", {}, "Already happened? Record actual handoff"),
            report,
          ),
    );
  }
  if (
    role === "recipient" &&
    record.recovery &&
    !record.recovery.receipt_recorded &&
    !["held", "released", "cancelled", "accepted"].includes(record.state)
  ) {
    const earlyOnward =
      record.recovery.redirect?.parent_allocation_id &&
      (!record.transport_confirmed || record.recovery.trip_needs_confirmation);
    const receiptForm = actionForm({
      title: "Count what arrived",
      physicalReport: true,
      description: earlyOnward
        ? "If food already arrived before the new trip was agreed, record what was physically accepted. The report will keep the missing agreement visible for review."
        : "Record the number your team accepts. Explain any short or rejected amount so the coordinator can follow up.",
      submit: "Record receiving count",
      fields: [
        field("Meal boxes accepted", {
          id: "receipt-count",
          name: "quantity",
          type: "number",
          min: 0,
          max: 999999,
          required: true,
        }),
        occurrenceFields("receipt", record.need.site?.time_zone),
        field("What happened to any difference?", {
          id: "receipt-note",
          name: "note",
          type: "textarea",
          maxLength: 2000,
          help: "Required if fewer than the reserved boxes are accepted. Say what you know; leave unknown outcomes unknown.",
        }),
        confirm("I have counted the food at our receiving point."),
      ],
      onSubmit: (data, error) => {
        if (
          data &&
          Number(data.get("quantity")) < Number(record.quantity) &&
          !data.get("note").trim()
        )
          throw new Error(
            "Explain the short or rejected quantity before recording this count.",
          );
        return mutate(
          "receive",
          data && {
            ...identifier,
            quantity: data.get("quantity"),
            occurred_at: occurredAt(data, record.need.site?.time_zone, ctx.now),
            note: data.get("note"),
          },
          error,
          "Receiving count recorded. Any missing quantity remains open for follow-up.",
        );
      },
    });
    append(
      panel,
      earlyOnward
        ? disclosure(
            "Already arrived? Record the actual accepted food",
            receiptForm,
          )
        : receiptForm,
    );
  }

  if (
    role === "recipient" &&
    recovery.receipt_recorded &&
    !["held", "released"].includes(record.state)
  )
    append(
      panel,
      disclosure(
        "More food arrived after our first count",
        actionForm({
          title: "Record additional boxes accepted",
          description:
            "Enter only boxes accepted after the previous report. To fix an earlier wrong count, correct that report in the history below instead.",
          submit: "Record additional accepted food",
          physicalReport: true,
          fields: [
            field("Additional meal boxes accepted", {
              id: "receipt-more-quantity",
              name: "quantity",
              type: "number",
              min: 1,
              max: 999999,
              required: true,
            }),
            occurrenceFields("receipt-more", record.need.site?.time_zone),
            field("Explain the additional arrival", {
              id: "receipt-more-note",
              name: "note",
              type: "textarea",
              required: true,
              maxLength: 2000,
            }),
            confirm(
              "These boxes were accepted after the earlier count. I have not counted the same food twice.",
            ),
          ],
          onSubmit: (data, error) =>
            mutate(
              "receive_more",
              data && {
                allocation_id: record.id,
                revision: record.revision,
                quantity: data.get("quantity"),
                occurred_at: occurredAt(
                  data,
                  record.need.site?.time_zone,
                  ctx.now,
                ),
                note: data.get("note"),
              },
              error,
              "Additional accepted food recorded. Earlier reports remain in history; any unmatched handoff still needs review.",
            ),
        }),
      ),
    );
  const outcomes =
    role === "kitchen"
      ? ["returned_to_kitchen"]
      : role === "recipient"
        ? ["rejected_at_site"]
        : role === "collector" && record.collector_id === ctx.user.id
          ? ["lost", "discarded"]
          : [];
  if (
    outcomes.length &&
    !["held", "released", "cancelled"].includes(record.state)
  )
    append(
      panel,
      disclosure(
        "Record a known outcome for food not accepted",
        actionForm({
          title: "What physically happened to these boxes?",
          physicalReport: true,
          description:
            "Use this only for an outcome you can confirm. Do not use a guessed loss to close an unexplained difference. A returned box stays quarantined and is not available for another invitation.",
          submit: "Record known physical outcome",
          fields: [
            field("Confirmed outcome", {
              id: "outcome-kind",
              name: "outcome",
              required: true,
              options: [
                ["", "Choose what you can confirm"],
                ...outcomes.map((value) => [value, outcomeLabels[value]]),
              ],
            }),
            field("Meal boxes with this outcome", {
              id: "outcome-quantity",
              name: "quantity",
              type: "number",
              min: 1,
              max: 999999,
              required: true,
            }),
            occurrenceFields(
              "outcome",
              role === "recipient"
                ? record.need.site?.time_zone
                : record.offer.site?.time_zone,
            ),
            field("What happened and where is the food?", {
              id: "outcome-note",
              name: "note",
              type: "textarea",
              required: true,
              maxLength: 2000,
            }),
            confirm(
              "I can confirm this physical outcome. This is not a guess about missing food.",
            ),
          ],
          onSubmit: (data, error) =>
            mutate(
              "record_disposition",
              data && {
                allocation_id: record.id,
                revision: record.revision,
                quantity: data.get("quantity"),
                outcome: data.get("outcome"),
                occurred_at: occurredAt(
                  data,
                  role === "recipient"
                    ? record.need.site?.time_zone
                    : record.offer.site?.time_zone,
                  ctx.now,
                ),
                note: data.get("note"),
              },
              error,
              "Physical outcome recorded. It stays separate from accepted food and any change to the promise.",
            ),
        }),
      ),
    );
  return panel.childNodes.length ? panel : null;
}
function disclosure(title, content) {
  return el(
    "details",
    { className: "section-gap" },
    el("summary", {}, title),
    content,
  );
}
/** Append-only physical history; a correction replaces a report without deleting its source. */
export function physicalHistory(ctx, record) {
  const reports = record.recovery?.custody_history || record.custody_history;
  if (!reports?.length) return null;
  const labels = {
    handoff: "Kitchen handoff",
    receipt: "Accepted at receiving site",
    lost: "Collector reported loss",
    discarded: "Collector discarded food",
    returned: "Returned to kitchen · quarantined",
    rejected_at_site: "Rejected and kept at receiving site",
    quarantine_disposed: "Kitchen disposed of quarantined food",
  };
  return el(
    "details",
    { className: "section-gap" },
    el("summary", {}, "Physical reports and corrections"),
    el(
      "div",
      { className: "panel" },
      reports.map((report) => {
        const zone =
          (["receipt", "rejected_at_site"].includes(report.kind)
            ? record.need?.site?.time_zone
            : (record.offer || record).site?.time_zone) || "UTC";
        return el(
          "section",
          { className: "source" },
          tag(
            report.active ? "Current report" : "Replaced by a correction",
            report.active ? "" : "warning",
          ),
          el("h3", {}, labels[report.kind] || "Physical food report"),
          facts([
            ["Quantity", boxCount(report.quantity)],
            ["Reported by", report.actor_name],
            ["Actually happened", time(report.occurred_at, zone)],
            ["Added to the record", time(report.recorded_at, zone)],
          ]),
          report.note && el("p", {}, report.note),
          report.agreement_issue && notice(report.agreement_issue, "warning"),
          report.can_correct &&
            disclosure(
              "Correct this report",
              actionForm({
                title: "Correct the earlier physical report",
                description:
                  "Enter the correct full quantity and actual time for this one report. The original report stays visible as replaced. This is not an additional arrival or handoff.",
                submit: "Save correction for review",
                physicalReport: true,
                fields: [
                  field("Correct total for this report", {
                    id: `correction-${report.id}-quantity`,
                    name: "quantity",
                    type: "number",
                    min: 0,
                    max: 999999,
                    value: report.quantity,
                    required: true,
                  }),
                  dateTimeField("Correct actual date and time", {
                    id: `correction-${report.id}-time`,
                    name: "occurred",
                    zone,
                    value: localValue(report.occurred_at, zone),
                    required: true,
                  }),
                  field("What was wrong with the earlier report?", {
                    id: `correction-${report.id}-note`,
                    name: "note",
                    type: "textarea",
                    required: true,
                    maxLength: 2000,
                  }),
                  confirm(
                    "This replaces the earlier report with the actual count and time. It does not record another movement of food.",
                  ),
                ],
                onSubmit: (data, error) =>
                  ctx.mutate(
                    "correct_custody",
                    data && {
                      custody_id: report.id,
                      revision: report.revision,
                      quantity: data.get("quantity"),
                      occurred_at: occurredAt(
                        data,
                        zone,
                        ctx.now,
                        report.occurred_at,
                      ),
                      note: data.get("note"),
                    },
                    error,
                    {
                      message:
                        "Correction recorded for review. The earlier source remains visible and current food promises have not been silently cancelled.",
                    },
                  ),
              }),
            ),
        );
      }),
    ),
  );
}
