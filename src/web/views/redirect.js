/** Food already carried by a collector: report a blocked destination, invite another team, agree the onward trip. */
import {
  append,
  el,
  link,
  heading,
  tag,
  notice,
  facts,
  boxCount,
  time,
  holdingLabel,
  labels,
  checkedAbsent,
  partnerName,
  siteFacts,
} from "../render.js";
import { field, actionForm, confirm, dateTimeField } from "../forms.js";
import { readLocal, earliest } from "../time.js";

export function redirectContext(ctx, record) {
  const onward = record.recovery?.redirect;
  if (!onward) return null;
  const section = el("section", { className: "redirect-context" });
  if (onward.parent_allocation_id) {
    append(
      section,
      tag(
        record.state === "held"
          ? "Invitation from already-collected food"
          : "Transferred from the original collection",
      ),
      el(
        "p",
        { className: "next-owner" },
        record.state === "held"
          ? `This invitation offers ${boxCount(record.quantity)} from food already collected by ${record.collector_name || "the assigned collector"}. Acceptance checks the current food before reserving your amount.`
          : `${boxCount(onward.transferred_in_quantity)} were assigned here from an existing collection. The kitchen remains the food origin.`,
      ),
    );
    if (onward.parent_readable)
      append(
        section,
        link(
          "Open the original collection",
          `/allocations/${onward.parent_allocation_id}`,
          "back-link section-gap",
        ),
      );
  }
  if (onward.issue) {
    const issue = onward.issue;
    const report = el(
      "div",
      { className: "source section-gap" },
      el(
        "strong",
        {},
        `${issue.actor_name || record.collector_name || "The assigned collector"} reported a blocked receiving point`,
      ),
      facts([
        [
          "Boxes confirmed in custody at that time",
          boxCount(issue.quantity_in_custody),
        ],
        ...(issue.current_location
          ? [["Collector’s reported location", issue.current_location]]
          : []),
        [
          "Holding conditions maintained",
          onward.handling_break_reported
            ? "Earlier break or unknown condition recorded · onward invitations blocked"
            : issue.handling_maintained
              ? "Collector confirmed"
              : "Not confirmed · no onward invitation",
        ],
        [
          "Confirmed at",
          time(issue.confirmed_at, record.offer.site?.time_zone),
        ],
      ]),
      issue.note && el("p", {}, issue.note),
      el(
        "p",
        { className: "help" },
        "This is a dated report. Onward invitations and confirmed arrivals are recorded separately.",
      ),
    );
    append(
      section,
      record.state === "redirected"
        ? el(
            "details",
            { className: "section-gap" },
            el("summary", {}, "Collector’s earlier food and location report"),
            el("div", { className: "panel" }, report),
          )
        : report,
    );
    if (ctx.user.role === "collector" && record.state !== "redirected")
      append(
        section,
        notice(
          Number(onward.pending_quantity) > 0
            ? "Next owner: the invited receiving team. After they accept, you must agree the onward arrival."
            : "Next owner: the coordinator. They need to invite another receiving team from the current food report.",
        ),
      );
  }
  if (
    Number(onward.transferred_out_quantity) > 0 ||
    Number(onward.pending_quantity) > 0
  )
    append(
      section,
      facts([
        [
          "Assigned to accepted onward collections",
          boxCount(onward.transferred_out_quantity),
        ],
        ["Held for onward replies", boxCount(onward.pending_quantity)],
      ]),
    );
  if (onward.children?.length)
    append(
      section,
      el(
        "div",
        { className: "section-gap" },
        onward.children.map((child) =>
          el(
            "p",
            {},
            child.can_open
              ? link(
                  `Onward collection · ${boxCount(child.quantity)}`,
                  `/allocations/${child.id}`,
                )
              : `${boxCount(child.quantity)} in an onward collection`,
            ` · ${{ held: "waiting for the receiving team’s reply", received: "receiving count confirmed", collected: "carried onward · receiving count needed", released: "invitation ended", partial_closed: "revised commitment closed · see its outcomes", destination_issue: "another receiving point needed", redirected: "continues in linked collections" }[child.state] || "check its current agreement and receiving count"}`,
          ),
        ),
      ),
    );
  return section.childNodes.length ? section : null;
}

