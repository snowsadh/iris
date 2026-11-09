import { readLocal, earliest } from "../time.js";
import {
  append,
  el,
  link,
  facts,
  tag,
  notice,
  boxCount,
  time,
  siteFacts,
  holdingLabel,
  checkedAbsent,
  labels,
} from "../render.js";
import { field, actionForm, confirm, dateTimeField } from "../forms.js";

/** Changed promises and known physical outcomes. Every quantity comes from the saved case. */
export function recoveryActions(ctx, record) {
  const recovery = record.recovery;
  if (!recovery) return null;
  const role = ctx.user.role;
  const panel = el("section", { className: "recovery-actions" });
  const mutate = (action, payload, error, message) =>
    ctx.mutate(action, payload, error, { message });
  const change = recovery.change;
  if (
    role === "collector" &&
    record.collector_id === ctx.user.id &&
    recovery.trip_needs_confirmation &&
    !recovery.redirect?.parent_allocation_id &&
    recovery.agreed_trip &&
    record.state !== "accepted" &&
    Number(record.quantity) > Number(record.received_quantity) &&
    !["cancelled", "closed_unconfirmed"].includes(record.state)
  ) {
    if (recovery.recipient_needs_confirmation)
      append(
        panel,
        notice(
          "Changed food or destination instructions need the receiving partner’s confirmation first. Ask the coordinator to request that reply. Your old ticket does not approve a new handoff.",
          "warning",
        ),
      );
    else {
      const current = recovery.current_context;
      const load =
        Number(recovery.unhanded_quantity) +
        Number(recovery.physical_unknown_quantity);
      append(
        panel,
        actionForm({
          title: "Review and agree the current trip instructions",
          description:
            "Compare these current instructions with your previous agreed ticket. Confirm only if you can carry the remaining load and meet the receiving window.",
          submit: "Agree these updated trip instructions",
          expiresAt: earliest(
            current.details.food.handling_until,
            current.details.receiving.receiving_until,
          ),
          now: ctx.now,
          blockedReason:
            record.offer.state !== "open" || record.need.state !== "open"
              ? "Current food or receiving facts are still paused or expired. Ask the coordinator to finish the review first."
              : "",
          fields: [
            siteFacts(
              { site: current.details.pickup },
              "Current pickup instructions",
            ),
            siteFacts(
              { site: current.details.destination },
              "Current receiving instructions",
            ),
            facts([
              [
                "Current packing",
                current.details.food.packaging || "Not confirmed",
              ],
              [
                "Required food holding",
                holdingLabel(current.details.food.holding),
              ],
              [
                "Receiving opens",
                time(
                  current.details.receiving.receiving_from,
                  current.details.destination.time_zone,
                ),
              ],
              [
                "Receiving closes",
                time(
                  current.details.receiving.receiving_until,
                  current.details.destination.time_zone,
                ),
              ],
              [
                "Food handling confirmed until",
                time(
                  current.details.food.handling_until,
                  current.details.pickup.time_zone,
                ),
              ],
            ]),
            dateTimeField("My new arrival deadline", {
              id: "updated-trip-arrival",
              name: "arrival",
              zone: current.details.destination.time_zone,
              required: true,
            }),
            field("Meal boxes I can still carry", {
              id: "updated-trip-capacity",
              name: "capacity",
              type: "number",
              min: load,
              max: 999999,
              required: true,
              help: "Check the actual packed load; meal count alone does not prove it fits your vehicle.",
            }),
            el(
              "label",
              { className: "check confirmation" },
              el("input", {
                type: "checkbox",
                name: "handling",
                required: true,
              }),
              "I checked these current places, packing and handling requirements and can carry this trip.",
            ),
          ],
          onSubmit: (data, error) =>
            mutate(
              "acknowledge_trip",
              data && {
                allocation_id: record.id,
                revision: record.revision,
                context_key: current.context_key,
                capacity: data.get("capacity"),
                handling_accepted: data.has("handling"),
                arrival_by: readLocal(
                  data,
                  "arrival",
                  current.details.destination.time_zone,
                ),
              },
              error,
              "Updated trip instructions agreed. The previous ticket remains in the history; physical handoff and receipt still need their own reports.",
            ),
        }),
      );
    }
  }
  if (change) {
    const changeLabels = {
      awaiting_response: "Waiting for partner replies",
      applied: "Collection change agreed",
      rejected: "A partner could not agree",
      stale: "Facts changed · a new proposal is needed",
    };
    const summary = el(
      "section",
      { className: "surface detail-main section-gap" },
      tag(
        changeLabels[change.state] || "Commitment change under review",
        change.state === "applied" ? "success" : "warning",
      ),
      el(
        "h2",
        {},
        `${change.state === "applied" ? "Agreed total" : "Proposed total"}: ${boxCount(change.new_quantity)}`,
      ),
      el("p", { className: "help" }, "Why the change was requested"),
      el("p", {}, change.reason),
      facts(
        (change.required_parties || []).map((party) => {
          const reply = change.responses?.[party];
          return [
            party === "recipient" ? "Receiving contact" : "Kitchen contact",
            reply?.status === "agreed"
              ? `${reply.actor_name || "Partner"} agreed`
              : reply?.status === "declined"
                ? `${reply.actor_name || "Partner"} could not agree`
                : "Reply needed",
          ];
        }),
      ),
      el(
        "p",
        { className: "help" },
        change.state === "applied"
          ? `The required partners agreed. The current commitment is ${boxCount(record.quantity)}; the earlier ${boxCount(change.original_quantity)} promise remains in history. Physical food reports stay separate.`
          : change.state === "awaiting_response"
            ? `The ${boxCount(change.original_quantity)} promise stays in place until the required partners agree. Physical food reports stay separate.`
            : `This proposal was not applied. The current ${boxCount(record.quantity)} promise remains recorded; a new proposal must use the current facts.`,
      ),
    );
    const proposed = change.context?.details;
    if (proposed)
      append(
        summary,
        disclosure(
          change.state === "applied"
            ? "Food and destination agreed in this change"
            : "Food and destination this proposal asks you to confirm",
          el(
            "div",
            { className: "panel" },
            siteFacts(
              { site: proposed.destination },
              "Proposed receiving place",
            ),
            facts([
              ["Food", proposed.food.description],
              ["Holding", holdingLabel(proposed.food.holding)],
              [
                "Holding confirmed until",
                time(proposed.food.handling_until, proposed.pickup.time_zone),
              ],
              [
                "Contains",
                proposed.food.present_allergens.length
                  ? labels(proposed.food.present_allergens)
                  : "No confirmed-present labels",
              ],
              [
                "Checked and not present",
                checkedAbsent(proposed.food).length
                  ? labels(checkedAbsent(proposed.food))
                  : "No confirmed-absent labels",
              ],
              [
                "Receiving opens",
                time(
                  proposed.receiving.receiving_from,
                  proposed.destination.time_zone,
                ),
              ],
              [
                "Receiving closes",
                time(
                  proposed.receiving.receiving_until,
                  proposed.destination.time_zone,
                ),
              ],
            ]),
            el(
              "p",
              { className: "help" },
              "Anything outside the confirmed allergen lists remains unconfirmed.",
            ),
          ),
        ),
      );
    append(panel, summary);
    const reply = change.responses?.[role];
    const mayReply =
      (change.state === "awaiting_response" ||
        (change.state === "applied" && role === "collector")) &&
      ((change.required_parties || []).includes(role) ||
        (role === "collector" && record.collector_id === ctx.user.id)) &&
      reply?.status !== "agreed";
    if (mayReply) {
      const countSource = record.offer.stock_source_id;
      const fields = [
        field("Your response", {
          id: "change-answer",
          name: "answer",
          required: true,
          options: [
            ["", "Choose your response"],
            ["agree", "I can confirm this change"],
            ["decline", "I cannot confirm this change"],
          ],
        }),
      ];
      if (role === "recipient")
        fields.push(
          facts([
            [
              "Receiving opens",
              time(record.need.receiving_from, record.need.site?.time_zone),
            ],
            [
              "Receiving closes",
              time(record.need.receiving_until, record.need.site?.time_zone),
            ],
            [
              "Food already reserved across kitchens",
              boxCount(record.need.committed_quantity),
            ],
          ]),
          field("Our full need for this recorded receiving window", {
            id: "change-need-total",
            name: "need_total",
            type: "number",
            min: 0,
            max: 999999,
            value: record.need.requested_quantity,
            help: "Include food already accepted and all food still needed in this same window. Do not enter only the missing amount. Required when you agree.",
          }),
        );
      if (role === "kitchen")
        fields.push(
          notice(
            countSource
              ? "Agreement uses your latest saved physical stock count. Count every box still at the kitchen, including quarantined returns."
              : "Record a current physical stock count before agreeing. You can still say you cannot confirm this proposal.",
            "warning",
          ),
          link(
            "Open this food’s physical count",
            `/offers/${record.offer.id}`,
            "button secondary",
          ),
        );
      fields.push(
        field("Explain your response", {
          id: "change-response-note",
          name: "note",
          type: "textarea",
          required: true,
          maxLength: 2000,
        }),
      );
      append(
        panel,
        actionForm({
          title:
            role === "collector"
              ? "Acknowledge the proposed change"
              : role === "recipient"
                ? `Can your team confirm ${boxCount(change.new_quantity)}?`
                : "Confirm the kitchen’s actual count",
          description:
            role === "collector"
              ? "Your reply acknowledges the update. You must separately agree a new trip ticket if the instructions changed."
              : role === "recipient"
                ? "Confirm the revised collection and your full need for this receiving window. Include food reserved from every kitchen."
                : "Confirm only after counting what is physically still at your kitchen. A smaller promise does not return missing food.",
          submit: "Save my response",
          fields,
          onSubmit: (data, error) => {
            const agree = data?.get("answer") === "agree";
            if (
              data &&
              agree &&
              role === "recipient" &&
              !data.get("need_total")
            )
              throw new Error(
                "Enter your full receiving need, including food already accepted, before agreeing.",
              );
            if (data && agree && role === "kitchen" && !countSource)
              throw new Error(
                "Record a physical count at the kitchen before agreeing to release its commitment.",
              );
            return mutate(
              "respond_change",
              data && {
                change_id: change.id,
                revision: change.revision,
                agree,
                need_total:
                  agree && role === "recipient" ? data.get("need_total") : null,
                need_revision:
                  agree && role === "recipient" ? record.need.revision : null,
                stock_source_id:
                  agree && role === "kitchen" ? countSource : null,
                note: data.get("note"),
              },
              error,
              "Your response is recorded. Check whether all required partners have agreed; transport and physical outcomes remain separate.",
            );
          },
        }),
      );
    }
  }
  if (
    role === "coordinator" &&
    record.state !== "held" &&
    record.state !== "released" &&
    (!change || change.state !== "awaiting_response") &&
    Number(record.quantity) > 0
  ) {
    append(
      panel,
      disclosure(
        "Change the commitment or confirm new instructions",
        actionForm({
          title: "Ask partners to confirm this collection",
          description:
            "Use this when the promised amount cannot arrive, is no longer needed, or the food or destination instructions changed. The receiving team confirms its full current need. Any unhanded stock release also needs the kitchen’s actual count. Missing food stays missing until someone reports its physical outcome.",
          submit: "Request partner confirmation",
          fields: [
            field("New total commitment for this collection", {
              id: "change-new-quantity",
              name: "quantity",
              type: "number",
              min: record.received_quantity,
              max: record.quantity,
              required: true,
              help: `Current commitment: ${boxCount(record.quantity)}. Keep the same total to confirm changed instructions, or enter a smaller whole total including food already accepted. Use zero only when nothing was accepted and this entire commitment should end.`,
            }),
            field("What changed and what needs confirming?", {
              id: "change-reason",
              name: "reason",
              type: "textarea",
              required: true,
              maxLength: 500,
            }),
          ],
          onSubmit: (data, error) =>
            mutate(
              "request_change",
              data && {
                allocation_id: record.id,
                revision: record.revision,
                new_quantity: data.get("quantity"),
                reason: data.get("reason"),
              },
              error,
              "Change proposed. The current promise remains until the required partners confirm.",
            ),
        }),
      ),
    );
  }
  if (
    record.state === "held" &&
    (role === "coordinator" ||
      (role === "kitchen" && !recovery.redirect?.parent_allocation_id))
  )
    append(
      panel,
      disclosure(
        "Withdraw this unaccepted food invitation",
        actionForm({
          title: "Withdraw the invitation",
          description:
            "This releases only an invitation that has not been accepted. An accepted promise needs the receiving partner’s agreement.",
          submit: "Withdraw invitation",
          fields: [
            field("Reason for the receiving contact", {
              id: "withdraw-reason",
              name: "reason",
              type: "textarea",
              required: true,
              maxLength: 500,
            }),
          ],
          onSubmit: (data, error) =>
            mutate(
              "withdraw_invitation",
              data && {
                allocation_id: record.id,
                revision: record.revision,
                reason: data.get("reason"),
              },
              error,
              "The unaccepted invitation is withdrawn. No accepted collection was cancelled.",
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
