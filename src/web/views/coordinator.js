import { redirectContext } from "./redirect.js";
import { api } from "../api.js";
import { earliest } from "../time.js";
import {
  append,
  el,
  link,
  heading,
  empty,
  notice,
  tag,
  facts,
  time,
  boxCount,
  partnerName,
  holdingLabel,
  labels,
  checkedAbsent,
  custody,
} from "../render.js";
import { field, actionForm, confirm } from "../forms.js";
import { collectionState } from "./collections.js";

const workText = (item) => {
  const food = item.offer;
  const record = item.allocation;
  if (food && item.kind === "plan_offer")
    return [
      "New food needs a receiving plan",
      `${food.description} · ${boxCount(food.available_quantity)} unassigned`,
      `/offers/${food.id}/plan`,
    ];
  if (food && item.kind === "confirm_food_details")
    return [
      "Kitchen details need confirmation",
      `${food.description} · ask the kitchen about missing confirmed facts`,
      `/offers/${food.id}`,
    ];
  if (food)
    return [
      "Changed food count needs review",
      `${food.description} · kitchen stock and promises need review`,
      `/offers/${food.id}`,
    ];
  const captions = {
    expire_invitation: "Invitation reply window ended",
    assign_collector: "Reserved food needs a collector",
    confirm_collector: `${record.collector_name || "Assigned collector"} needs to confirm the trip`,
    review_change: "Collection change needs partner replies",
    resolve_destination:
      "Receiving point unavailable · carried food needs a destination",
    check_pickup: "Agreed pickup time passed",
    check_arrival: "Receiving count is overdue",
    resolve_receipt:
      record.state === "closed_unconfirmed"
        ? "Expected arrival closed · physical outcome still unknown"
        : record.state === "custody_review"
          ? "Physical reports do not yet match"
          : "Receiving outcome needs follow-up",
  };
  return [
    captions[item.kind] || "A collection needs review",
    `${partnerName(record.offer, "Kitchen")} to ${partnerName(record.need, "receiving partner")}`,
    `/allocations/${record.id}`,
  ];
};

