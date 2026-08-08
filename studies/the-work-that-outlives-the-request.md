# The work that outlives the request, and why scale-to-zero needed three answers here

**Finding.** Idling a workload at zero replicas is lossless for software that computes everything in
answer to a request, and lossy in a specific and invisible way for software that does not. A sibling
repository worked that out for a link archive and made it a refusal; a second worked it out for a
chore scheduler and made it a warning. **Both are right, and this repository needed both — plus a
third answer neither of them has.**

Twelve applications is enough for the axis to become visible: what matters is not *whether* work
outlives the request, but **what fires it**.

**What this is based on.** Which of the twelve runs a timed loop, a filesystem watcher, or neither;
and for the ones that do, whether it can be switched off. Taken from what each one's process tree
starts and what its own configuration exposes, not from its description.

## The three triggers, and the three verdicts

| trigger | what it is | at zero replicas | verdict |
|---|---|---|---|
| **timer** | an in-process scheduler: reminder mail, recurring items, a conversion queue, a flush of buffered edits | the interval does not happen. Nothing is late; it is **never evaluated** | **refused** |
| **watch** | a watcher on an intake directory | a file copied there produces **no HTTP request at all**, so nothing can wake it and the drop is never seen | **refused** |
| **caller** | something outside the pod calls a scheduled endpoint | the call **wakes** the pod, and then waits out the cold start inside its own timeout | **warned** |

The `watch` row is the one worth stating slowly, because it is the strongest case in this repository
and it is not obvious. A wake front counts requests. A document manager whose intake is a directory
does not receive requests when a document arrives — somebody copies a file, over a file share, from
a scanner, from another machine entirely. There is no HTTP anywhere in that path. So the pod is not
woken *late*, it is not woken at all: the file sits in the directory, nothing is degraded, no probe
fails, no log line appears, and the document is simply not filed. Discovering it means noticing that
something you scanned three weeks ago is not in the archive.

The `caller` row is the calibrated middle, and this repository has exactly one: a booking service
whose reminder mail and outbound webhook deliveries are dispatched when something outside the pod
calls its task endpoints. Nothing is lost — that call *is* the wake. What it costs is a cold start
of about a minute paid out of the caller's own timeout, and a caller with a short one gives up and
skips the batch silently. That is worth a warning and is not worth a refusal, because whether it
matters depends on the caller, which this repository knows nothing about.

## The fourth answer: a group where the value does not exist

The collaborative editors are not on this axis at all, and that is what makes them a group.

Their unit of work is a **session**, not a request: a long-lived connection holding a document that
has been changed and not yet written back to the system that owns it. A wake front sees an idle
connection count and takes the pod away in the middle of it. So `scale-to-zero` is **not in that
group's `scaling` enum** — a missing value rather than a guard that fires, following the same
reasoning a sibling used for a renderer that must never be `public`: the property belongs to the
*group's definition* rather than to any entry in it, so any software that would belong in the group
has it too. Widening it means editing this repository and writing down why.

## The half that is a decision rather than a property

Two entries here can have their background work **switched off**, and one more only has any if
somebody authored it. That is not a detail — it is the difference between a workload that must be
resident forever and one that costs nothing while nobody is using it:

- a task manager's reminder mail is a setting. Off, everything it computes is computed for a caller,
  and it idles at zero quite safely. On, it runs a timer.
- a document manager's intake watcher is a setting, with exactly the consequence described above.
- a record platform's scheduled work exists **only if somebody built an automation with a schedule
  trigger**. There is no variable to inspect; the answer is a fact about how the instance is used.

So `backgroundWork` is a **required statement** on those declarations, refused everywhere else. Not
defaulted, because no default is right for both answers and the wrong one is silent in both
directions. And where the software has a real switch, the module **renders that switch from the same
boolean the guard reads** — so a declaration claiming reminders are off cannot be running with them
on. That is the strongest form available of "a catalogue field decides and a consumer cannot
override": the statement and the running process are the same value.

## The separate axis: heavy is not the same as lossy

Several of these are genuinely heavy — an office suite that pre-forks a document process per open
file, a typesetting service carrying a whole distribution, a document pipeline that opens a search
index on boot. Cold starts range from ten seconds to two minutes, and every one of them is measured
from a running deployment rather than estimated.

That cost is real and it is **not** a correctness problem, so it gets its own warning with a number
in it, above a threshold the consumer can move. Judgements about people get warnings; correctness
gets refusals. A workload can be perfectly safe to sleep and still be a bad idea to sleep, and
conflating those two would have made the refusals easy to ignore.

## What it decided

1. **`background` on every catalogue entry**: `null`, or a trigger plus a description of what
   actually happens plus an optional toggle. A `null` is a claim rather than a blank, and the
   catalogue check requires every entry to make one.
2. **`coldStart = { seconds; what; }` on every entry**, measured, which is what turns the second
   warning from a feeling into a number.
3. **The refusals name the mechanism rather than the rule.** `checks/cluster-eval.nix` asserts the
   *text* of the watcher refusal, because a refusal that does not explain a failure nobody would
   guess is only half a refusal.
4. **`nixoffice.cluster.mustStayAwake`**, a read-only map from workload to the work that only
   happens while it is running. It is the standing cost of the surface stated as data — and two
   entries can leave that list by a declaration rather than by a migration.
