#
# The office catalogue: things a human reads, writes and looks at.
#
# THE LINE THIS DRAWS. Document *processing* libraries -- pypdf, pdfplumber, extract-msg -- are
# not here even though they are obviously "document" tools. They belong in nixdev, because you
# script with them; you never look at them. The test is consumption, not subject matter: office is
# what renders something for a person to read.
#
# By the same test typst is here (you look at the PDF) while tinymist and typstyle are not -- an
# LSP and a formatter are editor plumbing, and they live in nixdev alongside the other toolchains.
#
# DELIBERATELY ABSENT: mail and calendar. Not an oversight -- the omission is recorded here so the
# next reader does not have to rediscover why.
#
# No mainstream desktop client speaks JMAP. Not Thunderbird, Evolution, Geary, KMail, aerc or
# neomutt; it has been discussed for Thunderbird for years and never shipped. JMAP is in practice
# a server-to-web-and-mobile protocol, which is why a JMAP server also serves IMAP4 -- IMAP is the
# desktop story on purpose, not a compatibility shim. Choosing a client on JMAP support would mean
# choosing nothing.
#
# Calendar is a different protocol again: JMAP-for-calendars exists on paper with near-zero client
# support, so calendar and contacts are CalDAV/CardDAV whatever the mail server does.
#
# So the entry, when it comes, is an ordinary IMAP + CalDAV + CardDAV client -- evolution (one app,
# all three, GTK, ~84 MiB) or thunderbird (~298 MiB, the most widely tested client there is). Both
# were evaluated; neither was declared, because the decision was deferred rather than made.
{ ... }:
{
  # ── Office suite ────────────────────────────────────────────────────────────────────────────
  suite = {
    onlyoffice = { arch = "onlyoffice-bin"; nixpkgs = "onlyoffice-desktopeditors"; };
  };

  # ── Authoring / typesetting ─────────────────────────────────────────────────────────────────
  # The renderer, not the tooling around it: what turns a source document into the artifact.
  authoring = {
    typst = { arch = "typst"; nixpkgs = "typst"; };
    quarto = { arch = "quarto-cli-bin"; nixpkgs = "quarto"; aur = true; };
    pandoc = { arch = "pandoc-cli"; nixpkgs = "pandoc"; };
  };

  # ── Prose editors ───────────────────────────────────────────────────────────────────────────
  # Distinct from a code editor on purpose: these are for writing English, and the person who
  # wants one usually does not want the other.
  editors = {
    ghostwriter = { arch = "ghostwriter"; nixpkgs = "ghostwriter"; };
    retext = { arch = "retext"; nixpkgs = "retext"; };

    # Obsidian is a prose editor by use even though it is a knowledge base by design: it edits
    # plain Markdown on disk, which is what makes it belong to a documents catalogue rather than
    # to a notes service. Nothing here manages a vault -- where the files live and what is in
    # them is the consumer's, and this table only says which program opens them.
    obsidian = { arch = "obsidian"; nixpkgs = "obsidian"; };
  };

  # ── Reading and marking up ──────────────────────────────────────────────────────────────────
  #
  # A reader and an annotator, deliberately two tools rather than one. The single-binary answer
  # here is okular, which does both plus forms and signatures -- and pulls 42 KDE/Qt6 packages
  # onto a desktop that has just finished removing KDE. papers is Evince's GTK4 successor and
  # xournalpp is the stylus/markup half; together they cover reading and annotating without
  # reintroducing a framework stack for two features.
  #
  # zathura and evince were here and are not any more: zathura's keyboard-driven minimalism reads
  # as a TUI but it is a GTK application, and neither was ever installed on a consuming host --
  # a catalogue entry nobody selects is a claim this table cannot back.
  viewers = {
    papers = { arch = "papers"; nixpkgs = "papers"; };
    xournalpp = { arch = "xournalpp"; nixpkgs = "xournalpp"; };
  };
}
