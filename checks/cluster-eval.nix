# Proves the cluster module resolves what it claims and REFUSES what it claims to refuse, both
# directions, through the real renderer and the real app grammar.
#
# Both halves matter and neither is enough alone. A guard nobody has watched fire is a comment; a
# guard that fires on everything is a wall. So every case below is the complete, valid surface from
# ../examples/all/values.nix with exactly one thing wrong, and that same surface unmodified is the
# `control` and MUST render -- without it, a typo in the shared base would make every other case
# "pass" for the wrong reason.
#
# THE CONTROL IS THE EXAMPLE FILE ITSELF, deliberately. It declares one workload of every group and
# every entry in the catalogue, so the example cannot drift away from the shape this check calls
# correct, and a catalogue entry nobody exercises cannot appear.
#
# ── THE PART THAT IS NOT AN ASSERTION ──────────────────────────────────────────────────────────
#
# Several of the most important refusals here are not guards at all. Giving a workload its own
# namespace or its own category, giving it a replica count, passing verbatim manifests -- and, most
# of all, naming an ENGINE'S IMAGE OR VERSION anywhere -- are UNKNOWN OPTIONS. They fail with "the
# option does not exist", which is the difference between a boundary somebody has to remember and
# one nobody can cross. Those are in `structurallyImpossible` below, so re-adding any of those
# options would break this check rather than quietly widening the surface.
#
# One more is a refused VALUE rather than a missing option, and it is in `mustFail` with the guards:
# a collaborative editor declared `scale-to-zero`, which that group's enum does not have.
#
# Four refusals additionally have their MESSAGE asserted by content, because `tryEval` can only say
# THAT something was refused: the missing-engine refusal (it has to explain that the software will
# silently use one inside its own container), the watcher refusal (it has to explain a failure with
# no HTTP request anywhere in it), the unsupported-engine refusal (it has to name both what was
# asked for and what the software speaks) and the namespace-naming refusal (it has to name the
# category, since that is the thing that outlives the application).
{ pkgs, lib, nixidy, appsModule, addressingModule, clusterModule }:
let
  good = import ../examples/all/values.nix;

  mkEnv = values: nixidy.lib.mkEnv {
    inherit pkgs;
    modules = [ appsModule addressingModule clusterModule values ];
  };

  renders = values:
    (builtins.tryEval (builtins.seq (mkEnv values).environmentPackage.drvPath true)).success;

  # The assertions themselves rather than the throw they eventually cause.
  failures = values:
    map (a: a.message)
      (lib.filter (a: !a.assertion) (mkEnv values).config.nixidy.assertions);

  sorted = lib.sort (a: b: a < b);

  ## ---------------------------------------------------------------------
  ## The floor: an empty surface renders nothing at all
  ## ---------------------------------------------------------------------

  emptyCfg = (mkEnv {
    nixidy.target.repository = "https://example.com/example-org/example-gitops.git";
    nixidy.target.branch = "main";
  }).config;

  goodCfg = (mkEnv good).config;

  ## ---------------------------------------------------------------------
  ## The failing direction: guards
  ## ---------------------------------------------------------------------

  mustFail = {
    # ── The engine rule, which is this repository's main claim ─────────────────────────────────

    # THE ONE THAT MATTERS MOST. Say nothing about the database and this software does not fail --
    # it makes one inside its own container and reports itself healthy.
    required-engine-connection-left-undeclared =
      lib.recursiveUpdate good { nixoffice.cluster.filings.pipeline.connections = lib.mkForce { }; };

    engine-the-software-does-not-speak =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.connections.database.engine = "postgres"; };

    connection-role-the-software-does-not-open =
      lib.recursiveUpdate good {
        nixoffice.cluster.wikis.pages.connections.cache = {
          engine = "redis";
          service = "example-keyvalue";
          namespace = "example-engines";
        };
      };

    # A `service` is a NAME. The address is derived from it, the namespace and the cluster domain,
    # which is the whole point of not letting a host be written here.
    field-connection-given-an-address-instead-of-a-service-name =
      lib.recursiveUpdate good {
        nixoffice.cluster.wikis.pages.connections.database.service = "example-sql.example-engines.svc";
      };

    field-connection-with-no-password =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.connections.database.password = null; };

    field-connection-also-given-a-connection-string =
      lib.recursiveUpdate good {
        nixoffice.cluster.wikis.pages.connections.database.dsn = { secret = "x"; key = "y"; };
      };

    connection-string-naming-no-secret =
      lib.recursiveUpdate good { nixoffice.cluster.trackers.board.connections.database.dsn = null; };

    # The fields would be a second copy of what is inside the string, and the string is the half the
    # software reads.
    connection-string-also-naming-fields =
      lib.recursiveUpdate good { nixoffice.cluster.trackers.board.connections.database.user = "example"; };

    embedded-engine-given-a-server-to-connect-to =
      lib.recursiveUpdate good {
        nixoffice.cluster.trackers.tasks.connections.database.service = "example-sql";
      };

    # ── Storage ────────────────────────────────────────────────────────────────────────────────

    required-directory-left-unbacked =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.state = lib.mkForce { }; };

    # The directory holding an EMBEDDED engine, with that engine chosen.
    embedded-engine-directory-left-unbacked =
      lib.recursiveUpdate good {
        nixoffice.cluster.trackers.tasks.state = lib.mkForce {
          files.hostPath = "/example/state/tasks-files";
        };
      };

    # ... and the other direction: backed, with an external engine chosen, so nothing will ever
    # write in it and the backing reads as though the data were there.
    embedded-engine-directory-backed-against-an-external-engine =
      lib.recursiveUpdate good {
        nixoffice.cluster.records.contacts.state.database.hostPath = "/example/state/records-db";
      };

    state-key-the-catalogue-does-not-hold =
      lib.recursiveUpdate good {
        nixoffice.cluster.wikis.pages.state.attachments.hostPath = "/example/state/pages-extra";
      };

    state-with-both-backings =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.state.config.claim = "example-pages"; };

    state-with-neither-backing =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.state.config.hostPath = null; };

    # ── Credentials ────────────────────────────────────────────────────────────────────────────

    credential-role-the-software-does-not-read =
      lib.recursiveUpdate good {
        nixoffice.cluster.wikis.pages.credentials.rootPassword = { secret = "x"; key = "y"; };
      };

    missing-required-credential-role =
      lib.recursiveUpdate good { nixoffice.cluster.trackers.board.credentials = lib.mkForce { }; };

    # ── The work that outlives the request ─────────────────────────────────────────────────────

    # A WATCHER. No request exists at any point, so nothing can ever wake it.
    watcher-workload-scaled-to-zero =
      lib.recursiveUpdate good { nixoffice.cluster.filings.pipeline.scaling = "scale-to-zero"; };

    # A TIMER that this declaration switched ON, while also asking for zero replicas.
    timer-switched-on-and-scaled-to-zero =
      lib.recursiveUpdate good { nixoffice.cluster.trackers.tasks.backgroundWork = true; };

    background-work-stated-on-software-that-does-none =
      lib.recursiveUpdate good { nixoffice.cluster.trackers.board.backgroundWork = true; };

    background-work-stated-where-it-is-not-optional =
      lib.recursiveUpdate good { nixoffice.cluster.filings.pipeline.backgroundWork = false; };

    # A REQUIRED DECISION. Which way it is set decides whether the workload may sleep.
    background-work-left-unstated-where-it-is-optional =
      lib.recursiveUpdate good { nixoffice.cluster.filings.shelf.backgroundWork = lib.mkForce null; };

    # The one group whose enum has no `scale-to-zero` in it at all.
    coeditor-declared-scale-to-zero =
      lib.recursiveUpdate good { nixoffice.cluster.coeditors.editing.scaling = "scale-to-zero"; };

    # ── Reachability ───────────────────────────────────────────────────────────────────────────

    unauthenticated-workload-declared-public =
      lib.recursiveUpdate good { nixoffice.cluster.records.profile.exposure = "public"; };

    public-url-missing-on-software-that-needs-one =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.publicUrl = null; };

    public-url-set-on-software-that-reads-none =
      lib.recursiveUpdate good {
        nixoffice.cluster.coeditors.editingsuite.publicUrl = "https://suite.example.com";
      };

    public-url-carrying-a-path-of-its-own =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.publicUrl = "https://pages.example.com/wiki"; };

    document-hosts-missing-on-an-editor-configured-from-this-end =
      lib.recursiveUpdate good { nixoffice.cluster.coeditors.editing.documentHosts = lib.mkForce [ ]; };

    document-hosts-set-on-an-editor-configured-from-the-other-end =
      lib.recursiveUpdate good {
        nixoffice.cluster.coeditors.editingsuite.documentHosts = [ "https://files.example.com" ];
      };

    # A port here matches nothing, and the symptom is a document that never opens.
    document-host-carrying-a-port =
      lib.recursiveUpdate good {
        nixoffice.cluster.coeditors.editing.documentHosts = lib.mkForce [ "https://files.example.com:443" ];
      };

    # ── Categories and namespaces ──────────────────────────────────────────────────────────────

    two-categories-in-one-namespace =
      lib.recursiveUpdate good { nixoffice.cluster.platform.namespaces.kanban = "example-tasks"; };

    namespace-named-after-an-application-in-the-catalogue =
      lib.recursiveUpdate good { nixoffice.cluster.platform.namespaces.wiki = "bookstack"; };

    # The rule the two-application categories exist to protect.
    namespace-named-after-a-workload-declared-in-it =
      lib.recursiveUpdate good { nixoffice.cluster.platform.namespaces.dms = "pipeline"; };

    two-workloads-on-one-slot =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.slot = 1; };

    two-workloads-creating-one-namespace =
      lib.recursiveUpdate good { nixoffice.cluster.filings.shelf.createNamespace = true; };
  };

  ## ---------------------------------------------------------------------
  ## The failing direction: the boundaries, which are not guards
  ##
  ## Each of these is an UNKNOWN OPTION rather than a refused value. That is the whole claim of this
  ## repository's design, so it is checked rather than asserted in prose.
  ## ---------------------------------------------------------------------

  structurallyImpossible = {
    # THE ENGINE RULE, AT ITS SHARPEST. There is nowhere in this module to name an engine's image,
    # its version, its storage or its root credential -- so an application cannot be given a
    # database beside it even by somebody trying.
    connection-naming-an-engine-image =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.connections.database.image = "example/sql:0.0.0"; };

    connection-naming-an-engine-version =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.connections.database.version = "0.0.0"; };

    connection-naming-an-engine-root-password =
      lib.recursiveUpdate good {
        nixoffice.cluster.wikis.pages.connections.database.rootPassword = { secret = "x"; key = "y"; };
      };

    # And the route a second object would have to take, which does not exist either.
    workload-passing-verbatim-manifests =
      lib.recursiveUpdate good {
        nixoffice.cluster.wikis.pages.manifests = [ "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: x\n" ];
      };

    workload-passing-raw-objects =
      lib.recursiveUpdate good {
        nixoffice.cluster.wikis.pages.raw = [ "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: x\n" ];
      };

    # A namespace comes from a category, and a category comes from the catalogue.
    workload-given-its-own-namespace =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.namespace = "example-somewhere-else"; };

    workload-declaring-its-own-category =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.category = "dms"; };

    # Everything here is the single writer of something.
    workload-given-a-replica-count =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.replicas = 2; };

    # Only the collaborative editors are told which hosts may hand them a document.
    document-hosts-on-a-workload-that-owns-its-own-documents =
      lib.recursiveUpdate good { nixoffice.cluster.wikis.pages.documentHosts = [ "https://files.example.com" ]; };
  };

  wronglyRendered =
    lib.attrNames (lib.filterAttrs (_: v: v) (lib.mapAttrs (_: renders) mustFail));
  wronglyAccepted =
    lib.attrNames (lib.filterAttrs (_: v: v) (lib.mapAttrs (_: renders) structurallyImpossible));

  ## ---------------------------------------------------------------------
  ## Messages, read as text
  ## ---------------------------------------------------------------------

  firstMatching = values: needle:
    let msgs = lib.filter (m: lib.hasInfix needle m) (failures values); in
    if msgs == [ ] then "" else lib.head msgs;

  engineMessage = firstMatching mustFail.required-engine-connection-left-undeclared "`pipeline`";
  watcherMessage = firstMatching mustFail.watcher-workload-scaled-to-zero "`pipeline`";
  unsupportedMessage = firstMatching mustFail.engine-the-software-does-not-speak "does not speak";
  namingMessage = firstMatching mustFail.namespace-named-after-a-workload-declared-in-it "`pipeline`";

  ## ---------------------------------------------------------------------
  ## The catalogue's own shape, so a future edit cannot silently break the above
  ## ---------------------------------------------------------------------

  catalogue = import ../lib/applications.nix { };

  # Group -> the field a declaration selects an entry by. Written out here rather than imported, so
  # that renaming one on the module without renaming it here is a failing check rather than a
  # silently narrower test.
  groupField = {
    wikis = "wiki";
    filings = "filing";
    trackers = "tracker";
    schedulers = "scheduler";
    coeditors = "coeditor";
    compilers = "compiler";
    records = "record";
  };
  groupNames = lib.attrNames groupField;
  allEntries = lib.concatMap (g: lib.attrValues catalogue.${g}) groupNames;
  entryNames = lib.concatMap (g: lib.attrNames catalogue.${g}) groupNames;
  categories = lib.unique (map (e: e.category) allEntries);

  # Which catalogue entry each declared workload in the control actually selected.
  selectedEntries = lib.concatLists (lib.mapAttrsToList
    (group: field: lib.mapAttrsToList (_: w: w.${field}) goodCfg.nixoffice.cluster.${group})
    groupField);

  results = {
    # ── The floor ─────────────────────────────────────────────────────────────────────────────
    "an empty surface defines no app in the grammar at all" =
      emptyCfg.nixk3s.apps == { };

    "an empty surface reports nothing at all: no category, no engine, nothing awake" =
      emptyCfg.nixoffice.cluster.categories == { }
      && emptyCfg.nixoffice.cluster.namespaces == { }
      && emptyCfg.nixoffice.cluster.engineDependencies == { }
      && emptyCfg.nixoffice.cluster.externalEngines == [ ]
      && emptyCfg.nixoffice.cluster.engineRequirements == { }
      && emptyCfg.nixoffice.cluster.mustStayAwake == { }
      && emptyCfg.nixoffice.cluster.corpora == { }
      && emptyCfg.nixoffice.cluster.splitCorpora == { }
      && emptyCfg.nixoffice.cluster.unauthenticated == [ ]
      && emptyCfg.nixoffice.cluster.slots == { }
      && emptyCfg.nixoffice.cluster.renderedByGrammar == [ ];

    "an empty surface raises no assertion of its own -- an unused module must be silent" =
      lib.all (a: a.assertion) emptyCfg.nixidy.assertions;

    # ── The control ───────────────────────────────────────────────────────────────────────────
    "one workload of every group, and every entry in the catalogue, renders" = renders good;

    "every declared workload goes through the grammar -- there is no second, untyped route" =
      goodCfg.nixoffice.cluster.renderedByGrammar == sorted (lib.attrNames goodCfg.nixk3s.apps)
      && lib.length goodCfg.nixoffice.cluster.renderedByGrammar == 12;

    # ── THE CATALOGUE'S OWN INTEGRITY ─────────────────────────────────────────────────────────
    "the module's groups are exactly the catalogue's tables, with nothing left unwired" =
      sorted (lib.attrNames catalogue) == sorted (groupNames ++ [ "engines" ]);

    "every catalogue entry is exercised by the control, so no entry is a claim nobody renders" =
      sorted selectedEntries == sorted entryNames;

    "no application in the catalogue shares a name with a category" =
      lib.intersectLists entryNames categories == [ ];

    "every entry states what it does when nobody is looking, as a claim rather than a blank" =
      lib.all (e: e ? background) allEntries
      && lib.all (e: e.background == null || lib.elem e.background.trigger [ "timer" "watch" "caller" ])
        allEntries;

    "every entry names a cold start, measured, because that is what the sleep warning is made of" =
      lib.all (e: e.coldStart.seconds > 0 && e.coldStart.what != "") allEntries;

    "every engine an entry accepts is an engine kind this catalogue knows" =
      lib.all
        (e: lib.all
          (n: lib.all (k: catalogue.engines ? ${k}) (lib.attrNames n.engines))
          (lib.attrValues e.needs))
        allEntries;

    "an embedded engine's wiring names the state directory that holds its file" =
      lib.all
        (e: lib.all
          (n: lib.all
            (k: !catalogue.engines.${k}.embedded || (e.state ? ${n.engines.${k}.state}))
            (lib.attrNames n.engines))
          (lib.attrValues e.needs))
        allEntries;

    "the two document managers answer one question differently, and the field says which" =
      lib.length (lib.attrNames catalogue.filings) == 2
      && sorted (lib.mapAttrsToList (_: e: e.ingest) catalogue.filings) == [ "pipeline" "shelf" ];

    "the two trackers sharing a category differ in what one row IS" =
      let inTasks = lib.filterAttrs (_: e: e.category == "tasks") catalogue.trackers; in
      lib.length (lib.attrNames inTasks) == 2
      && sorted (lib.mapAttrsToList (_: e: e.unit) inTasks) == [ "project" "task" ];

    "the collaborative editors own no corpus at all -- that is what defines the group" =
      lib.all (e: e.corpus == [ ] && e.corpusInEngine == null) (lib.attrValues catalogue.coeditors);

    # ── CATEGORIES, RESOLVED ──────────────────────────────────────────────────────────────────
    "a workload's namespace is its CATEGORY's, and nothing declared it" =
      goodCfg.nixk3s.apps.pages.namespace == "example-wiki"
      && goodCfg.nixk3s.apps.pipeline.namespace == "example-filing"
      && goodCfg.nixk3s.apps.shelf.namespace == "example-filing"
      && goodCfg.nixk3s.apps.board.namespace == "example-board";

    "two categories hold two applications each, which is what a category is for" =
      goodCfg.nixoffice.cluster.categories.dms == [ "pipeline" "shelf" ]
      && goodCfg.nixoffice.cluster.categories.tasks == [ "projects" "tasks" ]
      && goodCfg.nixoffice.cluster.categories.office == [ "editing" "editingsuite" ];

    "the same KIND of software lands in two categories, and the group did not decide that" =
      goodCfg.nixk3s.apps.tasks.namespace != goodCfg.nixk3s.apps.board.namespace;

    # ── THE ENGINES, WHICH THIS REPOSITORY NAMES AND DOES NOT RUN ─────────────────────────────
    "a field-style connection's address is DERIVED from a Service, a namespace and the domain" =
      goodCfg.nixk3s.apps.pages.env.DB_HOST == "example-sql.example-engines.svc.cluster.local"
      && goodCfg.nixk3s.apps.pipeline.env.PAPERLESS_DBHOST
      == "example-sql-pg.example-engines.svc.cluster.local";

    "and its port comes from the engine KIND when the declaration names none" =
      goodCfg.nixk3s.apps.pages.env.DB_PORT == "3306"
      && goodCfg.nixk3s.apps.pipeline.env.PAPERLESS_DBPORT == "5432";

    "the engine's own driver token is the catalogue's, and it is not the engine's name" =
      goodCfg.nixk3s.apps.contacts.env.DB_CLIENT == "pg"
      && goodCfg.nixk3s.apps.tasks.env.VIKUNJA_DATABASE_TYPE == "sqlite";

    "a connection string is a REFERENCE, and the variable it lands in is the software's" =
      goodCfg.nixk3s.apps.board.secrets."connection-database".secret == "example-board-db"
      && goodCfg.nixk3s.apps.board.secrets."connection-database".env.DATABASE_URL == "url"
      && !(goodCfg.nixk3s.apps.board.env ? DATABASE_URL);

    "a field connection's password is a reference too, and nothing else about it is" =
      goodCfg.nixk3s.apps.pages.secrets."connection-database".env.DB_PASSWORD == "password"
      && goodCfg.nixk3s.apps.pages.env.DB_USERNAME == "example_pages";

    "an embedded engine is a path inside this workload's own directory, and no address at all" =
      goodCfg.nixk3s.apps.tasks.env.VIKUNJA_DATABASE_PATH == "/etc/vikunja/vikunja.db"
      && goodCfg.nixk3s.apps.shelf.env.DATABASE_URL == "file:/app/app-data/db/db.sqlite"
      && !(goodCfg.nixk3s.apps.tasks.env ? VIKUNJA_DATABASE_HOST);

    "one workload opens two connections of two different engine families" =
      goodCfg.nixoffice.cluster.engineDependencies.typesetting
      == { database = "mongodb"; cache = "redis"; };

    "what this surface needs somebody else to run is countable, and an embedded engine is not in it" =
      goodCfg.nixoffice.cluster.externalEngines == [ "mariadb" "mongodb" "postgres" "redis" ];

    "a requirement on the SHAPE of somebody else's engine is published, not silently assumed" =
      lib.hasInfix "REPLICA SET" goodCfg.nixoffice.cluster.engineRequirements.typesetting.database;

    # ── WHAT HAPPENS WHEN NOBODY IS LOOKING ───────────────────────────────────────────────────
    "the workloads that must stay resident are countable, and they are the ones nothing can wake" =
      sorted (lib.attrNames goodCfg.nixoffice.cluster.mustStayAwake)
      == [ "editing" "editingsuite" "pipeline" "projects" "typesetting" ];

    "a switchable timer declared off is RENDERED off, so the two cannot disagree" =
      goodCfg.nixk3s.apps.tasks.env.VIKUNJA_SERVICE_ENABLEEMAILREMINDERS == "false"
      && goodCfg.nixk3s.apps.shelf.env.INGESTION_FOLDER_IS_ENABLED == "false";

    "and the workloads that switched it off are the ones allowed to sleep" =
      goodCfg.nixk3s.apps.tasks.scaling == "scale-to-zero"
      && goodCfg.nixk3s.apps.pipeline.scaling == "always"
      && goodCfg.nixk3s.apps.projects.scaling == "always";

    "a statement with no switch behind it renders no variable at all" =
      !(lib.any (v: lib.hasInfix "backgroundWork" v) (lib.attrNames goodCfg.nixk3s.apps.contacts.env));

    # ── THE ADDRESS A BROWSER USES, IN WHATEVER FORM EACH VARIABLE WANTS ──────────────────────
    "one origin becomes three variables in two forms" =
      goodCfg.nixk3s.apps.pipeline.env.PAPERLESS_URL == "https://filing.example.com"
      && goodCfg.nixk3s.apps.pipeline.env.PAPERLESS_ALLOWED_HOSTS == "filing.example.com"
      && goodCfg.nixk3s.apps.pipeline.env.PAPERLESS_CSRF_TRUSTED_ORIGINS == "https://filing.example.com";

    "software that wants a host rather than a URL gets the scheme stripped for it" =
      goodCfg.nixk3s.apps.editing.env.server_name == "edit.example.com";

    "document hosts go in as origins and come out NUMBERED and ESCAPED" =
      goodCfg.nixk3s.apps.editing.env.aliasgroup1 == "https://files\\.example\\.com"
      && goodCfg.nixk3s.apps.editing.env.aliasgroup2 == "https://pages\\.example\\.com";

    # ── The rest of the translation ───────────────────────────────────────────────────────────
    "the image is the catalogue repository plus THIS workload's version" =
      goodCfg.nixk3s.apps.pages.image == "lscr.io/linuxserver/bookstack:0.0.0"
      && goodCfg.nixk3s.apps.board.image == "ghcr.io/plankanban/planka:0.0.0";

    "each directory lands where the software writes it, backed by what the consumer supplied" =
      goodCfg.nixk3s.apps.pages.state.config.mountPath == "/config"
      && goodCfg.nixk3s.apps.pages.state.config.hostPath == "/example/state/pages"
      && goodCfg.nixk3s.apps.editingsuite.state.identity.mountPath == "/var/www/euro-office/Data";

    "the editors that own no document mount nothing, and one of them keeps two directories" =
      goodCfg.nixk3s.apps.editing.state == { }
      && lib.attrNames goodCfg.nixk3s.apps.editingsuite.state == [ "cache" "identity" ];

    "a slow first boot gets a startup probe rather than a readiness budget nobody can read" =
      goodCfg.nixk3s.apps.pipeline.probes.startup.failureThreshold == 72
      && goodCfg.nixk3s.apps.pipeline.probes.readiness.failureThreshold == 6
      && goodCfg.nixk3s.apps.pages.probes.startup == null;

    "a probe watches the port the catalogue calls primary, with the software's own path" =
      goodCfg.nixk3s.apps.tasks.probes.readiness.path == "/api/v1/info"
      && goodCfg.nixk3s.apps.contacts.probes.readiness.path == "/server/ping"
      && goodCfg.nixk3s.apps.board.probes.readiness.path == null
      && goodCfg.nixk3s.apps.profile.probes.readiness.port == "admin";

    "the two halves of a corpus are published, and the one workload holding both in one place is not" =
      lib.hasInfix "does not run" goodCfg.nixoffice.cluster.splitCorpora.pages
      && lib.hasInfix "embedded" goodCfg.nixoffice.cluster.splitCorpora.tasks
      && !(goodCfg.nixoffice.cluster.splitCorpora ? profile);

    "the software that asks nobody for anything is countable, and the token editors are not in it" =
      goodCfg.nixoffice.cluster.unauthenticated == [ "profile" ];

    # ── The band model ────────────────────────────────────────────────────────────────────────
    "every workload carries the declaring origin and its slot" =
      goodCfg.nixk3s.apps.pages.origin == "nixoffice"
      && goodCfg.nixk3s.apps.pages.slot == 0
      && goodCfg.nixk3s.apps.projects.slot == 11;

    "and the slot report is what a private layer reads to build an address" =
      lib.length (lib.attrNames goodCfg.nixoffice.cluster.slots) == 12;

    # ── The failing direction ─────────────────────────────────────────────────────────────────
    "every guard fires: nothing in the must-fail set renders" =
      wronglyRendered == [ ];

    "the boundary is structural: every boundary-crossing declaration is an unknown option" =
      wronglyAccepted == [ ];

    "the missing-engine refusal explains that this software would quietly make its own" =
      lib.hasInfix "EMBEDDED IN ITS OWN CONTAINER" engineMessage
      && lib.hasInfix "reports itself healthy" engineMessage;

    "the watcher refusal explains a failure with no HTTP request anywhere in it" =
      lib.hasInfix "no HTTP traffic" watcherMessage
      && lib.hasInfix "never noticed" watcherMessage;

    "the unsupported-engine refusal names both what was asked for and what it speaks" =
      lib.hasInfix "`postgres`" unsupportedMessage && lib.hasInfix "`mariadb`" unsupportedMessage;

    "the naming refusal names the CATEGORY, since that is the thing that outlives the application" =
      lib.hasInfix "`dms` category" namingMessage
      && lib.hasInfix "two applications each" namingMessage;
  };

  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) results);
in
if failed == [ ]
then
  pkgs.writeText "nixoffice-cluster-eval" ''
    control renders, the floor holds, and every guard fires:
    ${lib.concatMapStringsSep "\n" (n: "  refused: ${n}") (lib.attrNames mustFail)}
    and these are not refusals at all -- they are unknown options:
    ${lib.concatMapStringsSep "\n" (n: "  impossible: ${n}") (lib.attrNames structurallyImpossible)}
  ''
else
  throw ''
    nixoffice: cluster-eval check failed. Failing assertions:
    ${lib.concatMapStringsSep "\n" (f: "  - ${f}") failed}
    ${lib.optionalString (wronglyRendered != [ ])
      "Declarations that rendered but had to be refused: ${lib.concatStringsSep ", " wronglyRendered}"}
    ${lib.optionalString (wronglyAccepted != [ ])
      "Declarations that evaluated but had to be unknown options: ${lib.concatStringsSep ", " wronglyAccepted}"}
  ''