export function worklist(ctx) {
  const items = ctx.items;
  const current =
    items.find(
      (item) =>
        `${item.kind}:${item.allocation?.id || item.offer?.id}` ===
        ctx.query.get("case"),
    ) || items[0];
  const page = el(
    "div",
    {
      className: ctx.query.has("case")
        ? "work-page work-case-open"
        : "work-page",
    },
    heading(
      "Keep food handoffs moving.",
      "Clear up changed facts, confirm who acts next and check what actually arrived.",
      "Coordinator work",
    ),
  );
  if (!items.length)
    return el(
      "div",
      {},
      page,
      empty(
        "No saved follow-up needs attention",
        "New offers and receiving needs still need review before invitations are sent. A clear worklist does not mean every food offer has been placed.",
        link("Review food offers", "/offers", "button"),
      ),
    );
  const queue = el(
    "div",
    { className: "worklist" },
    el("div", { className: "worklist-header" }, "Recorded follow-up"),
  );
  for (const item of items) {
    const [title, description] = workText(item);
    const key = `${item.kind}:${item.allocation?.id || item.offer?.id}`;
    append(
      queue,
      link(
        el(
          "div",
          {},
          el(
            "div",
            { className: "row-top" },
            tag(
              item.kind === "resolve_receipt" || item.kind === "review_stock"
                ? "Count needs review"
                : "Follow-up needed",
              "warning",
            ),
          ),
          el("h2", {}, title),
          el("p", {}, description),
        ),
        `/work?case=${encodeURIComponent(key)}`,
        "record-row",
      ),
    );
    if (item === current) queue.lastChild.setAttribute("aria-current", "page");
  }
  const [title, description, path] = workText(current);
  const record = current.allocation;
  const context = el(
    "article",
    { className: "work-context" },
    link("← Back to follow-up", "/work", "back-link work-back"),
    el("h2", {}, title),
    el("p", {}, description),
  );
  if (record) {
    const [state, tone] = collectionState(record);
    append(context, tag(state, tone));
    if (current.kind === "resolve_destination")
      append(context, redirectContext(ctx, record));
    if (
      ["receipt_issue", "custody_review", "closed_unconfirmed"].includes(
        record.state,
      )
    )
      append(context, custody(record));
    else
      append(
        context,
        facts([
          ["Food quantity", boxCount(record.quantity)],
          ["Collector", record.collector_name || "Not assigned"],
          ...(record.state === "held"
            ? [
                [
                  "Reply deadline",
                  time(record.hold_until, record.need.site?.time_zone),
                ],
              ]
            : []),
          [
            "Pickup agreed",
            record.transport_confirmed
              ? time(record.pickup_at, record.offer.site?.time_zone)
              : "Not confirmed",
          ],
        ]),
      );
    if (current.kind === "review_change" && record.recovery?.change) {
      const waiting = (record.recovery.change.required_parties || [])
        .filter(
          (party) =>
            record.recovery.change.responses?.[party]?.status === "awaiting",
        )
        .map((party) =>
          party === "recipient"
            ? record.need.contact_name || "Receiving contact"
            : record.offer.contact_name || "Kitchen contact",
        );
      if (waiting.length)
        append(
          context,
          notice(
            `Reply needed from ${waiting.join(" and ")}. The current promise stays recorded until the required partners confirm.`,
            "warning",
          ),
        );
    }
    if (record.note)
      append(
        context,
        el(
          "div",
          { className: "source" },
          el("strong", {}, "Recorded outcome note"),
          el("p", {}, record.note),
        ),
      );
  } else {
    const food = current.offer;
    append(
      context,
      facts([
        ["Originally declared", boxCount(food.declared_quantity)],
        [
          "Recorded lot total, including handed-over food",
          food.stock_projection?.review_required
            ? "Uncertain · physical history needs review"
            : boxCount(food.current_quantity),
        ],
        [
          "Held and reserved",
          boxCount(
            Number(food.held_quantity) + Number(food.committed_quantity),
          ),
        ],
        ["Already handed over", boxCount(food.collected_quantity)],
      ]),
      notice(
        current.kind === "plan_offer"
          ? "The coordinator needs to review current receiving needs and prepare invitations. A suggestion does not create a hold."
          : current.kind === "confirm_food_details"
            ? "The kitchen needs to confirm the missing food details before the coordinator can plan invitations."
            : "The changed count has paused new invitations and handoffs. Existing promises are still recorded.",
        current.kind === "plan_offer" ? "" : "warning",
      ),
    );
  }
  append(
    context,
    el(
      "p",
      { className: "next-owner" },
      "The coordinator owns this follow-up. A missing reply or passed time does not prove a physical outcome.",
    ),
    link("Open the saved case", path, "button"),
  );
  append(
    page,
    el("section", { className: "surface workbench" }, queue, context),
  );
  if (ctx.hasMore)
    append(
      page,
      notice(
        "More saved cases need follow-up. Open collections or food offers to inspect additional records.",
        "warning",
      ),
    );
  append(
    page,
    el(
      "p",
      { className: "help section-gap" },
      `Worklist checked ${time(ctx.generatedAt, "UTC")}. Collection windows use each site’s local time zone.`,
    ),
  );
  return page;
}

