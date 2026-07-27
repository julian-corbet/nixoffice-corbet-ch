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
{ ... }:
{
  # ── Office suite ────────────────────────────────────────────────────────────────────────────
  suite = {
    onlyoffice = { arch = "onlyoffice-bin"; nixpkgs = "onlyoffice-desktopeditors"; };
    libreoffice = { arch = "libreoffice-fresh"; nixpkgs = "libreoffice-fresh"; };
  };

  # ── Authoring / typesetting ─────────────────────────────────────────────────────────────────
  # The renderer, not the tooling around it: what turns a source document into the artifact.
  authoring = {
    typst = { arch = "typst"; nixpkgs = "typst"; };
    quarto = { arch = "quarto-cli-bin"; nixpkgs = "quarto"; };
    pandoc = { arch = "pandoc-cli"; nixpkgs = "pandoc"; };
  };

  # ── Prose editors ───────────────────────────────────────────────────────────────────────────
  # Distinct from a code editor on purpose: these are for writing English, and the person who
  # wants one usually does not want the other.
  editors = {
    ghostwriter = { arch = "ghostwriter"; nixpkgs = "ghostwriter"; };
    retext = { arch = "retext"; nixpkgs = "retext"; };
  };

  # ── Reading ─────────────────────────────────────────────────────────────────────────────────
  viewers = {
    zathura = { arch = "zathura"; nixpkgs = "zathura"; };
    evince = { arch = "evince"; nixpkgs = "evince"; };
  };
}
