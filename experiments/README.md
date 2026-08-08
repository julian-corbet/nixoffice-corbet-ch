# experiments

Throwaway trials: spikes, one-off scripts, things tried and abandoned or not yet worth writing up.
Nothing here is guaranteed to work, be maintained, or survive the next cleanup pass — except the two
files below.

- `validate-nixpkgs-names.nix` — every non-null nixpkgs attribute in [`../lib/tools.nix`](../lib/tools.nix)
  forced rather than looked up. The distinction is the point: nixpkgs turns a removed package into
  `<oldName> = throw "...";`, which keeps the key present, so an existence check passes on an
  attribute that fails at build time. It is what caught the prose editor whose top-level alias
  disappeared with a desktop environment's end of life.

- `verify-upstream-coordinates.sh` — every image coordinate in
  [`../lib/applications.nix`](../lib/applications.nix) checked against the registry that serves it,
  through the registry API. `--tags N` additionally lists what upstream is shipping right now, which
  is the question this repository deliberately cannot answer from its own data: it pins no versions
  anywhere. Reads the coordinates out of the catalogue rather than a second hand-kept list.

## Why the second one lives here and not in `checks/`

`checks/` is `nix flake check`-wired and evaluates offline. It can prove how a declaration RESOLVES
— and it does, exhaustively, including every guard in both directions and the manifests that
actually come out. What it cannot prove is that a registry still serves an image today. That is a
fact about the world: it changes without this repository changing, and asserting it at eval time
would need either network access from a pure evaluation or a snapshot that silently goes stale.

## Open questions this repository has not answered

**Two pod-spec shapes the app grammar has no term for, and both are real.** One application collides
with the environment Kubernetes injects for a Service of its own name and needs that injection
turned off; another has no database retry at all and needs something to wait for its engine's port
before it starts. Both are recorded in the catalogue's notes, and both are handled today by the
grammar's own typed merge — a consumer defines the field onto the object this module renders. The
open question is whether either is common enough across the family to deserve a term of its own, and
that is not a question one repository should answer alone.

**Whether a mount path is still where the software writes.** That is the field this catalogue is
most likely to be wrong about eventually, and there is no honest way to check it from outside the
running software: the answer lives in an image's own defaults, not in a registry's metadata. It is
verified by reading upstream's documented deployment and by running it, and it is what the `note` on
each entry exists to record.

**Whether the driver tokens stay correct.** Three engines, three tokens, none of which is the
engine's own name — and nothing in an offline check can notice the day one of them changes. The
catalogue records them in one place precisely so that the day it matters, there is one place to fix.

If something in here turns out to matter in a different way, distil the actual finding into
[`../studies/`](../studies/README.md) and let the experiment stay disposable (or delete it).

See the main [README](../README.md) for the project itself.
