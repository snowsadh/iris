import { api, RequestError } from "./api.js";
import {
  append,
  el,
  link,
  button,
  brand,
  heading,
  empty,
  notice,
} from "./render.js";
import { sitePage } from "./views/site.js";
import { offerList, offerEntry, offerDetail } from "./views/kitchen.js";
import { needList, needEntry, needDetail } from "./views/receiving.js";
import { collectionList, collectionDetail } from "./views/collections.js";
import { worklist, planPage, caseEvidence } from "./views/coordinator.js";

const root = document.getElementById("app");
let user;
let site;
let generation = 0;
let flash = "";
let draftPlan = null;
let draftOfferId = null;
let draftCheckedAt = null;
let activeRead = null;
let checkingUpdates = false;
let serverTime = Date.now();
let serverClockRead = performance.now();
const now = () =>
  new Date(serverTime + performance.now() - serverClockRead).toISOString();
const roles = {
  kitchen: "Kitchen contact",
  recipient: "Receiving contact",
  collector: "Collector",
  coordinator: "Coordinator",
};
const defaultPath = () =>
  user.role === "coordinator"
    ? "/work"
    : user.role === "kitchen"
      ? "/offers"
      : user.role === "recipient"
        ? "/needs"
        : "/allocations";

function route() {
  const raw = location.hash.slice(1) || defaultPath();
  const [path, search = ""] = raw.split("?");
  return {
    path: path === "/" ? defaultPath() : path,
    query: new URLSearchParams(search),
  };
}

function navigation(path) {
  const choices =
    user.role === "coordinator"
      ? [
          ["Follow-up", "/work"],
          ["Food offers", "/offers"],
          ["Receiving needs", "/needs"],
          ["Collections", "/allocations"],
        ]
      : user.role === "kitchen"
        ? [
            ["Your food", "/offers"],
            ["Collections", "/allocations"],
            ["Pickup place", "/site"],
          ]
        : user.role === "recipient"
          ? [
              ["Your needs", "/needs"],
              ["Invitations / arrivals", "/allocations"],
              ["Receiving place", "/site"],
            ]
          : [["Your collections", "/allocations"]];
  return el(
    "nav",
    { className: "navigation", "aria-label": "Your work" },
    choices.map(([label, target]) => {
      const item = link(label, target);
      if (path === target || path.startsWith(`${target}/`))
        item.setAttribute("aria-current", "page");
      return item;
    }),
  );
}

function shell(path, message = "") {
  const main = el(
    "main",
    { id: "content", className: "page" },
    el("div", { id: "recovery" }),
    el("div", { id: "global-status", className: "global-status" }),
    el(
      "div",
      { id: "screen", "aria-busy": "true", "data-route": path },
      el("p", { role: "status" }, "Reading your saved records…"),
    ),
    el(
      "footer",
      { className: "footer" },
      el("span", {}, "Allfedo · clear food handoffs"),
      el("span", {}, "Collection times use each named site’s local clock."),
    ),
  );
  root.replaceChildren(
    el(
      "header",
      { className: "header" },
      brand(),
      navigation(path),
      el(
        "div",
        { className: "identity" },
        el(
          "div",
          {},
          el("strong", {}, user.name),
          el("span", {}, site?.name || roles[user.role]),
        ),
        button("Read updates", { className: "text-button", onClick: load }),
        button("Sign out", {
          className: "text-button",
          onClick: async (event) => {
            const control = event.currentTarget;
            control.disabled = true;
            try {
              await api.logout();
              location.assign("/allfedo/");
            } catch (error) {
              showGlobal(error.message, "error");
              control.disabled = false;
            }
          },
        }),
      ),
    ),
    ...(user.demo === true
      ? [
          el(
            "div",
            { className: "demo-banner", role: "status" },
            "Demo workspace · fictional partners and food. No real collection is being arranged.",
          ),
        ]
      : []),
    main,
  );
  if (message) showGlobal(message);
  recoveryNotice();
}

function showGlobal(message, tone = "") {
  document
    .getElementById("global-status")
    ?.replaceChildren(notice(message, tone));
}