export function redirectActions(ctx, record) {
  const onward = record.recovery?.redirect;
  if (!onward) return null;
  const role = ctx.user.role;
  const identifier = { allocation_id: record.id, revision: record.revision };
  const panel = el("section");
  if (
    role === "collector" &&
    record.collector_id === ctx.user.id &&
    Number(record.recovery.physical_unknown_quantity) > 0
  )
    append(
      panel,
      el(
        "details",
        {
          className: "section-gap",
          ...(!onward.issue && record.state === "destination_issue"
            ? { open: true }
            : {}),
        },
        el(
          "summary",
          {},
          onward.issue
            ? "Update your current food and location report"
            : "Receiving point unavailable? Report the food still with you",
        ),
        actionForm({
          title: "Where is the food now?",
          description:
            "Confirm only the boxes from this collection that you still physically carry. The coordinator can review another receiving point; a report does not send the food there.",
          submit: "Save current food and location report",
          fields: [
            field("Meal boxes from this collection still with me", {
              id: "destination-custody",
              name: "quantity",
              type: "number",
              min: 0,
              max: 999999,
              required: true,
            }),
            field("Where are you now?", {
              id: "destination-location",
              name: "location",
              required: true,
              maxLength: 1000,
              help: "Give a clear street address or named stopping point. Do not enter an intended destination.",
            }),
            field(
              "Have the recorded food holding conditions been maintained?",
              {
                id: "destination-handling",
                name: "handling",
                required: true,
                options: [
                  ["", "Choose what you can confirm"],
                  ["yes", `Yes · ${holdingLabel(record.offer.holding)}`],
                  ["unknown", "I cannot confirm this"],
                  ["no", "No"],
                ],
                help: "A no or unknown answer blocks onward invitations for this food, including after a later report says yes. Always record what you actually know.",
              },
            ),
            field("What stopped the handoff?", {
              id: "destination-note",
              name: "note",
              type: "textarea",
              required: true,
              maxLength: 2000,
              help: "For example: no receiving contact at the agreed door after calling the site.",
            }),
            confirm(
              "This is my current count and location. I have not handed these boxes to the receiving team.",
            ),
          ],
          onSubmit: (data, error) =>
            ctx.mutate(
              "record_destination_issue",
              data && {
                ...identifier,
                quantity_in_custody: data.get("quantity"),
                current_location: data.get("location"),
                handling_maintained: data.get("handling") === "yes",
                note: data.get("note"),
              },
              error,
              {
                message:
                  "Current food, location and handling report saved. The coordinator needs to review the next receiving point.",
              },
            ),
        }),
      ),
    );
  if (role === "coordinator" && onward.issue && record.state !== "redirected") {
    append(
      panel,
      onward.issue.handling_maintained &&
        !onward.handling_break_reported &&
        Number(onward.available_quantity) > 0
        ? link(
            "Find another receiving point",
            `/allocations/${record.id}/redirect`,
            "button section-gap",
          )
        : notice(
            onward.handling_break_reported
              ? "A recorded break or unknown food holding condition blocks onward invitations. A newer report does not clear that history. Record any actual return or disposal instead."
              : !onward.issue.handling_maintained
                ? "The collector could not confirm the food holding conditions. Do not invite another receiving team from this report."
                : "No carried food is currently available for another onward invitation. Check pending replies and linked collections.",
            "warning",
          ),
    );
  }
  if (
    role === "coordinator" &&
    onward.issue &&
    Number(record.recovery.unhanded_quantity) > 0
  ) {
    const stock = record.offer.stock_source_id;
    append(
      panel,
      el(
        "details",
        { className: "section-gap" },
        el("summary", {}, "Release a remainder that never left the kitchen"),
        stock
          ? actionForm({
              title: "Release only the uncollected promise",
              description: `The kitchen’s latest actual count must support this release. ${boxCount(record.recovery.unhanded_quantity)} are still promised but have not been handed over. The old receiving need will require fresh confirmation.`,
              submit: "Release uncollected remainder",
              fields: [
                field("Unhanded meal boxes to release", {
                  id: "unavailable-release",
                  name: "quantity",
                  type: "number",
                  min: 1,
                  max: record.recovery.unhanded_quantity,
                  required: true,
                }),
                field("Why is this promise being released?", {
                  id: "unavailable-reason",
                  name: "reason",
                  type: "textarea",
                  required: true,
                  maxLength: 500,
                }),
                confirm(
                  "I reviewed the kitchen’s actual count. This release does not return carried food to the kitchen.",
                ),
              ],
              onSubmit: (data, error) =>
                ctx.mutate(
                  "release_unavailable",
                  data && {
                    ...identifier,
                    stock_source_id: stock,
                    quantity: data.get("quantity"),
                    reason: data.get("reason"),
                  },
                  error,
                  {
                    message:
                      "Uncollected promise released from the kitchen’s actual count. The old receiving need requires a fresh confirmation.",
                  },
                ),
            })
          : el(
              "div",
              { className: "panel" },
              notice(
                "The kitchen must record its actual current count before this remainder can be released.",
                "warning",
              ),
              link(
                "Open the kitchen food record",
                `/offers/${record.offer.id}`,
                "button secondary section-gap",
              ),
            ),
      ),
    );
  }
  const inTransit = Boolean(onward.parent_allocation_id);
  if (
    inTransit &&
    role === "collector" &&
    record.collector_id === ctx.user.id &&
    record.state !== "held" &&
    record.recovery.trip_needs_confirmation &&
    Number(record.recovery.physical_unknown_quantity) > 0
  ) {
    const context = record.recovery.current_context;
    const agreement = actionForm({
      title: "Agree the onward destination and arrival",
      blockedReason: onward.handling_break_reported
        ? "A recorded break or unknown holding condition blocks an onward delivery agreement. Record the actual return or disposal instead."
        : record.recovery.recipient_needs_confirmation
          ? "The receiving team must confirm changed food or receiving instructions first. Ask the coordinator to request that confirmation."
          : record.need.state !== "open"
            ? "This receiving window is paused or unconfirmed. The coordinator must review the next destination before you agree to arrive."
            : "",
      description:
        "This food is already with you. Check the receiving entrance, remaining load and holding deadline before agreeing the changed trip.",
      submit: "Confirm onward destination and arrival",
      expiresAt: earliest(
        context.details.food.handling_until,
        context.details.receiving.receiving_until,
        record.need.confirmed_until,
      ),
      now: ctx.now,
      fields: [
        siteFacts({ site: context.details.destination }, "New receiving place"),
        facts([
          [
            "Food already assigned to this destination",
            boxCount(record.quantity),
          ],
          [
            "Receiving opens",
            time(
              context.details.receiving.receiving_from,
              context.details.destination.time_zone,
            ),
          ],
          [
            "Receiving closes",
            time(
              context.details.receiving.receiving_until,
              context.details.destination.time_zone,
            ),
          ],
          [
            "Food holding confirmed until",
            time(
              context.details.food.handling_until,
              context.details.pickup.time_zone,
            ),
          ],
          [
            "Kitchen’s lot packing · check the carried portion",
            context.details.food.packaging,
          ],
        ]),
        dateTimeField("I will arrive by", {
          id: "redirect-arrival",
          name: "arrival",
          zone: context.details.destination.time_zone,
          required: true,
        }),
        facts([
          [
            "All food still carried across linked collections",
            boxCount(onward.required_capacity_quantity),
          ],
        ]),
        field("Capacity for all linked food still with me", {
          id: "redirect-capacity",
          name: "capacity",
          type: "number",
          min: onward.required_capacity_quantity,
          help: "Include this onward collection and food still carried for the linked original or other receiving teams. This is the whole carried load, not just this destination’s amount.",
          max: 999999,
          required: true,
        }),
        el(
          "label",
          { className: "check confirmation" },
          el("input", { type: "checkbox", name: "handling", required: true }),
          "I checked the new destination and can maintain the recorded food holding conditions until arrival.",
        ),
      ],
      onSubmit: (data, error) =>
        ctx.mutate(
          "confirm_redirect",
          data && {
            ...identifier,
            context_key: context.context_key,
            arrival_by: readLocal(
              data,
              "arrival",
              context.details.destination.time_zone,
            ),
            capacity: data.get("capacity"),
            handling_accepted: data.has("handling"),
          },
          error,
          {
            message:
              "Onward destination and arrival agreed. The receiving contact still records what is physically accepted.",
          },
        ),
    });
    panel.prepend(agreement);
  }
  return panel.childNodes.length ? panel : null;
}

