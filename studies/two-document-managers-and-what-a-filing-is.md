# Two document managers, and the difference that is not "one is newer"

**Finding.** This repository catalogues two document management systems in one category, and they
are not a migration in progress. They answer the same question — *where do the documents I received
go* — with two genuinely different answers, and the difference is mechanical rather than editorial:

> One is a **pipeline**: it transforms what you give it and owns the result.
> The other is a **shelf**: it keeps the file you gave it and builds an index over it.

Both projects describe themselves as document management. That word is exactly where this question
gets lost, which is why the distinction became a catalogue field (`ingest`) rather than a paragraph.

**What this is based on.** What each one does to a file between receiving it and having it: which
processes run, what ends up on disk, and what else has to exist for either to work at all. Not their
project descriptions.

## The two claims, side by side

| | pipeline | shelf |
|---|---|---|
| what happens to the file | OCR, classification against a model trained on **your own past filing decisions**, correspondent and type matching, renamed by a template built from those fields, and an archive copy kept beside the original | it is stored, its text is extracted for search, and it is left alone |
| what is on disk afterwards | the software's **output**: a derived document under a name the software composed | the file you gave it, under a name you can predict |
| what else must be running | an engine, **a broker**, and (for office formats) two converter services | an engine |
| how many moving parts | a web server and three workers under a supervisor, plus the above | one process |
| intake | a watched directory **and a mailbox it polls** | a watched directory |
| tenancy | per-user, with permissions on documents | per-organisation, and the intake path itself is organisation-scoped |
| engines it accepts | three, one of them embedded — **and the embedded one is what you get by saying nothing** | one, embedded, and it is the only choice there is |
| can it idle at zero | **no.** Its watcher and its scheduler are not requests, and neither can be switched off | **yes, if its watcher is off** — and that is a declaration, not a property |

## Where the real line falls

**It is not "readable files versus opaque database".** That was the first hypothesis and it does not
survive contact with either one. Both write files to disk; both name them from database fields; both
are unreadable-in-practice without their records, because a directory of documents named after
correspondents and dates is still a directory whose meaning is in the index. Both entries carry a
`corpus` **and** a `corpusInEngine`, and both are in `splitCorpora` for exactly that reason.

**It is what the software is authoritative for.** The pipeline's copy is a *product*: it exists
because the software made it, in the shape the software decided, and re-deriving it means re-running
the pipeline. The shelf's copy is *custody*: it is the artefact you handed over, and the software's
contribution is knowing where it is. That difference decides everything operational about them —
what a restore has to reproduce, what a migration away costs, and whether a human dropping a file
into a directory is doing input or is doing filing.

## What running both actually costs

Not nothing, and it is worth being specific rather than reassuring:

- **Two intake points, both of which claim to be where documents go**, and nothing reconciling them.
  A document filed in one is invisible to the other. That is a decision to make once and write down,
  not a state to drift into.
- **One permanently resident pod.** The pipeline cannot sleep, so it is a standing cost whether or
  not anybody uses it this month; the shelf can, with its watcher off. Running both means paying for
  the first and choosing for the second.
- **Three more things somebody else has to run** — the pipeline's broker and its two converter
  services — none of which the shelf needs and none of which this repository renders.
- **Two OCR passes on anything fed to both**, and two search indexes over overlapping content.

What it does **not** cost is confusion about which one is "the real one", provided the choice is
made on the axis above. A household or a person who wants the archive to be the software's product —
classified, templated, searchable, with an archive PDF of every scan — wants the pipeline. One who
wants the archive to be a directory they could hand to somebody else, with an index over it, wants
the shelf.

## What it decided here

1. **The `ingest` field**, with values `pipeline` and `shelf`, which is the only thing separating the
   two claims without appealing to marketing. `checks/cluster-eval.nix` asserts that the two entries
   in this group carry *different* values, so if either changed to match the other the check fails
   rather than the claim quietly stopping being true.
2. **The category holds both, and is named after neither.** That is what a category is for here — a
   container that outlives any one application in it — and it is why the module refuses a namespace
   named after an application in the catalogue *or* after a workload declared in it. The day a
   second document manager arrives, a namespace named after the first would make it a guest in its
   own category, and the only fix is a rename, which is a migration.
3. **The example renders both**, so the pair is visible in the checked output rather than described
   in prose: one resident, one asleep, in one namespace, with one anchoring it.
