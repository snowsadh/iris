import { formatTime, possibleInstants, readLocal } from "./time.js";
/** Conditional children are omitted; real zero counts and source text remain visible. */
export function append(node, ...children) {
  for (const child of children.flat(Infinity)) {
    if (child !== null && child !== undefined && typeof child !== "boolean")
      node.append(child instanceof Node ? child : String(child));
  }
  return node;
}

/** Safe browser rendering and shared form behavior; record text never becomes HTML. */
export function el(tag, attributes = {}, ...children) {
  const node = document.createElement(tag);
  for (const [name, value] of Object.entries(attributes)) {
    if (value === undefined || value === null || value === false) continue;
    if (name.startsWith("on"))
      node.addEventListener(name.slice(2).toLowerCase(), value);
    else if (name === "className") node.className = value;
    else if (name === "value") node.value = value;
    else if (name === "checked" || name === "disabled" || name === "required")
      node[name] = value;
    else node.setAttribute(name, String(value));
  }
  append(node, ...children);
  return node;
}

export const link = (text, path, className = "") =>
  el("a", { href: `#${path}`, className }, text);
export const button = (text, attributes = {}) =>
  el("button", { type: "button", className: "button", ...attributes }, text);
export const heading = (title, description, eyebrow = "") =>
  el(
    "header",
    { className: "page-heading" },
    eyebrow && el("p", { className: "eyebrow" }, eyebrow),
    el("h1", { tabIndex: "-1" }, title),
    description && el("p", {}, description),
  );
export const notice = (text, tone = "") =>
  el(
    "div",
    {
      className: `notice ${tone}`,
      role: tone === "error" ? "alert" : "status",
    },
    text,
  );
export const empty = (title, text, action) =>
  el(
    "section",
    { className: "empty" },
    el("h2", {}, title),
    el("p", {}, text),
    action,
  );
export const tag = (text, tone = "") =>
  el("span", { className: `tag ${tone}` }, text);
export const boxCount = (value) =>
  `${value} meal ${Number(value) === 1 ? "box" : "boxes"}`;
export const holdingLabel = (value) =>
  ({
    chilled: "Chilled",
    hot: "Hot held",
    ambient: "Kept at room temperature",
  })[value] || "Not confirmed";
export const time = (value, zone, withDate = true) =>
  formatTime(value, zone, withDate);
export const labels = (value) =>
  value?.length ? value.join(", ") : "No labels recorded";
export function checkedAbsent(record) {
  const present = new Set(
    (record.present_allergens || []).map((label) => label.toLowerCase()),
  );
  return (record.assessed_allergens || []).filter(
    (label) => !present.has(label.toLowerCase()),
  );
}
export function facts(items) {
  return el(
    "dl",
    { className: "facts" },
    items.map(([label, value]) =>
      el("div", {}, el("dt", {}, label), el("dd", {}, value)),
    ),
  );
}
export function field(label, { help, options, type = "text", ...attributes }) {
  const input = options
    ? el(
        "select",
        attributes,
        options.map(([value, text]) => el("option", { value }, text)),
      )
    : el(
        type === "textarea" ? "textarea" : "input",
        type === "textarea" ? attributes : { type, ...attributes },
      );
  if (attributes.value !== undefined) input.value = attributes.value;
  const helpId = `${attributes.id}-help`;
  if (help) input.setAttribute("aria-describedby", helpId);
  return el(
    "div",
    { className: "field" },
    el("label", { for: attributes.id }, label),
    input,
    help && el("p", { id: helpId, className: "help" }, help),
  );
}
export function checklist(
  legend,
  name,
  choices,
  { required = false, help = "", selected = [] } = {},
) {
  const group = el(
    "fieldset",
    { className: "checklist" },
    el("legend", {}, legend),
  );
  for (const [value, text] of choices)
    append(
      group,
      el(
        "label",
        { className: "check" },
        el("input", {
          type: "checkbox",
          name,
          value,
          checked: selected.includes(value),
        }),
        text,
      ),
    );
  if (help) append(group, el("p", { className: "help" }, help));
  if (required) group.dataset.requireSelection = "1";
  return group;
}
export const confirm = (text) =>
  el(
    "label",
    { className: "check confirmation" },
    el("input", { type: "checkbox", required: true }),
    text,
  );
