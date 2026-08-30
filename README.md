# nixoffice

**Where the written work happens, declared** — the office applications a fleet runs, and the
documents half of a workstation.

Two halves, one option namespace. A **cluster** surface for the applications a person keeps their
working life in: a wiki, document managers, task trackers, a booking page, collaborative editors, a
typesetting service, record platforms. And a **host** surface for the office software a person
installs on a machine: suites, typesetting tools, prose editors and document viewers.

The cluster half renders no Kubernetes object of its own. Everything expressible as an app is
expressed in [nixk3s](https://github.com/julian-corbet/nixk3s-corbet-ch)'s app grammar; what this
repository adds is the one thing that grammar cannot know — what each *kind* of office application
is, which engine it needs and cannot run, and which of them is still working after the request was
answered.

## Most of these need a database, and none of them may run one

Nine of the twelve applications catalogued here need at least one engine, and they do not agree on
which: Postgres, MariaDB, MongoDB, Redis and an embedded SQLite are all represented, and several
accept more than one. **None of them is this repository's to run** — a sibling owns engines.

That much is a boundary anybody would write in a README. What makes it a design is the failure mode
on the other side of it:

> Four of these applications start perfectly happily with **no database configuration at all**. They
> create a database inside their own container, come up, work, and report themselves healthy. One
> ships an entire database **server** inside its image, and the only thing that stops it starting
> that server is being told a host that is not localhost.

So an engine dependency is a typed, named connection here rather than an environment variable
somebody remembers to set:

```nix
nixoffice.cluster.wikis.example-wiki = {
  wiki = "bookstack";
  version = "0.0.0";
  connections.database = {
    engine = "mariadb";            # which engines this software SPEAKS is the catalogue's
    service = "example-sql";       # a NAME, never an address
    namespace = "example-engines"; # the address is DERIVED from these and the cluster domain
    database = "example_wiki";
    user = "example_wiki";
    password = { secret = "example-wiki-db"; key = "password"; };   # by reference, never a value
  };
};
```

Software that reads one whole connection string still uses a Secret reference when that string is
opaque or contains credentials. A credential-free in-cluster Service URL can instead be assembled
from typed pieces when the engine catalogue explicitly permits its scheme:

```nix
connections.broker = {
  engine = "redis";
  serviceDsn = {
    scheme = "redis";
    service = "example-broker";
    port = 6379;
  };
};
```

That renders `redis://example-broker.<category-namespace>.svc.<cluster-domain>:6379`. The namespace
and cluster domain are platform facts, the Service must be a bare name, and no raw host, path, query
or userinfo is accepted. The existing `dsn = { secret; key; };` form remains the only form for a
credential-bearing or otherwise opaque connection string.

**A required connection is defaultless, and its absence fails evaluation** — naming the role, and
explaining that this particular software would otherwise make a database inside its own container
rather than refusing to start. Choosing an embedded engine is something somebody writes down:

```nix
connections.database.engine = "sqlite";   # deliberate, and the directory holding it must be backed
```

And the boundary is **structural rather than advisory**. There is nowhere in this module to name an
engine's image, its version, its storage or its root credential; there is no `manifests` option and
no `raw` passthrough; one declaration renders exactly one container. Shipping a database beside an
application is not refused — it is unwritable. `checks/cluster-render.nix` reads that back off the
rendered bytes: every Deployment has exactly one container, no init containers, and no object
anywhere in the tree is an engine.

Full reasoning:
[`studies/an-office-application-may-not-run-the-engine-it-needs.md`](studies/an-office-application-may-not-run-the-engine-it-needs.md).

## Scale-to-zero needed three answers, not one

Several of these are genuinely heavy — an office suite that pre-forks a process per open document, a
typesetting service carrying a whole distribution, a document pipeline that opens a search index on
boot — and several do real work after the request that started it has been answered. So idling at
zero replicas is **not uniformly safe here**, and the module calibrates rather than defaults:

| trigger | at zero replicas | verdict |
|---|---|---|
| an in-process **timer** | the interval does not happen. Nothing is late; it is never evaluated | **refused** |
| a directory **watcher** | a file copied in produces **no HTTP request at all**, so nothing can wake it | **refused** |
| an outside **caller** | the call wakes the pod and then waits out the cold start in its own timeout | **warned** |
| a long **cold start** | the first person to arrive pays for all of it, every time | **warned**, with the measured number |

And a fourth answer that is not a guard at all: for the **collaborative editors**, whose unit of work
is a session rather than a request, `scale-to-zero` is not in that group's `scaling` enum. A missing
value, not a refusal — a wake front counting requests sees an idle connection and takes the pod away
mid-edit, and any software belonging in that group has the same property.

Two entries can have their background work **switched off**, and there the declaration must say
which way it is set — the answer is what decides whether the workload may sleep, and no default is
right for both. Where the software has a real switch, the module **renders it from the same boolean
the guard reads**, so a declaration claiming reminders are off cannot be running with them on:

```nix
nixoffice.cluster.trackers.example-tasks = {
  tracker = "vikunja";
  backgroundWork = false;        # required here, refused where the work is not optional
  scaling = "scale-to-zero";     # which this is what makes safe rather than hopeful
  # ...
};
```

Full reasoning:
[`studies/the-work-that-outlives-the-request.md`](studies/the-work-that-outlives-the-request.md).

## A group is what the software IS; a category is what it lands next to

Every catalogue entry carries a `category`, and it is **not declarable**. A workload's namespace is
its category's namespace, and those are defaultless options — so there is no per-workload
`namespace` option anywhere in this module and there will not be one.

The two questions come apart in this catalogue rather than in theory: a kanban board and a task list
are the same *kind* of software (commitments with a state, so one option set) and land in two
categories, because a wall of cards and a list of due dates are read by different people, fail
differently, and are worth separating by blast radius.

**Two categories hold two applications each, on purpose and not in transition.** That is what a
category is for — a container that outlives any one application in it — and it is why a namespace
may not be named after an application in the catalogue *or* after a workload declared in it. The day
a second one arrives, a namespace named after the first makes it a guest in its own category, and
the only fix is a rename, which is a migration.

Both pairs are written up from evidence rather than from marketing:

- **Two document managers** — a **pipeline** that transforms what you give it and owns the result,
  and a **shelf** that keeps custody of the file you handed over. What running both costs, stated:
  [`studies/two-document-managers-and-what-a-filing-is.md`](studies/two-document-managers-and-what-a-filing-is.md).
- **Two task managers** — one where a row is a **task** to be finished, one where a row is a
  **project** that accumulates goals, timesheets and a retrospective. One can idle at zero and one
  is permanently resident, and that follows from what a row is:
  [`studies/two-task-managers-and-what-a-unit-is.md`](studies/two-task-managers-and-what-a-unit-is.md).

Each distinction is a catalogue field (`ingest`, `unit`) with a check asserting the two entries stay
*different*, so a claim cannot quietly stop being true.

## One value, several variables, several forms

Most of these have to be told the URL a browser reaches them at, and getting it wrong produces the
classic failure: every credential correct, and nobody able to sign in. The origin is a fleet fact and
comes from the declaration; **which variables it goes into, whether each wants a whole origin or the
bare host, and any path suffix are knowledge** and live in the catalogue. One application needs three
variables in two forms from one value; another wants the host with the scheme stripped off.

The collaborative editors take the same idea further. A declaration gives ordinary origins:

```nix
documentHosts = [ "https://files.example.com" ];
```

and the module produces **numbered** variables carrying **regular expressions** with every dot
escaped — and refuses a port, because the value is matched against a host that carries none, so one
with a port matches nothing and the symptom is a document that never opens.

Every workload may also set `adopt = true` when its Argo Application is taking over objects that
already exist. This is deliberately explicit and defaults to false: adoption is deployment history,
not a property of any catalogue entry, and it enables server-side apply plus server-side diff only
for the workload that asks for it.

## The seven groups

| group | what it is | in the catalogue |
|---|---|---|
| `wikis` | pages you author and link; the corpus is the wiki | a wiki whose pages are rows and whose pictures are files |
| `filings` | documents you received, filed so they can be found again | a pipeline and a shelf |
| `trackers` | commitments with a state | a task list, a project manager, a board |
| `schedulers` | other people's claims on your time | a booking service |
| `coeditors` | live editing of a document **another system stores** | two office suites |
| `compilers` | a source document turned into an artefact | a collaborative typesetting service |
| `records` | structured records whose meaning is yours | a data platform and a fixed-schema profile |

## The host half

Unchanged and independent: a platform-neutral module that selects office software by group —
`suite`, `authoring`, `editors`, `viewers`, `apps` — and resolves each to a pacman package, an AUR
package, a Flatpak id or a nixpkgs attribute, **each independently nullable**, because an
application really can exist on some channels and not others.

The scope is stated as a test, not a list: this half owns what a **person consumes visually**. A
suite you click around in, a typesetter whose output you read, an editor you write prose in, a viewer
you open a PDF with. Anything you only ever script against belongs in
[nixdev](https://github.com/julian-corbet/nixdev-corbet-ch) instead — pypdf and pdfplumber are
libraries, not documents.

- **NixOS:** full. Selections resolve to nixpkgs attributes and install via
  `environment.systemPackages`.
- **Arch / CachyOS (via system-manager):** publishes `nixoffice.archPackages` and
  `nixoffice.aurPackages` for the host's own reconciler.
- **Flatpak, either platform:** publishes `nixoffice.flatpakApps` as `{ id; remoteName; remoteUrl; }`
  — id and remote **together**, never a bare id list, because a bare id can only assume Flathub and
  that assumption is wrong often enough to matter. Nothing here installs them;
  [nixflat](https://github.com/julian-corbet/nixflat-corbet-ch) is written against exactly this
  shape.

Mail and calendar are absent on purpose, not by oversight — see
[`studies/no-desktop-client-speaks-jmap.md`](studies/no-desktop-client-speaks-jmap.md).

**The cluster surface is nested under `nixoffice.cluster`**, and that is not decoration: the host
half already owns `nixoffice.editors` and `nixoffice.apps` at the top level, which is exactly what a
cluster group of the same subject would want to be called. One repository is one option namespace,
and two surfaces inside it must not be able to collide — least of all by both meaning something
reasonable.

## Public mechanism, private layout

**No address, no slot number, no namespace value, no node path, no hostname and no credential
appears anywhere in this repository.** Every one of those is a fleet fact and is a parameter the
consumer supplies. The catalogue carries what software needs in order to be **correct** — where it
writes, which variable a credential arrives in, which engines it speaks, what it does when nobody is
looking — and never what it needs in order to be the right **size**: no replica counts, no heap
sizes, no resource requests, no storage sizes.

Container ports and an engine's canonical port are the only numbers here, because both are properties
of software rather than of anybody's network.

## Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | `nixidyModules` (cluster), `nixosModules`/`systemManagerModules` (host), `lib.*`, `checks`. |
| `lib/applications.nix` | The cluster catalogue: seven groups, twelve applications, nine categories, five engine kinds — and the knowledge that makes each one run. |
| `modules/cluster.nix` | The cluster surface: translates declarations into `nixk3s.apps`, and renders nothing itself. |
| `lib/tools.nix` | The host catalogue: one entry per selectable tool, with its name on each channel. |
| `lib/resolve.nix` | Selection → per-channel outputs, as pure functions, testable against fixtures rather than only the catalogue. |
| `modules/nixoffice.nix` | Host policy: the group options and the selection surface. |
| `modules/nixos.nix`, `modules/arch.nix` | Host backends. |
| `examples/all/values.nix` | Placeholder values that make the render check real — and the control the eval check is written against. |
| `checks/` | `nix flake check` — three checks, none of them syntax-only. |
| `experiments/` | Open questions, and the two scripts that check facts about the world. |
| `studies/` | Findings verified once that should not need verifying again. |

## Checks

`nix flake check` runs three, and none of them is syntax-only.

**`eval-checks`** drives the host resolution with **fixture** entry tables containing entry shapes
the real catalogue does not have — which is why the resolution was split out of the module in the
first place, and how a real bug was found that no test written against the catalogue could have
caught. See [`studies/resolution-was-untestable-inline.md`](studies/resolution-was-untestable-inline.md).

**`cluster-eval`** renders the cluster module through the real grammar and the real renderer, in both
directions: an empty surface defines no app at all, the example surface renders every catalogue entry
— and then **thirty-five declarations that must each be refused**, against that control. Missing and
unsupported engines, a connection string that also names fields, an embedded engine given a server, a
directory backed against the wrong engine and one left unbacked, a watcher scaled to zero, a timer
switched on and scaled to zero, a required decision left unstated, an unauthenticated workload
declared public, a document host carrying a port, a namespace named after a workload in it. Four have
their **message** asserted by content, because `tryEval` can only say *that* something was refused.

Nine more are not refusals at all: naming an **engine's image, version or root password**, passing
verbatim manifests, giving a workload its own namespace or category or replica count. Those fail with
"the option does not exist", and asserting that keeps the boundary from being quietly widened.

**`cluster-render`** parses the manifests the surface actually produced and asserts them field by
field. Among others: every Deployment is exactly one container and none of them is a database; the
engine address is built from a Service name, a namespace and the cluster domain; a password and a
connection string are `secretKeyRef` and never values; an embedded engine is a path inside a mounted
directory with no host variable at all; the document-host patterns come out numbered and escaped;
the switchable timers are rendered off in the same manifests whose workloads are labelled
`scale-to-zero`; state forces `Recreate` on every workload that keeps anything; Cal.com and
Collabora remain `Recreate` despite empty state because their schema migration and document session
are single-writer work; each namespace is anchored exactly once and carries the annotation that
stops it being cascade-deleted; and no Service carries a pinned address, an external IP or a node
port.

Every guard has been **mutation-tested**: breaking the missing-engine assertion makes `cluster-eval`
fail on both the refusal and its message, and adding a `replicas` option back makes it fail on the
structural claim. The stateless single-writer checks are adversarial in the same way: each first
proves that no volume can be forcing the strategy and then requires `Recreate`; a volume-backed
workload is the negative control, remaining unmarked and reaching `Recreate` through state instead.

## Status

**Pre-alpha.** The cluster catalogue's knowledge is extracted from a production surface that runs all
twelve, and every image coordinate is verified against the registry that serves it — but this
repository has not yet replaced that surface's own declarations. The host half is in use as it
stands.

## Related projects

Part of the same independently-usable module family:
[nixk3s](https://github.com/julian-corbet/nixk3s-corbet-ch) (the app grammar this consumes, and the
band model its slots answer to),
[nixdb](https://github.com/julian-corbet/nixdb-corbet-ch) (the database tier that runs the engines
this repository names and refuses to operate),
[nixnotes](https://github.com/julian-corbet/nixnotes-corbet-ch) (the personal knowledge surface, and
where the scale-to-zero calibration started),
[nixflat](https://github.com/julian-corbet/nixflat-corbet-ch) (installs the Flatpak channel this
module only names),
[nixmsg](https://github.com/julian-corbet/nixmsg-corbet-ch) (a catalogue of the same shape, for
messengers),
[nixdev](https://github.com/julian-corbet/nixdev-corbet-ch) (operator tooling — where the document
*libraries* live),
[nixfont](https://github.com/julian-corbet/nixfont-corbet-ch) (fonts as a shared concern) and
[nixprint](https://github.com/julian-corbet/nixprint-corbet-ch) (printing declared).

## License

MIT License &copy; 2026 Julian Corbet
