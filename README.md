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

- **Selects document applications by group.** `suite` (an office suite), `authoring` (tools that
  render a source document into the thing you read), `editors` (tools for writing prose),
  `viewers` (tools for reading and annotating), and `apps` (ordinary desktop applications that are
  documents-adjacent without being documents — see `lib/tools.nix` for why that group exists).
- **Resolves to platform-specific package names.** Via `lib/tools.nix`, each application maps to a
  pacman package, an AUR package, a Flatpak id, and a nixpkgs attribute — **each independently
  nullable**, because an application really can exist on some of those channels and not others.
  `lib/resolve.nix` turns a selection into one list per channel.

It exists in three forms:

- `modules/nixoffice.nix`: the declarative policy and selection logic.
- `modules/nixos.nix`: the NixOS backend, which installs via `environment.systemPackages`.
- `modules/arch.nix`: the Arch / system-manager backend, which publishes `nixoffice.archPackages`
  and `nixoffice.aurPackages` for the host's own reconciler to consume.

## The Flatpak channel

An application with no pacman name at all resolves to Flatpak, and appears in
`nixoffice.flatpakApps` as `{ id; remoteName; remoteUrl; }` — id and remote **together**, never a
bare id list, because a bare id can only assume Flathub and that assumption is wrong often enough
to matter.

Nothing here installs them. Flatpak is neither pacman nor nixpkgs, so this list is inert until a
host wires it to something that runs `flatpak install`;
[nixflat](https://github.com/julian-corbet/nixflat-corbet-ch) is written against exactly this
shape and takes several catalogues at once:

```nix
nixflat.apps = config.nixoffice.flatpakApps ++ config.nixmsg.flatpakApps;
```

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
- **Mail and calendar.** Absent on purpose, not by oversight — no mainstream desktop client speaks
  JMAP, and calendar is a different protocol again. See
  [`studies/no-desktop-client-speaks-jmap.md`](studies/no-desktop-client-speaks-jmap.md) for what
  was checked and which two candidates were evaluated without being declared.

## Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | Flake entry point: `nixosModules.default` (NixOS install), `systemManagerModules.default` (Arch publish), `lib.catalogue`, `lib.resolve`, `checks`. |
| `modules/nixoffice.nix` | Platform-neutral policy: the group options and the selection surface. |
| `modules/nixos.nix`, `modules/arch.nix` | Platform backends. |
| `lib/tools.nix` | The application catalogue: one entry per selectable tool, with its name on each channel. |
| `lib/resolve.nix` | Selection → per-channel outputs, as pure functions. Separate from the module so they can be tested against fixture tables rather than only the catalogue. |
| `checks/` | `nix flake check` — eval-time proof of the resolution, including entry shapes the catalogue does not contain. |
| `studies/` | Findings verified once that should not need verifying again. |
| `experiments/` | Open questions: defaults and inferences that are reasoned, not measured. |

## Platform support

**NixOS:** Full. Selections resolve to nixpkgs attributes; the NixOS backend installs via
`environment.systemPackages`.

**Arch / CachyOS (via system-manager):** Publishes `nixoffice.archPackages` and
`nixoffice.aurPackages` for the host's reconciler to consume. Cannot install packages itself.

**Flatpak, either platform:** publishes `nixoffice.flatpakApps`. Cannot install them either — see
above.

## Related projects

Part of the same independently-usable NixOS module family:
[nixflat](https://github.com/julian-corbet/nixflat-corbet-ch) (installs the Flatpak channel this
module only names), [nixmsg](https://github.com/julian-corbet/nixmsg-corbet-ch) (a catalogue of
the same shape, for messengers), [nixdev](https://github.com/julian-corbet/nixdev-corbet-ch)
(operator tooling — where the document *libraries* live),
[nixfont](https://github.com/julian-corbet/nixfont-corbet-ch) (fonts as a shared concern),
[nixprint](https://github.com/julian-corbet/nixprint-corbet-ch) (printing declared), and
[nixram](https://github.com/julian-corbet/nixram-corbet-ch) (memory-pressure tuning).

## License

MIT License &copy; 2026 Julian Corbet