function reviewProposal(ctx, proposal, origin) {
  const offer = ctx.record;
  const changes = [];
  if (offer.state !== "open")
    changes.push(
      "Current food facts do not allow new invitations. This saved proposal remains visible, but cannot be sent.",
    );
  if (proposal.offer_revision !== offer.revision)
    changes.push(
      "The kitchen record has changed since this proposal. Prepare a fresh draft from the current food facts.",
    );
  for (const request of proposal.requests) {
    const need = ctx.needs.find((item) => item.id === request.need_id);
    if (!need)
      changes.push(
        "A receiving need in this proposal is no longer available for review.",
      );
    else if (Number(request.quantity) > Number(need.remaining_quantity))
      changes.push(
        `${partnerName(need, "This receiving partner")} now has room for ${boxCount(need.remaining_quantity)}; the proposal asks for ${request.quantity}. Prepare a smaller current draft.`,
      );
    else if (need.state !== "open" || request.need_revision !== need.revision)
      changes.push(
        `${partnerName(need, "This receiving partner")} changed or needs fresh confirmation. Review the current receiving facts before sending.`,
      );
  }
  if (
    proposal.requests.reduce(
      (total, request) => total + Number(request.quantity),
      0,
    ) > Number(offer.available_quantity)
  )
    changes.push(
      "The proposed total exceeds food currently unassigned. Prepare a new split.",
    );
  const choices = proposal.requests.map((request) => {
    const need = ctx.needs.find((item) => item.id === request.need_id);
    return el(
      "section",
      { className: "plan-choice" },
      el(
        "h3",
        {},
        partnerName(need || {}, `Receiving need ${request.need_id}`),
      ),
      facts([
        ["Invitation quantity", boxCount(request.quantity)],
        [
          "Current remaining need",
          need ? boxCount(need.remaining_quantity) : "Refresh receiving facts",
        ],
        [
          "Receiving window",
          need
            ? `${time(need.receiving_from, need.site?.time_zone)} to ${time(need.receiving_until, need.site?.time_zone)}`
            : "Not available",
        ],
      ]),
    );
  });
  return el(
    "section",
    { className: "surface panel review-panel" },
    tag(
      origin === "agent"
        ? "Saved planning suggestion"
        : "Your draft · not sent",
    ),
    el("h2", { className: "section-gap" }, "Review these food invitations"),
    el("p", { className: "intro" }, proposal.reason),
    choices,
    ctx.checkedAt &&
      el(
        "p",
        { className: "help" },
        `Checked against current records ${time(ctx.checkedAt, "UTC")}. No reservation was created.`,
      ),
    notice(
      "Sending creates temporary food holds and recipient invitations. It does not confirm acceptance, a collector or a trip.",
    ),
    actionForm({
      title: "Send after your review",
      blockedReason: changes.join(" "),
      expiresAt: earliest(
        offer.collect_by,
        offer.handling_until,
        ...proposal.requests.flatMap((request) => {
          const need = ctx.needs.find((item) => item.id === request.need_id);
          return [need?.confirmed_until, need?.receiving_until];
        }),
      ),
      now: ctx.now,
      description:
        "Current food stock and shared receiving need are checked again when the holds are saved.",
      submit: "Send these invitations",
      fields: [
        confirm(
          "I have reviewed the quantities, food requirements and receiving windows.",
        ),
      ],
      onSubmit: (_, error) =>
        ctx.mutate("apply_plan", proposal, error, {
          path: `/allocations?offer_id=${offer.id}`,
          message:
            "Invitations saved with temporary holds. Receiving partners still need to reply, and transport is not confirmed.",
        }),
    }),
  );
}