export function actionForm({
  title,
  description,
  submit,
  fields,
  onSubmit,
  pendingText = "Waiting for the saved result…",
  expiresAt = null,
  blockedReason = "",
  now = () => new Date().toISOString(),
}) {
  const status = el("div", { className: "form-status", "aria-live": "polite" });
  const send = button(submit, {
    type: "submit",
    disabled: Boolean(blockedReason),
  });
  if (blockedReason) append(status, notice(blockedReason, "warning"));
  const form = el(
    "form",
    { className: "action-form" },
    el("h2", {}, title),
    description && el("p", { className: "intro" }, description),
    fields,
    status,
    send,
  );
  form.addEventListener("input", () => {
    form.dataset.dirty = "1";
  });
  form.addEventListener("change", () => {
    form.dataset.dirty = "1";
  });
  const expire = () => {
    form.dataset.expired = "1";
    send.disabled = true;
    status.replaceChildren(
      notice(
        "The recorded window has ended. Read the current records before making a new agreement.",
        "warning",
      ),
    );
  };
  const timeLeft = () =>
    expiresAt
      ? new Date(expiresAt).getTime() - new Date(now()).getTime()
      : Infinity;
  if (expiresAt) {
    if (timeLeft() <= 0) expire();
    else
      setTimeout(
        () => {
          if (form.isConnected) expire();
        },
        Math.min(timeLeft() + 20, 2147483647),
      );
  }
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (form.dataset.stale) {
      status.replaceChildren(
        notice(
          "This case changed. Read the updated record before submitting.",
          "warning",
        ),
      );
      return;
    }
    if (blockedReason) {
      status.replaceChildren(notice(blockedReason, "warning"));
      return;
    }
    if (timeLeft() <= 0) {
      expire();
      return;
    }
    for (const group of form.querySelectorAll("[data-require-selection]")) {
      if (!group.querySelector("input:checked")) {
        status.replaceChildren(
          notice(
            "Choose at least one option for " +
              group.querySelector("legend").textContent.toLowerCase() +
              ".",
            "error",
          ),
        );
        return;
      }
    }
    if (form.dataset.submitting) return;
    form.dataset.submitting = "1";
    send.disabled = true;
    status.replaceChildren(notice(pendingText));
    try {
      await onSubmit(new FormData(form));
    } catch (error) {
      status.replaceChildren(notice(error.message, "error"));
      if (error.command) {
        form.dataset.uncertain = "1";
        for (const input of form.querySelectorAll("input,select,textarea"))
          input.disabled = true;
        append(
          status,
          notice(
            "The saved result is uncertain. Check it before changing this request.",
          ),
        );
        append(
          status,
          button("Check the saved result", {
            className: "button secondary",
            onClick: async () => {
              if (form.dataset.submitting) return;
              form.dataset.submitting = "1";
              send.disabled = true;
              try {
                await onSubmit(null, error);
              } catch (retryError) {
                status.prepend(notice(retryError.message, "error"));
                if (!retryError.command) {
                  delete form.dataset.uncertain;
                  for (const input of form.querySelectorAll(
                    "input,select,textarea",
                  ))
                    input.disabled = false;
                }
              } finally {
                delete form.dataset.submitting;
                send.disabled =
                  Boolean(blockedReason) ||
                  !!form.dataset.uncertain ||
                  !!form.dataset.expired ||
                  !!form.dataset.stale;
              }
            },
          }),
        );
      }
      if (!error.command && [409, 422].includes(error.status))
        append(
          status,
          button("Read the current record again", {
            className: "button secondary",
            onClick: () => location.reload(),
          }),
        );
      // A changed request is a new intention; an uncertain one keeps its recovery reference.
    } finally {
      delete form.dataset.submitting;
      send.disabled =
        Boolean(blockedReason) ||
        !!form.dataset.uncertain ||
        !!form.dataset.expired ||
        !!form.dataset.stale;
    }
  });
  return form;
}
export const allergens = [
  "milk",
  "egg",
  "fish",
  "shellfish",
  "peanut",
  "tree nuts",
  "wheat",
  "soy",
  "sesame",
  "celery",
  "mustard",
  "lupin",
  "sulphites",
].map((value) => [value, value[0].toUpperCase() + value.slice(1)]);
export const holding = [
  ["chilled", "Chilled"],
  ["hot", "Hot held"],
  ["ambient", "Room temperature"],
];
export function drawing(kind) {
  const namespace = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(namespace, "svg");
  svg.setAttribute("viewBox", "0 0 150 110");
  svg.setAttribute("aria-hidden", "true");
  const paths =
    kind === "unknown"
      ? [
          [
            "rect",
            {
              x: 25,
              y: 45,
              width: 38,
              height: 35,
              fill: "#fff3ee",
              "stroke-dasharray": "4 4",
            },
          ],
          [
            "rect",
            {
              x: 82,
              y: 45,
              width: 38,
              height: 35,
              fill: "#fff3ee",
              "stroke-dasharray": "4 4",
            },
          ],
          ["path", { d: "M69 22a7 7 0 1 1 10 6q-4 2-4 7m0 5v1" }],
        ]
      : [
          [
            "path",
            { d: "M13 88h55V36H13zM7 36h68l-9-16H16z", fill: "#f2e6ed" },
          ],
          ["path", { d: "M25 88V50h22v38M52 49h9v15h-9z" }],
          ["circle", { cx: 93, cy: 41, r: 8, fill: "#e8b89b" }],
          ["path", { d: "M93 53v27m0-18 15 10m-15 8-11 19m11-19 12 19" }],
          [
            "path",
            { d: "M111 64h29v28h-29zm14 0v28m-14-20h29", fill: "#edc99e" },
          ],
        ];
  for (const [tagName, attributes] of paths) {
    const path = document.createElementNS(namespace, tagName);
    for (const [name, value] of Object.entries({
      stroke: "currentColor",
      "stroke-width": 2.6,
      fill: "none",
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      ...attributes,
    }))
      path.setAttribute(name, value);
    append(svg, path);
  }
  return svg;
}
export function brand() {
  const namespace = "http://www.w3.org/2000/svg";
  const mark = document.createElementNS(namespace, "svg");
  mark.setAttribute("viewBox", "0 0 36 36");
  mark.setAttribute("aria-hidden", "true");
  const line = document.createElementNS(namespace, "path");
  for (const [name, value] of Object.entries({
    d: "m5 24 10-18h6l10 18M7 22c2.8 4 6.5 6 11 6s8.2-2 11-6M12 32h12",
    fill: "none",
    stroke: "currentColor",
    "stroke-width": 3.5,
    "stroke-linecap": "round",
    "stroke-linejoin": "round",
  }))
    line.setAttribute(name, value);
  append(mark, line);
  return el(
    "a",
    { className: "brand", href: "#/" },
    mark,
    el("div", {}, "Allfedo", el("small", {}, "Good food. Clear handoffs.")),
  );
}
export function custody(record) {
  if (record.recovery) return recoveryCustody(record);
  const received = ["received", "receipt_issue"].includes(record.state);
  const gap = Number(record.unresolved_quantity) > 0;
  const missingAtHandoff = Math.max(
    0,
    Number(record.quantity) - Number(record.collected_quantity),
  );
  const notAccepted = Math.max(
    0,
    Number(record.collected_quantity) - Number(record.received_quantity),
  );
  const differences = [];
  if (missingAtHandoff)
    differences.push(
      `${missingAtHandoff} ${missingAtHandoff === 1 ? "was" : "were"} not handed over.`,
    );
  if (notAccepted)
    differences.push(
      `${notAccepted} ${notAccepted === 1 ? "was" : "were"} handed over but not accepted.`,
    );
  const caption = received
    ? `${boxCount(record.quantity)} ${Number(record.quantity) === 1 ? "was" : "were"} reserved. ${gap ? differences.join(" ") + " The coordinator still needs to confirm these outcomes." : "The receiving count accounts for the full commitment."}`
    : "The kitchen handoff is recorded. The receiving contact still needs to count what actually arrived.";
  return el(
    "figure",
    { className: "custody" },
    el(
      "div",
      { className: "custody-flow" },
      el(
        "div",
        { className: "custody-stop" },
        drawing("handoff"),
        el("strong", {}, `${record.collected_quantity} collected`),
        el("span", {}, "Kitchen handoff recorded"),
      ),
      el(
        "div",
        { className: "custody-stop" },
        drawing(received ? "handoff" : "unknown"),
        el(
          "strong",
          {},
          received ? `${record.received_quantity} accepted` : "Receipt needed",
        ),
        el(
          "span",
          {},
          received ? "Receiving count recorded" : "No receiving count recorded",
        ),
      ),
      el(
        "div",
        { className: "custody-stop" },
        drawing(gap ? "unknown" : "handoff"),
        el(
          "strong",
          {},
          received
            ? gap
              ? `${record.unresolved_quantity} unresolved`
              : "Count matches"
            : gap
              ? `${record.unresolved_quantity} not handed over`
              : "Full handoff recorded",
        ),
        el(
          "span",
          {},
          received
            ? gap
              ? "Actual outcome still needs follow-up"
              : "Full commitment accounted for"
            : gap
              ? "Any short handoff stays open"
              : "Receiving count still needed",
        ),
      ),
    ),
    el("figcaption", {}, caption),
  );
}
function recoveryCustody(record) {
  const balance = record.recovery;
  const stages = [
    [
      "handoff",
      `${record.collected_quantity} handed over`,
      "Kitchen’s physical reports",
    ],
    [
      "handoff",
      `${record.received_quantity} accepted`,
      "Receiving team’s physical reports",
    ],
    [
      Number(balance.physical_unknown_quantity) ? "unknown" : "handoff",
      `${balance.physical_unknown_quantity} whereabouts unconfirmed`,
      "Changing a promise does not explain missing food",
    ],
  ];
  const known = [
    ["Lost", balance.lost_quantity],
    ["Discarded", balance.disposed_quantity],
    ["Rejected and kept at receiving site", balance.rejected_quantity],
    ["Returned to kitchen · quarantined", balance.returned_quantity],
    ["Still promised, not handed over", balance.unhanded_quantity],
    [
      "Known unable to arrive · recipient decision needed",
      balance.cannot_arrive_quantity,
    ],
    [
      "Physical reports needing a matching count",
      balance.unmatched_report_quantity,
    ],
  ].filter(([, quantity]) => Number(quantity) > 0);
  return el(
    "figure",
    { className: "custody" },
    el(
      "div",
      { className: "custody-flow" },
      stages.map(([image, count, caption]) =>
        el(
          "div",
          { className: "custody-stop" },
          drawing(image),
          el("strong", {}, count),
          el("span", {}, caption),
        ),
      ),
    ),
    known.length
      ? facts(known.map(([label, quantity]) => [label, boxCount(quantity)]))
      : null,
    el(
      "figcaption",
      {},
      `Current commitment: ${boxCount(record.quantity)}. `,
      balance.original_promise_quantity !== null
        ? `Originally promised: ${boxCount(balance.original_promise_quantity)}. `
        : "",
      Number(balance.closed_unknown_quantity) > 0
        ? `${boxCount(balance.closed_unknown_quantity)} no longer count as expected arrivals, but their physical whereabouts remain unconfirmed.`
        : "Known outcomes stay separate from food accepted by the receiving team.",
    ),
  );
}
export const partnerName = (record, fallback) =>
  record.site?.name || record.organization_name || fallback;
