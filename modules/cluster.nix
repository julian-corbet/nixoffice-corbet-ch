#
# nixoffice's cluster surface: declare the office applications this fleet runs, and render them.
#
# ── THIS MODULE DOES NOT IMPLEMENT KUBERNETES, AND THAT IS THE WHOLE DESIGN ─────────────────────
#
# There is a sibling repository whose entire subject is the app grammar -- an app declares WHAT IT
# NEEDS (an image, ports, an exposure class, whether it scales to zero, which existing claims or
# node paths hold its state, which existing Secrets it consumes) and that grammar renders the Argo
# CD Application, the Namespace, the Deployment and the Service. Everything this module can express
# in those terms is expressed in them: it DEFINES INTO `nixk3s.apps` and renders no Kubernetes
# object of its own.
#
# So this module is a translator, not a renderer. What it adds is the one thing the grammar cannot
# know: what a wiki, a document manager, a task tracker, a booking page, a collaborative editor, a
# typesetting service and a record platform each ARE -- which directories hold the work, which
# engine each one needs and cannot run, and which of them is still working after the request was
# answered.
#
# IMPORT THE GRAMMAR ALONGSIDE THIS MODULE. `nixk3s.apps` is declared there, not here, and a render
# that composes this module without it fails with "the option `nixk3s.apps' does not exist". That is
# a hard requirement rather than an optional integration, and it is deliberately not softened: a
# version of this module that quietly rendered its own Deployments when the grammar was absent would
# be the second implementation this repository exists to not have.
#
# ── THE SURFACE IS NESTED UNDER `nixoffice.cluster`, AND THAT IS NOT DECORATION ────────────────
#
# This repository already had a half: a catalogue of office software a PERSON INSTALLS ON A HOST,
# whose option groups live at `nixoffice.suite`, `nixoffice.editors`, `nixoffice.apps` and so on.
# Two of those names are exactly what a cluster group of the same subject would want to be called.
# So the cluster half is nested, for the same reason the continuous-integration sibling nests its
# client half: one repository is one option namespace, and two surfaces inside it must not be able
# to collide -- least of all by both meaning something reasonable.
#
# ── THE ENGINE RULE, WHICH IS THIS FILE'S MAIN CLAIM ───────────────────────────────────────────
#
# MOST OF THESE APPLICATIONS NEED A DATABASE AND THEY DO NOT AGREE ON WHICH. None of them is this
# repository's to run. That is structural here rather than advisory, and it is worth listing exactly
# how, because "we documented the boundary" is how every boundary is eventually crossed:
#
#   1. NOTHING HERE CAN RENDER AN ENGINE. There is no `manifests` option, no `raw` passthrough and
#      no second image anywhere in this module: one declaration produces exactly one container,
#      through somebody else's grammar. Shipping a database beside an application is not refused --
#      it is unwritable, because the option that would carry it does not exist.
#   2. AN ENGINE DEPENDENCY IS A TYPED CONNECTION, NOT AN ENVIRONMENT VARIABLE. `connections.<role>`
#      names the engine kind and either a Service and namespace or a Secret holding a connection
#      string. Which engine kinds the software actually speaks is the CATALOGUE's, and one outside
#      that set is refused by name.
#   3. A REQUIRED CONNECTION IS DEFAULTLESS AND ITS ABSENCE IS AN EVAL FAILURE. This is the guard
#      that matters most: four of these applications start perfectly happily with no database
#      configuration at all, create an embedded file inside their own container, and report
#      themselves healthy -- and one of them starts a whole database SERVER it ships in its image,
#      which nothing but a non-local host name suppresses. Choosing the embedded engine here is a
#      value somebody wrote down; it is never what happens when nobody wrote anything.
#   4. THE ADDRESS IS DERIVED WHERE THE SOFTWARE LETS IT BE. A declaration names a Service and a
#      namespace, never a host: this module builds the in-cluster name from them and the cluster
#      domain. Where software takes one connection string, an opaque or credential-bearing value
#      stays in a Secret; a credential-free Service URL may be derived only for a scheme the engine
#      catalogue explicitly permits.
#   5. AN EMBEDDED ENGINE'S DIRECTORY MUST BE BACKED WHEN IT IS CHOSEN, AND MUST NOT BE WHEN IT IS
#      NOT. A backing for a database file that will never be written reads, to everybody who comes
#      after, as though the data were in there.
#
# ── AND THE OTHER AXIS: WHAT HAPPENS WHEN NOBODY IS LOOKING ────────────────────────────────────
#
# Several of these are genuinely heavy, and several do real work after the request that started it
# has been answered. Scale-to-zero is therefore NOT uniformly safe here, and this module calibrates
# three different answers rather than one:
#
#   REFUSED   work fired by an in-process TIMER or by a filesystem WATCHER. At zero replicas the
#             interval does not happen and the dropped file is seen by nobody -- silently, with
#             nothing degraded and nothing in a log.
#   WARNED    work fired by a CALLER outside the pod. The call wakes the pod and then waits out the
#             cold start inside its own timeout, so nothing is lost and a batch can be skipped.
#             And, separately, any workload whose measured cold start is long enough that the first
#             person to arrive pays for it.
#   ABSENT    the collaborative editors, whose unit of work is a SESSION rather than a request.
#             `scale-to-zero` is not in that group's `scaling` enum at all: a wake front counting
#             requests sees an idle connection and takes the pod away mid-edit, and any software
#             belonging to that group has the same property.
#
# Two entries can have their background work SWITCHED OFF, and there the declaration must say which
# way it is set -- the answer decides whether the workload may sleep and nothing can guess it. Where
# the software has a real switch, this module RENDERS it from the same boolean the guard reads, so a
# declaration claiming the work is off cannot be running with it on.
#
# ── CATEGORIES, NOT NAMESPACES ─────────────────────────────────────────────────────────────────
#
# Every catalogue entry names a CATEGORY, and it is not declarable. A workload's namespace is its
# category's namespace, and those are defaultless options -- so no per-workload `namespace` option
# exists here and there will not be one. Two categories may not resolve to one namespace, and a
# namespace may not be named after any application in the catalogue OR after any workload declared
# in it: two of these categories hold two applications each, which is what a category is FOR, and a
# category named after one of its tenants stops being able to hold the second one honestly.
#
# ONE NAMESPACE. Everything declared here lives under `nixoffice`, like every repo in this family.
{ mkConsumerModule }:
{ config, lib, ... }:
let
  cfg = config.nixoffice.cluster;
  platform = cfg.platform;

  catalogue = import ../lib/applications.nix { };
  engineKinds = catalogue.engines;
  serviceDsnSchemes = lib.unique (lib.concatMap
    (engine: engine.serviceDsnSchemes or [ ])
    (lib.attrValues engineKinds));

  # The common factory uses `selfUrlEnv` as the catalogue-side marker for whether a public URL is
  # required. Nixoffice has the richer source fact below (`publicUrl.envs`, including host/origin
  # forms and suffixes); the extension replaces the factory's one-variable projection with that
  # exact fan-out. This marker therefore centralises only the two presence guards.
  catalogueFor = group: lib.mapAttrs
    (_: entry: entry // {
      selfUrlEnv =
        if entry.publicUrl == null
        then null
        else lib.head (lib.attrNames entry.publicUrl.envs);
    })
    catalogue.${group};

  # The catalogue's groups, hand-listed to match the option surface below. The fragility that
  # invites -- a group added to the catalogue and never wired into an option -- is closed by a check
  # rather than by cleverness: ../checks/cluster-eval.nix asserts that these are exactly the
  # catalogue's own tables.
  groups = {
    wikis = "wiki";
    filings = "filing";
    trackers = "tracker";
    schedulers = "scheduler";
    coeditors = "coeditor";
    compilers = "compiler";
    records = "record";
  };

  enabledOf = attrs: lib.filterAttrs (_: w: w.enable) attrs;

  # Every declared workload, tagged with its group, the field it was selected by and its catalogue
  # entry, in one list. Almost every guard here is about the surface AS A WHOLE -- two workloads on
  # one slot, two categories in one namespace, a namespace named after a tenant -- so they are
  # written against this rather than against seven separate tables.
  allWorkloads = lib.concatLists (lib.mapAttrsToList
    (group: field:
      lib.mapAttrsToList
        (name: w: {
          inherit name w group;
          entry = catalogue.${group}.${w.${field}};
        })
        (enabledOf cfg.${group}))
    groups);

  ## ---------------------------------------------------------------------
  ## Categories and namespaces
  ## ---------------------------------------------------------------------

  # Derived from the catalogue rather than listed: an application filed into a new category adds
  # that category's namespace option automatically, and a category nobody catalogues cannot linger
  # as an option nothing reads.
  allCategories = lib.unique (lib.concatMap
    (group: lib.mapAttrsToList (_: e: e.category) catalogue.${group})
    (lib.attrNames groups));

  categoryOf = x: x.entry.category;
  categoriesInUse = lib.unique (map categoryOf allWorkloads);
  inCategory = c: lib.filter (x: categoryOf x == c) allWorkloads;

  # THE ONE PLACE A NAMESPACE COMES FROM. There is no per-workload option and there will not be one.
  # Only the categories actually declared are ever forced, which is what lets every one of these be
  # defaultless without a render of one application demanding nine values.
  namespaceOfCategory = c: platform.namespaces.${c};
  namespaceOf = x: namespaceOfCategory (categoryOf x);

  ## ---------------------------------------------------------------------
  ## Engine connections
  ## ---------------------------------------------------------------------

  needsOf = x: x.entry.needs;
  connectionsOf = x: x.w.connections;

  # Total on purpose: an unknown role, or an engine the software does not speak, is REFUSED by an
  # assertion below -- and the messages that ever get formatted are exactly the FAILING ones, so a
  # helper that threw on the broken input would throw precisely when the refusal is trying to
  # report it, taking the evaluation down before it could say anything.
  wiringOf = x: role:
    let need = x.entry.needs.${role} or null; in
    if need == null then null
    else if !(connectionsOf x ? ${role}) then null
    else need.engines.${(connectionsOf x).${role}.engine} or null;

  engineOf = x: role: (x.w.connections.${role}.engine or null);
  styleOf = x: role: let w = wiringOf x role; in if w == null then null else w.style;

  isEmbeddedEngine = e: e != null && (engineKinds.${e}.embedded or false);

  # The in-cluster name of the engine a `fields` connection points at. DERIVED, from a Service name
  # and a namespace the declaration gives and from the cluster's own domain -- so nobody writes a
  # cross-namespace address by hand and nothing numeric can enter through it.
  addressOf = conn:
    "${toString conn.service}.${toString conn.namespace}.svc.${platform.clusterDomain}";

  serviceDsnOf = x: dsn:
    "${dsn.scheme}://${dsn.service}.${namespaceOf x}.svc.${platform.clusterDomain}:${toString dsn.port}";

  portOf = conn:
    if conn.port != null then conn.port else engineKinds.${conn.engine}.port;

  connectionEnv = x: role:
    let
      conn = (connectionsOf x).${role};
      w = wiringOf x role;
      typed = lib.optionalAttrs (w.typeEnv or null != null) { ${w.typeEnv} = w.typeValue; };
    in
    if w == null then { }
    else if w.style == "fields" then
      typed
      // {
        ${w.hostEnv} =
          addressOf conn
          + lib.optionalString w.portInHost ":${toString (portOf conn)}";
      }
      // lib.optionalAttrs (w.portEnv != null) { ${w.portEnv} = toString (portOf conn); }
      // lib.optionalAttrs (w.databaseEnv != null && conn.database != null) {
        ${w.databaseEnv} = conn.database;
      }
      // lib.optionalAttrs (w.userEnv != null && conn.user != null) { ${w.userEnv} = conn.user; }
    else if w.style == "file" then
      typed
      // lib.optionalAttrs (w.env != null) {
        ${w.env} = w.prefix + x.entry.state.${w.state}.mountPath + "/" + w.file;
      }
    # `dsn`: an opaque or credential-bearing string arrives by Secret reference. The one safe plain
    # form is assembled from typed pieces below: no userinfo, host, path or query can enter it.
    else if w.style == "dsn" && conn.serviceDsn != null then
      typed // { ${w.env} = serviceDsnOf x conn.serviceDsn; }
    else typed;

  connectionSecrets = x: role:
    let
      conn = (connectionsOf x).${role};
      w = wiringOf x role;
    in
    if w == null then { }
    else if w.style == "fields" && conn.password != null then {
      "connection-${role}" = {
        secret = conn.password.secret;
        env.${w.passwordEnv} = conn.password.key;
      };
    }
    else if w.style == "dsn" && conn.dsn != null then {
      "connection-${role}" = {
        secret = conn.dsn.secret;
        env.${w.env} = conn.dsn.key;
      };
    }
    else { };

  ## ---------------------------------------------------------------------
  ## Storage
  ## ---------------------------------------------------------------------

  # Three populations, and the third is why this is not a single list. A directory that exists ONLY
  # to hold an embedded engine's file is demanded when that engine is chosen and refused when it is
  # not -- a backing for a database nothing will ever write reads as though the data were in it.
  requiredStateKeys = x:
    lib.attrNames (lib.filterAttrs
      (_: s: s.required || (s.embeddedFor != null && isEmbeddedEngine (engineOf x s.embeddedFor)))
      x.entry.state);

  allowedStateKeys = x:
    lib.attrNames (lib.filterAttrs
      (_: s: s.required || s.embeddedFor == null || isEmbeddedEngine (engineOf x s.embeddedFor))
      x.entry.state);

  # Public state keys are semantic catalogue names and remain source-compatible even where an
  # established camelCase key is not a Kubernetes DNS label. Only the rendered volume identity is
  # resolved; every mount and central guard follows the same factory callback.
  volumeNameOf = { entry, ... }: key: entry.state.${key}.volumeName or key;

  ## ---------------------------------------------------------------------
  ## The address a browser uses, in whatever form each variable wants
  ## ---------------------------------------------------------------------

  hostPart = origin: lib.removePrefix "http://" (lib.removePrefix "https://" origin);

  # ONE VALUE, SEVERAL VARIABLES, SEVERAL FORMS. The origin is a fleet fact and comes from the
  # declaration; which variables exist, whether each wants a whole origin or the bare host, and any
  # path suffix are knowledge and come from the catalogue. One entry here needs three variables in
  # two forms from this single value, and the classic failure -- every credential correct and
  # nobody able to sign in -- is what getting the second half wrong looks like.
  publicUrlEnv = x:
    lib.optionalAttrs (x.entry.publicUrl != null && x.w.publicUrl != null)
      (lib.mapAttrs
        (_: spec:
          (if spec.form == "host" then hostPart x.w.publicUrl else x.w.publicUrl) + spec.path)
        x.entry.publicUrl.envs);

  ## ---------------------------------------------------------------------
  ## The document hosts a collaborative editor accepts
  ## ---------------------------------------------------------------------

  # NUMBERED VARIABLES CARRYING REGULAR EXPRESSIONS. A declaration gives ordinary origins; the
  # numbering, the escaping of every dot and the absence of a port are all knowledge, and all three
  # are what a hand-written value gets wrong.
  escapeRegex = s: builtins.replaceStrings [ "." ] [ "\\." ] s;

  wopiHostEnv = x:
    lib.optionalAttrs (x.entry.wopiHosts or null != null)
      (lib.listToAttrs (lib.imap1
        (i: host: lib.nameValuePair
          "${x.entry.wopiHosts.envPrefix}${toString i}"
          (if x.entry.wopiHosts.escape == "regex" then escapeRegex host else host))
        (x.w.documentHosts or [ ])));

  ## ---------------------------------------------------------------------
  ## Background work
  ## ---------------------------------------------------------------------

  backgroundOf = x: x.entry.background;
  hasToggle = x: backgroundOf x != null && (backgroundOf x).toggle != null;

  # Whether this workload actually DOES work outside a request, which is the declaration's answer
  # where there is a switch and the catalogue's everywhere else.
  backgroundActive = x:
    backgroundOf x != null
    && (!(hasToggle x) || x.w.backgroundWork == true);

  triggerOf = x: if backgroundOf x == null then null else (backgroundOf x).trigger;

  # Rendered from the SAME boolean the guard reads, wherever the software has a real switch: a
  # declaration cannot claim the work is off while the process is doing it.
  backgroundEnv = x:
    lib.optionalAttrs (hasToggle x && (backgroundOf x).toggle.env != null) {
      ${(backgroundOf x).toggle.env} =
        if x.w.backgroundWork == true
        then (backgroundOf x).toggle.onValue
        else (backgroundOf x).toggle.offValue;
    };

  ## ---------------------------------------------------------------------
  ## Translation into the app grammar
  ## ---------------------------------------------------------------------

  imageOf = x: if x.w.image != null then x.w.image else "${x.entry.image}:${x.w.version}";

  secretsOf = x:
    lib.mapAttrs
      (role: d: {
        secret = d.secret;
        env.${x.entry.credentials.${role}.env} = d.key;
      })
      (lib.filterAttrs (role: _: x.entry.credentials ? ${role}) x.w.credentials)
    // lib.foldl' (acc: role: acc // connectionSecrets x role) { }
      (lib.attrNames (lib.filterAttrs (role: _: needsOf x ? ${role}) (connectionsOf x)))
    // lib.listToAttrs
      (map (s: lib.nameValuePair s { secret = s; envFrom = true; }) x.w.envFromSecrets);

  envOf = x:
    x.entry.env
    // lib.foldl' (acc: role: acc // connectionEnv x role) { }
      (lib.attrNames (lib.filterAttrs (role: _: needsOf x ? ${role}) (connectionsOf x)))
    // publicUrlEnv x
    // wopiHostEnv x
    // backgroundEnv x
    // x.w.env;

  # The shared projection stays factory-owned, including the legacy-subtype state renderer. The
  # extension replaces only the domain halves the common factory cannot know: the role-shaped
  # credential/connection secrets and the richer environment fan-out. `image` is repeated because
  # its public option is a disabled-common replacement used to suppress the generic override
  # warning; rendering a disabled replacement is this adapter's responsibility.
  extendApp = x: x.app // {
    image = imageOf x;
    secrets = secretsOf x;
    env = envOf x;
  };

  ## ---------------------------------------------------------------------
  ## Derived facts the guards are written against
  ## ---------------------------------------------------------------------

  listNames = names: lib.concatMapStringsSep ", " (n: "`${n}`") names;

  slotClaims = lib.filter (x: x.w.slot != null) allWorkloads;

  # Every application this catalogue knows, by name. A namespace may not be called after one of
  # them -- see the assertions.
  catalogueApps =
    lib.concatMap (group: lib.attrNames catalogue.${group}) (lib.attrNames groups);

  categoryPairs =
    let n = lib.length categoriesInUse; in
    lib.concatMap
      (i: map (j: { a = lib.elemAt categoriesInUse i; b = lib.elemAt categoriesInUse j; })
        (lib.range (i + 1) (n - 1)))
      (lib.range 0 (n - 1));

  # An origin: a scheme and a host and nothing else. Written out rather than matched with one
  # expression because the message has to be able to say WHICH half is wrong.
  isOrigin = u:
    (lib.hasPrefix "https://" u || lib.hasPrefix "http://" u)
    && !(lib.hasInfix "/" (hostPart u))
    && !(lib.hasInfix ":" (hostPart u));

  # A Service NAME. Never an address, never a URL, never a fully qualified name: the namespace is
  # its own field and the domain is the platform's, and this module joins all three.
  isBareName = s: !(lib.hasInfix "." s) && !(lib.hasInfix "/" s) && !(lib.hasInfix ":" s);

  ## ---------------------------------------------------------------------
  ## Assertions
  ##
  ## The module system filters the assertions down to the FAILING ones and only then formats their
  ## messages. A passing assertion's message is never evaluated at all, and two things follow.
  ##
  ## Every message here is a TOTAL function of the declaration, because a message that throws on a
  ## partial declaration throws at exactly the moment its own assertion has failed -- the one moment
  ## it was written for -- and takes the evaluation down instead of reporting anything.
  ##
  ## And a value mentioned ONLY in a message is never forced, so its type is never checked either.
  ## Whatever an assertion wants checked has to be in its `assertion` expression. See nixwatch's
  ## study `an-option-nothing-renders-is-never-checked`.
  ## ---------------------------------------------------------------------

  connectionAssertions = lib.concatMap
    (x:
      let
        need = needsOf x;
        declared = connectionsOf x;
        unknown = lib.filter (r: !(need ? ${r})) (lib.attrNames declared);
        missing = lib.attrNames
          (lib.filterAttrs (r: n: n.required && !(declared ? ${r})) need);
        embeddedMissing = lib.filter
          (r: lib.any (e: engineKinds.${e}.embedded) (lib.attrNames need.${r}.engines))
          missing;
        unsupported = lib.filter
          (r: (need ? ${r}) && !(need.${r}.engines ? ${declared.${r}.engine}))
          (lib.attrNames declared);
      in
      [
        {
          assertion = unknown == [ ];
          message =
            "nixoffice: `${x.name}` declares connection(s) " + listNames unknown + " that this "
            + "software does not open. It connects out to "
            + (if need == { } then "nothing at all" else listNames (lib.attrNames need))
            + ". A connection nothing reads renders variables no process looks at, which is worse "
            + "than being refused because it looks provisioned.";
        }
        {
          # THE GUARD THIS REPOSITORY'S CLUSTER HALF EXISTS FOR.
          assertion = missing == [ ];
          message =
            "nixoffice: `${x.name}` is missing required connection(s) " + listNames missing
            + ". This repository does not run engines and this declaration does not name one, so "
            + "there is nothing for the workload to connect to"
            + (if embeddedMissing == [ ]
            then ", and it will not start"
            else
              " -- and for " + listNames embeddedMissing + " that is NOT a startup failure: this "
              + "software falls back to an engine EMBEDDED IN ITS OWN CONTAINER, comes up, works, "
              + "reports itself healthy, and loses everything at the next restart. Choosing that "
              + "engine is a decision somebody makes explicitly here")
            + ". Name the engine and either the Service that serves it or the Secret holding its "
            + "connection string.";
        }
        {
          assertion = unsupported == [ ];
          message =
            "nixoffice: `${x.name}` points a connection at an engine this software does not speak: "
            + lib.concatMapStringsSep "; "
              (r: "`${r}` -> `${declared.${r}.engine}`, and it speaks "
              + listNames (lib.attrNames need.${r}.engines))
              unsupported
            + ". Which engines a piece of software supports is a property of the software, so this "
            + "is not a preference that degrades -- it renders variables the process never reads "
            + "and a connection that is never opened.";
        }
      ]
      ++ lib.concatMap
        (role:
          let
            conn = declared.${role};
            w = wiringOf x role;
            style = if w == null then "unknown" else w.style;
            set = lib.optional (conn.service != null) "service"
            ++ lib.optional (conn.namespace != null) "namespace"
            ++ lib.optional (conn.port != null) "port"
            ++ lib.optional (conn.database != null) "database"
            ++ lib.optional (conn.user != null) "user"
            ++ lib.optional (conn.password != null) "password"
            ++ lib.optional (conn.dsn != null) "dsn"
            ++ lib.optional (conn.serviceDsn != null) "serviceDsn";
            fieldOnly = [ "service" "namespace" "port" "database" "user" "password" ];
            dsnSources = lib.optional (conn.dsn != null) "dsn"
            ++ lib.optional (conn.serviceDsn != null) "serviceDsn";
          in
          [
            {
              assertion = style != "fields"
              || (conn.service != null
                && conn.namespace != null
                && conn.dsn == null
                && conn.serviceDsn == null);
              message =
                "nixoffice: `${x.name}`'s `${role}` connection takes its address as separate "
                + "variables, so it needs a `service` and a `namespace` and must not be given a "
                + "`dsn` or `serviceDsn`. It sets "
                + (if set == [ ] then "nothing at all" else listNames set)
                + ". The point of naming a Service rather than a host is that the address is "
                + "DERIVED here -- from the name, the namespace and the cluster domain -- so a "
                + "cross-namespace address is never written by hand.";
            }
            {
              assertion = style != "fields" || conn.service == null || isBareName conn.service;
              message =
                "nixoffice: `${x.name}`'s `${role}` connection gives "
                + "`service = \"${toString conn.service}\"`, which is not a bare name. It is the "
                + "NAME of an existing Service: no dots, no scheme, no port, no path. The namespace "
                + "is its own field and the cluster domain is the platform's, and this module joins "
                + "the three.";
            }
            {
              assertion = style != "fields" || !w.passwordRequired || conn.password != null;
              message =
                "nixoffice: `${x.name}`'s `${role}` connection needs a password and names none. It "
                + "is a reference to an existing Secret and a key inside it -- never the value; "
                + "everything this module renders is committed to git.";
            }
            {
              assertion = style != "dsn" || lib.length dsnSources == 1;
              message =
                "nixoffice: `${x.name}`'s `${role}` connection is a single connection STRING and "
                + "must choose exactly one source: `dsn` names the Secret holding an opaque or "
                + "credential-bearing value; `serviceDsn` derives a credential-free URL from a "
                + "typed scheme, Service name, port, this workload's namespace and the cluster "
                + "domain. It sets "
                + (if dsnSources == [ ] then "neither" else listNames dsnSources) + ".";
            }
            {
              assertion = style != "dsn" || lib.intersectLists set fieldOnly == [ ];
              message =
                "nixoffice: `${x.name}`'s `${role}` connection is a single connection string and "
                + "also sets " + listNames (lib.intersectLists set fieldOnly) + ". Those would be a "
                + "second copy of what is inside the string, and the string is the half the software "
                + "actually reads -- so the two would drift apart with nothing to notice.";
            }
            {
              assertion = conn.serviceDsn == null || isBareName conn.serviceDsn.service;
              message =
                "nixoffice: `${x.name}`'s `${role}` service-derived connection gives "
                + "`service = \"${if conn.serviceDsn == null then "" else conn.serviceDsn.service}\"`, "
                + "which is not a bare name. It is the NAME of a Service in this workload's category "
                + "namespace: no dots, scheme, port, path or userinfo. The namespace and cluster "
                + "domain come from the platform, and this module joins them.";
            }
            {
              assertion = style != "dsn"
              || conn.serviceDsn == null
              || lib.elem conn.serviceDsn.scheme
                (engineKinds.${conn.engine}.serviceDsnSchemes or [ ]);
              message =
                "nixoffice: `${x.name}`'s `${role}` connection asks to derive a `${conn.engine}` "
                + "connection with scheme `"
                + (if conn.serviceDsn == null then "" else conn.serviceDsn.scheme)
                + "`, but that engine permits "
                + listNames (engineKinds.${conn.engine}.serviceDsnSchemes or [ ])
                + ". A scheme is protocol knowledge, not an arbitrary URL prefix.";
            }
            {
              assertion = style != "file" || set == [ ];
              message =
                "nixoffice: `${x.name}`'s `${role}` connection is an EMBEDDED engine -- a file "
                + "inside this workload's own directory -- and it sets " + listNames set + ". There "
                + "is no server to reach, no user to be and no password to give. What it does need "
                + "is the directory holding it backed, which is checked separately.";
            }
          ])
        (lib.attrNames (lib.filterAttrs (r: _: need ? ${r}) declared)))
    allWorkloads;

  credentialAssertions = lib.concatMap
    (x:
      let
        known = lib.attrNames x.entry.credentials;
        unknown = lib.filter (r: !(x.entry.credentials ? ${r})) (lib.attrNames x.w.credentials);
        missing = lib.attrNames
          (lib.filterAttrs (r: c: c.required && !(x.w.credentials ? ${r})) x.entry.credentials);
      in
      [
        {
          assertion = unknown == [ ];
          message =
            "nixoffice: `${x.name}` names credential role(s) " + listNames unknown + " that this "
            + "software does not read. It reads "
            + (if known == [ ] then "none at all" else listNames known)
            + ". A role nothing reads renders a reference into a variable no process looks at, "
            + "which is worse than being refused because it looks provisioned.";
        }
        {
          assertion = missing == [ ];
          message =
            "nixoffice: `${x.name}` is missing required credential role(s) " + listNames missing
            + ". Name the existing Secret and the key inside it -- never the value; everything this "
            + "module renders is committed to git.";
        }
      ])
    allWorkloads;

  # THE SCALE-TO-ZERO GUARD, and the whole point of it is that it is not uniform. A refusal for work
  # nothing can wake, a warning for work something outside can, and nothing at all for a workload
  # that computes everything in answer to a request.
  scalingAssertions = lib.concatMap
    (x: [
      {
        assertion =
          x.w.scaling != "scale-to-zero"
          || !(backgroundActive x)
          || triggerOf x == "caller";
        message =
          "nixoffice: `${x.name}` is declared `scale-to-zero`, and this software keeps working after "
          + "the request that started the work has been answered: "
          + (if backgroundOf x == null then "(it does not)" else (backgroundOf x).what) + ". "
          + (if triggerOf x == "watch"
          then
            "That work is not started by a request AT ALL -- a file copied into a directory produces "
            + "no HTTP traffic, so no wake front can see it, and the drop is simply never noticed."
          else
            "A wake front counts REQUESTS, so at zero replicas the interval does not happen: the "
            + "work is not late, it is never evaluated, and the first thing that runs after a wake "
            + "finds it already overdue.")
          + " Nothing reports any of this -- nothing is degraded, nothing restarts, no probe fails. "
          + (if hasToggle x
          then "Either leave it `always`, or set `backgroundWork = false`, which this module renders "
          + "into the software's own switch so the two cannot disagree."
          else "Leave it `always`; this software has no switch that turns the work off.");
      }
      {
        assertion = backgroundOf x != null || x.w.backgroundWork == null;
        message =
          "nixoffice: `${x.name}` states `backgroundWork`, and this software does nothing after a "
          + "request is answered -- everything it computes, it computes for a caller. There is "
          + "nothing to switch on or off, so the statement would be a claim about behaviour that "
          + "does not exist.";
      }
      {
        assertion = hasToggle x || x.w.backgroundWork == null;
        message =
          "nixoffice: `${x.name}` states `backgroundWork`, and this software's background work is "
          + "not optional: "
          + (if backgroundOf x == null then "(it has none)" else (backgroundOf x).what)
          + ". It happens whenever the workload is running, so the statement could only ever be "
          + "wrong in one direction.";
      }
      {
        # A REQUIRED DECISION rather than a defaulted one. Which way this is set decides whether the
        # workload may sleep, and no default could be right for both answers.
        assertion = !(hasToggle x) || x.w.backgroundWork != null;
        message =
          "nixoffice: `${x.name}` must state `backgroundWork`, and does not. This software's work "
          + "outside a request is OPTIONAL -- "
          + (if backgroundOf x == null then "(none)" else (backgroundOf x).what)
          + " -- so whether this instance does any of it is a decision rather than a property, and "
          + "it is the decision that says whether the workload may idle at zero. "
          + (if hasToggle x && (backgroundOf x).toggle.env != null
          then "This module renders the software's own switch from the same value, so the answer and "
          + "the running process cannot disagree."
          else "There is no switch to inspect: the work exists only if somebody authored something "
          + "that schedules it, which is a fact about how this instance is used.");
      }
    ])
    allWorkloads;

  # THE UNAUTHENTICATED GUARD. Calibrated deliberately against the token-authenticating editors in
  # the same repository: a document editor with no accounts hands nothing to a request that carries
  # no token, and an administrative interface with no password hands over everything.
  authAssertions = map
    (x: {
      assertion = x.entry.authentication != "none" || x.w.exposure != "public";
      message =
        "nixoffice: `${x.name}` is declared `public`, and this software asks nobody for anything -- "
        + "there is no login on it at all, so whoever reaches it can read and rewrite everything in "
        + "it. It also serves "
        + (if lib.length (lib.attrNames x.entry.ports) > 1
        then "more than one audience from one pod (" + listNames (lib.attrNames x.entry.ports)
        + "), and an exposure class is a property of the WORKLOAD rather than of a port, so "
        + "publishing the read-only half publishes the editing half by exactly the same amount"
        else "no authenticated surface at all")
        + ". If a part of it has to be public, the thing that publishes it is a front in front of "
        + "one port, and that front is not this workload.";
    })
    allWorkloads;

  # The factory owns whether the selected software needs or accepts a public URL. This surface's
  # extra rule is narrower: the one value fans out into several catalogue-shaped variables, so it
  # must be an origin rather than an arbitrary URL.
  publicUrlAssertions = map
    (x: {
        assertion = x.w.publicUrl == null || isOrigin x.w.publicUrl;
        message =
          "nixoffice: `${x.name}` gives `publicUrl = \"${toString x.w.publicUrl}\"`, which is not a "
          + "bare origin. It must be a scheme and a host and nothing else -- no port, no trailing "
          + "slash, no path. One of the applications in this catalogue wants that value with the "
          + "scheme stripped off and another wants a path appended to it, and both of those are "
          + "derived here from one origin.";
      })
    allWorkloads;

  coeditorAssertions = lib.concatMap
    (x: [
      {
        assertion = (x.entry.wopiHosts or null) == null || (x.w.documentHosts or [ ]) != [ ];
        message =
          "nixoffice: `${x.name}` must be told which document hosts may hand it a file, and "
          + "`documentHosts` is empty. A collaborative editor stores nothing of its own: a document "
          + "arrives from a host system, and one that has not been told which systems those are "
          + "serves an error page instead of the document. Give ordinary origins -- the numbering "
          + "of the variables, the escaping of every dot and the absence of a port are knowledge "
          + "and this module supplies them.";
      }
      {
        assertion = (x.entry.wopiHosts or null) != null || (x.w.documentHosts or [ ]) == [ ];
        message =
          "nixoffice: `${x.name}` names `documentHosts`, and this software is not told which hosts "
          + "may reach it that way -- it is configured from the other end, by the system that holds "
          + "the documents. The value would reach no object at all.";
      }
      {
        assertion = lib.all isOrigin (x.w.documentHosts or [ ]);
        message =
          "nixoffice: `${x.name}` gives a document host that is not a bare origin: "
          + listNames (lib.filter (h: !(isOrigin h)) (x.w.documentHosts or [ ]))
          + ". A scheme and a host and nothing else. A PORT IN PARTICULAR MUST NOT APPEAR: this "
          + "value is compared, as a pattern, against a host that carries none, so a port makes it "
          + "match nothing at all -- and the symptom is a document that never opens rather than a "
          + "configuration error.";
      }
    ])
    (lib.filter (x: x.group == "coeditors") allWorkloads);

  categoryAssertions =
    map
      (pair: {
        assertion = namespaceOfCategory pair.a != namespaceOfCategory pair.b;
        message =
          "nixoffice: the `${pair.a}` and `${pair.b}` categories are declared into the SAME "
          + "namespace, and this surface has workloads in both. A category is what decides blast "
          + "radius here: it is what a backup policy selects on, what a Secret set unseals into, "
          + "and what a prune slip is contained by. Give each one its own.";
      })
      categoryPairs
    ++ map
      (c: {
        assertion = !(lib.elem (namespaceOfCategory c) catalogueApps);
        message =
          "nixoffice: the `${c}` category's namespace is `${namespaceOfCategory c}`, which is the "
          + "name of an application in this catalogue. A namespace named after one of its own "
          + "tenants stops being able to hold the second one honestly -- and two categories here "
          + "hold two applications each, which is exactly what a category is for. Name it after "
          + "what the category IS.";
      })
      categoriesInUse
    ++ map
      (x: {
        assertion = x.name != namespaceOf x;
        message =
          "nixoffice: workload `${x.name}` is declared into a namespace of the same name. The "
          + "namespace belongs to the `${categoryOf x}` category, which outlives any one "
          + "application in it: the day a second one arrives, the one the namespace is named after "
          + "reads as the category's implementation and every other as a guest. Two categories here "
          + "already hold two applications each. Name one of the two for what it IS.";
      })
      allWorkloads;

  ## ---------------------------------------------------------------------
  ## Warnings
  ## ---------------------------------------------------------------------

  warnings =
    map
      (x: {
        # The calibrated middle case: nothing is lost, and something outside pays for the wake.
        when = x.w.scaling == "scale-to-zero" && backgroundActive x && triggerOf x == "caller";
        message =
          "nixoffice: `${x.name}` scales to zero, and its scheduled work is fired by something "
          + "OUTSIDE the pod: " + (if backgroundOf x == null then "(none)" else (backgroundOf x).what)
          + ". That call wakes the workload, so nothing is lost -- and it then waits out a cold "
          + "start of about ${toString x.entry.coldStart.seconds}s inside its own timeout. A caller "
          + "with a short one gives up, and the batch it was going to trigger is skipped silently.";
      })
      allWorkloads
    ++ map
      (x: {
        when =
          x.w.scaling == "scale-to-zero"
          && platform.warnColdStartAtOrAbove > 0
          && x.entry.coldStart.seconds >= platform.warnColdStartAtOrAbove;
        message =
          "nixoffice: `${x.name}` scales to zero and takes about "
          + "${toString x.entry.coldStart.seconds}s to answer after a start -- "
          + x.entry.coldStart.what + ". Nothing breaks; the first person to arrive pays for all of "
          + "it, every time the workload has been idle. This is a judgement about people rather "
          + "than about correctness, which is why it is said once and not enforced.";
      })
      allWorkloads
    ++ map
      (x: {
        when = x.entry.authentication == "none" && x.w.exposure != "internal";
        message =
          "nixoffice: `${x.name}` asks nobody for anything and is declared `${x.w.exposure}`, so "
          + "whatever grants membership of that class IS the entire access control on it. That can "
          + "be a perfectly deliberate arrangement; it is worth knowing that it is the arrangement.";
      })
      allWorkloads;

  ## ---------------------------------------------------------------------
  ## Option shapes
  ## ---------------------------------------------------------------------

  backingType = lib.types.submodule {
    options = {
      claim = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          NAME of an existing PersistentVolumeClaim backing this directory. A name, never a path.
          Nothing here creates the claim: it outlives every version of the software that mounts it,
          so its existence is not the workload's to declare.
        '';
      };

      hostPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path on the NODE backing this directory instead of a claim, and in practice the common
          answer for a document corpus: it is usually a directory somebody curates deliberately and
          reaches by other means as well.

          IT PINS THE WORKLOAD TO A NODE, because the path only exists on one. The VALUE is a fleet
          fact and belongs to the consumer that passes it in -- no path appears anywhere in this
          repository.
        '';
      };

      hostPathType = lib.mkOption {
        type = lib.types.enum [ "Directory" "DirectoryOrCreate" ];
        default = "Directory";
        description = ''
          Whether a missing node path is an error or is created empty. `Directory` (the default) is
          the right answer for almost everything here: an office application that finds an empty
          directory does not report a problem, it reports an EMPTY WIKI, an empty archive, a fresh
          installation -- healthy, and with nothing in it. `DirectoryOrCreate` is defensible on a
          genuinely first start.
        '';
      };
    };
  };

  credentialType = lib.types.submodule {
    options = {
      secret = lib.mkOption {
        type = lib.types.str;
        description = "NAME of an existing Secret holding this credential.";
      };
      key = lib.mkOption {
        type = lib.types.str;
        description = "Which key inside that Secret carries it.";
      };
    };
  };

  serviceDsnType = lib.types.submodule {
    options = {
      service = lib.mkOption {
        type = lib.types.str;
        example = "example-broker";
        description = ''
          NAME of a Service in this workload's category namespace. A name, never a host or URL: the
          namespace and cluster domain are platform facts and are appended by this module.
        '';
      };

      scheme = lib.mkOption {
        type = lib.types.enum serviceDsnSchemes;
        example = "redis";
        description = ''
          Connection scheme to place before the derived Service address. The engine catalogue
          further restricts which of these schemes each engine supports.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        example = 6379;
        description = ''
          Port to append to the derived Service address. Required rather than inferred so changing
          an engine kind's conventional port cannot silently move an existing connection.
        '';
      };
    };
  };

  connectionType = lib.types.submodule {
    options = {
      engine = lib.mkOption {
        type = lib.types.enum (lib.attrNames engineKinds);
        description = ''
          WHICH ENGINE fills this role. Available: ${lib.concatStringsSep ", " (lib.attrNames engineKinds)}.

          Which of them a given piece of software actually speaks is the catalogue's, measured from
          the software rather than assumed, and one outside that set is refused by name -- a wrong
          choice does not degrade, it renders variables the process never reads.

          NOTHING HERE RUNS THE ENGINE. This names one that already exists, operated by whoever
          operates engines.
        '';
      };

      service = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "example-sql";
        description = ''
          NAME of the existing Service that serves this engine. A NAME: no dots, no scheme, no port,
          no path -- the namespace is the next field and the cluster domain is the platform's, and
          this module joins the three into the address. That is the point of it: a cross-namespace
          address is never written by hand here.

          For software that takes one whole connection string, this is refused -- see `dsn`.
        '';
      };

      namespace = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "example-engines";
        description = ''
          Namespace that Service lives in. A fleet fact, and deliberately not defaulted to this
          workload's own: the whole premise is that the engine is somebody else's workload.
        '';
      };

      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = ''
          Port to connect on. `null` (the default) uses the engine kind's canonical port, which is a
          property of the protocol rather than of anybody's network. Setting it says something
          deliberate.
        '';
      };

      database = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "example_app";
        description = "Which database inside the engine this workload uses.";
      };

      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "example_app";
        description = "Which role it connects as. The password is a reference -- see `password`.";
      };

      password = lib.mkOption {
        type = lib.types.nullOr credentialType;
        default = null;
        description = ''
          The Secret and key holding this connection's password. A reference, never a value:
          everything this module renders is committed to git.
        '';
      };

      dsn = lib.mkOption {
        type = lib.types.nullOr credentialType;
        default = null;
        description = ''
          The Secret and key holding a WHOLE CONNECTION STRING, for software that takes one value
          rather than separate variables.

          This remains the source for every opaque or credential-bearing string. The ADDRESS is
          inside the Secret too, so nothing can check where it points. For the narrower case of a
          credential-free in-cluster Service URL, see `serviceDsn`.
        '';
      };

      serviceDsn = lib.mkOption {
        type = lib.types.nullOr serviceDsnType;
        default = null;
        description = ''
          A credential-free whole connection string derived from a typed scheme, a bare Service
          name and a port. The Service is resolved in this workload's category namespace and under
          `nixoffice.cluster.platform.clusterDomain`; no host, path, query or userinfo is accepted.

          Available only where the selected engine's catalogue entry explicitly permits the
          scheme. Mutually exclusive with `dsn`, whose existing Secret-backed behavior is unchanged.
        '';
      };
    };
  };

  # Shared by every group. What is NOT here matters as much as what is: no `namespace` (a category
  # decides that), no `replicas` (everything here is the single writer of something), no
  # `manifests` and no `raw` (everything here is one image), and nothing anywhere that could name an
  # engine's image, version, storage or root credential.
  sharedOptions = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to render this workload. Declaring the attribute is declaring the workload, so this
        defaults to true; set false to park a declaration without rendering it.
      '';
    };

    project = lib.mkOption {
      type = lib.types.str;
      default = platform.project;
      defaultText = lib.literalExpression "config.nixoffice.cluster.platform.project";
      description = "Delivery project this workload's Application belongs to.";
    };

    createNamespace = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this workload anchors its category's namespace. Defaults to false: a category
        outlives every application in it, and exactly one thing may own the namespace. Two workloads
        creating one namespace fails eval.
      '';
    };

    version = lib.mkOption {
      type = lib.types.str;
      example = "0.0.0";
      description = ''
        Which version THIS workload runs, used as the image tag. Required, with no default anywhere
        in this repository: no catalogue entry carries a version, because an entry is a KIND of
        software and a version is a value.

        It matters more here than in most of this family. Several of these applications run schema
        migrations on first start, against a database this repository does not own -- so the version
        is what decides whether a restart is a restart or a migration.
      '';
    };

    image = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Whole image reference, replacing the catalogue repository plus `version`. Set it to PIN BY
        DIGEST (`repository:tag@sha256:...`), which is the only way two syncs of an identical
        rendered tree cannot run different code -- the grammar warns while it is unpinned.
      '';
    };

    exposure = lib.mkOption {
      type = lib.types.enum [ "internal" "nb" "public" ];
      default = "internal";
      description = ''
        WHO can reach this workload, as a class and never an address. `internal` is the default.

        One application in this catalogue asks nobody for anything, and `public` on it is refused
        rather than warned about -- the class is a property of the WORKLOAD, and that one serves an
        editing interface and a published view from one pod.
      '';
    };

    scaling = lib.mkOption {
      type = lib.types.enum [ "always" "scale-to-zero" ];
      default = "always";
      description = ''
        Whether this workload keeps a running replica or idles at zero until something wakes it.

        NOT UNIFORMLY SAFE IN THIS REPOSITORY, and the three answers are calibrated rather than
        guessed. REFUSED where work is fired by an in-process timer or by a filesystem watcher: at
        zero the interval does not happen and the dropped file is seen by nobody, silently. WARNED
        where the work is fired by a caller outside the pod, which wakes it and pays the cold start
        out of its own timeout -- and warned again, separately, wherever that cold start is long
        enough that a person notices it.
      '';
    };

    slot = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        THE POSITION this workload holds in the fleet's ordered identity space. Not an address --
        the layers underneath map it into however many address spaces the fleet keeps, which is
        exactly why nothing here moves one.

        The VALUE is a fleet fact and belongs to the consumer that passes it in. Every entry in this
        catalogue declares ports, so every workload here renders a Service and wants one. Which
        RANGE the numbers may come from is a different question, answered by the band model -- see
        `nixoffice.cluster.platform.origin`.
      '';
    };

    state = lib.mkOption {
      type = lib.types.attrsOf backingType;
      default = { };
      description = ''
        What BACKS each directory this software writes, keyed by the catalogue's own name for it.
        Where each lands inside the container is knowledge and comes from the catalogue; what holds
        it is a value and comes from here.

        EVERY directory the catalogue marks as one this software cannot lose must appear. So must
        the directory holding an EMBEDDED engine, when that is the engine this declaration chose --
        and that same directory must NOT appear when it is not, because a backing for a database
        file nothing will ever write reads as though the data were in it.
      '';
    };

    connections = lib.mkOption {
      type = lib.types.attrsOf connectionType;
      default = { };
      description = ''
        THE ENGINES THIS SOFTWARE CONNECTS OUT TO, keyed by the catalogue's ROLE for each one --
        `database`, `broker`, `cache`. A role rather than an engine kind, because one application
        here opens two SQL connections to two different databases for two different purposes.

        NOTHING HERE RUNS AN ENGINE, and nothing here can: there is no option anywhere in this
        module that could name an engine's image, its version, its storage or its root credential,
        and one declaration renders exactly one container. An engine is somebody else's workload and
        this names it.

        A REQUIRED ROLE LEFT UNDECLARED IS AN EVAL FAILURE, which is the guard that matters most in
        this repository. Four of these applications start perfectly happily with no database
        configuration at all -- they create a file inside their own container, work, and report
        themselves healthy -- and one of them starts a whole database SERVER it ships in its image,
        suppressed only by being told a host that is not local. Choosing an embedded engine here is
        something somebody wrote down.
      '';
    };

    credentials = lib.mkOption {
      type = lib.types.attrsOf credentialType;
      default = { };
      description = ''
        The credentials this software reads, keyed by the catalogue's ROLE for each one. WHICH
        environment variable a role arrives in is knowledge; which Secret holds it and under which
        key is a value. A role the software does not read is refused, and a required role that is
        missing is refused.

        A connection's password is NOT here: it belongs to the connection that uses it, in
        `connections.<role>.password`, so that a credential and the thing it opens cannot drift
        apart.
      '';
    };

    envFromSecrets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        NAMES of existing Secrets loaded wholesale into the environment, for software whose set of
        keys changes without its declaration changing -- an identity-provider configuration is the
        usual one here.
      '';
    };

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra plain environment, merged OVER whatever the catalogue and this module supply. Plain is
        the operative word: a credential belongs in a Secret, and an address belongs to whatever
        allocates addresses -- the app grammar scans these values and refuses an address literal.

        This is where capacity goes, and where the address of a service this repository names and
        does not wire goes: a document converter, a content extractor, a mail relay. The catalogue
        supplies what software needs in order to be CORRECT and never what it needs in order to be
        the right size.
      '';
    };

    args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra entrypoint arguments, appended to whatever the catalogue supplies.";
    };

    publicUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://example.com";
      description = ''
        The ORIGIN a browser reaches this workload at -- scheme and host, nothing else -- for
        software that has to be told. A fleet fact, which is why it is here and not in the
        catalogue.

        Give no port, no path and no trailing slash. WHICH VARIABLES it goes into, whether each one
        wants the whole origin or the bare host, and any path suffix are knowledge and live in the
        catalogue: one application here needs three variables in two forms from this one value, and
        another wants the host with the scheme stripped off. That split is what makes the classic
        failure -- every credential correct and nobody able to sign in -- unwritable rather than
        merely documented.

        Refused on software that reads no such variable, and required on software that does.
      '';
    };

    backgroundWork = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        WHETHER THIS INSTANCE DOES WORK OUTSIDE A REQUEST, for the software where that is optional.

        Required -- and refused everywhere else. Where the software's background work is not
        optional, this would be a claim that can only be wrong; where it has none, it would be a
        claim about behaviour that does not exist. Where it IS optional, no default could be right,
        because the answer is what decides whether the workload may idle at zero.

        Where the software has a real switch, this module renders it from this same value, so a
        declaration claiming the work is off cannot be running with it on. Where it has none -- work
        that exists only because somebody authored something that schedules it -- this is a
        statement about how the instance is used, and nothing is rendered from it.
      '';
    };
  };

  # THE COLLABORATIVE EDITORS, and the difference is the whole reason they are a separate option
  # set. Their unit of work is a SESSION rather than a request, so `scale-to-zero` is not in this
  # enum at all -- a missing value rather than a guard that fires, because any software belonging to
  # this group has the same property. And they alone are told which document hosts may reach them.
  coeditorOptions = sharedOptions // {
    scaling = lib.mkOption {
      type = lib.types.enum [ "always" ];
      default = "always";
      description = ''
        Whether this workload keeps a running replica. `scale-to-zero` IS NOT IN THIS ENUM, and its
        absence is the encoding of what puts software in this group: its unit of work is an editing
        SESSION -- a long-lived connection holding a document that has been changed and not yet
        written back to the system that owns it. A wake front counts requests, sees an idle
        connection, and takes the pod away in the middle of that.

        A missing value rather than a refusal, so widening it means editing this repository and
        saying why. See ../studies/the-work-that-outlives-the-request.md.
      '';
    };

    documentHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "https://files.example.com" ];
      description = ''
        The ORIGINS of the systems that may hand this editor a document. Bare origins: scheme and
        host, nothing else.

        A PORT MUST NOT APPEAR, and that is not a style rule. The value is compared as a PATTERN
        against a host that carries no port, so one with a port matches nothing -- and the symptom
        is a document that never opens rather than a configuration error. The numbering of the
        variables and the escaping of every dot are knowledge too, and this module applies both.

        Required for software configured from this end, and refused for software configured from
        the other.
      '';
    };
  };

  # The factory owns each root option and selector enum. Keep the former examples and selector
  # declarations beside their roots so the documentation-only delta stays reviewable, but pass
  # neither as `extraOptions`: the selector path is deliberately collision-protected by the API.
  mkKind = { options ? sharedOptions, extra, description, example }: {
    selector = lib.head (lib.attrNames extra);
    extraOptions = options;
    inherit description example;
  };

  available = group: lib.concatStringsSep ", " (lib.attrNames catalogue.${group});

  selector = group: what: lib.mkOption {
    type = lib.types.enum (lib.attrNames catalogue.${group});
    description = "Which ${what}, from the catalogue. Available: ${available group}.";
  };

  platformOptions = {
      namespaces = lib.mkOption {
        description = ''
          WHICH NAMESPACE each category's workloads land in. One option per category the catalogue
          contains, WITH NO DEFAULT: evaluation fails naming the option the moment a workload of
          that category is declared, because what a cluster calls its namespaces is a value.

          That the categories exist, and which application is in which, is knowledge -- and two of
          them hold two applications each, on purpose. That is what a category is for: a container
          that outlives any one application in it. Two categories may not resolve to one namespace,
          and a namespace may not be named after an application in this catalogue or after a
          workload declared in it.

          There is no per-workload override anywhere in this module and there will not be one.
        '';
        type = lib.types.submodule {
          options = lib.genAttrs allCategories (category: lib.mkOption {
            type = lib.types.str;
            description = "Namespace for the `${category}` category.";
          });
        };
      };

      project = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = ''
          Delivery project every workload lands in unless it says otherwise.

          Defaults to `default` -- the delivery tool's own built-in project, which permits every
          destination and is therefore the answer that cannot break a render. It is not the answer
          to leave in place: name a project of your own so this surface is governed like everything
          else.
        '';
      };

      clusterDomain = lib.mkOption {
        type = lib.types.str;
        default = "cluster.local";
        description = ''
          The cluster's internal DNS domain, used to build the addresses of the ENGINES these
          applications connect out to. Defaulted, unlike the namespaces, because it is a Kubernetes
          default rather than a fleet fact -- but it is an option because a cluster installed with a
          different one would otherwise get connection strings that resolve nowhere.
        '';
      };

      origin = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "nixoffice";
        description = ''
          The declaring-origin name to stamp on the workloads the app grammar renders, handing their
          slots to the BAND MODEL -- which governs which range of the identity space a declaring
          repository's workloads may take a number from.

          `null` by default because `origin` and `slot` are that model's terms: defining them into a
          render that does not include it fails with "the option does not exist". Set this only when
          it is part of the same render, and set it to the name that model binds a band for.
        '';
      };

      warnColdStartAtOrAbove = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = ''
          Warn about a workload declared `scale-to-zero` whose measured cold start is this many
          seconds or more. `0` turns the warning off.

          It exists because several applications here are genuinely heavy -- an office suite that
          pre-forks document processes, a typesetting service that carries a whole distribution, a
          document pipeline that opens a search index -- and the cost of idling them at zero is paid
          in full by whoever arrives first, every time. That is a judgement about people rather than
          about correctness, so it is a number somebody can move rather than a rule.
        '';
      };
  };

  rootDefinitions = {
    wikis = mkKind {
      description = ''
        Wikis, keyed by a name of your choosing. Pages somebody AUTHORED, linked to each other, in
        a corpus that is the wiki itself.

        The one group here whose content is text a person typed into it -- everything else either
        receives documents, tracks commitments, or edits a file that lives somewhere else.
      '';
      example = lib.literalExpression ''
        {
          example-wiki = {
            wiki = "bookstack";
            version = "0.0.0";
            slot = 3;
            exposure = "nb";
            createNamespace = true;
            publicUrl = "https://wiki.example.com";
            state.config.hostPath = "/example/state/wiki";
            # The engine is somebody else's workload. This names it; it never runs one.
            connections.database = {
              engine = "mariadb";
              service = "example-sql";
              namespace = "example-engines";
              database = "example_wiki";
              user = "example_wiki";
              password = { secret = "example-wiki-db"; key = "password"; };
            };
          };
        }
      '';
      extra.wiki = selector "wikis" "wiki";
    };

    filings = mkKind {
      description = ''
        Document managers, keyed by a name of your choosing. Software that keeps documents you
        RECEIVED, with the metadata that makes them findable again.

        TWO ENTRIES ANSWER THIS ONE QUESTION and they are not redundant. One is a PIPELINE: it
        transforms what you give it, owns the result, and needs a broker and two converter services
        to do it. The other is a SHELF: it keeps the file you gave it under a name you can predict.
        The `ingest` field in the catalogue is the difference, and it is mechanical rather than
        editorial -- see the studies.
      '';
      example = lib.literalExpression ''
        {
          example-filing = {
            filing = "papra";
            version = "0.0.0";
            slot = 4;
            exposure = "nb";
            publicUrl = "https://files.example.com";
            # Its intake watcher is optional, and whether it is on decides whether this may sleep.
            backgroundWork = true;
            state = {
              appdata.hostPath = "/example/state/filing-appdata";
              corpus.hostPath = "/example/documents";
            };
            connections.database.engine = "sqlite";   # embedded, chosen deliberately
          };
        }
      '';
      extra.filing = selector "filings" "document manager";
    };

    trackers = mkKind {
      description = ''
        Trackers, keyed by a name of your choosing. Commitments with a state: a task, a project, a
        card.

        THIS GROUP SPANS TWO CATEGORIES, which is the clearest demonstration in this repository that
        a group and a category are different questions. A board and a due-date list are the same
        KIND of software and land in different namespaces, because they are read by different
        people and fail differently. Inside the category that holds two of them, the catalogue's
        `unit` field is what separates them.
      '';
      example = lib.literalExpression ''
        {
          example-tasks = {
            tracker = "vikunja";
            version = "0.0.0";
            slot = 5;
            exposure = "nb";
            publicUrl = "https://tasks.example.com";
            # Its reminder timer is optional. False here, and this module renders the switch from
            # the same value -- which is what makes scaling to zero safe rather than hopeful.
            backgroundWork = false;
            scaling = "scale-to-zero";
            state = {
              files.hostPath = "/example/state/tasks-files";
              database.hostPath = "/example/state/tasks-db";
            };
            connections.database.engine = "sqlite";
          };
        }
      '';
      extra.tracker = selector "trackers" "tracker";
    };

    schedulers = mkKind {
      description = ''
        Scheduling, keyed by a name of your choosing. Software that publishes when you are free and
        takes bookings from people who have no account with you.

        A group of its own because of WHO reaches it. Everything else in this repository is opened
        by the person whose work is in it; this is opened by whoever was sent a link.
      '';
      example = lib.literalExpression ''
        {
          example-booking = {
            scheduler = "calcom";
            version = "0.0.0";
            slot = 6;
            exposure = "public";
            publicUrl = "https://book.example.com";
            connections.database = {
              engine = "postgres";
              dsn = { secret = "example-booking-db"; key = "url"; };
            };
            credentials = {
              session = { secret = "example-booking"; key = "session"; };
              encryption = { secret = "example-booking"; key = "encryption"; };
            };
          };
        }
      '';
      extra.scheduler = selector "schedulers" "scheduling application";
    };

    coeditors = mkKind {
      options = coeditorOptions;
      description = ''
        Collaborative document editors, keyed by a name of your choosing. Software that is HANDED a
        document by another system, edits it in people's browsers, and hands it back.

        IT OWNS NO DOCUMENT, which is what makes it a group rather than a kind of office suite: what
        it keeps is a cache and an identity, and the work lives in whatever storage system called
        it. Two consequences are in the option set rather than in prose -- `scale-to-zero` is not in
        this group's `scaling` enum, because the unit of work is a session; and this group alone is
        told which document hosts may reach it.
      '';
      example = lib.literalExpression ''
        {
          example-editor = {
            coeditor = "collabora";
            version = "0.0.0";
            slot = 7;
            exposure = "public";
            publicUrl = "https://edit.example.com";
            # Origins in, numbered escaped patterns out. A port here matches nothing.
            documentHosts = [ "https://files.example.com" ];
          };
        }
      '';
      extra.coeditor = selector "coeditors" "collaborative editor";
    };

    compilers = mkKind {
      description = ''
        Typesetting services, keyed by a name of your choosing. Software where several people edit
        one SOURCE document and a toolchain turns it into the artefact they are actually making.

        The second half has no equivalent anywhere else here: everything else stores what you wrote,
        and this runs a compiler over it -- which is why it is the heaviest thing in this catalogue
        and why its cold start is measured rather than estimated.
      '';
      example = lib.literalExpression ''
        {
          example-typesetting = {
            compiler = "overleaf";
            version = "0.0.0";
            slot = 8;
            exposure = "nb";
            publicUrl = "https://typeset.example.com";
            state.data.hostPath = "/example/state/typesetting";
            connections = {
              # Its document store must be a replica set, even with one member. The catalogue says
              # so and the report publishes it; nothing here can check somebody else's workload.
              database.engine = "mongodb";
              database.dsn = { secret = "example-typesetting"; key = "documentStore"; };
              cache = {
                engine = "redis";
                service = "example-keyvalue";
                namespace = "example-engines";
              };
            };
            credentials.session = { secret = "example-typesetting"; key = "session"; };
          };
        }
      '';
      extra.compiler = selector "compilers" "typesetting service";
    };

    records = mkKind {
      description = ''
        Record platforms, keyed by a name of your choosing. Structured records with an interface and
        an API over them, where what a record MEANS is the operator's.

        The catalogue's `schema` field says whether the shapes are yours to define or the software's
        to know, which is the difference between the two entries here -- and the reason they share a
        group despite landing in two categories.
      '';
      example = lib.literalExpression ''
        {
          example-records = {
            record = "directus";
            version = "0.0.0";
            slot = 9;
            exposure = "nb";
            publicUrl = "https://records.example.com";
            # It has no switch for this: the answer is whether anybody authored a scheduled
            # automation, which is a fact about how the instance is used.
            backgroundWork = false;
            scaling = "scale-to-zero";
            state = {
              uploads.hostPath = "/example/state/records-uploads";
              extensions.hostPath = "/example/state/records-extensions";
            };
            connections.database = {
              engine = "postgres";
              service = "example-sql";
              namespace = "example-engines";
              database = "example_records";
              user = "example_records";
              password = { secret = "example-records-db"; key = "password"; };
            };
            credentials = {
              key = { secret = "example-records"; key = "key"; };
              secret = { secret = "example-records"; key = "secret"; };
            };
          };
        }
      '';
      extra.record = selector "records" "record platform";
    };

  };

  reportOptions = {
    # ── Computed, read-only ─────────────────────────────────────────────────────────────────────

    categories = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      readOnly = true;
      default = lib.genAttrs categoriesInUse
        (c: lib.sort (a: b: a < b) (map (x: x.name) (inCategory c)));
      defaultText = lib.literalExpression "computed from the declared workloads";
      description = ''
        category -> the workloads in it. Nothing declared a category: it is read from each
        workload's catalogue entry, and it is what decides the namespace.

        The point of publishing it is that the categories holding MORE THAN ONE application are
        visible. Two applications answering one question is a decision somebody made, and it should
        be readable in one place rather than reconstructed from a namespace listing.
      '';
    };

    namespaces = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.genAttrs categoriesInUse namespaceOfCategory;
      defaultText = lib.literalExpression "the namespace each DECLARED category resolved to";
      description = ''
        category -> the namespace its workloads landed in, for every category actually declared.
        Only the declared ones: reading the namespace of a category nobody uses would force an
        option nobody has any reason to set.
      '';
    };

    engineDependencies = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      readOnly = true;
      default = lib.listToAttrs
        (map (x: lib.nameValuePair x.name (lib.mapAttrs (_: c: c.engine) (connectionsOf x)))
          (lib.filter (x: connectionsOf x != { }) allWorkloads));
      defaultText = lib.literalExpression "workload -> role -> the engine kind filling it";
      description = ''
        workload -> the engines it connects out to, by the role each one plays.

        Published rather than rendered, and it is the answer to "what does this surface depend on
        that it does not operate". Nine of these twelve applications need at least one engine and
        they do not agree on which; none of them is this repository's to run.
      '';
    };

    externalEngines = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = lib.sort (a: b: a < b) (lib.unique
        (lib.concatMap
          (x: lib.filter (e: !engineKinds.${e}.embedded)
            (lib.mapAttrsToList (_: c: c.engine) (connectionsOf x)))
          allWorkloads));
      defaultText = lib.literalExpression "every non-embedded engine kind some workload connects to";
      description = ''
        The distinct engine kinds this surface needs somebody else to be running. Read-only, and the
        point of it is that it is COUNTABLE: it is the list of things that have to exist before any
        of this starts, and the list a database tier can be checked against.

        An EMBEDDED engine is deliberately absent from it -- there is nothing for anybody else to
        run -- which makes the two lists together the honest picture of what this surface costs.
      '';
    };

    engineRequirements = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      readOnly = true;
      default = lib.listToAttrs
        (lib.filter (p: p.value != { })
          (map
            (x: lib.nameValuePair x.name
              (lib.mapAttrs (_: n: n.requires)
                (lib.filterAttrs (role: n: n.requires != null && connectionsOf x ? ${role})
                  (needsOf x))))
            allWorkloads));
      defaultText = lib.literalExpression "workload -> role -> what the engine has to be, beyond its kind";
      description = ''
        Where naming the engine KIND is not enough: what the engine behind a connection additionally
        has to BE. One of these applications needs its document store to be a replica set even with
        a single member, because it uses transactions a standalone server refuses -- a perfectly
        healthy engine of the right kind and version still produces an application that fails on
        write.

        Published rather than checked, deliberately: it is a property of somebody else's workload,
        and this repository can state a requirement it has no way to verify.
      '';
    };

    mustStayAwake = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.listToAttrs
        (map (x: lib.nameValuePair x.name (backgroundOf x).what)
          (lib.filter (x: backgroundActive x && triggerOf x != "caller") allWorkloads));
      defaultText = lib.literalExpression "workload -> the work that only happens while it runs";
      description = ''
        Workloads that do work NOTHING CAN WAKE THEM FOR, and what that work is. Every one of them
        is refused `scale-to-zero`, so this is the standing cost of the surface: the pods that have
        to be resident whether or not anybody is using them.

        It is a list two entries can leave by a declaration rather than by a migration -- their
        background work is optional, and turning it off is what makes them able to sleep.
      '';
    };

    corpora = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      readOnly = true;
      default = lib.listToAttrs
        (map (x: lib.nameValuePair x.name x.entry.corpus)
          (lib.filter (x: x.entry.corpus != [ ]) allWorkloads));
      defaultText = lib.literalExpression "workload -> the directories holding the work itself";
      description = ''
        workload -> which of its directories hold the WORK, as opposed to an index, a cache or a
        log. What is not in this list is derived and costs a rebuild; what is in it is somebody's
        documents.

        Read it beside `engineDependencies`: most of these keep the files here and the records that
        give them meaning in an engine somebody else runs, and neither half is usable alone.
      '';
    };

    splitCorpora = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.listToAttrs
        (map
          (x: lib.nameValuePair x.name
            (
              let engine = engineOf x x.entry.corpusInEngine; in
              listNames x.entry.corpus + " on disk, and the records that give them meaning in "
              + (if isEmbeddedEngine engine
              then "an embedded `${engine}` under `${x.entry.state.${(needsOf x).${x.entry.corpusInEngine}.engines.${engine}.state}.mountPath}`"
              else "a `${toString engine}` engine this repository does not run")
            ))
          (lib.filter
            (x: x.entry.corpus != [ ]
              && x.entry.corpusInEngine != null
              && connectionsOf x ? ${x.entry.corpusInEngine}
              && (
              !(isEmbeddedEngine (engineOf x x.entry.corpusInEngine))
                || !(lib.elem
                (needsOf x).${x.entry.corpusInEngine}.engines.${engineOf x x.entry.corpusInEngine}.state
                x.entry.corpus)
            ))
            allWorkloads));
      defaultText = lib.literalExpression "workload -> where the two halves of its corpus are";
      description = ''
        THE WORKLOADS WHOSE WORK IS IN TWO PLACES AT ONCE, and where the second place is. Most of
        these applications keep the files on disk and the records that give them meaning in an
        engine -- so a directory of documents named after database fields is not a corpus, and the
        records without the files are an index of things you no longer have.

        NEITHER HALF IS USABLE ALONE, so the backup that covers one of these has to capture both in
        ONE consistent moment -- and for most of them one half belongs to a system this repository
        does not run and cannot coordinate with. Published rather than warned about: it is a
        property of every entry here rather than a mistake in any declaration, and a warning that
        fires on almost everything is one people turn off.

        A workload whose embedded engine sits in the SAME directory as its corpus is absent, because
        for it there is nothing to coordinate -- one mount is both halves. There is exactly one of
        those.
      '';
    };

    unauthenticated = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = map (x: x.name)
        (lib.filter (x: x.entry.authentication == "none") allWorkloads);
      defaultText = lib.literalExpression "computed from the declared workloads";
      description = ''
        Workloads whose software asks nobody for anything. Read-only, and countable on purpose: for
        every one of these, whatever grants reachability IS the access control, and `public` on one
        is refused rather than warned about.

        The editors that authenticate PER DOCUMENT are deliberately not in this list. A request
        arriving at one without a token issued by the system that owns the file reaches nothing,
        which is a different thing from an interface with no password.
      '';
    };

    slots = lib.mkOption {
      type = lib.types.attrsOf lib.types.ints.unsigned;
      readOnly = true;
      default = lib.listToAttrs (map (x: lib.nameValuePair x.name x.w.slot) slotClaims);
      defaultText = lib.literalExpression "every declared workload that claims a slot";
      description = ''
        workload -> the position it claims. Nothing is rendered from it here: what an address looks
        like is the private layer's business, and this is what that layer reads to build one.
      '';
    };

  };

  # Keep only the terms this public surface owns. `adopt` is deliberately included even though it
  # says nothing about office software: it records whether THIS deployment is taking over objects
  # that already exist, and hiding that delivery-history fact would force a consumer back through
  # the lower-level grammar. `image` and role-shaped `credentials` are deliberate disabled-common
  # replacements in `extraOptions`; `state` remains enabled, and its exact legacy subtype refines
  # the common contract now that the factory treats absent extended backing fields as their closed
  # defaults.
  enabledOptions = [
    "version"
    "createNamespace"
    "adopt"
    "project"
    "slot"
    "exposure"
    "scaling"
    "state"
    "publicUrl"
    "env"
    "args"
  ];

  factoryRoots = lib.mapAttrs
    (group: definition: {
      catalogue = catalogueFor group;
      selector = definition.selector;
      inherit enabledOptions;
      extraOptions = definition.extraOptions;
      inherit namespaceOf volumeNameOf requiredStateKeys allowedStateKeys;
      extend = extendApp;
      description = definition.description;
    })
    rootDefinitions;

  factoryModule = mkConsumerModule {
    namespace = "nixoffice";
    optionPath = [ "nixoffice" "cluster" ];
    platformOption = "platform";
    roots = factoryRoots;

    # `project` and `origin` are factory-owned names. The other three platform terms keep their
    # exact existing option declarations; the resolved project default is restored below at the
    # same priority as the former mkOption default.
    extraPlatformOptions = builtins.removeAttrs platformOptions [ "project" "origin" ];
    extraNamespaceOptions = reportOptions;

    # Storage shape/requiredness, namespace anchors, slot collisions, declaration/rendered-name
    # collisions, and URL presence are now central. Everything here is office-domain knowledge.
    extraAssertions = _workloads:
      connectionAssertions
      ++ credentialAssertions
      ++ scalingAssertions
      ++ authAssertions
      ++ publicUrlAssertions
      ++ coeditorAssertions
      ++ categoryAssertions;

    # The factory owns the one slot-without-origin warning. These retain the calibrated background,
    # cold-start, and unauthenticated-exposure diagnostics.
    extraWarnings = _workloads: warnings;

    extraConfig = _workloads: {
      nixoffice.cluster.platform.project = lib.mkOptionDefault "default";
    };
  };
in
{
  imports = [ factoryModule ];
}
