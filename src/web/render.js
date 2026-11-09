import { formatTime } from "./time.js";
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
  return el(
    "a",
    { className: "brand", href: "#/", "aria-label": "Allfedo home" },
    el("img", {
      src: "/allfedo/assets/wordmark.svg",
      alt: "Allfedo",
      width: 144,
      height: 35,
    }),
    el("small", {}, "Good food. Clear handoffs."),
  );
}
export function custody(record) {
  if (!record.recovery)
    return notice(
      "Physical report details are not available. Read the saved collection again before judging any difference.",
      "warning",
    );
  const balance = record.recovery;
  const stages = [
    [
      "handoff",
      Number(balance.redirect?.transferred_in_quantity) > 0
        ? `${balance.redirect.transferred_in_quantity} carried from a linked collection`
        : `${balance.kitchen_handoff_quantity ?? record.collected_quantity} handed over`,
      Number(balance.redirect?.transferred_in_quantity) > 0
        ? Number(balance.kitchen_handoff_quantity) > 0
          ? `${balance.kitchen_handoff_quantity} additional boxes reported from the kitchen`
          : "Custody transferred · no new kitchen pickup"
        : "Kitchen’s physical reports",
    ],
    [
      "handoff",
      `${record.received_quantity} accepted`,
      Number(balance.redirect?.transferred_out_quantity) > 0
        ? "Accepted on this original case"
        : balance.redirect?.parent_allocation_id
          ? "Accepted on this onward case"
          : "Receiving team’s physical reports",
    ],
    [
      Number(balance.physical_unknown_quantity) ? "unknown" : "handoff",
      Number(balance.physical_unknown_quantity) > 0
        ? balance.redirect?.issue || balance.redirect?.parent_allocation_id
          ? `${boxCount(balance.physical_unknown_quantity)} still need a receiving outcome`
          : `${boxCount(balance.physical_unknown_quantity)} not yet accounted for`
        : Number(balance.unmatched_report_quantity) > 0
          ? "Reported counts do not match"
          : "Handed-over food accounted for",
      Number(balance.physical_unknown_quantity) > 0
        ? balance.redirect?.issue || balance.redirect?.parent_allocation_id
          ? "The last collector report and each actual receiving count stay separate"
          : "A changed promise does not explain missing food"
        : Number(balance.unmatched_report_quantity) > 0
          ? "A physical report still needs a matching handoff"
          : "Accepted food and other known outcomes stay separate",
      Number(balance.physical_unknown_quantity) === 0 &&
        Number(balance.unmatched_report_quantity) === 0,
    ],
  ];
  const known = [
    [
      "Reassigned in linked collections",
      balance.redirect?.transferred_out_quantity,
    ],
    ["Held for onward replies", balance.redirect?.pending_quantity],
    ["Lost", balance.lost_quantity],
    ["Discarded", balance.disposed_quantity],
    ["Rejected and kept at receiving site", balance.rejected_quantity],
    ["Returned to kitchen", balance.returned_quantity],
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
      stages.map(([image, count, caption, resolved]) =>
        el(
          "div",
          { className: `custody-stop${resolved ? " resolved" : ""}` },
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