export function siteFacts(record, label) {
  const site = record.site;
  if (!site)
    return notice(
      `${label} address and access details have not been recorded. Ask the partner before travel.`,
      "warning",
    );
  return el(
    "section",
    {},
    el("h3", {}, label),
    facts([
      ["Place", site.name],
      ["Address", site.address],
      ["Entrance / access", site.entrance || "Not provided"],
      ["Contact", site.contact_name || "Partner contact"],
      ["Phone", site.contact_phone || "Not provided"],
    ]),
  );
}

export function dateTimeField(label, { zone, help, ...attributes }) {
  const repeated = el("div");
  const wrapper = field(label, {
    ...attributes,
    type: "datetime-local",
    help: `${help ? help + " " : ""}Local time at this site: ${zone}.`,
  });
  const input = wrapper.querySelector("input");
  const update = () => {
    repeated.replaceChildren();
    if (!input.value) return;
    let options;
    try {
      options = possibleInstants(input.value, zone);
    } catch {
      return;
    }
    if (options.length > 1)
      append(
        repeated,
        field("The clocks change here. Which occurrence?", {
          id: `${attributes.id}-occurrence`,
          name: `${attributes.name}_instant`,
          required: true,
          options: [
            ["", "Choose the intended time"],
            ...options.map((value) => [value, formatTime(value, zone)]),
          ],
        }),
      );
    else if (!options.length)
      append(
        repeated,
        notice(
          "That clock reading does not exist because the clocks change. Choose another time.",
          "error",
        ),
      );
  };
  input.addEventListener("input", update);
  append(wrapper, repeated);
  update();
  return wrapper;
}
/** A physical report defaults to now; a late report keeps the actual occurrence time. */
export function occurrenceFields(prefix, zone) {
  return el(
    "details",
    {},
    el("summary", {}, "Reporting later? Set when it happened"),
    el(
      "div",
      { className: "panel" },
      dateTimeField("Actual date and time", {
        id: `${prefix}-occurred`,
        name: "occurred",
        zone,
        help: "Leave blank only when this happened just now. This records a fact, not a future booking.",
      }),
    ),
  );
}
export function occurredAt(data, zone, now) {
  const value = data.get("occurred")
    ? readLocal(data, "occurred", zone)
    : now();
  if (new Date(value) > new Date(now()))
    throw new Error(
      "A physical report cannot happen in the future. Use the actual time, or record it after it happens.",
    );
  return value;
}

