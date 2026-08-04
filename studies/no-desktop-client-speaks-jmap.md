# No desktop mail client speaks JMAP

**Finding:** picking a mail client on JMAP support would mean picking nothing. JMAP is in practice
a server-to-web-and-mobile protocol; the desktop story is IMAP, on purpose, not as a compatibility
shim. Calendar is a separate protocol question again, and its answer is CalDAV regardless of what
the mail server speaks.

This is why `lib/tools.nix` has no mail or calendar entry. The omission is a decision, recorded so
it is not rediscovered as an oversight.

## What was checked

None of the mainstream desktop clients speak JMAP: Thunderbird, Evolution, Geary, KMail, aerc,
neomutt. Thunderbird has discussed it for years and never shipped it.

That is not a gap in those clients. A JMAP server also serves IMAP4 precisely because IMAP is the
protocol desktop clients are built around — JMAP's design centre is a web or mobile client talking
to a server over HTTP, where IMAP's connection model is the actual problem being solved.

## Calendar is a different question

JMAP-for-calendars exists on paper with near-zero client support. Calendar and contacts are
CalDAV/CardDAV whatever the mail server does, so the mail decision does not constrain the calendar
decision at all — they are two independent choices that happen to be made by one application.

## Where this leaves the entry

An ordinary IMAP + CalDAV + CardDAV client, when it is declared. Two were evaluated:

| Candidate | Size | Note |
|---|---|---|
| `evolution` | ~84 MiB | One app covering mail, calendar and contacts. GTK. |
| `thunderbird` | ~298 MiB | The most widely tested desktop mail client there is. |

Neither was declared. The decision was **deferred, not made** — a catalogue entry nobody has
selected is a claim the table cannot back, which is the same reason `zathura` and `evince` were
removed rather than left in place.