function recoveryNotice() {
  const target = document.getElementById("recovery");
  if (!target) return;
  const pending = api.pending();
  target.replaceChildren();
  if (!pending.length) return;
  const names = {
    create_offer: "Food offer submission",
    confirm_food: "Food detail confirmation",
    observe_stock: "Changed stock count",
    count_stock: "Physical stock count",
    request_change: "Collection change request",
    respond_change: "Partner response to a collection change",
    record_disposition: "Known physical food outcome",
    acknowledge_trip: "Updated trip agreement",
    receive_more: "Additional receiving count",
    correct_custody: "Correction to a physical report",
    dispose_quarantined: "Quarantined food disposal",
    withdraw_invitation: "Invitation withdrawal",
    resume_offer: "Review before resuming invitations",
    create_need: "Receiving need submission",
    update_need: "Receiving need update",
    save_site: "Partner location update",
    apply_plan: "Invitation send",
    plan_offer: "Planning request",
    accept: "Food reservation",
    decline: "Invitation decline",
    assign_collector: "Collector assignment",
    confirm_transport: "Transport confirmation",
    handoff: "Kitchen handoff",
    receive: "Receiving count",
    expire_hold: "Expired hold release",
  };
  const panel = el(
    "section",
    {
      className: "notice warning global-status",
      "aria-label": "Check an earlier change",
    },
    el("h2", {}, "An earlier change needs checking"),
    el(
      "p",
      {},
      "It may already be saved. Check its result before sending another change. Your food records still come from the server.",
    ),
  );
  for (const command of pending) {
    const status = el("div", { "aria-live": "polite" });
    append(
      panel,
      el(
        "p",
        { className: "section-gap" },
        names[command.action] || "Earlier change",
      ),
      status,
      button("Check the saved result", {
        className: "button secondary",
        onClick: async (event) => {
          const control = event.currentTarget;
          control.disabled = true;
          status.replaceChildren(
            el("p", {}, "Checking the same saved request…"),
          );
          try {
            const result = await api.retry({ command });
            flash =
              "The earlier request’s saved result has been checked. Review the saved record below.";
            const destination = result.offer_id
              ? `/offers/${result.offer_id}`
              : result.need_id
                ? `/needs/${result.need_id}`
                : result.allocation_id
                  ? `/allocations/${result.allocation_id}`
                  : command.action === "plan_offer"
                    ? `/offers/${command.payload.offer_id}/plan`
                    : command.action === "apply_plan"
                      ? `/allocations?offer_id=${command.payload.offer_id}`
                      : command.action === "save_site"
                        ? "/site"
                        : null;
            if (destination && location.hash !== `#${destination}`)
              location.hash = destination;
            else await load();
          } catch (error) {
            status.replaceChildren(notice(error.message, "error"));
            if (error.status === 401 || error.code === "UNREADABLE_RESPONSE")
              append(
                status,
                el(
                  "a",
                  { href: "/allfedo/" },
                  "Sign in again to check this request",
                ),
              );
            if (!error.command) {
              flash = `Earlier request check: ${error.message}`;
              await load();
            } else control.disabled = false;
          }
        },
      }),
    );
  }
  append(target, panel);
}

async function allRecords(resource, params = {}) {
  const rows = [];
  const seen = new Set();
  let after = "";
  do {
    const result = await api.list(resource, { ...params, after });
    rows.push(...result.records);
    after = result.next_after;
    if (after && seen.has(after))
      throw new Error(
        "The next records could not be read safely. Refresh this page.",
      );
    seen.add(after);
  } while (after);
  return rows;
}

async function mutate(action, payload, error, options = {}) {
  try {
    const result = error
      ? await api.retry(error)
      : await api.command(action, payload);
    flash =
      options.message ||
      "Your change is saved. The current records are shown below.";
    if (result.agreement_issue)
      flash += ` Review needed: ${result.agreement_issue}`;
    if (
      result.observation_applied === false ||
      result.observation_applied === 0
    )
      flash +=
        " This count is saved for review. It did not replace the newer current stock observation.";
    if (action === "apply_plan") {
      draftPlan = null;
      draftOfferId = null;
    }
    const path =
      typeof options.path === "function" ? options.path(result) : options.path;
    if (path && location.hash !== `#${path}`) location.hash = path;
    else await load();
    return result;
  } catch (failure) {
    recoveryNotice();
    throw failure;
  }
}

function requireRole(allowed) {
  if (!allowed.includes(user.role))
    throw new RequestError(
      "This task is not available to your signed-in role.",
      { status: 403 },
    );
}