export function planPage(ctx) {
  const offer = ctx.record;
  const zone = offer.site?.time_zone;
  const main = el(
    "div",
    {},
    link("← Back to this food offer", `/offers/${offer.id}`, "back-link"),
    heading(
      offer.state === "open"
        ? "Choose receiving partners, then review."
        : "Review the saved planning result.",
      "A suggestion does not reserve food. You decide whether to send invitations from current confirmed records.",
      offer.description,
    ),
  );
  if (offer.state !== "open")
    append(
      main,
      notice(
        "New invitations are paused or the food window has ended. Saved planning results remain visible; the kitchen and coordinator must review current facts before a new invitation.",
        "warning",
      ),
    );
  let review = null;
  if (ctx.draftPlan) review = reviewProposal(ctx, ctx.draftPlan, "manual");
  else if (ctx.savedPlan?.state === "proposed" && ctx.savedPlan.proposal)
    review = reviewProposal(ctx, ctx.savedPlan.proposal, "agent");
  else if (ctx.savedPlan?.reason)
    append(main, notice(ctx.savedPlan.reason, "warning"));
  else if (ctx.savedPlan?.state === "failed")
    append(
      main,
      notice(
        ctx.savedPlan.error?.message ||
          "The earlier planning request did not produce a usable saved suggestion. Review the facts or prepare your own draft.",
        "warning",
      ),
    );
  const selections = ctx.needs.map((need) =>
    el(
      "section",
      { className: "plan-candidate" },
      el(
        "div",
        { className: "candidate-main" },
        el(
          "h3",
          {},
          link(
            partnerName(need, `Receiving need ${need.id}`),
            `/needs/${need.id}`,
          ),
        ),
        el(
          "p",
          { className: "help" },
          `Receive ${time(need.receiving_from, need.site?.time_zone)} to ${time(need.receiving_until, need.site?.time_zone)}`,
        ),
        el(
          "p",
          { className: "help" },
          `${need.accepted_holding.length ? need.accepted_holding.map(holdingLabel).join(", ") : "Holding not confirmed"} · ${need.excluded_allergens.length ? "Excludes " + labels(need.excluded_allergens) : "No allergens excluded by team"}`,
        ),
        el(
          "p",
          { className: "help" },
          `${need.requested_quantity} total need · ${need.held_quantity} held · ${need.committed_quantity} reserved`,
        ),
        need.state !== "open" && tag("Receiving facts need review", "warning"),
      ),
      el(
        "div",
        { className: "candidate-capacity" },
        el("strong", {}, need.remaining_quantity),
        el("span", {}, "boxes left to invite"),
      ),
      field("Meal boxes to invite", {
        id: `plan-${need.id}`,
        name: `need-${need.id}`,
        type: "number",
        min: 0,
        max: need.remaining_quantity,
        value: "0",
        disabled:
          Number(need.remaining_quantity) === 0 || need.state !== "open",
      }),
    ),
  );
  const manual = actionForm({
    title: "Make your own invitation draft",
    blockedReason:
      offer.state !== "open"
        ? "Current food facts must be confirmed before preparing a new invitation."
        : "",
    pendingText: "Checking the current kitchen and receiving records…",
    description:
      "Choose quantities from the shared need. Leave 0 for a partner you are not inviting. Current food and receiving facts are checked before the review opens.",
    submit: "Review this draft",
    fields: [
      selections,
      field("Why this split fits today", {
        id: "plan-reason",
        name: "reason",
        type: "textarea",
        maxLength: 500,
        required: true,
      }),
    ],
    onSubmit: async (data) => {
      const requests = ctx.needs
        .filter((need) => Number(data.get(`need-${need.id}`)) > 0)
        .map((need) => ({
          need_id: need.id,
          need_revision: need.revision,
          quantity: data.get(`need-${need.id}`),
          unit: "meal_box",
          evidence_ids: [...offer.source_ids, ...need.source_ids],
        }));
      if (!requests.length)
        throw new Error(
          "Choose a positive quantity for at least one receiving partner.",
        );
      if (
        requests.reduce((total, item) => total + Number(item.quantity), 0) >
        Number(offer.available_quantity)
      )
        throw new Error(
          "The draft exceeds the food currently unassigned. Reduce the requested quantities.",
        );
      const proposal = {
        offer_id: offer.id,
        offer_revision: offer.revision,
        reason: data.get("reason"),
        requests,
      };
      const checked = await api.checkPlan(proposal);
      ctx.reviewPlan(proposal, checked.checked_at);
    },
  });
  const assistant = el(
    "aside",
    {},
    el(
      "section",
      { className: "surface panel" },
      el("h2", {}, `${boxCount(offer.available_quantity)} unassigned`),
      facts([
        ["Holding", holdingLabel(offer.holding)],
        ["Collect before", time(offer.collect_by, zone)],
        [
          "Contains",
          offer.present_allergens.length
            ? labels(offer.present_allergens)
            : "No confirmed-present labels",
        ],
        [
          "Checked and not present",
          checkedAbsent(offer).length
            ? labels(checkedAbsent(offer))
            : "No confirmed-absent labels",
        ],
      ]),
    ),
    actionForm({
      title: "Ask for a suggested split",
      blockedReason:
        offer.state !== "open"
          ? "Current food facts must be confirmed before requesting another suggestion."
          : ctx.savedPlan?.state === "running"
            ? "An earlier planning request has not finished. Read its saved result before starting another."
            : Number(offer.available_quantity) === 0
              ? "No unassigned food remains for a new proposal."
              : "",
      expiresAt: earliest(offer.collect_by, offer.handling_until),
      now: ctx.now,
      pendingText: "Waiting for the saved planning result…",
      description:
        "Allfedo checks confirmed food and receiving records to suggest a split. It may return a specific question instead. You still review before sending.",
      submit: "Get a planning suggestion",
      fields: [],
      onSubmit: (_, error) =>
        ctx.mutate("plan_offer", { offer_id: offer.id }, error, {
          message:
            "Planning result saved. Review it before sending any invitation.",
        }),
    }),
    planEvidence(ctx.savedPlan),
  );
  append(
    main,
    el(
      "div",
      { className: "plan-grid section-gap" },
      review
        ? el(
            "div",
            {},
            review,
            el(
              "details",
              { className: "section-gap" },
              el("summary", {}, "Change the split or make another draft"),
              manual,
            ),
          )
        : manual,
      assistant,
    ),
  );
  return main;
}