export function allergenFields(present = [], assessed = []) {
  const known = allergens.map(([label]) => label);
  return el(
    "div",
    {},
    checklist("Allergens confirmed present", "present", allergens, {
      selected: present,
    }),
    field("Other confirmed-present allergens", {
      id: "other-present",
      name: "other_present",
      value: present.filter((value) => !known.includes(value)).join(", "),
      help: "Use the kitchen’s exact labels, separated by commas. This list is not a complete allergen standard.",
    }),
    el(
      "details",
      {},
      el("summary", {}, "Record allergens you checked and found absent"),
      el(
        "div",
        { className: "panel" },
        checklist(
          "Allergens checked and confirmed absent",
          "absent",
          allergens,
          {
            selected: assessed.filter((value) => !present.includes(value)),
            help: "Leave an item unchecked when it has not been assessed. A blank is unknown, not a promise of absence.",
          },
        ),
        field("Other allergens checked and confirmed absent", {
          id: "other-absent",
          name: "other_absent",
          value: assessed
            .filter(
              (value) => !known.includes(value) && !present.includes(value),
            )
            .join(", "),
        }),
      ),
    ),
  );
}
export function readAllergens(data) {
  const split = (name) =>
    data
      .get(name)
      .split(",")
      .map((value) => value.trim().toLowerCase())
      .filter(Boolean);
  const present = [
    ...new Set([...data.getAll("present"), ...split("other_present")]),
  ];
  const absent = [
    ...new Set([...data.getAll("absent"), ...split("other_absent")]),
  ];
  if (present.some((value) => absent.includes(value)))
    throw new Error(
      "An allergen cannot be both present and confirmed absent. Check your selections.",
    );
  return {
    present_allergens: present,
    assessed_allergens: [...present, ...absent],
  };
}
