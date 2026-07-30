# nixoffice

The documents half of a workstation declared — office suites, typesetting tools, prose editors,
and document viewers that a person consumes visually, resolved to the right package name on each
platform.

The scope is stated as a test, not a list: this module owns what a **person consumes visually**.
A suite you click around in, a typesetter whose output you read, an editor you write prose in, a
viewer you open a PDF with. Anything you only ever script against belongs in nixdev instead — pypdf
and pdfplumber are libraries, not documents, even though they are obviously document-shaped. That
boundary matters because it keeps the module's concerns clear: office is for rendering and reading,
not for data transformation.

## What nixoffice is

A platform-neutral NixOS module that:

- **Selects document applications by group.** suite (OnlyOffice, LibreOffice), authoring (Typst,
  Quarto, Pandoc — tools that render a source document into the thing you read), editors (Ghostwriter,
  Retext — tools for writing prose), and viewers (Zathura, Evince — tools for reading).
- **Resolves to platform-specific package names.** Via `lib/tools.nix`, each application maps to a
  pacman package and a nixpkgs attribute, or null where no equivalent exists.

It exists in three forms:

- `nixoffice.nix`: the declarative policy and selection logic.
- `modules/nixos.nix`: the NixOS backend, which installs via `environment.systemPackages`.
- `modules/arch.nix`: the Arch / system-manager backend, which publishes `nixoffice.archPackages`
  and `nixoffice.aurPackages` for the host's own reconciler to consume.

Every application is selected explicitly by the operator, never defaulted. An empty selection is a
legitimate answer — for a machine that has no office needs, or whose operator uses web-based
alternatives instead.

## What it explicitly does not own

- **Document processing libraries.** pypdf, pdfplumber, extract-msg, and other tools you script
  with belong in nixdev, because the difference is consumption: do you look at it, or does only a
  program? If a program does, it is dev. This is the boundary that keeps office concerns separate
  from automation.
- **Editor configuration.** nixoffice installs Ghostwriter or Retext, but the settings, color
  schemes, and per-user plugins belong to that editor's own configuration files or nixarch, not
  here.
- **Typesetting compiler options.** Typst is here (you look at the PDF), but tinymist (the Typst
  LSP) and typstyle (the formatter) are in nixdev, because they are editor plumbing you use when
  *writing* the source, not the rendering. The test is again consumption: editor tooling you script
  against stays in nixdev.
- **Font rendering or metric definitions.** nixoffice consumes fonts from nixfont (which another
  module provides), but the rendering pipeline and font selection for specific documents belong to
  the application itself.
- **PDF markup or annotation.** Opening a PDF is nixoffice's concern. Adding comments or signatures
  is beyond this scope — it belongs to workflow or security modules if they exist.

## Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | Flake entry point: `nixosModules.default` (NixOS install), `systemManagerModules.default` (Arch publish), and `nixoffice.nix` (the module). |
| `modules/` | Platform backends: `nixos.nix` and `arch.nix`. |
| `lib/tools.nix` | The application catalogue: one entry per selectable tool, with platform-specific package names. |

## Platform support

**NixOS:** Full. Selections resolve to nixpkgs attributes; the NixOS backend installs via
`environment.systemPackages`.

**Arch / CachyOS (via system-manager):** Publishes `nixoffice.archPackages` and
`nixoffice.aurPackages` for the host's reconciler to consume. Cannot install packages itself.

## Related projects

Part of the same independently-usable NixOS module family: [nixdev](https://github.com/julian-corbet/nixdev-corbet-ch)
(operator tooling), [nixfont](https://github.com/julian-corbet/nixfont-corbet-ch) (fonts as a shared
concern), [nixprint](https://github.com/julian-corbet/nixprint-corbet-ch) (printing declared), and
[nixram](https://github.com/julian-corbet/nixram-corbet-ch) (memory-pressure tuning).

## License

MIT License &copy; 2026 Julian Corbet