function pagination(ctx) {
  if (!ctx.nextAfter && !ctx.query.has("after")) return null;
  const actions = el("nav", {
    className: "pagination",
    "aria-label": "Record pages",
  });
  if (ctx.query.has("after")) {
    const first = new URLSearchParams(ctx.query);
    first.delete("after");
    append(
      actions,
      link(
        "First page",
        `${ctx.path}${first.size ? `?${first}` : ""}`,
        "button secondary",
      ),
    );
  }
  if (ctx.nextAfter) {
    const next = new URLSearchParams(ctx.query);
    next.set("after", ctx.nextAfter);
    append(
      actions,
      link("Next records", `${ctx.path}?${next}`, "button secondary"),
    );
  }
  append(actions, el("span", {}, "Up to 100 saved records per page."));
  return actions;
}

async function load(options = {}) {
  const quiet = options?.quiet === true;
  const previousScroll = window.scrollY;
  activeRead = null;
  if (!user) return;
  const version = ++generation;
  const { path, query } = route();
  const message = flash;
  flash = "";
  shell(path, message);
  const screen = document.getElementById("screen");
  try {
    const ownSite = await api.list("site");
    if (version !== generation) return;
    site = ownSite.record;
    const ctx = {
      user,
      site,
      organization: site?.name || roles[user.role],
      path,
      query,
      now,
      mutate,
    };
    let view;
    let watcher = null;
    const match = path.match(
      /^\/(offers|needs|allocations)\/(\d+)(?:\/(edit|plan))?$/,
    );
    if (path === "/site") {
      requireRole(["kitchen", "recipient"]);
      view = sitePage;
    } else if (path === "/offers/new") {
      requireRole(["kitchen"]);
      view = offerEntry;
    } else if (path === "/needs/new") {
      requireRole(["recipient"]);
      ctx.currentNeeds = (await allRecords("needs")).filter(
        (need) => new Date(need.receiving_until) > new Date(now()),
      );
      view = needEntry;
    } else if (path === "/work") {
      requireRole(["coordinator"]);
      const result = await api.list("worklist");
      const fingerprint = (value) =>
        JSON.stringify([value.items, value.has_more]);
      watcher = {
        read: () => api.list("worklist"),
        fingerprint,
        previous: fingerprint(result),
      };
      Object.assign(ctx, {
        items: result.items,
        hasMore: result.has_more,
        generatedAt: result.generated_at,
      });
      view = worklist;
    } else if (match) {
      const [, resource, id, task] = match;
      if (resource === "offers")
        requireRole(
          task === "plan"
            ? ["coordinator"]
            : task === "edit"
              ? ["kitchen"]
              : ["kitchen", "coordinator"],
        );
      if (resource === "needs")
        requireRole(
          task === "edit" ? ["recipient"] : ["recipient", "coordinator"],
        );
      const detail = await api.read(resource, id);
      if (!task)
        watcher = {
          read: () => api.read(resource, id),
          fingerprint: (value) => JSON.stringify(value),
          previous: JSON.stringify(detail),
          revision: detail.record?.revision,
        };
      Object.assign(ctx, {
        record: detail.record,
        history: detail.history,
        notifications: detail.notifications,
      });
      if (resource === "offers" && task === "plan") {
        const [needs, plan] = await Promise.all([
          allRecords("needs"),
          api.read("plans", id),
        ]);
        Object.assign(ctx, {
          needs,
          savedPlan: plan.record,
          draftPlan: draftOfferId === id ? draftPlan : null,
          checkedAt: draftOfferId === id ? draftCheckedAt : null,
          reviewPlan(proposal, checkedAt) {
            draftPlan = proposal;
            draftCheckedAt = checkedAt;
            draftOfferId = id;
            load();
          },
        });
        view = planPage;
      } else if (resource === "offers") {
        if (task !== "edit") {
          const related = await api.list("allocations", { offer_id: id });
          ctx.relatedAllocations = related.records;
          ctx.moreCollections = Boolean(related.next_after);
        }
        view = task === "edit" ? offerEntry : offerDetail;
      } else if (resource === "needs")
        view = task === "edit" ? needEntry : needDetail;
      else {
        if (task)
          throw new RequestError("This collection page does not exist.", {
            status: 404,
          });
        if (
          ctx.record.state === "accepted" &&
          ["coordinator", "recipient"].includes(user.role)
        )
          ctx.collectors = await allRecords("collectors");
        view = collectionDetail;
      }
    } else if (["/offers", "/needs", "/allocations"].includes(path)) {
      const resource = path.slice(1);
      if (resource === "offers") requireRole(["kitchen", "coordinator"]);
      if (resource === "needs") requireRole(["recipient", "coordinator"]);
      const result = await api.list(resource, {
        after: query.get("after") || "",
        ...(resource === "allocations"
          ? {
              offer_id: query.get("offer_id") || "",
              need_id: query.get("need_id") || "",
            }
          : {}),
      });
      Object.assign(ctx, {
        records: result.records,
        nextAfter: result.next_after,
      });
      view =
        resource === "offers"
          ? offerList
          : resource === "needs"
            ? needList
            : collectionList;
    } else throw new RequestError("This page does not exist.", { status: 404 });
    if (version !== generation) return;
    const pager = pagination(ctx);
    const content = view(ctx);
    if (
      user.role === "coordinator" &&
      (ctx.history?.length || ctx.notifications?.length)
    )
      append(content, caseEvidence(ctx));
    screen.replaceChildren(content, ...(pager ? [pager] : []));
    screen.removeAttribute("aria-busy");
    // Show the refreshed site name after saving setup without keeping a second partner record in the browser.
    const identity = root.querySelector(".identity span");
    if (identity) identity.textContent = site?.name || roles[user.role];
    recoveryNotice();
    activeRead = watcher;
    if (!quiet) {
      const heading = [...screen.querySelectorAll("h1,h2")].find(
        (node) => node.getClientRects().length,
      );
      if (heading) {
        heading.tabIndex = -1;
        heading.focus({ preventScroll: true });
      }
    }
    window.scrollTo(0, quiet ? previousScroll : 0);
  } catch (error) {
    if (version !== generation) return;
    screen.replaceChildren(
      empty(
        "This page could not be opened",
        error.message,
        error.status === 401
          ? el("a", { className: "button", href: "/allfedo/" }, "Sign in again")
          : button("Read the saved records again", { onClick: load }),
      ),
    );
    screen.removeAttribute("aria-busy");
  }
}

