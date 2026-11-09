/** Shared form input and save/retry behavior. Business rules remain on the native server. */
import { el, append, button, notice } from "./render.js";
import { formatTime, possibleInstants, readLocal } from "./time.js";

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
  physicalReport = false,
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
    {
      className: "action-form",
      "data-physical-report": physicalReport ? "1" : null,
    },
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
    if (form.dataset.stale && !physicalReport) {
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
                  (!physicalReport && !!form.dataset.stale);
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
        (!physicalReport && !!form.dataset.stale);
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
export function occurredAt(data, zone, now, original = null) {
  // The transport resolves "just now" from a fresh server reading before saving
  // the retry reference. An estimated browser clock can predate a new agreement.
  if (!data.get("occurred")) return null;
  const value = readLocal(data, "occurred", zone, original);
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
