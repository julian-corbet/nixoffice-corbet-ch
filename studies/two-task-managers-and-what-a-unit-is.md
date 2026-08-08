# Two task managers, one category, and the question of what one row is

**Finding.** The second pair of competing implementations in this repository is two task managers in
one category — and unlike the document managers, the thing that separates them is not what they do
to the input. It is **what one row IS**:

> In one, a row is a **task**: an item with a due date, in a list, done and gone.
> In the other, a row is a **project**: a structure that accretes goals, milestones, a client, time
> logged against the work, and a retrospective when it ends.

A task exists inside a project in the second; a project is a folder for tasks in the first. That
inversion is the whole difference, and it decides the operational behaviour rather than following
from it.

A third application in the same *group* — a kanban board — is a third answer (`card`) and lives in a
category of its own. That is deliberate and is discussed at the end.

**What this is based on.** What each one demands before it will start, what its process tree runs,
what its schema is authoritative for, and what it stores. Not their project descriptions, which both
say "project management".

## The three claims, side by side

| | task list | project manager | board |
|---|---|---|---|
| one row is | a **task** | a **project** | a **card** |
| what the unit is for | being finished | accumulating context until the work ends | being *looked at*, in a column, on a wall |
| time logged against work | no | **yes, and it is a first-class object** | no |
| what happens when the unit is done | it disappears from view | it is closed and keeps its history, its timesheets and its retrospective | it moves to the last column and stays visible |
| store | one static binary, **three engines including an embedded one** | a MySQL-compatible engine and nothing else | one engine, by connection string, and no embedded option |
| attachments | one directory | **two**, because it serves one publicly and gates the other | one, plus three directories of decoration |
| background work | a reminder timer that **can be switched off** | a scheduler its process supervisor starts beside the web server, which **cannot** | none at all |
| can it idle at zero | **yes, with the timer off** | no | yes |

## Where the real line falls

**"Both track work" is not the distinction, and neither is "one is heavier".** The mechanical test
that survives is whether there is anywhere to **log time against a unit**. There is nowhere in the
task list — no timesheet object, no rate, no client to bill. There is nowhere in the project manager
for a task that belongs to nothing: the hierarchy is not optional, because the surrounding structure
is what the software is for.

That single difference propagates all the way down to the deployment:

- the task list is one static binary that will open an **embedded** database if pointed at one, and
  it can be idled at zero the moment its reminder timer is switched off;
- the project manager cannot use an embedded engine at all, and its scheduler is started by its own
  process supervisor with no switch — so it is **permanently resident** in a way its neighbour is
  not.

So the pair does not merely overlap in features. One is a workload that costs nothing while nobody
is using it and one is a standing cost, and that follows from what a row is.

## What running both actually costs

- **Two inboxes for "things I owe", and no convention deciding which.** A due date in one is
  invisible to the other. This is the same cost the document-manager pair has, and it is worse here,
  because the overlap is a whole product rather than an intake path: everything the task list does,
  the project manager also does, badly, inside a project.
- **One permanently resident pod plus one engine that would otherwise not be needed.** The project
  manager brings a MySQL-compatible engine into the picture that nothing else here requires — while
  the task list can run on a file in its own directory.
- **A judgement that has to be made once**: is the unit a thing to finish, or a thing to accumulate?
  A household or a person tracking errands wants the first; anybody who bills time or runs work with
  a client wants the second. Running both because both are installed is how you end up with a task
  list nobody trusts, which is worse than either.

## The board, and why it is a different category rather than a different group

The kanban board is the **same kind of software** — something owed, with a state — and it is
catalogued in the same group. It lands in a category of its own, and that is not taxonomy:

- a board is read **at a glance, by whoever is looking at the wall**; a due-date list is read by the
  person who owes the work. Different audiences, and the exposure decision is therefore a different
  decision;
- they fail differently and are backed up differently: a board's content is cards and attachments,
  and a list's is dated obligations;
- and a category is what a blast radius is drawn around here.

That split is this repository's clearest demonstration that a **group** (what the software IS,
deciding which option set a declaration gets) and a **category** (what it lands next to, deciding
the namespace) are two different questions. Collapsing them would have forced either three
namespaces for one kind of software, or one namespace for three audiences.

## What it decided here

1. **The `unit` field** — `task`, `project`, `card` — which is the only thing separating the claims
   without appealing to marketing. `checks/cluster-eval.nix` asserts that the two entries sharing a
   category carry *different* units, so the claim cannot quietly stop being true.
2. **A group that spans two categories**, which is what made the group/category distinction
   necessary rather than decorative, and which the checks assert on the rendered namespaces.
3. **The scale-to-zero asymmetry is a catalogue fact, not a preference.** One has a switchable timer
   and the module renders that switch from the same boolean the guard reads; the other has a
   scheduler with no switch and is refused. The pair is the cleanest evidence in this repository
   that "can this sleep" is a property of the software plus a decision, never a default.
