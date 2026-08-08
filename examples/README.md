# examples

Placeholder values that make this repository's checks real, and the shortest readable answer to
"what does a declaration actually look like".

- [`all/values.nix`](all/values.nix) — one complete surface: **one workload of every group and every
  entry in the catalogue**, in nine categories, two of which hold two applications each. A wiki
  whose pages are in an engine and whose pictures are on disk; two document managers answering one
  question differently, one resident and one asleep; two task managers in one category and a board
  in another; a booking page taking its whole connection as one string in a Secret; two
  collaborative editors, one with no state and no engine at all; a typesetting service needing two
  engines of two different families at once; and a record platform whose embedded-engine directory
  is absent precisely because it runs on an external one.

  It is not only an example. `checks/cluster-eval.nix` uses this file as its **control** — the
  surface that must render, against which every refusal is one thing changed — and
  `checks/cluster-render.nix` parses the manifests it produced and asserts them field by field. So
  the example cannot drift away from the shape the checks call correct, and a catalogue entry
  nobody exercises here fails a check rather than going unnoticed.

**Nothing in here is real.** Every namespace, node path, Secret name, image reference, origin, band
and slot number is invented for the check. That is not a disclaimer, it is the design: every one of
those is a fleet fact, and this repository supplies none of them — see the main
[README](../README.md).