function planEvidence(run) {
  if (!run) return null;
  const toolNames = {
    ReadOffer: "Read confirmed food details",
    ReadCurrentNeeds: "Read current receiving needs",
    ReadCollectionFacts: "Read saved collection agreements",
    ReadCaseEvidence: "Read a partner’s source confirmation",
    SubmitProposal: "Checked a proposed food split",
    RequestReview: "Asked the coordinator to review an issue",
  };
  const measures = (value, names) =>
    Object.entries(names)
      .filter(([key]) => Number.isFinite(value?.[key]) && value[key] >= 0)
      .map(([key, label]) => [label, String(value[key])]);
  const session = measures(run.usage?.session, {
    total_interactions: "Model interactions",
    total_prompt_tokens: "Input tokens across this run",
    total_completion_tokens: "Output tokens across this run",
    total_tool_calls: "Tool calls across this run",
    total_llm_duration_ms: "Measured model time in milliseconds",
  });
  const response = run.usage?.last_response;
  const final = measures(
    {
      input_tokens: Number.isFinite(response?.input_tokens)
        ? response.input_tokens
        : response?.prompt_tokens,
      output_tokens: Number.isFinite(response?.output_tokens)
        ? response.output_tokens
        : response?.completion_tokens,
      total_tokens: response?.total_tokens,
    },
    {
      input_tokens: "Input tokens in final response",
      output_tokens: "Output tokens in final response",
      total_tokens: "Total tokens in final response",
    },
  );
  return el(
    "details",
    { className: "section-gap" },
    el("summary", {}, "How this suggestion was made"),
    el(
      "div",
      { className: "panel" },
      facts([
        ["Configured model", run.model || "Not recorded"],
        ["Provider", run.provider || "Not recorded"],
        ["Connection", run.credential_source === "personal" ? "Personal key" : run.credential_source === "default" ? "Default connection" : "Not recorded"],
        ["Started", time(run.started_at, "UTC")],
        [
          "Finished",
          run.finished_at ? time(run.finished_at, "UTC") : "No finish recorded",
        ],
      ]),
      el("h3", {}, "Recorded actions"),
      run.tool_audit?.length
        ? el(
            "ol",
            { className: "audit-list" },
            run.tool_audit.map((call) =>
              el(
                "li",
                {},
                el(
                  "strong",
                  {},
                  toolNames[call.tool] || "Recorded case action",
                ),
                el("p", { className: "help" }, time(call.at, "UTC")),
                call.tool === "SubmitProposal" &&
                  call.outcome?.ok === false &&
                  notice(
                    "This proposal check did not pass. No invitation was sent.",
                    "warning",
                  ),
              ),
            ),
          )
        : el(
            "p",
            { className: "help" },
            "No tool calls were recorded for this result.",
          ),
      session.length || final.length
        ? el(
            "section",
            { className: "section-gap" },
            el("h3", {}, "Measured model use"),
            el(
              "p",
              { className: "help" },
              "Tokens are the text units reported by the model. These are measured counts, not cost estimates. Final-response counts are separate from totals for the whole run.",
            ),
            session.length ? facts(session) : null,
            final.length ? facts(final) : null,
          )
        : el(
            "p",
            { className: "help section-gap" },
            "Model-use measurements were not provided for this result.",
          ),
      el(
        "p",
        { className: "help section-gap" },
        "These recorded actions can read facts and propose a split. They cannot reserve food, agree a trip or confirm a physical handoff.",
      ),
    ),
  );
}

