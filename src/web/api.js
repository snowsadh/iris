/** Same-origin transport. IRIS owns identity, facts and every food commitment. */
export class RequestError extends Error {
  constructor(
    message,
    { code = "NETWORK_ERROR", status = 0, command = null } = {},
  ) {
    super(message);
    this.name = "RequestError";
    Object.assign(this, { code, status, command });
  }
}

let actorId = null;
let pending = [];
const storageKey = () => `allfedo:in-flight:${actorId}`;

function preservePending() {
  try {
    if (pending.length)
      sessionStorage.setItem(storageKey(), JSON.stringify(pending));
    else sessionStorage.removeItem(storageKey());
  } catch {
    throw new RequestError(
      "This browser could not keep a recovery reference. No new change was sent.",
      { code: "RECOVERY_UNAVAILABLE" },
    );
  }
}

function forget(command) {
  pending = pending.filter((item) => item.request_id !== command.request_id);
  // A successful server result remains successful even if clearing browser metadata fails.
  try {
    preservePending();
  } catch {
    /* Rechecking this saved request remains safe. */
  }
}

async function request(path, options = {}) {
  let response;
  try {
    response = await fetch(`/allfedo/api/${path}`, {
      credentials: "same-origin",
      cache: "no-store",
      ...options,
      headers: { Accept: "application/json", ...options.headers },
    });
  } catch {
    throw new RequestError(
      "Allfedo could not reach the server. Check your connection and try again.",
    );
  }
  let body;
  try {
    body = await response.json();
  } catch {
    throw new RequestError(
      "The server returned an unreadable response. Your latest saved records need to be checked.",
      { code: "UNREADABLE_RESPONSE", status: response.status },
    );
  }
  if (!response.ok || body.ok === false) {
    throw new RequestError(
      body.error?.message || "This request could not be completed.",
      { code: body.error?.code || "REQUEST_FAILED", status: response.status },
    );
  }
  return body;
}

async function send(command) {
  if (!actorId)
    throw new RequestError("Sign in before sending a change.", {
      code: "SIGN_IN_REQUIRED",
    });
  if (!pending.some((item) => item.request_id === command.request_id)) {
    pending.push({ ...command, started_at: new Date().toISOString() });
  }
  // Recovery metadata is saved before sending. It contains no session token or account password.
  preservePending();
  const { request_id, action, payload } = command;
  try {
    const result = await request("commands", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Allfedo-Request": "1" },
      body: JSON.stringify({ request_id, action, payload }),
    });
    forget(command);
    return result;
  } catch (error) {
    if (
      error instanceof RequestError &&
      (!error.status ||
        error.status >= 500 ||
        error.status === 401 ||
        ["BUSY", "AGENT_BUSY", "AGENT_NOT_SAVED"].includes(error.code) ||
        error.code === "UNREADABLE_RESPONSE")
    ) {
      error.command = { request_id, action, payload };
    } else {
      forget(command);
    }
    throw error;
  }
}

export const api = {
  session: () => request("session"),
  setActor(id) {
    actorId = id;
    try {
      const saved = JSON.parse(sessionStorage.getItem(storageKey()) || "[]");
      pending = Array.isArray(saved)
        ? saved
            .filter(
              (item) =>
                typeof item.request_id === "string" &&
                typeof item.action === "string" &&
                item.payload &&
                typeof item.payload === "object" &&
                !Array.isArray(item.payload),
            )
            .slice(0, 20)
        : [];
    } catch {
      pending = [];
    }
  },
  pending: () => pending.map((item) => ({ ...item })),
  list(resource, params = {}) {
    const query = new URLSearchParams(
      Object.entries(params).filter(
        ([, value]) => value !== undefined && value !== "",
      ),
    );
    return request(`${resource}${query.size ? `?${query}` : ""}`);
  },
  read: (resource, id) => request(`${resource}/${encodeURIComponent(id)}`),
  checkPlan(proposal) {
    return request("plan-check", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Allfedo-Request": "1" },
      body: JSON.stringify(proposal),
    });
  },
  async command(action, payload) {
    // Resolve the form's "just now" marker once. Retries keep this exact instant.
    if (payload.occurred_at === null)
      payload = { ...payload, occurred_at: (await request("session")).now };
    if (pending.length) {
      throw new RequestError(
        "An earlier change still needs its saved result checked. Use the recovery notice before sending another change.",
        { code: "PENDING_COMMAND" },
      );
    }
    return send({ request_id: crypto.randomUUID(), action, payload });
  },
  retry(error) {
    const command = pending.find(
      (item) => item.request_id === error.command?.request_id,
    );
    if (!command)
      throw new RequestError(
        "This recovery reference is not part of your signed-in session. Refresh the current record.",
      );
    return send(command);
  },
  async logout() {
    await request("logout", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Allfedo-Request": "1" },
      body: "{}",
    });
    pending = [];
    try {
      preservePending();
    } catch {
      /* Native session has already ended. */
    }
    actorId = null;
  },
};
