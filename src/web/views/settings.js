import { el, heading, facts, notice } from "../render.js";
import { actionForm, field } from "../forms.js";
import { formatTime } from "../time.js";

export function settingsPage(ctx) {
  const { source, providers, personal, default: defaults } = ctx.settings;
  const names = Object.fromEntries(providers.map(provider => [provider.id, provider.name]));
  const current = personal || defaults;
  const providerField = field("Provider", {
    id: "ai-provider", name: "provider", value: current.provider,
    options: providers.map(provider => [provider.id, provider.name]),
  });
  const modelField = field("Model", {
    id: "ai-model", name: "model", value: current.model,
    required: true, maxLength: 150, autocomplete: "off",
    help: "Use a model available to your account that supports tool calls. You can change the suggested model ID.",
  });
  providerField.querySelector("select").addEventListener("change", (event) => {
    modelField.querySelector("input").value = providers.find(provider => provider.id === event.target.value).model;
  });

  const ownKey = actionForm({
    title: personal ? "Your personal connection" : "Add your own connection",
    description: "Requests use your provider account. Your key stays in the server's secure wallet and is never shown again. It expires after one hour, or is removed when you sign out.",
    submit: personal ? "Replace my connection" : "Use my key",
    fields: [
      providerField,
      modelField,
      field("API key", {
        id: "ai-key", name: "api_key", type: "password", required: true,
        maxLength: 2000, autocomplete: "off",
        help: "The key is checked by your provider when you request a plan. Saving it does not make a model call.",
      }),
    ],
    onSubmit: async (data) => {
      await ctx.saveAISettings({ provider: data.get("provider"), model: data.get("model"), api_key: data.get("api_key") });
      ownKey.reset();
    },
  });

  return el("section", { className: "entry-layout" },
    el("aside", { className: "entry-context" },
      heading("Planning AI", "Use the default connection, or choose your own provider for this browser session.", "Settings"),
      el("p", {}, "This changes how planning suggestions are made. Food checks, permissions and the separate send step stay the same."),
    ),
    el("div", {},
      el("section", { className: "panel" },
        el("h2", {}, source === "personal" ? "Using your key" : source === "expired" ? "Your personal connection expired" : "Default connection"),
        source === "expired"
          ? notice("Enter your key again, or explicitly choose the default connection. An expired personal key never silently switches to the workspace key.", "warning")
          : null,
        personal ? facts([
          ["Provider", names[personal.provider]], ["Model", personal.model],
          ["Expires", formatTime(personal.expires_at, "UTC")],
        ]) : facts([
          [source === "expired" ? "Default provider" : "Provider", names[defaults.provider]],
          [source === "expired" ? "Default model" : "Model", defaults.model],
        ]),
        defaults.available
          ? el("p", { className: "help section-gap" }, "The default connection is provided by this workspace. No personal key is needed; a daily allowance applies.")
          : notice("No default key is configured. Add your own key below to use AI planning. Checked manual planning is still available.", "warning"),
        source !== "default" ? actionForm({
          title: "Remove my personal key", fields: [],
          submit: defaults.available ? "Use default AI" : "Remove my key",
          onSubmit: () => ctx.saveAISettings({}),
        }) : null,
      ),
      el("details", { className: "section-gap", open: source !== "default" },
        el("summary", {}, "Use my own API key"), ownKey,
      ),
    ),
  );
}
