import { el, heading } from "../render.js";
import { field, actionForm, confirm } from "../forms.js";

export function sitePage(ctx) {
  const site = ctx.site;
  const receiving = ctx.user.role === "recipient";
  const zone =
    site?.time_zone || Intl.DateTimeFormat().resolvedOptions().timeZone;
  const zones = [
    ...new Set([
      "UTC",
      zone,
      ...(Intl.supportedValuesOf ? Intl.supportedValuesOf("timeZone") : []),
    ]),
  ].sort();
  return el(
    "section",
    { className: "entry-layout" },
    el(
      "aside",
      { className: "entry-context" },
      heading(
        receiving
          ? "Make the receiving place easy to find."
          : "Make the pickup place easy to find.",
        "Your team’s location, entrance and named contact travel with food collection agreements.",
        ctx.user.name,
      ),
      el(
        "p",
        {},
        "This is a confirmed partner record. Keep it current when your contact point or access details change.",
      ),
    ),
    actionForm({
      title: site ? "Your partner location" : "Set up your partner location",
      description:
        "Check the actual location and time zone. Device location is only a starting suggestion.",
      submit: "Save partner location",
      fields: [
        field("Kitchen or receiving site name", {
          id: "site-name",
          name: "name",
          value: site?.name || "",
          required: true,
          maxLength: 200,
        }),
        field("Street address", {
          id: "site-address",
          name: "address",
          type: "textarea",
          value: site?.address || "",
          required: true,
          maxLength: 500,
        }),
        field("Entrance and access instructions", {
          id: "site-entrance",
          name: "entrance",
          value: site?.entrance || "",
          maxLength: 500,
          help: "For example: service entrance, loading door or reception desk.",
        }),
        field("Location time zone", {
          id: "site-time-zone",
          name: "time_zone",
          list: "site-time-zones",
          value: zone,
          required: true,
          help: "Search for the location’s city, such as London or New York. Collection times follow that city’s clock, even on a device elsewhere.",
        }),
        el(
          "datalist",
          { id: "site-time-zones" },
          zones.map((value) =>
            el("option", {
              value,
              label: value.replaceAll("_", " ").replace("/", " — "),
            }),
          ),
        ),
        field("Contact phone", {
          id: "site-phone",
          name: "contact_phone",
          type: "tel",
          value: site?.contact_phone || "",
          maxLength: 80,
        }),
        el(
          "p",
          { className: "help" },
          `Contact name comes from your signed-in account: ${ctx.user.name}.`,
        ),
        confirm("I confirm these are the correct location and access details."),
      ],
      onSubmit: (data, error) =>
        ctx.mutate(
          "save_site",
          data && {
            revision: site?.revision || 0,
            name: data.get("name"),
            address: data.get("address"),
            entrance: data.get("entrance"),
            time_zone: data.get("time_zone"),
            contact_phone: data.get("contact_phone"),
          },
          error,
          {
            path: receiving ? "/needs" : "/offers",
            message: "Your partner location is saved.",
          },
        ),
    }),
  );
}
