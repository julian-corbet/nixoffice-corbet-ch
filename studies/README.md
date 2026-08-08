# studies

Findings worth keeping: things verified once, at cost, that should not have to be verified again.
An entry here is a settled fact about the world (a package's real name, a protocol's real client
support, a design that was tried and rejected for a stated reason) — not a work log.

Open questions live in [`../experiments/`](../experiments/README.md) instead, and move here when
they close.

## Index

| Study | Finding |
|---|---|
| [`an-office-application-may-not-run-the-engine-it-needs.md`](an-office-application-may-not-run-the-engine-it-needs.md) | Four of these applications start happily with **no** database configuration — they make one inside their own container — and one ships a database server in its image that only a non-local host name suppresses. Decided that an engine dependency is a typed, defaultless connection; that there is nowhere to name an engine's image, version or storage; and that an embedded engine's directory is demanded exactly when that engine is chosen. |
| [`the-work-that-outlives-the-request.md`](the-work-that-outlives-the-request.md) | Scale-to-zero needed three answers, not one: refused for a timer or a directory watcher (the interval never happens; the dropped file is never seen), warned for work an outside caller fires, and absent from the enum entirely for the editors whose unit of work is a session. Decided the `background` trigger field, the required `backgroundWork` statement, and rendering the software's own switch from it. |
| [`two-document-managers-and-what-a-filing-is.md`](two-document-managers-and-what-a-filing-is.md) | Two document managers in one category are a pipeline and a shelf: one transforms what you give it and owns the result, the other keeps custody of the file. Decided the `ingest` field, what running both costs, and the refusal to name a namespace after an application in it. |
| [`two-task-managers-and-what-a-unit-is.md`](two-task-managers-and-what-a-unit-is.md) | Two task managers differ in what one ROW is — a task to finish, or a project that accumulates — and that decides the deployment: one can idle at zero and one is permanently resident. Decided the `unit` field, and the group/category split that lets a board be the same kind of software in a different namespace. |
| [`no-desktop-client-speaks-jmap.md`](no-desktop-client-speaks-jmap.md) | Mail and calendar are absent from the package catalogue on purpose; JMAP has no desktop client, and calendar is a different protocol again. |
| [`resolution-was-untestable-inline.md`](resolution-was-untestable-inline.md) | A real bug survived because the only available test input was the catalogue itself, which contains no instance of the failing shape. |

See the main [README](../README.md) for the project itself.