async function checkUpdates() {
  const watched = activeRead;
  if (
    !watched ||
    checkingUpdates ||
    document.visibilityState !== "visible" ||
    api.pending().length
  )
    return;
  checkingUpdates = true;
  try {
    const latest = await watched.read();
    if (
      activeRead !== watched ||
      watched.fingerprint(latest) === watched.previous
    )
      return;
    if (root.querySelector('.action-form[data-dirty="1"]')) {
      showGlobal(
        "This case has newer saved details. Read them before making a new agreement. Actual physical reports can still be recorded for review; your unsaved fields are kept below.",
        "warning",
      );
      const target = document.getElementById("global-status");
      append(
        target,
        button("Read the updated record", {
          className: "button secondary section-gap",
          onClick: () => load({ quiet: true }),
        }),
      );
      if (latest.record?.revision !== watched.revision)
        for (const form of root.querySelectorAll(
          '.action-form:not([data-physical-report="1"])',
        )) {
          form.dataset.stale = "1";
          form.querySelector('button[type="submit"]').disabled = true;
        }
    } else {
      flash = "This case has new saved details. The view has been updated.";
      await load({ quiet: true });
    }
  } catch {
    if (activeRead === watched)
      showGlobal(
        "New updates could not be read. The view still shows the last saved details you opened. Use Read updates to check again.",
        "warning",
      );
  } finally {
    checkingUpdates = false;
  }
}

setInterval(checkUpdates, 15000);
window.addEventListener("focus", checkUpdates);
document.addEventListener("visibilitychange", checkUpdates);
document.addEventListener("click", (event) => {
  const target = event.target.closest('a[href^="#"]');
  if (target && target.hash === location.hash) {
    event.preventDefault();
    load();
  }
});

window.addEventListener("hashchange", () => {
  load();
});
(async () => {
  try {
    const session = await api.session();
    user = session.user;
    api.setActor(user.id);
    serverTime = new Date(session.now).getTime();
    serverClockRead = performance.now();
    await load();
  } catch (error) {
    root.replaceChildren(
      el(
        "main",
        { id: "content", className: "page" },
        brand(),
        empty(
          "Sign in with your invited account",
          error.message,
          el(
            "a",
            { className: "button", href: "/allfedo/" },
            "Open secure sign-in",
          ),
        ),
      ),
    );
  }
})();
