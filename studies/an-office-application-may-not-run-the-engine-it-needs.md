# An office application may not run the engine it needs, and the fallback is why

**Finding.** Nine of the twelve applications this repository catalogues need a database, and they do
not agree on which: Postgres, MariaDB, MongoDB, Redis and an embedded SQLite are all represented,
and several accept more than one. None of them is this repository's to run — a sibling owns engines.

That much is a boundary anybody would write in a README. What makes it a *design* is the failure
mode on the other side of it:

> Four of these applications start perfectly happily with **no database configuration at all**. They
> create a database inside their own container, come up, work, and report themselves healthy. One of
> them ships an entire database **server** inside its image, and the only thing that stops it
> starting that server is being told a host that is not localhost.

A boundary whose violation *fails* needs a note. A boundary whose violation **succeeds** needs a
mechanism.

**What this is based on.** The twelve applications' own configuration as deployed: which variables
each one reads, what its image does when they are absent, and what its entrypoint starts.

## The three shapes a connection actually comes in

Not a taxonomy invented for the module — it is what the software forces, and each shape has a
different operational consequence:

| | how the software takes it | what that costs |
|---|---|---|
| **fields** | host, port, database and user as separate variables; only the password is secret | the address can be **derived** from a Service name and a namespace, so nobody writes a cross-namespace address by hand |
| **dsn** | one connection string | opaque or credential-bearing strings stay in Secrets; a credential-free in-cluster Service URL can be **derived** only from a catalogue-approved scheme and typed address pieces |
| **file** | a path inside one of its own directories | there is no address, no user and no password — and the directory holding it becomes load-bearing |

The `dsn` row is the interesting one. Five connections here have that shape because their software
reads one value. Four are opaque database strings that may carry credentials, so the module refuses
to let them be anything but Secret references. One is a passwordless Redis broker in the same
namespace as its application. For that narrower shape, hiding the address in a Secret loses useful
validation without protecting anything: `serviceDsn` takes a catalogue-approved scheme, a bare
Service name and a port, then derives the namespace and cluster domain from the platform. It cannot
carry userinfo, a raw host, a path or a query. If that connection ever acquires a credential, it must
move to the unchanged Secret-backed `dsn` form.

## What is structural, and what is merely checked

Four things about the engine rule cannot be written wrong, and one is checked:

1. **Nothing here can render an engine.** There is no `manifests` option, no `raw` passthrough and
   no second image anywhere in the cluster module: one declaration produces exactly one container,
   through somebody else's app grammar. `checks/cluster-render.nix` reads that back off the bytes —
   every rendered Deployment has exactly one container, none of them is an engine image, and there
   are no init containers.
2. **There is nowhere to name an engine's image, version, storage or root credential.** Those are
   unknown options, asserted as such in `checks/cluster-eval.nix`, so adding one back breaks the
   check rather than quietly widening the surface.
3. **A required connection is defaultless**, and its absence fails evaluation with a message that
   explains the embedded fallback rather than restating the rule.
4. **Which engines a piece of software speaks is the catalogue's**, measured from the software; a
   connection pointed at one outside that set is refused by name. That one is an assertion rather
   than a missing enum value, because the option's type would have to depend on a sibling option's
   value inside the same submodule — which is a recursion, not a design.

## The directory that must be backed exactly when it is used

An embedded engine lives in a directory, and that turns out to need two rules rather than one:

- with the embedded engine chosen, the directory holding it **must** be backed — the failure
  otherwise is not a lost cache, it is the entire database;
- with an external engine chosen, the same directory **must not** be backed, because nothing will
  ever write in it and a backing for a database file that does not exist reads, to everybody who
  comes after, as though the data were in there.

Three catalogue entries have a directory that exists *only* for that purpose, and two more have one
that holds the embedded database **and** other things it cannot lose. So `state.<key>` carries
`required` and `embeddedFor` as separate fields, and the demanded set is computed from the engine
the declaration chose.

## What it decided

- **`needs.<role>` is keyed by the role a connection plays, not by the engine family.** One
  application here opens two SQL connections, to two different databases, for two different
  purposes; a table keyed by `sql` could not say so.
- **Every wiring style is recorded per engine kind**, including the driver token — which for one
  application is a different string from the engine's own name for all three of its engines, and a
  catalogue that reused the engine key would produce a startup failure about an unknown client.
- **`engineRequirements` is published rather than checked.** One application needs its document
  store to be a *replica set*, even with a single member, because it uses transactions a standalone
  server refuses: a perfectly healthy engine of the right kind and version still produces an
  application that fails on write. This repository can state that requirement and has no way to
  verify it, and saying so is better than either pretending or omitting.
- **`externalEngines` is countable.** It is the list of things that must exist before any of this
  starts, and an embedded engine is deliberately absent from it — there is nothing for anybody else
  to run.

## The honest gap

Two of these applications also want *non-database* services this repository names and does not wire:
a content extractor and a document converter, reached over HTTP. Those arrive as ordinary addresses
in the declaration's own `env`, exactly like any other fleet fact, and they are **not** modelled as
connections — they are somebody else's workloads with no shared connection grammar to speak of. The
same is true in the other direction of any broker or converter that a deployment chooses to run
beside an application: this repository will not render it, and that is the rule working rather than
a gap in it.
