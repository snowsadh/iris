# Native checks

Run these in the `ALLFEDO` namespace after installing the application classes and making `src/python` importable by Embedded Python. Load `AllfedoScenario.cls` first.

Stop the Production before updating its running host classes. Load and compile the change, then start the Production again. An existing worker can retain an older loaded implementation; successful compilation alone does not prove that a running worker uses the new code.

```objectscript
Write ##class(AllfedoScenario).TestCommands().%ToJSON(),!
Write ##class(AllfedoScenario).TestFacts().%ToJSON(),!
Write ##class(AllfedoScenario).TestRaces().%ToJSON(),!
Write ##class(AllfedoScenario).TestBusyRecovery().%ToJSON(),!
```

Each check creates a separate synthetic partner network. It keeps its records for inspection and never clears existing application data. The race checks start two real IRIS processes behind a shared start signal. The busy check deliberately holds a resource lock for five seconds.

These four checks passed on AI Hub Community `2027.1.0AI.109.0`. They cover guarded commands, Embedded Python validation, shared stock and need, lock retry recovery, assigned collection, partial physical outcomes, confirmed site/food facts, and invitation deadlines. They do not prove browser authentication, model quality, or persistent worker cleanup.

`TestProductionLocks()` is a separate check that needs a running Production and an authenticated test principal without an existing Allfedo membership. It makes no model call. It temporarily binds only fresh synthetic partner accounts, sends six real Production commands against the same site, offer, and need. It verifies a recorded worker separate from the caller, then lets that caller acquire each resource lock while the Production remains running. The number of distinct workers is reported honestly; dispatch does not have to use multiple workers for every resource. The binding is restored afterward. A process crash can leave that fixture binding for manual inspection; the next run refuses to overwrite it.

`ProveProductionWithModel()` is a **separate, paid, opt-in check**. Never include it in an ordinary test run. It requires a running `Allfedo.Production`, a configured provider key, and an authenticated native principal with no existing Allfedo membership. It temporarily binds a newly created synthetic coordinator to that principal, requests a native model proposal, checks that planning created no holds, then sends a separate command that saves holds and notification intentions. It restores the synthetic coordinator's original login afterward. A process crash can leave the temporary fixture binding for manual inspection; the next run refuses to overwrite it.

An outbox row is an intention to send. An SMTP acknowledgement is channel evidence. Neither proves that a receiving partner accepted food or that food was delivered.

The `Storage Default` blocks in persistent record source map saved values to fields. Preserve existing slot numbers when adding fields. Export and retain the actual native layout after a schema change; regenerating a different order can misread existing records.
