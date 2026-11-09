/** Site-local clock readings are not device-local dates. Keep conversion and clock-change handling here. */
function parts(value, zone) {
  const values = new Intl.DateTimeFormat("en-CA", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(value));
  return Object.fromEntries(
    values
      .filter((item) => item.type !== "literal")
      .map((item) => [item.type, item.value]),
  );
}

export function localValue(value, zone) {
  if (!value || !zone || !Number.isFinite(new Date(value).getTime())) return "";
  try {
    const item = parts(value, zone);
    return `${item.year}-${item.month}-${item.day}T${item.hour}:${item.minute}`;
  } catch {
    return "";
  }
}

export function formatTime(value, zone, withDate = true) {
  if (!value) return "Not confirmed";
  if (!zone) return "Site time zone not recorded";
  try {
    return new Intl.DateTimeFormat(undefined, {
      timeZone: zone,
      ...(withDate ? { year: "numeric", month: "short", day: "numeric" } : {}),
      hour: "2-digit",
      minute: "2-digit",
      timeZoneName: "short",
    }).format(new Date(value));
  } catch {
    return "Time or site time zone unavailable";
  }
}

export function possibleInstants(local, zone) {
  if (!zone)
    throw new Error(
      "Record the site time zone before choosing a collection time.",
    );
  if (!/^\d{4}-\d\d-\d\dT\d\d:\d\d$/.test(local))
    throw new Error("Enter a complete date and time.");
  const nominal = Date.parse(`${local}:00Z`);
  if (
    !Number.isFinite(nominal) ||
    new Date(nominal).toISOString().slice(0, 16) !== local
  )
    throw new Error("Enter a valid date and time.");
  const offsets = new Set();
  for (const shift of [-86400000, 0, 86400000]) {
    const sample = nominal + shift;
    const p = parts(sample, zone);
    const sameClockUTC = Date.parse(
      `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}:00Z`,
    );
    offsets.add(sameClockUTC - sample);
  }
  return [...offsets]
    .map((offset) => new Date(nominal - offset).toISOString())
    .filter((instant) => localValue(instant, zone) === local)
    .sort();
}

export function readLocal(data, name, zone) {
  const options = possibleInstants(data.get(name), zone);
  if (!options.length)
    throw new Error(
      "That local time does not exist because the clocks change. Choose another local time.",
    );
  if (options.length === 1) return options[0];
  const selected = data.get(`${name}_instant`);
  if (!options.includes(selected))
    throw new Error(
      "That local time occurs twice because the clocks change. Choose which occurrence you mean.",
    );
  return selected;
}

export function earliest(...values) {
  const instants = values
    .filter(Boolean)
    .map((value) => new Date(value).getTime())
    .filter(Number.isFinite);
  return instants.length ? new Date(Math.min(...instants)).toISOString() : null;
}