export function caseEvidence(ctx) {
  const section = el("section", {
    className: "section-gap",
    "aria-label": "Saved case evidence",
  });
  const eventNames = {
    offer_confirmed: "Kitchen food declaration",
    food_reconfirmed: "Kitchen details confirmed again",
    stock_observed: "Changed kitchen count",
    stock_counted: "Physical count at the kitchen",
    change_requested: "Collection change proposed",
    change_response: "Partner replied to a collection change",
    invitation_withdrawn: "Unaccepted invitation withdrawn",
    trip_reconfirmed: "Collector agreed updated trip instructions",
    record_disposition: "Known physical food outcome recorded",
    rejection_transferred: "Rejected food returned or disposed of",
    transfer_rejected: "Rejected food returned or disposed of",
    rejected_food_moved: "Rejected food follow-up recorded",
    receive_more: "Additional food accepted",
    custody_corrected: "Earlier physical report corrected",
    quarantine_disposed: "Kitchen recorded quarantine disposal",
    invitations_resumed: "Invitations resumed after review",
    destination_unavailable:
      "Collector confirmed a blocked destination and current food",
    redirect_invited: "Onward receiving invitation sent",
    redirect_accept: "Another receiving team accepted onward food",
    redirect_decline: "Onward invitation declined",
    redirect_confirmed: "Collector agreed onward destination and arrival",
    unavailable_released: "Kitchen-backed uncollected remainder released",
    need_confirmed: "Receiving need confirmed",
    need_reconfirmed: "Receiving need updated",
    invitation_held: "Invitation hold saved",
    accept: "Food reserved by receiving partner",
    decline: "Invitation declined",
    assign_collector: "Collector assigned",
    confirm_transport: "Collector confirmed the trip",
    handoff: "Kitchen handoff recorded",
    receive: "Receiving count recorded",
    expire_hold: "Expired hold released",
  };
  if (ctx.history?.length)
    append(
      section,
      el(
        "details",
        {},
        el("summary", {}, `Recorded changes (${ctx.history.length})`),
        el(
          "div",
          { className: "panel" },
          ctx.history.map((event) =>
            el(
              "div",
              { className: "source" },
              el(
                "strong",
                {},
                eventNames[event.kind] || "Recorded case update",
              ),
              el(
                "p",
                {},
                `${event.actor_name || "Partner"}${event.quantity !== undefined ? ` · ${boxCount(event.quantity)}` : ""}`,
              ),
              el(
                "time",
                { datetime: event.at },
                `Recorded ${time(event.at, "UTC")}`,
              ),
              event.note && el("p", {}, event.note),
              event.reason && el("p", {}, event.reason),
            ),
          ),
        ),
      ),
    );
  if (ctx.notifications?.length) {
    const names = {
      pending: "Email waiting to be sent",
      queued: "Email queued for sending",
      sent: "Mail server accepted the email",
      failed: "Email send needs follow-up",
      superseded: "Older email no longer needed",
    };
    append(
      section,
      el(
        "details",
        { className: "section-gap" },
        el("summary", {}, `Invitation emails (${ctx.notifications.length})`),
        el(
          "div",
          { className: "panel" },
          notice(
            "Mail-server acceptance does not confirm a person read the invitation or accepted food.",
          ),
          ctx.notifications.map((item) =>
            el(
              "div",
              { className: "source" },
              el(
                "strong",
                {},
                names[item.state] || "Email state needs checking",
              ),
              link(
                `Collection ${item.allocation_id}`,
                `/allocations/${item.allocation_id}`,
              ),
              el(
                "p",
                {},
                `${item.attempts} sending ${Number(item.attempts) === 1 ? "attempt" : "attempts"}`,
              ),
              item.sent_at
                ? el(
                    "time",
                    { datetime: item.sent_at },
                    `Mail server acknowledged ${time(item.sent_at, "UTC")}`,
                  )
                : ["pending", "queued"].includes(item.state) &&
                    item.due_at &&
                    el(
                      "time",
                      { datetime: item.due_at },
                      `Next recorded check ${time(item.due_at, "UTC")}`,
                    ),
            ),
          ),
        ),
      ),
    );
  }
  return section;
}
