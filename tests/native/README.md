# Native checks

Run these in the `ALLFEDO` namespace after installing the application classes and making `src/python` importable by Embedded Python. Load `AllfedoScenario.cls` first.

Stop the Production before updating its running host classes. Load and compile the change, then start the Production again. An existing worker can retain an older loaded implementation; successful compilation alone does not prove that a running worker uses the new code.

```objectscript
Write ##class(AllfedoScenario).TestCommands().%ToJSON(),!
Write ##class(AllfedoScenario).TestRaces().%ToJSON(),!
Write ##class(AllfedoScenario).TestBusyRecovery().%ToJSON(),!
```

Each check creates a separate synthetic partner network. It keeps its records for inspection and never clears existing application data. The race checks start two real IRIS processes behind a shared start signal. The busy check deliberately holds a resource lock for five seconds.

These three checks passed on AI Hub Community `2027.1.0AI.109.0`. They cover the guarded domain commands, Embedded Python validation, shared stock and need, retry recovery, assigned collection, and partial physical outcomes. They do not prove browser authentication, email receipt, model quality, or restart recovery.

`ProveProductionWithModel()` is a **separate, paid, opt-in check**. Never include it in an ordinary test run. It requires a running `Allfedo.Production`, a configured provider key, and an authenticated native principal with no existing Allfedo membership. It temporarily binds a newly created synthetic coordinator to that principal, requests a native model proposal, checks that planning created no holds, then sends a separate command that saves holds and notification intentions. It restores the synthetic coordinator's original login afterward. A process crash can leave the temporary fixture binding for manual inspection; the next run refuses to overwrite it.

An outbox row is an intention to send. An SMTP acknowledgement is channel evidence. Neither proves that a receiving partner accepted food or that food was delivered.