export function redirectPage(ctx) {
  const record = ctx.record;
  const onward = record.recovery?.redirect;
  const main = el(
    "div",
    {},
    link("← Back to this collection", `/allocations/${record.id}`, "back-link"),
    heading(
      "Find another receiving point.",
      "Invite a known team for food already with the collector. Their acceptance and the collector’s new arrival agreement remain separate.",
      record.offer.description,
    ),
  );
  if (
    !onward?.issue ||
    !onward.issue.handling_maintained ||
    onward.handling_break_reported ||
    Number(onward.available_quantity) <= 0
  )
    return el(
      "div",
      {},
      main,
      notice(
        "This case has no confirmed carried food available for another invitation. Review the collector’s current report and any pending onward replies.",
        "warning",
      ),
    );
  append(main, redirectContext(ctx, record));
  const current = ctx.needs.filter(
    (need) =>
      need.organization_id !== record.need.organization_id &&
      need.state === "open" &&
      Number(need.remaining_quantity) > 0,
  );
  const chosen = current.find((need) => need.id === ctx.query.get("need"));
  if (!chosen) {
    append(
      main,
      el(
        "section",
        { className: "surface panel section-gap" },
        el("h2", {}, "Current known receiving windows"),
        el(
          "p",
          { className: "help" },
          "The invitation checks food requirements, current shared capacity and deadlines before it is saved. A listed need is not a confirmed trip.",
        ),
        current.length
          ? el(
              "div",
              { className: "list" },
              current.map((need) =>
                link(
                  el(
                    "div",
                    {},
                    el("h3", {}, partnerName(need, "Receiving team")),
                    el(
                      "p",
                      {},
                      `${boxCount(need.remaining_quantity)} still needed · ${need.contact_name || "Receiving contact"}`,
                    ),
                    el(
                      "p",
                      { className: "help" },
                      `${time(need.receiving_from, need.site?.time_zone)} to ${time(need.receiving_until, need.site?.time_zone)}`,
                    ),
                    el(
                      "p",
                      { className: "help" },
                      need.accepted_holding.map(holdingLabel).join(", "),
                    ),
                  ),
                  `/allocations/${record.id}/redirect?need=${need.id}`,
                  "record-row",
                ),
              ),
            )
          : notice(
              "No other current receiving window has recorded remaining capacity. A receiving partner must confirm a real need before it can be invited.",
              "warning",
            ),
      ),
    );
    return main;
  }
  append(
    main,
    link(
      "← Choose a different receiving team",
      `/allocations/${record.id}/redirect`,
      "back-link section-gap",
    ),
    el(
      "div",
      { className: "detail-layout section-gap" },
      el(
        "section",
        { className: "surface detail-main" },
        tag("Review the onward invitation"),
        el(
          "h2",
          { className: "section-gap" },
          partnerName(chosen, "Receiving team"),
        ),
        siteFacts(chosen, "Receiving place"),
        facts([
          ["Current remaining need", boxCount(chosen.remaining_quantity)],
          ["Food holding", holdingLabel(record.offer.holding)],
          [
            "This team can handle",
            chosen.accepted_holding.map(holdingLabel).join(", ") ||
              "Not confirmed",
          ],
          [
            "This team excludes",
            chosen.excluded_allergens.length
              ? labels(chosen.excluded_allergens)
              : "None excluded by the team",
          ],
          [
            "Food contains",
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
            "Carried food available for a new invitation",
            boxCount(onward.available_quantity),
          ],
          [
            "Receiving opens",
            time(chosen.receiving_from, chosen.site?.time_zone),
          ],
          [
            "Receiving closes",
            time(chosen.receiving_until, chosen.site?.time_zone),
          ],
          [
            "Food holding confirmed until",
            time(record.offer.handling_until, record.offer.site?.time_zone),
          ],
        ]),
      ),
      actionForm({
        title: "Invite this team to receive carried food",
        description:
          "Sending holds an amount for this team’s reply. It does not say they accepted or that the collector agreed the new destination.",
        submit: "Send onward food invitation",
        expiresAt: earliest(
          record.offer.handling_until,
          chosen.receiving_until,
          chosen.confirmed_until,
        ),
        now: ctx.now,
        fields: [
          field("Meal boxes to invite", {
            id: "redirect-quantity",
            name: "quantity",
            type: "number",
            min: 1,
            max: Math.min(
              Number(onward.available_quantity),
              Number(chosen.remaining_quantity),
            ),
            required: true,
          }),
          field("Why this receiving point?", {
            id: "redirect-reason",
            name: "reason",
            type: "textarea",
            required: true,
            maxLength: 500,
          }),
          confirm(
            "I reviewed this team’s food requirements and receiving window. The collector must still confirm the onward trip.",
          ),
        ],
        onSubmit: (data, error) =>
          ctx.mutate(
            "redirect",
            data && {
              allocation_id: record.id,
              revision: record.revision,
              target_need_id: chosen.id,
              target_need_revision: chosen.revision,
              quantity: data.get("quantity"),
              reason: data.get("reason"),
            },
            error,
            {
              message:
                "Onward invitation saved. The receiving team must reply, then the collector must agree the new destination and arrival.",
              path: (result) => `/allocations/${result.child_allocation_id}`,
            },
          ),
      }),
    ),
  );
  return main;
}
