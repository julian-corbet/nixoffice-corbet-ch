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
    # `nixpkgs` is the kdePackages attribute, NOT the bare name: the top-level `ghostwriter` alias
    # was removed with KDE Gear 5 / Plasma 5's end of life and now THROWS when forced. A throwing
    # alias is still an attribute, so `hasAttrByPath` passes it -- only forcing the derivation
    # catches it. Same trap, same fix as `kdenlive` -> `kdePackages.kdenlive`.
    ghostwriter = { arch = "ghostwriter"; nixpkgs = "kdePackages.ghostwriter"; };
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
  # onto a desktop that has just finished removing KDE. Zathura is the reading half: its glib file
  # monitor reloads a PDF when a typesetter replaces it, which makes it the viewer for a watched
  # Typst build rather than merely another way to open a finished file. Xournal++ is the
  # stylus/markup half.
  #
  # Arch splits the shell from its document backends, and the shell alone cannot open a PDF. Name
  # the MuPDF backend as the package: it depends on the shell and therefore resolves one catalogue
  # selection to a working PDF viewer. Nixpkgs' top-level `zathura` is already the corresponding
  # wrapper with its plugins, so its channel needs no second entry.
  viewers = {
    papers = { arch = "papers"; nixpkgs = "papers"; };
    zathura = { arch = "zathura-pdf-mupdf"; nixpkgs = "zathura"; };
    xournalpp = { arch = "xournalpp"; nixpkgs = "xournalpp"; };
  };

  # ── Applications that are documents-adjacent but not documents ──────────────────────────────
  #
  # This group exists because nothing else owns an ordinary desktop application. A trip planner
  # is not a document by this file's own test -- it renders nothing you read later -- and it is
  # filed here by decision rather than by rule, which is worth saying plainly so the test above
  # is not quietly widened to fit it. If a general desktop-application domain ever appears, this
  # group is what moves.
  apps = {
    # Flatpak-only: not in any Arch repo, and the project renamed itself from Railway to DieBahn,
    # so the id and the name disagree with each other in the obvious search.
    diebahn = { arch = null; nixpkgs = "diebahn"; flatpak = "de.schmidhuberj.DieBahn"; };
  };
}
