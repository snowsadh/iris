# InterSystems contest notes

Checked: **9 November 2026**. Sources include organizer replies, not just the original announcement. These notes describe platform capabilities; the [implementation guide](TECHNICAL_PLAN.md) identifies what Allfedo actually uses. Build 109, native AI Hub, Embedded Python, signed-in browser flows and scheduled test email have been verified.

## 1. Task and deadline

Build working **IRIS Interoperability workflow**. Its **AI Hub agent must make a decision** inside that workflow. Interoperability means moving data between systems and handling it along the way. Agent means software that asks an AI model what to do and can call tools.

Allfedo's case: receive confirmed food and need, let the agent propose receiving partners, review and send invitations, then record partner replies and actual food movement. The agent runs inside the native workflow.

- Submission closes **8 November, 11:59:59 PM EST**.
- Same instant in India: **9 November, 10:29:59 AM IST**.
- Voting: **9–15 November EST**. Ends **16 November, 10:29 AM IST**.
- Changes allowed during voting. Initial submission still has earlier deadline.

EST means Eastern Standard Time, UTC−5. IST means India Standard Time, UTC+5:30. [Contest page](https://openexchange.intersystems.com/contest/49), [announcement and replies](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows).

## 2. Entry rules

- Working, original app. New entry or major improvement to existing app.
- No copied app or thin wrapper around another library; C++ integration has exception.
- Open source on GitHub or GitLab.
- English README: install steps plus video or clear explanation.
- Maximum three entries per developer/team.
- Community members eligible; employees excluded, contractors allowed.
- Solo or teams of 2–5; README needs members' Community profile links.
- Synthetic data and AI assistants allowed; disclosure optional.
- Newcomer award: at most five prior contests; no prior top-three expert/community finish.

Published judging criteria: **Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability**. In plain English: technical work, clear setup, ease of building with it, usefulness, and ease of use. The page gives no numerical weights. Review decisions final. [Entry requirements](https://openexchange.intersystems.com/contest/49), [organizer clarifications](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows).

General terms also require local age of majority and minimum age 16. Location/export restrictions apply, including Quebec, Crimea, Iran, North Korea, and Syria. Identity checks and tax paperwork may be required. Requested eligibility proof: within 10 days; tax documents: within 7 days or sooner where required. Contest-specific rules take priority over general terms. Read [full terms](https://openexchange.intersystems.com/markdown?url=/assets/doc/contest-terms.md) before entering.

## 3. Image and access traps

Docker runs packaged software in containers. An image is that package. Compose starts containers from project configuration.

AI Hub comes through **Early Access Program (EAP)**. It is prerelease software; interfaces can change. Ordinary release image may lack AI Hub. [AI Hub overview](https://github.com/intersystems-community/ai-hub-eap).

- Original: **2026.3.0AI.154.0** Community, IRIS or IRIS for Health; supersedes 162.
- **November 2 accepts 2027.1.0AI.109.0**. Declare build; judges match it.
- Never publish EAP/derived images publicly. Share Docker source. Contest development/demos permitted.
- Own model keys; no credits. Judges supply keys.
- Providers: OpenAI, Anthropic, Gemini, Bedrock. Other integrations experimental in organizer's list.
- Replay allowed alongside live mode; static replay earns no online-demo bonus.
- Approval can remain pending at deadline; submit working entry on time.

These come from [organizer replies](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows). On 9 November we downloaded the actual x64 Community archive from the signed-in [portal](https://evaluation.intersystems.com/Eval/early-access/AIHub). Installed version reports `2027.1.0AI (Build 109U)`; `%AI.Agent`, `%AI.Provider`, and `%AI.ToolSet` exist. Embedded Python reports 3.12.3. Application compilation, native capacity tests, a Production-based OpenAI proposal, and local SMTP delivery have now passed. Browser access and full recovery are separate checks.

**Setup pattern**, after downloading matching archive:

```bash
docker image load -i /path/to/downloaded-docker.tar.gz
docker images
docker tag <loaded-image-name> <local-image-name>:<exact-build>
docker compose up --build -d
```

Place actual local image name in Dockerfile or Compose. README must give exact archive, architecture, image tag, key variable, start command, and working check. Placeholders above are instructions, not runnable project setup. [Template setup](https://github.com/intersystems-community/ai-hub-dev-template).

## 4. Platform pieces

IRIS combines database and app runtime. **ObjectScript** is its native language. **Production** means configured integration workflow here; it does not mean public deployment.

Production has three main parts:

1. **Business Service** receives outside input and creates internal message.
2. **Business Process** receives message, applies logic, and coordinates next steps.
3. **Business Operation** receives internal request and talks to outside destination.

Keep business decisions in process. **Business Process Language (BPL)** defines processes visually. **Data Transformation Language (DTL)** maps one message shape into another. Business rules choose paths from message values. Custom classes support logic beyond visual editors. [Process guide](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGIN_busproc).

**Adapter** handles external connection, such as file, email, HTTP, or messaging system. Inbound adapter feeds service; outbound adapter helps operation send data. Some web services work without adapters. [Connection guide](https://docs.intersystems.com/irislatest/csp/docbook/Doc.View.cls?KEY=EGIN_options_connectivity).

**Management Portal** is browser control panel. Message Viewer shows stored messages. Visual Trace shows related messages moving between components. Click message's Session ID to inspect its path and body. This shows message flow; agent details need their own recorded data. [Trace guide](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EMONITOR_message_trace).

## 5. AI Hub: model, agent, tools

**Large language model (LLM)** generates responses. Provider hosts or serves model. AI Hub connects our code to it; using Hub does not train a new model.

**Software development kit (SDK)** provides classes for building app. **Application programming interface (API)** means callable software interface.

Main ObjectScript classes:

| Class | Job |
|---|---|
| `%AI.Provider` | Connect to model provider. |
| `%AI.Agent` | Send instructions; run model/tool loop. |
| `%AI.Agent.Session` | Keep conversation and run statistics. |
| `%AI.Tool` | Expose callable code to agent. |
| `%AI.ToolSet` | Group selected tools. |
| `%AI.ToolMgr` | Register tools; enforce tool policies. |
| `%AI.LLM.Response` | Return text, tool requests, and token usage. |
| `%AI.Catalog` | Discover available AI assets. |

Typical flow: configure provider/model, initialize agent, attach tools, create session, call `Chat()`, inspect response. `StreamChat()` returns text in chunks. Declarative agents keep provider, model, toolsets, and instructions in class definition.

Two limits differ: `MaxIterations` bounds outer `Run()` turns; session `max_iterations` bounds tool rounds inside `Chat()`. Current guide says omitted inner limit is unlimited. Set positive limit.

Built-ins cover SQL, files, web search, shell, and binary inspection. Tool availability depends on build. Shell execution needs authorization policy. [SDK guide](https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Guide.md).

Hub includes ObjectScript SDK, Python LangChain integration, and tools exposed to outside agents. Java LangChain4J guide remains marked forthcoming in overview. Treat announced features separately from features verified on chosen build. [Hub overview](https://github.com/intersystems-community/ai-hub-eap).

### Optional AI features

**Retrieval-augmented generation (RAG)** searches documents before model answers. Embedding converts text into number list representing meaning. `%AI.RAG.VectorStore.IRIS` stores those lists; `%AI.RAG.KnowledgeBase` adds search tool. FastEmbed can create embeddings locally; OpenAI option needs key.

Authorization policy decides whether tool may run. Audit policy records execution. Global and toolset authorization must both allow call. Both audit policies run. Toolset discovery policy takes precedence over global fallback.

Skills bundle instructions and tools; current experimental design loads details when needed. Sub-agents have separate conversation context. Planning skill tracks tasks. Advanced guide marks these areas experimental. [Advanced SDK guide](https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Advanced.md).

Useful learning samples: `BasicUsage`, `ToolUsage`, `PolicyEnforcement`, `RAGUsage`, and `AdvancedToolSet` under `Sample.AI.Examples`. Samples teach patterns; app still needs original workflow. [Examples](https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Examples.md).

Starter choices; none selected or copied yet:

- [AI Hub template](https://github.com/intersystems-community/ai-hub-dev-template): agent, toolsets, and MCP samples. Community starter; adjust image to chosen build.
- [IRIS dev template](https://openexchange.intersystems.com/package/intersystems-iris-dev-template): ObjectScript workspace, tests, Python setup, package manifest.
- [Fullstack template](https://openexchange.intersystems.com/package/iris-fullstack-template): browser app plus backend web interface.
- [REST template](https://openexchange.intersystems.com/package/rest-api-contest-template): create/read/update/delete examples and interactive interface docs. REST is common pattern for web APIs.

Review inherited image-publishing automation before reuse; EAP image restriction still applies.

### Settings and secrets

**Config Store** holds named settings, such as model endpoint. **IRIS Wallet** stores secret values. Roles control who can read, use, or edit them. `%ConfigStore.Configuration` manages settings; `%Wallet.KeyValue` manages secrets. Configurations can reference Wallet entries. [Config Store guide](https://github.com/intersystems-community/ai-hub-eap/blob/master/Config_Store_Guide.md).

Python option: `langchain-intersystems` loads named models with `init_chat_model()` and remote tools with `init_mcp_client()`. Its wheel comes from EAP portal. It reuses IRIS settings and access controls. [Python integration](https://github.com/intersystems-community/ai-hub-eap/blob/master/langchain_SDK.md).

### Practical implementation checks

- **Web input:** A `%CSP.REST` class can create a configured Business Service with `Ens.Director.CreateBusinessService()`. The service passes a typed message into the Production. A web endpoint writing straight to a table does not demonstrate this workflow. [REST integration](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=EREST_business_service).
- **Agent tools:** Extend `%AI.ToolSet`; list methods in its `XData Definition`. Typed method arguments become tool input schemas. Attach with `UseToolSet()`, create a session, then call `Chat()`. Our code must still check permissions, allowed actions, evidence, and current record version. A valid input shape does not make the decision correct. [SDK at reviewed revision](https://github.com/intersystems-community/ai-hub-eap/blob/1cca39afeb069413846c4c31196eed0b731f793a/ObjectScript_SDK_Guide.md).
- **Long waits:** BPL can send an asynchronous request and wait with `<sync>`. IRIS saves the waiting process to disk and frees its worker. Set a timeout and handle late replies. Human Workflow uses `EnsLib.Workflow.TaskRequest` and `TaskResponse`; a polished review screen still needs our work. [BPL waiting](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EBPL_sync), [task response](https://docs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?CLASSNAME=EnsLib.Workflow.TaskResponse&LIBRARY=ENSLIB).
- **Concurrent changes:** SQL transactions and a conditional `UPDATE` can check stock or record version before changing it. Check the affected-row count. Give incoming events unique IDs to reject repeats. A database commit does not make a separate web request happen exactly once; track outgoing requests and acknowledgements too. [SQL updates](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_update).
- **Private data:** IRIS supports row-level security, meaning different users can read different rows. This protects SQL access, not direct object/global access. Application code must check those paths. Background workers also need the original caller's verified identity; the model must not choose it. [Security limits](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_rls).
- **Search permissions:** Filter permitted sources before sending text to a model. A search filter chosen by the model is not an access check. Recheck access for citations, source files, logs, and exports. Hub search helpers do not automatically supply our application's permission rules. [Search guide](https://github.com/intersystems-community/ai-hub-eap/blob/1cca39afeb069413846c4c31196eed0b731f793a/ObjectScript_SDK_Advanced.md#rag-retrieval-augmented-generation).
- **Python libraries:** Embedded Python can load installed packages, but Python version, operating system, and binary libraries must match. A separate Python service called by a Business Operation is another option. That still leaves the required agent decision in AI Hub; an outside Python service alone does not earn the Embedded Python bonus. [Package setup](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GEPYTHON_loadlib), [runtime requirements](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GEPYTHON_prereqs).

## 6. Two different MCP tools

**Model Context Protocol (MCP)** lets AI clients discover and call tools. These projects serve different jobs.

### `iris-mcp-server`: app tools for external agents

Publish IRIS code through `%AI.MCP.Service`, then connect external MCP client. Supports local process input/output (`stdio`) and remote web connections. Server talks to IRIS through native gateway protocol, normally port **1972**.

Gateway login and per-request MCP identity are separate checks. Passing first does not pass second. Server supports tool discovery, logs, monitoring, and tracing. Some advanced features remain experimental. External MCP server optional for contest's core task. [MCP server guide](https://github.com/intersystems-community/ai-hub-eap/blob/master/MCP_Server_Guide.md).

### `iris-agentic-dev`: tools for building our code

Optional development helper. Lets coding assistant inspect live IRIS, compile classes, query data, test code, and inspect integrations. Requires IRIS 2023.1+. Runs as MCP server or command-line tool. Skills install separately. Its normal connection uses **web port 52773**, unlike native gateway above. [Project guide](https://github.com/intersystems-community/iris-agentic-dev).

Relevant tool map:

| Tools | Use |
|---|---|
| `check_config`, `iris_servers`, `iris_test_server` | Check target and connection. |
| `iris_doc`, `iris_doc_search`, `docs_introspect` | Check real class interfaces. |
| `iris_search`, `iris_symbols`, `iris_info` | Find code and inspect classes. |
| `iris_compile`, `iris_execute`, `iris_execute_method` | Compile or run code. |
| `iris_query`, `iris_table_info` | Query data; inspect tables. |
| `iris_test`, `iris_coverage` | Run tests; measure exercised code. |
| `iris_production`, `iris_production_item` | Inspect or manage integration. |
| `iris_interop_query`, `iris_message_body` | Read queues, logs, messages. |
| `iris_production_diff`, `iris_business_rule_info` | Inspect changes and rules. |

Full catalog also covers servers, debugging, code generation, credentials, lookup tables, persistent execution sessions, administration, skills, and telemetry. Installed version defines exact names and arguments:

```bash
iris-agentic-dev tool --list
iris-agentic-dev tool iris_query --schema
```

For `iris_production` start, argument is `production_name`; autostart uses `production`. Some actions require `IRIS_CONTAINER`. [Complete tool reference](https://github.com/intersystems-community/iris-agentic-dev/blob/master/docs/tools.md).

Useful skill packs: `ensemble-production`, `iris-ai-hub`, `iris-docs`, `iris-embedded-python`, `iris-sql`, `iris-vector-ai`, `iris-vscode-objectscript`, and `objectscript-unit-test`. These teach coding patterns. They are separate from AI Hub's runtime skills. AI Hub pack records findings from older build 139; verify against selected image. [Skill inventory](https://github.com/intersystems-community/iris-agentic-dev/blob/master/docs/skills.md).

## 7. Bonus features, explained

**Embedded Python** runs Python inside IRIS beside ObjectScript. Separate Python web server alone does not demonstrate this feature. [Python guide](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=AFL_epython).

**Production Extension (PEX)** lets Java or .NET components join integration. **Workflow Engine** assigns tasks to people. For example, `EnsLib.Workflow.Operation` sends tasks to users belonging to its workflow role. A custom approval table alone does not demonstrate engine use. [PEX docs](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EPEX), [workflow docs](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGWF_dev).

**Vector Search** finds data with similar meaning using embeddings. IRIS supports `VECTOR_COSINE` and `VECTOR_DOT_PRODUCT`; larger scores mean closer match. [Search guide](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_vecsearch).

**InterSystems Package Manager (IPM)** installs app packages. Older name and command: ZPM / `zpm`. Public registry publication uses Open Exchange. Put versioned `module.xml` at repository root and select package publication in listing. [Publishing guide](https://docs.openexchange.intersystems.com/apps/ipm/).

Organizer's build-154 package guard:

```xml
<SystemRequirements Version=">=2026.3" Interoperability="enabled"/>
```

For build 109, verify actual minimum version. [November 2 clarification](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows).

Optional points from [bonus announcement and replies](https://community.intersystems.com/post/technology-bonuses-intersystems-programming-contest-ai-agents-interoperability-workflows):

| Feature | Points |
|---|---:|
| Feedback questionnaire | 1 |
| PEX with Java/.NET | 3 |
| Workflow Engine | 2 |
| Own inbound/outbound adapter, used in workflow | 2 |
| AI Hub bugs | 2 first; +1 second |
| Embedded Python | 3 |
| IRIS Vector Search | 2 |
| IRIS in Docker | 2 |
| Published IPM package | 2 |
| Live hosted demo | 2 |
| Implement Community Opportunity idea | 4 maximum |
| Embedded Python bugs | 2 first; +1 second |
| First Community article | 2 |
| Second article or translation | 1 |
| Demo video | 3 |

Conditions:

- Bug claims need reproducible reports; each bug category capped at 3.
- Idea must have **Community Opportunity** status. Link in README and listing; show implementation. Multiple entries may use same idea.
- Video must be downloadable without account. November 6 reminder explicitly asks YouTube users for downloadable copy.
- Further articles earn no extra points. Bonus list may change.

[Feedback questionnaire](https://forms.cloud.microsoft/r/upQDKbj78D).


## 8. Submission and judging checklist

For a short working list, use [SUBMISSION.md](SUBMISSION.md). It separates required work, our delivery standard, and every optional bonus.

1. Create Open Exchange account and app listing. Fill repository, license, description, categories, and relevant resource links. **Save** keeps draft; **Send for Approval** submits review. [Listing guide](https://docs.openexchange.intersystems.com/apps/submit/).
2. Apply to contest 49 and verify entry association. Generic guide offers contest Apply button, app Contest tab, or developer-portal menu. Its approval wording conflicts with contest-specific pending-review allowance above. [Application guide](https://docs.openexchange.intersystems.com/contest/apply/).
3. Test README from clean setup. Include sample input, expected result, exact build, model/key settings, and visible agent decision.
4. Put best evidence near README top: task fit, useful technical choice, demo, and relevant code. Link proof beside each bonus claim.
5. Keep hosted demo available during review. Article can explain build experience and failures. [Judges' advice](https://community.intersystems.com/post/what-experts-look-contest-entries).

Experts also ask for a distinctive technical contribution and bonuses that serve the app. They explicitly say innovation need not mean complexity. This is advice, not a weighted scoring formula. [Expert guidance](https://community.intersystems.com/post/what-experts-look-contest-entries).

Read past winners against their own contest theme. Contest 48 required an IRIS management interface; OcuPilot added an AI copilot to that task. Its platform focus alone does not establish a general judge preference for developer tools. [Contest 48 task](https://openexchange.intersystems.com/contest/48).

**Our quality standard:** deliver a coherent app another developer can run, understand, inspect, and build on. Documentation is part of that work: quick review path, exact setup, design explanation, repeatable checks, troubleshooting, and clear limits. This is our synthesis of expert advice and repository evidence, not a disclosed judging formula. OcuPilot's [review-period developer guide](https://github.com/jbrandtmse/OcuPilot/blob/0f9cfb5718e9d308f039a9d2b4b235998610cf9e/docs/DEVELOPMENT.md) and [successful October 5 automated check](https://github.com/jbrandtmse/OcuPilot/actions/runs/37388387925) show concrete examples. Professional work can have a focused scope; file count and document length are not goals.

Suggested app checks, not extra contest rules: invalid input, provider outage, bounded retries, duplicate request, rejected agent output, and human-review path. Record input, decision, tool calls, model, elapsed time, and token usage. Show live and replay modes clearly. Cost estimates need model prices and recorded usage; no measured cost yet.

## 9. Current limits and next decisions

- No image downloaded, code compiled, or agent run here. Current SDK docs can describe features newer than chosen EAP build.
- Reviewed Hub source revision `1cca39a` (6 November). Documentation support is not proof that every feature exists on either accepted image. First runtime check: compile one toolset, call one agent from a Production, wait/resume, inspect saved messages, and verify the selected Python packages.
- Food rescue is selected. Define the complete user journey and screen behavior; then choose the accepted image, model, and small toolset and verify exact classes on the running image.
- Prize pool: **$12,000** across expert, community, newcomer awards. [Prize breakdown](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows).
