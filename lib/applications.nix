#
# The cluster catalogue: the office applications a person keeps their working life in, and the
# knowledge that makes each one actually run.
#
# ── THE PLACEMENT RULE, so the next candidate is decidable rather than argued ───────────────────
#
#   Is the thing a place where a person's OWN WORK is written, filed, tracked or edited -- a page,
#   a document, a commitment, an appointment, a record?
#     yes -> it belongs here
#     no  -> it belongs to whichever repository owns the thing it actually is
#
# "IT HAS DOCUMENTS IN IT" IS NOT THE TEST, and that clause is load-bearing. A file sync service, a
# backup tool and an object store all hold documents, and if holding one were the test this
# catalogue would swallow the storage layer. The test is whether the software is where the WORK
# happens: you open it, you write in it, and what comes out is yours.
#
# ── SEVEN GROUPS, BECAUSE THERE ARE SEVEN KINDS OF THING HERE ──────────────────────────────────
#
#   `wikis`       pages you author and link. The corpus is the wiki itself.
#   `filings`     documents you RECEIVED, kept with the metadata that makes them findable again.
#   `trackers`    commitments with a state: a task, a project, a card.
#   `schedulers`  other people's claims on your time. The only group here reached by strangers.
#   `coeditors`   live editing of a document ANOTHER system stores. No corpus of its own at all.
#   `compilers`   a source document turned into an artefact, in a project the software owns.
#   `records`     structured records with a UI over them, where what a record MEANS is yours.
#
# ── A GROUP IS NOT A CATEGORY, AND THAT IS DELIBERATE ──────────────────────────────────────────
#
# Every entry also carries a `category`, and it is a different question with a different answer:
#
#   the GROUP     is what the software IS. It decides which option set a declaration gets.
#   the CATEGORY  is what it lands NEXT TO. ../modules/cluster.nix reads a workload's namespace
#                 from it, and nothing declares it.
#
# The two come apart in this catalogue rather than in theory: a kanban board and a task list are
# the same KIND of software -- commitments with a state -- and they are two categories, because a
# board full of cards and a list of due dates fail differently, are backed up differently, and are
# reached by different people. Flattening either into the other would make one of the two questions
# unanswerable.
#
# TWO CATEGORIES HOLD TWO APPLICATIONS EACH, on purpose and not in transition: two document
# managers, and two task managers. That is what a category is FOR -- it is a container that outlives
# any one application in it -- and it is why no namespace may be named after an application inside
# it. See ../studies/ for what actually separates each pair, and what running both costs.
#
# ── ONE PIECE OF SOFTWARE IS NOT ONE VERSION, so no entry below carries one ─────────────────────
#
# For the same reason the sibling catalogues state: a version is a value supplied by whoever
# declares a workload, and an entry here is a KIND of software rather than a copy of one. Two of
# these twelve are pinned in production to the exact version that OWNS the migrated schema, because
# their first start runs migrations -- which is precisely the fact a version baked into a catalogue
# would get wrong for everybody else.
#
# ── THE ENGINE RULE, WHICH IS THE STRUCTURE OF THIS REPOSITORY'S CLUSTER HALF ──────────────────
#
# MOST OF THESE NEED A DATABASE AND THEY DO NOT AGREE ON WHICH. Postgres, MariaDB, MongoDB, Redis
# and an embedded SQLite are all represented, and several entries accept more than one. NONE OF
# THEM IS THIS REPOSITORY'S TO RUN: a sibling owns engines, and an application that shipped its own
# would be the second implementation of a database tier that nobody asked for.
#
# So a dependency on an engine is a TYPED, NAMED thing here rather than a connection string
# somebody remembers to set:
#
#   `needs.<role>`  what this software connects OUT to, keyed by the ROLE the connection plays --
#                   `database`, `broker`, `cache`. A role rather than an engine kind, because one
#                   application here opens TWO SQL connections to two different databases for two
#                   different purposes, and a table keyed by engine kind could not say so.
#   `.kind`         which FAMILY of engine fills the role: `sql`, `documentdb`, `keyvalue`.
#   `.engines`      which engine kinds the software ACTUALLY supports, each with the wiring it
#                   demands. The set is the software's, measured; a consumer choosing one outside it
#                   is refused by name.
#   `.required`     whether the software runs at all without it.
#
# THE WIRING HAS THREE STYLES AND THE DIFFERENCE MATTERS OPERATIONALLY:
#
#   `fields`  host, port, database and user arrive as separate variables, so ../modules/cluster.nix
#             DERIVES the address from the Service name and namespace the declaration gives it, and
#             nobody writes a cross-namespace address by hand. Only the password is a credential.
#   `dsn`     the software takes ONE connection string. An opaque or credential-bearing value stays
#             inside a Secret. Where an engine explicitly publishes safe Service-URL schemes, a
#             credential-free string may instead be derived from a typed scheme, bare Service name,
#             port, category namespace and cluster domain -- never from an arbitrary raw URL.
#   `file`    the engine is EMBEDDED: a file inside one of this software's own state directories.
#             No address, no user, no password -- and a hard requirement that the directory holding
#             it is backed, because the failure otherwise is the whole database.
#
# THE EMBEDDED FALLBACK IS THE HAZARD THIS MODEL EXISTS FOR. Four entries below start perfectly
# happily with NO database configuration at all: they create an SQLite file inside the container and
# report themselves healthy, and the data is gone at the next restart. One of them additionally
# ships a whole Postgres server inside its image, and the ONLY thing that stops it starting that
# server is being told a host that is not localhost. So `needs.<role>` with `required = true` is
# defaultless in the declaration and evaluation fails naming it: choosing the embedded engine is a
# value somebody wrote down, and never what happens when nobody wrote anything.
# See ../studies/an-office-application-may-not-run-the-engine-it-needs.md.
#
# ── THE OTHER AXIS: WHAT HAPPENS WHEN NOBODY IS LOOKING ────────────────────────────────────────
#
# `background` says whether work outlives the request that started it, and WHAT FIRES IT:
#
#   `timer`   an in-process scheduler. Reminder mail, recurring tasks, a conversion queue, a flush
#             of buffered edits. At zero replicas the interval simply does not happen.
#   `watch`   a filesystem watcher on an intake directory. Nothing HTTP happens at all when a file
#             is dropped there, so no wake front can ever be triggered by it.
#   `caller`  something outside the pod calls an endpoint on a schedule. This one survives scaling
#             to zero -- the call wakes the pod -- and pays the whole cold start out of the caller's
#             timeout.
#
# `background.toggle` is the interesting half. For two entries the work is genuinely OPTIONAL, and
# the declaration must SAY which way it is set: where the software has a switch, this catalogue
# names it and the module renders it from the same boolean the guard reads -- so a declaration
# claiming reminders are off cannot be running with them on.
# See ../studies/the-work-that-outlives-the-request.md.
#
# ── FIELDS ─────────────────────────────────────────────────────────────────────────────────────
#
# Shared by every group:
#
#   `category`     which namespace-deciding category this belongs to. NOT DECLARABLE anywhere.
#   `image`        container image REPOSITORY, with no tag. The tag is the declaration's `version`.
#   `ports`        named container-side ports, `<name> = <number>`. A container port is a property
#                  of the software rather than of any network, which is the one kind of number a
#                  public catalogue may carry.
#   `primaryPort`  which of those the probes watch.
#   `state`        directories this software writes, as
#                  `<name> = { mountPath; readOnly; required; embeddedFor; }`. WHERE each lands
#                  inside the container is knowledge; what BACKS it is a value and comes from the
#                  declaration. `required` is false for a directory whose loss costs a rebuild
#                  rather than content. `embeddedFor` names the `needs` role whose EMBEDDED engine
#                  lives in it -- such a directory must be backed when that engine is chosen and
#                  must not be backed when it is not, because a backing for a database that will
#                  never be written reads as though the data were there.
#   `corpus`       WHICH of those directories hold the work itself, by name. What is not in this
#                  list is derived: an index, a thumbnail cache, a log.
#   `corpusInEngine` the `needs` role whose engine holds the PRIMARY record, or null. Where this is
#                  set and `corpus` is non-empty, neither half is usable alone and they have to be
#                  backed up in one consistent moment -- across two systems, one of which this
#                  repository does not run.
#   `needs`        engine dependencies. See above.
#   `env`          plain environment the software needs in order to be CORRECT -- never sizing,
#                  never credentials, never an address of anything outside the container.
#   `args`         entrypoint arguments in the same spirit.
#   `readiness`    probe shape and timing. `path = null` is a TCP connect, which is the honest
#                  answer for software that documents no health endpoint.
#   `startup`      a startup probe for software whose FIRST boot is slow and whose steady state is
#                  not, or null. Better than inflating a readiness budget forever.
#   `credentials`  `<role> = { env; required; }`. The role is what the credential IS; which Secret
#                  holds it and under which key is a value.
#   `authentication`
#                    `builtin`  it has accounts and always asks.
#                    `token`    it authenticates per-DOCUMENT with a token issued by the system that
#                               handed it the file. There are no accounts, and a request without a
#                               token reaches nothing.
#                    `none`     it asks nobody for anything. Whoever reaches it has everything.
#   `publicUrl`    `{ envs = { <VAR> = { form; path; }; }; }` for software that must be told where a
#                  browser reaches it, or null. THE VALUE IS A FLEET FACT and comes from the
#                  declaration as a bare origin; the variable names, the FORM each one wants
#                  (a whole origin, or the host alone) and any path suffix are knowledge and live
#                  here. One entry needs three variables in two forms from one value.
#   `background`   see above, or null when everything is computed in answer to a request. A null is
#                  a claim rather than a blank.
#   `coldStart`    `{ seconds; what; }` -- how long this software takes to answer after a start, and
#                  what it is doing. Measured from running deployments rather than guessed. It sizes
#                  the probes above and it is what makes the scale-to-zero warning quantitative
#                  rather than a feeling.
#   `note`         what the entry is, and every non-obvious thing about running it.
#
# Group-specific:
#
#   `ingest`       (filings) `pipeline` when the software TRANSFORMS what it is given and owns the
#                  result, `shelf` when it keeps the file it was given and indexes it. The only
#                  thing that separates the two document managers without appealing to marketing.
#   `unit`         (trackers) what ONE ROW is: a `task`, a `project`, a `card`. Same idea, same
#                  reason -- all three call themselves project management.
#   `schema`       (records) `operator` when the record shapes are yours to define, `fixed` when the
#                  software knows what a record is.
#   `wopiHosts`    (coeditors) `{ envPrefix; escape; }` for a coeditor that must be told which
#                  document hosts may hand it a file, or null. The variables are NUMBERED from one
#                  and the value is a regular expression, so the dots in a hostname have to be
#                  escaped and a port must not appear at all -- knowledge nobody remembers, and a
#                  coeditor that gets it wrong serves an error page instead of a document.
{ ... }:
rec {
  # ── The engine kinds, and the one number each of them is ────────────────────────────────────
  #
  # A canonical service port is the same kind of fact as a container port: a property of the
  # software, not of anybody's network. It is here so that a declaration naming an engine's Service
  # does not also have to name its port -- and so that a declaration that DOES name one is saying
  # something deliberate.
  engines = {
    postgres = { family = "sql"; port = 5432; embedded = false; };
    mariadb = { family = "sql"; port = 3306; embedded = false; };
    sqlite = { family = "sql"; port = null; embedded = true; };
    mongodb = { family = "documentdb"; port = 27017; embedded = false; };
    redis = {
      family = "keyvalue";
      port = 6379;
      embedded = false;
      serviceDsnSchemes = [ "redis" "rediss" ];
    };
  };

  # ── Wikis: pages you author and link ────────────────────────────────────────────────────────
  wikis = {
    bookstack = {
      category = "wiki";

      image = "lscr.io/linuxserver/bookstack";
      ports.http = 80;
      primaryPort = "http";

      state.config = {
        mountPath = "/config";
        readOnly = false;
        required = true;
        embeddedFor = null;
      };

      corpus = [ "config" ];
      corpusInEngine = "database";

      needs.database = {
        kind = "sql";
        required = true;
        requires = null;
        engines.mariadb = {
          style = "fields";
          typeEnv = null;
          typeValue = null;
          hostEnv = "DB_HOST";
          portEnv = "DB_PORT";
          portInHost = false;
          databaseEnv = "DB_DATABASE";
          userEnv = "DB_USERNAME";
          passwordEnv = "DB_PASSWORD";
          passwordRequired = true;
        };
      };

      env = { };
      args = [ ];

      readiness = {
        path = null;
        initialDelaySeconds = 20;
        periodSeconds = 10;
        timeoutSeconds = 3;
        failureThreshold = 18;
      };
      startup = null;

      credentials.appKey = { env = "APP_KEY"; required = false; };
      authentication = "builtin";

      publicUrl.envs.APP_URL = { form = "origin"; path = ""; };

      background = null;

      coldStart = {
        seconds = 30;
        what = "a PHP application boot, plus the schema migration its entrypoint runs on every start";
      };

      note = ''
        A wiki: shelves, books, chapters and pages, authored and linked by the people who use it.
        It is the only entry in this catalogue whose corpus is TEXT SOMEBODY TYPED, which is what
        puts it in a group of its own -- everything else here either receives documents, tracks
        commitments or edits somebody else's file.

        ITS PAGES ARE ROWS AND ITS PICTURES ARE FILES, and that split is the most important
        operational fact about it. The page content, the revision history and every permission live
        in the SQL engine; the uploaded images, the attachments and the generated application key
        live in the state directory. Neither half is usable alone: the database without the
        directory is a wiki whose images are all broken, and the directory without the database is a
        folder of pictures nobody can name. They must be backed up in ONE consistent moment, across
        two systems, one of which this repository does not run.

        IT SPEAKS ONE ENGINE FAMILY AND ONLY ONE. There is no Postgres support and no embedded
        option: without a MySQL-compatible engine it does not start at all, which -- unusually for
        this catalogue -- is the SAFE failure. The entries that quietly succeed on an embedded
        database are the dangerous ones.

        THE APPLICATION KEY IS GENERATED INTO THE STATE DIRECTORY WHEN IT IS NOT SUPPLIED, and that
        is why the credential role is optional rather than required. It is also why the directory
        being backed matters more than it looks: a regenerated key does not fail, it invalidates
        every session and makes anything the old key encrypted unreadable. Supplying it explicitly
        makes the workload survive an empty directory; not supplying it makes the directory
        load-bearing.

        IT MUST BE TOLD ITS OWN URL. Every link it generates, every redirect and the whole OAuth
        handshake are built from that one value, so a wrong one produces a wiki that works perfectly
        until somebody clicks something.

        THE PROBE IS A TCP CONNECT WITH A WIDE BUDGET. It publishes no cheap health endpoint, and
        its entrypoint runs migrations before serving anything -- and refuses to start at all while
        the engine is unreachable, which is a co-restart away from a crash loop on a cluster where
        both come up at once.
      '';
    };
  };

  # ── Filings: documents you received, kept so they can be found again ────────────────────────
  #
  # TWO ENTRIES, AND THEY ARE NOT REDUNDANT -- they are two answers to one question, and the `ingest`
  # field is what separates them. One is a PIPELINE: it transforms what you give it, owns the result,
  # and needs a broker and two converter services to do it. The other is a SHELF: it keeps the file
  # you gave it under a name you can predict, and is one process with one file.
  # See ../studies/two-document-managers-and-what-a-filing-is.md.
  filings = {
    paperless = {
      category = "dms";
      ingest = "pipeline";

      image = "ghcr.io/paperless-ngx/paperless-ngx";
      ports.http = 8000;
      primaryPort = "http";

      state = {
        data = {
          mountPath = "/usr/src/paperless/data";
          readOnly = false;
          required = true;
          embeddedFor = "database";
        };
        media = {
          mountPath = "/usr/src/paperless/media";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        consume = {
          mountPath = "/usr/src/paperless/consume";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        export = {
          mountPath = "/usr/src/paperless/export";
          readOnly = false;
          required = false;
          embeddedFor = null;
        };
      };

      corpus = [ "media" ];
      corpusInEngine = "database";

      needs = {
        database = {
          kind = "sql";
          required = true;
          requires = null;
          engines = {
            postgres = {
              style = "fields";
              typeEnv = null;
              typeValue = null;
              hostEnv = "PAPERLESS_DBHOST";
              portEnv = "PAPERLESS_DBPORT";
              portInHost = false;
              databaseEnv = "PAPERLESS_DBNAME";
              userEnv = "PAPERLESS_DBUSER";
              passwordEnv = "PAPERLESS_DBPASS";
              passwordRequired = true;
            };
            mariadb = {
              style = "fields";
              typeEnv = "PAPERLESS_DBENGINE";
              typeValue = "mariadb";
              hostEnv = "PAPERLESS_DBHOST";
              portEnv = "PAPERLESS_DBPORT";
              portInHost = false;
              databaseEnv = "PAPERLESS_DBNAME";
              userEnv = "PAPERLESS_DBUSER";
              passwordEnv = "PAPERLESS_DBPASS";
              passwordRequired = true;
            };
            sqlite = {
              style = "file";
              typeEnv = null;
              typeValue = null;
              env = null;
              prefix = "";
              file = "db.sqlite3";
              state = "data";
            };
          };
        };

        broker = {
          kind = "keyvalue";
          required = true;
          requires = "a broker its task workers share: the consumer, the OCR pass and the scheduler are separate processes inside this pod and they queue through it";
          engines.redis = {
            style = "dsn";
            env = "PAPERLESS_REDIS";
          };
        };
      };

      env = {
        # Correctness, and belt-and-braces against a trap this catalogue cannot fix on its own: a
        # Service named after this workload makes Kubernetes inject `<NAME>_PORT=tcp://<ip>:<port>`
        # into the pod, which collides with this software's own integer variable of the same name
        # and kills the server on boot. Setting it explicitly wins over the injection; turning the
        # injection off is a pod-spec field the app grammar has no term for -- see the note.
        PAPERLESS_PORT = "8000";
      };
      args = [ ];

      readiness = {
        path = "/";
        initialDelaySeconds = 0;
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 6;
      };
      startup = {
        path = "/";
        initialDelaySeconds = 0;
        periodSeconds = 5;
        timeoutSeconds = 5;
        failureThreshold = 72;
      };

      credentials.secretKey = { env = "PAPERLESS_SECRET_KEY"; required = true; };
      authentication = "builtin";

      publicUrl.envs = {
        PAPERLESS_URL = { form = "origin"; path = ""; };
        # THE SAME VALUE IN A DIFFERENT FORM. Its framework rejects any request whose Host header is
        # not in this list -- including a probe, which is why the probe below is a plain GET on the
        # Service address and its budget is wide. A hostname, never a URL.
        PAPERLESS_ALLOWED_HOSTS = { form = "host"; path = ""; };
        PAPERLESS_CSRF_TRUSTED_ORIGINS = { form = "origin"; path = ""; };
      };

      background = {
        trigger = "watch";
        what = "a consumer watches the intake directory and OCRs, classifies and files whatever appears in it, and a scheduled worker fetches mail, retrains the classifier and optimises the search index";
        toggle = null;
      };

      coldStart = {
        seconds = 120;
        what = "schema migrations, a process supervisor bringing up a web server and three workers, and a search index open";
      };

      note = ''
        A document management system that is a PIPELINE. You give it a scan; it OCRs it, runs it
        through a classifier it trained on your own filing decisions, matches a correspondent, a
        document type and tags, renames it by a template built from those fields, and keeps the
        result beside the original. What comes out is not what went in, and that is the product.

        THAT PIPELINE IS WHY IT CANNOT SLEEP, and the refusal is not about the OCR being slow. Two
        of its three background paths are not requests at all: a directory watcher ingests whatever
        is dropped into the intake folder, and a scheduler fetches mail and retrains the classifier
        on a timer. A wake front counts HTTP requests, so a file copied into the intake directory of
        a sleeping pod is seen by nobody -- it simply sits there, and nothing anywhere reports it.
        See ../studies/the-work-that-outlives-the-request.md.

        IT ACCEPTS THREE ENGINES AND FALLS BACK TO THE FOURTH WHEN TOLD NOTHING. With no database
        host it uses an embedded SQLite inside the state directory, starts, works, and is a complete
        installation -- which is exactly the configuration somebody reaches by forgetting rather
        than by choosing. The declaration has to name one.

        IT ALSO NEEDS A BROKER, and that is a second engine this repository does not run. Its
        workers are separate processes queueing through it; without one the web interface comes up
        and nothing is ever consumed, with no error on the page.

        AND IT WANTS TWO CONVERTER SERVICES it can reach over HTTP, for office formats and for
        content extraction. Both are optional, both are addresses, and both belong in the
        declaration's own `env` -- they are somebody else's workloads, and the sensible ones to
        point at a wake front, because they are called by this pod rather than by a person.

        ONE THING THE APP GRAMMAR CANNOT EXPRESS FOR IT. The Kubernetes service-link injection
        described above is turned off with a pod-spec field this vocabulary has no term for. The
        environment variable set here wins over the injection, which covers the case; a consumer
        that wants the field itself defines it onto the rendered object through the grammar's own
        typed merge. Said out loud rather than left as a surprise.

        THE PROBE IS A PLAIN GET WITH A LONG STARTUP BUDGET. Its first boot migrates, brings up a
        supervisor and opens a search index; a readiness probe alone would either flap or have to
        carry that budget forever, which is what the separate startup probe exists to avoid.
      '';
    };

    papra = {
      category = "dms";
      ingest = "shelf";

      image = "ghcr.io/papra-hq/papra";
      ports.http = 1221;
      primaryPort = "http";

      state = {
        appdata = {
          mountPath = "/app/app-data";
          readOnly = false;
          required = true;
          embeddedFor = "database";
        };
        corpus = {
          mountPath = "/app/corpus";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
      };

      corpus = [ "corpus" ];
      corpusInEngine = "database";

      needs.database = {
        kind = "sql";
        required = true;
        requires = null;
        engines.sqlite = {
          style = "file";
          typeEnv = null;
          typeValue = null;
          env = "DATABASE_URL";
          prefix = "file:";
          file = "db/db.sqlite";
          state = "appdata";
        };
      };

      env = {
        # THE THREE VARIABLES THAT MAKE THIS ENTRY'S OWN CLAIM TRUE, which is why they are catalogue
        # knowledge rather than a consumer's taste. The default layout nests the documents inside the
        # application-data directory, which makes the readable corpus and the opaque database one
        # mount and defeats the only reason to prefer this software; and the default storage key
        # scheme writes files named after internal identifiers, which makes "the files are readable"
        # false in the way that matters -- you can open them, and you cannot tell which is which.
        DOCUMENT_STORAGE_DRIVER = "filesystem";
        DOCUMENT_STORAGE_FILESYSTEM_ROOT = "/app/corpus/documents";
        DOCUMENT_STORAGE_USE_LEGACY_STORAGE_KEY_DEFINITION_SYSTEM = "false";
        DOCUMENT_STORAGE_KEY_PATTERN = "{{organization.id}}/{{document.name}}";
        INGESTION_FOLDER_ROOT_PATH = "/app/corpus/ingestion";
      };
      args = [ ];

      readiness = {
        path = null;
        initialDelaySeconds = 10;
        periodSeconds = 10;
        timeoutSeconds = 3;
        failureThreshold = 18;
      };
      startup = null;

      credentials.authSecret = { env = "AUTH_SECRET"; required = true; };
      authentication = "builtin";

      publicUrl.envs = {
        APP_BASE_URL = { form = "origin"; path = ""; };
        TRUSTED_ORIGINS = { form = "origin"; path = ""; };
      };

      background = {
        trigger = "watch";
        what = "a watcher on the intake directory imports whatever is dropped there, extracts its text and moves the source aside";
        toggle = {
          option = "backgroundWork";
          env = "INGESTION_FOLDER_IS_ENABLED";
          onValue = "true";
          offValue = "false";
        };
      };

      coldStart = {
        seconds = 15;
        what = "a single server process opening an embedded database";
      };

      note = ''
        A document management system that is a SHELF. You give it a file; it keeps that file, under
        a name you can predict, and builds an index over it. Nothing is transformed and nothing is
        derived, which is the entire difference from the pipeline in the same category -- and the
        reason the two are both catalogued rather than one being the successor of the other.

        ITS RECORDS ARE ROWS AND ITS DOCUMENTS ARE FILES, in two separate directories on purpose.
        The environment above is what forces that split and what keeps the on-disk names readable;
        with the software's own defaults the documents live inside the application-data directory
        under identifier-shaped names, and the claim that anything else can read the corpus stops
        being true. Backing both, in one consistent moment, is still required -- a directory of
        readable files without the records is a folder, not an archive.

        ITS BACKGROUND WORK IS OPTIONAL, AND THAT IS THE INTERESTING PART. With the intake watcher
        off, everything it does happens inside a request and it can idle at zero replicas quite
        safely. With it on, files arrive by being COPIED INTO A DIRECTORY -- no HTTP request exists
        at any point, so nothing can wake it and the drop is simply never seen. The declaration has
        to state which of the two it is, and this module renders the switch from that same statement
        so the two cannot disagree.

        IT IS ORGANISATION-SCOPED RATHER THAN USER-SCOPED, which shows up in the intake path: a file
        has to be dropped inside a subdirectory named for the organisation it belongs to, and one
        that is not is ignored silently. That is a value nobody can guess and it is why the intake
        directory is a mount rather than a setting.

        SQLITE IS ITS ONLY ENGINE, and here that is a fact rather than a fallback: there is no
        external option to choose, the file lives in the application-data directory, and the
        declaration says so explicitly. Compare the pipeline entry above, where the same engine is
        what you get by saying nothing.

        THE PROBE IS A TCP CONNECT. It documents no health endpoint, and a probe on the application
        root would be a login redirect rather than a statement about the server.
      '';
    };
  };

  # ── Trackers: commitments with a state ──────────────────────────────────────────────────────
  #
  # THREE ENTRIES IN TWO CATEGORIES, which is this catalogue's clearest demonstration that a group
  # and a category are different questions. All three are the same kind of software -- something you
  # owe, with a state and a due date -- and the board lands in its own category because a wall of
  # cards and a list of due dates are read by different people, fail differently, and are worth
  # separating by blast radius. The `unit` field is what separates the two that DO share a category.
  # See ../studies/two-task-managers-and-what-a-unit-is.md.
  trackers = {
    leantime = {
      category = "tasks";
      unit = "project";

      image = "leantime/leantime";
      ports.http = 8080;
      primaryPort = "http";

      state = {
        userfiles = {
          mountPath = "/var/www/html/userfiles";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        publicUserfiles = {
          volumeName = "public-userfiles";
          mountPath = "/var/www/html/public/userfiles";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        plugins = {
          mountPath = "/var/www/html/app/Plugins";
          readOnly = false;
          required = false;
          embeddedFor = null;
        };
        logs = {
          mountPath = "/var/www/html/storage/logs";
          readOnly = false;
          required = false;
          embeddedFor = null;
        };
      };

      corpus = [ "userfiles" "publicUserfiles" ];
      corpusInEngine = "database";

      needs.database = {
        kind = "sql";
        required = true;
        requires = null;
        engines.mariadb = {
          style = "fields";
          typeEnv = null;
          typeValue = null;
          hostEnv = "LEAN_DB_HOST";
          portEnv = "LEAN_DB_PORT";
          portInHost = false;
          databaseEnv = "LEAN_DB_DATABASE";
          userEnv = "LEAN_DB_USER";
          passwordEnv = "LEAN_DB_PASSWORD";
          passwordRequired = true;
        };
      };

      env = { };
      args = [ ];

      readiness = {
        # A REAL 200 RATHER THAN THE APPLICATION ROOT, which redirects -- and a probe on a redirect
        # is logged as a warning on every single cycle, forever, by a cluster that is behaving
        # correctly.
        path = "/auth/login";
        initialDelaySeconds = 0;
        periodSeconds = 10;
        timeoutSeconds = 3;
        failureThreshold = 18;
      };
      startup = {
        path = "/auth/login";
        initialDelaySeconds = 10;
        periodSeconds = 10;
        timeoutSeconds = 3;
        failureThreshold = 30;
      };

      credentials.sessionPassword = { env = "LEAN_SESSION_PASSWORD"; required = true; };
      authentication = "builtin";

      publicUrl.envs.LEAN_APP_URL = { form = "origin"; path = ""; };

      background = {
        trigger = "timer";
        what = "its process supervisor runs a scheduler beside the web server: notification and digest mail, recurring work and the roll-over of anything dated";
        toggle = null;
      };

      coldStart = {
        seconds = 40;
        what = "a process supervisor starting a web server and a scheduler, then a PHP application boot";
      };

      note = ''
        A project manager whose UNIT IS A PROJECT. A task here exists inside a structure -- goals,
        milestones, a client, a canvas, a retrospective, timesheets against the work -- and that
        structure is what the software is for. The individual to-do is the smallest thing in it
        rather than the thing itself, which is the whole distinction from its neighbour in the same
        category.

        IT RUNS A SCHEDULER AND THAT SCHEDULER IS NOT OPTIONAL. Its image starts a process
        supervisor, and the supervisor starts a scheduler beside the web server: dated work rolls
        over, notification and digest mail goes out, recurring items appear. None of that is
        triggered by a request, so scaling to zero does not make it late -- the interval simply does
        not happen, and the first thing that runs after a wake is a fresh evaluation of what is due
        now. It is refused rather than warned about, because unlike its neighbour there is no switch
        that turns it off.

        ITS CORPUS IS SPLIT ACROSS AN ENGINE AND TWO DIRECTORIES. Every project, task, comment and
        time entry is a row in a MySQL-compatible engine this repository does not run; the
        attachments are files, in two directories rather than one because the software serves one of
        them publicly and keeps the other behind its own permission checks. Both are corpus.

        ITS PLUGIN DIRECTORY IS NOT CORPUS AND IS STILL WORTH BACKING. Losing it costs a
        reinstallation rather than content, which is why it is optional here -- but an unbacked one
        silently removes the features somebody installed, which looks like an upgrade regression.

        ITS SESSION PASSWORD IS REQUIRED AND HAS A LENGTH RULE the software enforces itself. It is a
        credential in the ordinary sense and arrives by reference like any other.

        THE PROBE IS A LOGIN PAGE ON PURPOSE. It is the shallowest path that returns a real 200
        without a session; the application root redirects, and a probe on a redirect produces a
        warning every cycle from a cluster that is doing exactly what it was told.
      '';
    };

    vikunja = {
      category = "tasks";
      unit = "task";

      image = "vikunja/vikunja";
      ports.http = 3456;
      primaryPort = "http";

      state = {
        files = {
          mountPath = "/app/vikunja/files";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        database = {
          mountPath = "/etc/vikunja";
          readOnly = false;
          # Holds the embedded database file and nothing else: demanded with that engine, refused
          # with any other.
          required = false;
          embeddedFor = "database";
        };
      };

      corpus = [ "files" ];
      corpusInEngine = "database";

      needs.database = {
        kind = "sql";
        required = true;
        requires = null;
        engines = {
          sqlite = {
            style = "file";
            typeEnv = "VIKUNJA_DATABASE_TYPE";
            typeValue = "sqlite";
            env = "VIKUNJA_DATABASE_PATH";
            prefix = "";
            file = "vikunja.db";
            state = "database";
          };
          postgres = {
            style = "fields";
            typeEnv = "VIKUNJA_DATABASE_TYPE";
            typeValue = "postgres";
            hostEnv = "VIKUNJA_DATABASE_HOST";
            # NO PORT VARIABLE EXISTS. Its configuration has a host and no port at all, so the port
            # travels inside the host value -- and a catalogue that assumed the usual pair would
            # render a variable nothing reads while the connection quietly went to the default port.
            portEnv = null;
            portInHost = true;
            databaseEnv = "VIKUNJA_DATABASE_DATABASE";
            userEnv = "VIKUNJA_DATABASE_USER";
            passwordEnv = "VIKUNJA_DATABASE_PASSWORD";
            passwordRequired = true;
          };
          mariadb = {
            style = "fields";
            typeEnv = "VIKUNJA_DATABASE_TYPE";
            typeValue = "mysql";
            hostEnv = "VIKUNJA_DATABASE_HOST";
            portEnv = null;
            portInHost = true;
            databaseEnv = "VIKUNJA_DATABASE_DATABASE";
            userEnv = "VIKUNJA_DATABASE_USER";
            passwordEnv = "VIKUNJA_DATABASE_PASSWORD";
            passwordRequired = true;
          };
        };
      };

      env = { };
      args = [ ];

      readiness = {
        # Answers 200 with JSON to an anonymous caller, before any account exists.
        path = "/api/v1/info";
        initialDelaySeconds = 0;
        periodSeconds = 5;
        timeoutSeconds = 3;
        failureThreshold = 24;
      };
      startup = null;

      credentials.jwtSecret = { env = "VIKUNJA_SERVICE_JWTSECRET"; required = false; };
      authentication = "builtin";

      publicUrl.envs.VIKUNJA_SERVICE_PUBLICURL = { form = "origin"; path = ""; };

      background = {
        trigger = "timer";
        what = "reminder mail for a due date, and the roll-over of a recurring task, run on an in-process timer";
        toggle = {
          option = "backgroundWork";
          env = "VIKUNJA_SERVICE_ENABLEEMAILREMINDERS";
          onValue = "true";
          offValue = "false";
        };
      };

      coldStart = {
        seconds = 10;
        what = "one static binary opening its database and serving its own front end";
      };

      note = ''
        A task manager whose UNIT IS A TASK. One item, with a due date, in a list, optionally
        assigned -- the checkbox is the thing, and everything above it (projects, buckets, filters)
        exists to arrange checkboxes. That is a genuinely different product from the project manager
        beside it in the same category, and the difference is mechanical rather than editorial:
        there is nowhere here to log time against work, and nowhere there to have a task that
        belongs to nothing.

        ITS BACKGROUND WORK CAN BE SWITCHED OFF, WHICH IS WHY IT CAN SLEEP AND ITS NEIGHBOUR CANNOT.
        With reminder mail enabled it runs an in-process timer, and at zero replicas the interval
        does not happen: the reminder is not late, it is never evaluated, and the first thing that
        runs after a wake finds it overdue. With reminder mail disabled everything it computes is
        computed in answer to a request and idling at zero costs nothing at all. The declaration
        states which, and this module renders the switch from that same statement -- so a
        declaration claiming reminders are off cannot be running with them on.

        ITS SIGNING SECRET IS GENERATED WHEN NOT SUPPLIED, and the generated one does not survive a
        restart: every session becomes invalid the moment the pod moves. That is why the credential
        role exists even though nothing requires it -- an unset secret is not an error, it is an
        application that logs everybody out at every deployment.

        ONE BINARY, THREE ENGINES, AND AN EMBEDDED DEFAULT. It serves its API and its whole front end
        from one origin and one port, and it will open an embedded database file if that is what it
        is pointed at. The external engines have no port variable at all, which is recorded above
        because it is exactly the kind of thing a generic connection helper gets wrong.

        ITS IMAGE TAG HAS NO LEADING LETTER. The obvious guess at a version-prefixed tag is a
        four-oh-four on the registry, and since a version is a value here, this is the one place
        that trap can be written down.
      '';
    };

    planka = {
      category = "kanban";
      unit = "card";

      image = "ghcr.io/plankanban/planka";
      ports.http = 1337;
      primaryPort = "http";

      state = {
        attachments = {
          mountPath = "/app/private/attachments";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        backgroundImages = {
          volumeName = "background-images";
          mountPath = "/app/public/background-images";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        userAvatars = {
          volumeName = "user-avatars";
          mountPath = "/app/public/user-avatars";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        favicons = {
          mountPath = "/app/public/favicons";
          readOnly = false;
          required = false;
          embeddedFor = null;
        };
        logs = {
          mountPath = "/app/logs";
          readOnly = false;
          required = false;
          embeddedFor = null;
        };
      };

      corpus = [ "attachments" ];
      corpusInEngine = "database";

      needs.database = {
        kind = "sql";
        required = true;
        requires = null;
        engines.postgres = {
          style = "dsn";
          env = "DATABASE_URL";
        };
      };

      env = { };
      args = [ ];

      readiness = {
        path = null;
        initialDelaySeconds = 15;
        periodSeconds = 10;
        timeoutSeconds = 3;
        failureThreshold = 12;
      };
      startup = null;

      credentials.secretKey = { env = "SECRET_KEY"; required = true; };
      authentication = "builtin";

      publicUrl.envs.BASE_URL = { form = "origin"; path = ""; };

      background = null;

      coldStart = {
        seconds = 20;
        what = "a server process running its schema migrations and opening a realtime channel";
      };

      note = ''
        A kanban board whose UNIT IS A CARD: a thing on a wall, in a column, moved by dragging it.
        The same KIND of software as the two task managers -- something owed, with a state -- and a
        different category, because a board is read at a glance by whoever is looking at the wall
        while a due-date list is read by the person who owes the work. Blast radius, not taxonomy:
        they fail differently and they are backed up differently.

        IT SPEAKS ONE ENGINE AND TAKES IT AS ONE CONNECTION STRING. There is no embedded fallback
        and no second option -- which makes it the simplest dependency in this catalogue and, because
        the string is a single value, the one where the address cannot be derived from a Service
        name. It travels inside a Secret with everything else.

        IT HAS NO DATABASE RETRY. When the engine is briefly unavailable -- a restart, a failover,
        the ordinary case of both starting at once -- it does not wait, it exits, and a container
        that exits repeatedly ends up in a backoff that outlasts the outage that caused it. The
        usual fix is an init container that waits for the port, which is a pod-spec shape the app
        grammar has no term for; a consumer that wants one defines it onto the rendered object
        through the grammar's own typed merge. Recorded here because the symptom -- an application
        still down long after its database came back -- points at the wrong thing.

        ITS LOG DIRECTORY IS A MOUNT FOR AN UNOBVIOUS REASON. Its logger writes into a directory
        inside the image tree, which is owned by the identity the image was built with; a workload
        running as any other identity cannot create it and the process dies on a permission error
        that names a log file. Mounting it is what makes running as somebody else possible at all.

        THE PROBE IS A TCP CONNECT. It documents no health endpoint, and its realtime channel means
        an HTTP probe would be asserting something about a page rather than about the server.
      '';
    };
  };

  # ── Schedulers: other people's claims on your time ──────────────────────────────────────────
  schedulers = {
    calcom = {
      category = "cal";

      image = "calcom/cal.com";
      ports.http = 3000;
      primaryPort = "http";

      # The image runs schema migrations before starting the server. Two copies during a rolling
      # update can therefore race the same production schema even though this workload keeps no
      # directory of its own. Name the single-writer property directly; empty `state` must not turn
      # it into a rolling update.
      singleWriter = true;

      state = { };
      corpus = [ ];
      corpusInEngine = "database";

      needs = {
        database = {
          kind = "sql";
          required = true;
          requires = null;
          engines.postgres = {
            style = "dsn";
            env = "DATABASE_URL";
          };
        };

        # A SECOND SQL CONNECTION, TO A SECOND DATABASE, FOR A DIFFERENT PURPOSE. This is why the
        # dependency table is keyed by ROLE rather than by engine kind: one application here opens
        # two, they are not interchangeable, and a table keyed by `sql` could not say so.
        identityStore = {
          kind = "sql";
          required = false;
          requires = "its own database rather than a schema inside the first: the identity component that owns it manages its own migrations";
          engines.postgres = {
            style = "dsn";
            env = "SAML_DATABASE_URL";
          };
        };
      };

      env = { };
      args = [ ];

      readiness = {
        # A REDIRECT COUNTS AS READY. The application root answers with a redirect to its sign-in
        # page, which is inside the range Kubernetes treats as success -- so this is a real
        # statement that the server is serving, without needing an account to exist.
        path = "/";
        initialDelaySeconds = 0;
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 30;
      };
      startup = {
        path = "/";
        initialDelaySeconds = 0;
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 30;
      };

      credentials = {
        session = { env = "NEXTAUTH_SECRET"; required = true; };
        encryption = { env = "CALENDSO_ENCRYPTION_KEY"; required = true; };
      };
      authentication = "builtin";

      publicUrl.envs = {
        NEXT_PUBLIC_WEBAPP_URL = { form = "origin"; path = ""; };
        NEXTAUTH_URL = { form = "origin"; path = ""; };
      };

      background = {
        trigger = "caller";
        what = "reminder mail, workflow notifications and outbound webhook deliveries are queued when a booking is made and dispatched when something outside the pod calls its scheduled-task endpoints";
        toggle = null;
      };

      coldStart = {
        seconds = 60;
        what = "a schema migration that is usually a no-op, then a server-rendered application's first compile and cache warm";
      };

      note = ''
        Scheduling: it publishes when you are free, takes bookings from people who do not have an
        account with you, and writes the result into your calendars. It is a group of its own because
        of who reaches it -- everything else in this catalogue is opened by the person who owns the
        data in it, and this one is opened by whoever was sent a link.

        IT KEEPS NOTHING ON DISK, WHICH IS RARE HERE AND NOT A SIMPLIFICATION. Every booking, every
        connected calendar and every credential for a third-party service is in the SQL engine, so
        the workload itself is disposable and the entire consequence of losing the engine is total.
        There is no directory to back up and no state option to fill in.

        THE ENCRYPTION KEY IS THE MOST DANGEROUS VALUE IN THIS CATALOGUE. It encrypts the stored
        credentials for every calendar, video and payment integration somebody connected. Rotating
        it does not fail: the application starts, and every connected integration is silently
        undecryptable, which looks like every third party having revoked access at once.

        IT MUST BE TOLD ITS OWN URL, IN TWO VARIABLES. One is what the browser-side application
        believes it is; the other is what the sign-in flow redirects through. A mismatch between
        either and the address people actually use produces booking links that point somewhere else
        and sign-ins that end nowhere, with every credential correct.

        ITS SCHEDULED WORK IS FIRED FROM OUTSIDE THE POD, which makes it the only entry in this
        catalogue where scaling to zero neither loses work nor is free. The call that triggers a
        batch of reminders wakes the pod, and then waits out the cold start inside its own timeout;
        a caller with a short one gives up, and the batch it was going to trigger is skipped
        silently. So this one is warned about rather than refused.

        IT CAN TAKE A SECOND DATABASE for the enterprise identity component it bundles. Optional,
        separate, and its own connection -- not a schema inside the first, because that component
        migrates its own.
      '';
    };
  };

  # ── Coeditors: live editing of a document somebody else stores ──────────────────────────────
  #
  # THE GROUP THAT OWNS NO DOCUMENT. A coeditor is handed a file by a host system, edits it in
  # people's browsers, and hands it back. It has no corpus, it has no notion of "your documents",
  # and losing everything it has is losing a cache.
  #
  # ITS UNIT OF WORK IS A SESSION RATHER THAN A REQUEST, and that is not a detail -- it is the
  # group's definition, and ../modules/cluster.nix encodes it by leaving `scale-to-zero` out of this
  # group's `scaling` enum entirely. An editing session is a long-lived connection holding a document
  # that has been changed and not yet saved back; a wake front counts requests, sees an idle
  # connection, and takes the pod away mid-edit. The value is missing rather than refused, because
  # any software that belongs in this group has the same property.
  coeditors = {
    collabora = {
      category = "office";

      image = "collabora/code";
      ports.http = 9980;
      primaryPort = "http";

      # The unit of work is a live document session held by one COOLWSD process. A rolling update
      # would send requests for that session to a fresh process that has never seen the document.
      # There is no durable directory from which the grammar could infer this, so say it directly.
      singleWriter = true;

      state = { };
      corpus = [ ];
      corpusInEngine = null;

      needs = { };

      env = { };
      args = [ ];

      readiness = {
        path = "/";
        # The live COOLWSD deployment establishes this endpoint with one-second requests. Its cold
        # dictionary load is represented by the two-minute failure budget, not by making each
        # individual probe wait longer or by guessing a separate initial delay.
        periodSeconds = 10;
        failureThreshold = 12;
      };
      startup = null;

      credentials = {
        adminUser = { env = "username"; required = false; };
        adminPassword = { env = "password"; required = false; };
      };
      authentication = "token";

      # IT WANTS THE HOST AND NOT A URL. Its own configuration parser treats this as a name, and a
      # value with a scheme in front of it is not a stricter version of the right answer -- it is a
      # different kind of value, and the failure is a websocket that never establishes.
      publicUrl.envs.server_name = { form = "host"; path = ""; };

      wopiHosts = {
        envPrefix = "aliasgroup";
        escape = "regex";
      };

      background = {
        trigger = "timer";
        what = "an editing session holds a changed document in memory and writes it back to the host system after the people in it stop typing";
        toggle = null;
      };

      coldStart = {
        seconds = 25;
        what = "an office suite's core starting and pre-forking the processes that will hold documents";
      };

      note = ''
        An office suite that runs on a server and paints into a browser. It is given a document over
        a host protocol, spawns a process per document to hold it, and streams the rendering to
        everybody in the session. IT STORES NOTHING: no state option, no directory, no database, no
        engine dependency of any kind -- the only entry in this catalogue with none.

        IT HAS TO BE TOLD WHICH HOSTS MAY HAND IT A FILE, and this is the field that gets it wrong
        most often. The variables are NUMBERED from one, the values are REGULAR EXPRESSIONS -- so the
        dots in a hostname have to be escaped or the pattern quietly matches more hosts than
        intended -- and a port must not appear at all, because it parses the value as a URI and the
        host it is compared against carries no port. A declaration here gives ordinary origins and
        this module produces all three of those properties, because every one of them is knowledge
        and none of them is a value.

        IT AUTHENTICATES PER DOCUMENT AND HAS NO ACCOUNTS. Authorisation is a token the host system
        issued for one file and one person, so a request arriving without one reaches nothing. That
        is why it is `token` rather than `none`: the class is what decides whether this repository
        will let a workload be declared reachable from the internet, and a document editor with no
        accounts is genuinely a different thing from an administrative interface with no password.

        ITS ADMIN CONSOLE IS THE ONE THING WITH A LOGIN, and the two halves of that login are two
        ordinary variables. Optional, because the console is optional; named, because the alternative
        is somebody putting them in plain environment.

        IT IS HEAVY IN A WAY A MANIFEST DOES NOT SHOW. Each open document is a real office-suite
        process; memory scales with how many people are editing, not with how much traffic arrives,
        and the ceiling that matters is set by the documents rather than by the requests.
      '';
    };

    eurooffice = {
      category = "office";

      image = "ghcr.io/euro-office/documentserver";
      ports.http = 80;
      primaryPort = "http";

      state = {
        cache = {
          mountPath = "/var/lib/euro-office/documentserver";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        identity = {
          mountPath = "/var/www/euro-office/Data";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
      };

      corpus = [ ];
      corpusInEngine = null;

      needs.database = {
        kind = "sql";
        required = true;
        requires = "a database of its own that it initialises itself on first connection";
        engines.postgres = {
          style = "fields";
          typeEnv = "DB_TYPE";
          typeValue = "postgres";
          hostEnv = "DB_HOST";
          portEnv = "DB_PORT";
          portInHost = false;
          databaseEnv = "DB_NAME";
          userEnv = "DB_USER";
          passwordEnv = "DB_PWD";
          passwordRequired = true;
        };
      };

      env = {
        # Required for a host system to be able to hand it a document at all; the image's own
        # default is off.
        WOPI_ENABLED = "true";
      };
      args = [ ];

      readiness = {
        path = "/healthcheck";
        initialDelaySeconds = 30;
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 30;
      };
      startup = null;

      credentials.signing = { env = "JWT_SECRET"; required = false; };
      authentication = "token";

      publicUrl = null;
      wopiHosts = null;

      background = {
        trigger = "timer";
        what = "document conversion runs in a queue whose results are written to its own tables, and an editing session holds a changed document until it is saved back";
        toggle = null;
      };

      coldStart = {
        seconds = 90;
        what = "a converter pool sized to the visible processor count, plus a font and theme scan on first boot";
      };

      note = ''
        The second office suite, and a genuinely different implementation of the same job: the same
        host protocol, the same "documents live somewhere else", a different rendering engine and a
        different set of formats it is faithful to. Both are in this catalogue because which one a
        given host system is wired to is a property of that host system, and running both is a real
        state rather than a migration.

        IT SHIPS A DATABASE SERVER INSIDE ITS OWN IMAGE, AND THE ONLY THING THAT STOPS IT STARTING
        THAT SERVER IS BEING TOLD A HOST THAT IS NOT LOCALHOST. There is no switch. That single fact
        is the sharpest argument in this repository for making an engine dependency a typed, required
        declaration rather than an environment variable somebody remembers: forget it, and you get a
        working office suite with a database inside a container, which nothing reports and nothing
        backs up.

        IT DOES NOT LOAD ITS OWN SCHEMA INTO AN EXTERNAL ENGINE. The image bakes its schema into the
        bundled server at build time; pointed at an external one it waits for the connection and then
        creates only the tables it happens to need at runtime. A first deployment against an empty
        database therefore comes up and works, and a consumer who wants the schema loaded properly
        does it once, out of band. Recorded because the failure -- if there is one -- arrives later
        than the deployment that caused it.

        ITS IDENTITY DIRECTORY IS THE SURPRISE IN THIS ENTRY, and it is the reason `state` here has
        two keys rather than one. The document cache is what it looks like. The other directory holds
        the KEY PAIR it proves its identity with to the host system, and the entrypoint regenerates
        that pair whenever the file is missing -- so an unbacked directory does not lose a cache, it
        issues a new identity on every restart, and the host system rejects every call with a
        verification error until it re-fetches the discovery document. It reports itself healthy
        throughout.

        ITS CONVERTER POOL SIZES ITSELF TO THE VISIBLE PROCESSOR COUNT rather than to any limit the
        workload was given, which makes its steady-state memory a function of the NODE rather than of
        the declaration. That is capacity and therefore a value, but it is the one entry here where
        the default is surprising enough to be worth stating: the number a person would guess is
        roughly an order of magnitude low.
      '';
    };
  };

  # ── Compilers: a source document turned into an artefact ────────────────────────────────────
  compilers = {
    overleaf = {
      category = "latex";

      image = "sharelatex/sharelatex";
      ports.http = 80;
      primaryPort = "http";

      state.data = {
        mountPath = "/var/lib/overleaf";
        readOnly = false;
        required = true;
        embeddedFor = null;
      };

      corpus = [ "data" ];
      corpusInEngine = "database";

      needs = {
        database = {
          kind = "documentdb";
          required = true;
          requires = "a REPLICA SET, even with a single member: it uses multi-document transactions, which a standalone server refuses";
          engines.mongodb = {
            style = "dsn";
            env = "OVERLEAF_MONGO_URL";
          };
        };

        cache = {
          kind = "keyvalue";
          required = true;
          requires = "the live document state of every open editing session, which is why losing it is not the same as losing a cache";
          engines.redis = {
            style = "fields";
            typeEnv = null;
            typeValue = null;
            hostEnv = "OVERLEAF_REDIS_HOST";
            portEnv = "OVERLEAF_REDIS_PORT";
            portInHost = false;
            databaseEnv = null;
            userEnv = null;
            passwordEnv = "OVERLEAF_REDIS_PASS";
            passwordRequired = false;
          };
        };
      };

      env = { };
      args = [ ];

      readiness = {
        path = null;
        initialDelaySeconds = 45;
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 40;
      };
      startup = null;

      credentials.session = { env = "OVERLEAF_SESSION_SECRET"; required = true; };
      authentication = "builtin";

      publicUrl.envs.OVERLEAF_SITE_URL = { form = "origin"; path = ""; };

      background = {
        trigger = "timer";
        what = "edits are held in the key-value store and flushed to the document store on a timer, and a compilation runs past the request that asked for it";
        toggle = null;
      };

      coldStart = {
        seconds = 120;
        what = "a process supervisor starting a dozen internal services against two external engines";
      };

      note = ''
        Collaborative typesetting: several people edit one source document in a browser and a
        compiler turns it into the artefact they are actually making. It is its own group because
        that second half has no equivalent anywhere else here -- everything else stores what you
        wrote, and this one runs a toolchain over it.

        IT IS THE HEAVIEST THING IN THIS CATALOGUE, and for a reason that does not show up in a
        manifest: the image carries a complete typesetting distribution, and a compilation is a
        real, minutes-long, processor- and disk-bound job that can outlive the request that asked
        for it. Capacity is a value and none of it is here -- but the cold start below is measured,
        and it is what makes the scale-to-zero warning in this repository a number rather than a
        feeling.

        IT NEEDS TWO ENGINES AND NEITHER IS OPTIONAL. A document store holds the projects, the
        document text and the history; a key-value store holds the LIVE state of every open editing
        session. That second one is the one people get wrong, because its usual name suggests a
        cache: losing it loses the edits that had not yet been flushed, which is a different and much
        worse thing than a cold start.

        THE DOCUMENT STORE MUST BE A REPLICA SET, even with one member. It uses multi-document
        transactions, and a standalone server refuses them -- so a perfectly healthy engine of the
        right kind and version still produces an application that fails on write. That is a
        requirement on the SHAPE of somebody else's workload, which is exactly why this repository
        publishes what it depends on instead of only naming the kind.

        ITS FILE STORE IS ON DISK AND ITS PROJECTS ARE NOT. The directory holds uploaded files and
        compiled output; the projects that reference them are documents in the store. Neither half
        is usable alone, and the pair has to be backed up in one consistent moment.

        THE PROBE IS A TCP CONNECT WITH A LONG DELAY. It brings up a dozen internal services under a
        supervisor and does not publish a single endpoint that means all of them are ready; a probe
        that guessed one would report an application healthy while half of it was still starting.
      '';
    };
  };

  # ── Records: structured records with a UI over them ─────────────────────────────────────────
  records = {
    directus = {
      category = "crm";
      schema = "operator";

      image = "directus/directus";
      ports.http = 8055;
      primaryPort = "http";

      state = {
        database = {
          mountPath = "/directus/database";
          readOnly = false;
          # NOT required on its own: this directory exists ONLY to hold the embedded engine's file,
          # so backing it is demanded when that engine is chosen and REFUSED when it is not.
          required = false;
          embeddedFor = "database";
        };
        uploads = {
          mountPath = "/directus/uploads";
          readOnly = false;
          required = true;
          embeddedFor = null;
        };
        extensions = {
          mountPath = "/directus/extensions";
          readOnly = false;
          required = false;
          embeddedFor = null;
        };
      };

      corpus = [ "uploads" ];
      corpusInEngine = "database";

      needs.database = {
        kind = "sql";
        required = true;
        requires = null;
        engines = {
          postgres = {
            style = "fields";
            typeEnv = "DB_CLIENT";
            typeValue = "pg";
            hostEnv = "DB_HOST";
            portEnv = "DB_PORT";
            portInHost = false;
            databaseEnv = "DB_DATABASE";
            userEnv = "DB_USER";
            passwordEnv = "DB_PASSWORD";
            passwordRequired = true;
          };
          mariadb = {
            style = "fields";
            typeEnv = "DB_CLIENT";
            typeValue = "mysql";
            hostEnv = "DB_HOST";
            portEnv = "DB_PORT";
            portInHost = false;
            databaseEnv = "DB_DATABASE";
            userEnv = "DB_USER";
            passwordEnv = "DB_PASSWORD";
            passwordRequired = true;
          };
          sqlite = {
            style = "file";
            typeEnv = "DB_CLIENT";
            # NOT THE ENGINE'S OWN NAME. The value is the driver's name, which differs from the
            # engine's for every one of the three -- a catalogue that reused the engine key here
            # would produce a workload that refuses to start with an unhelpful message about an
            # unknown client.
            typeValue = "sqlite3";
            env = "DB_FILENAME";
            prefix = "";
            file = "data.db";
            state = "database";
          };
        };
      };

      env = { };
      args = [ ];

      readiness = {
        # ANSWERS ANONYMOUSLY. Its other health endpoint is gated behind an administrator session
        # and returns a refusal to anything else, which makes it useless as a probe and looks like
        # an unhealthy application.
        path = "/server/ping";
        initialDelaySeconds = 0;
        periodSeconds = 5;
        timeoutSeconds = 3;
        failureThreshold = 36;
      };
      startup = {
        path = "/server/ping";
        initialDelaySeconds = 0;
        periodSeconds = 5;
        timeoutSeconds = 3;
        failureThreshold = 60;
      };

      credentials = {
        key = { env = "KEY"; required = true; };
        secret = { env = "SECRET"; required = true; };
        adminPassword = { env = "ADMIN_PASSWORD"; required = false; };
      };
      authentication = "builtin";

      publicUrl.envs.PUBLIC_URL = { form = "origin"; path = ""; };

      background = {
        trigger = "timer";
        what = "any automation whose trigger is a schedule fires from an in-process timer";
        toggle = {
          option = "backgroundWork";
          # NOTHING IS RENDERED FROM THIS ONE, and that is the difference from the two entries whose
          # toggle names a variable. There is no switch in the software: whether it does scheduled
          # work depends on whether anybody has authored an automation with a schedule trigger, so
          # the declaration's boolean is a statement about how this instance is USED. It still
          # decides whether the workload may sleep, and it still cannot be guessed.
          env = null;
          onValue = null;
          offValue = null;
        };
      };

      coldStart = {
        seconds = 40;
        what = "schema migrations, then a scan and build of whatever extensions are mounted";
      };

      note = ''
        A data platform rather than an application: you define what a record IS -- the collections,
        the fields, the relations -- and it gives you an administrative interface, a permission model
        and an API over them. Used as a customer or contact database, which is one of the things it
        is for and not the only one; what puts it in this group is that the MEANING of a row is the
        operator's, and the software is deliberately generic about it.

        IT ACCEPTS THREE ENGINES AND NAMES THEM BY DRIVER RATHER THAN BY ENGINE. Each one has a
        different token, none of which is the engine's own name, and that is recorded above because
        the obvious guess produces a startup failure that talks about an unknown client rather than
        about the database.

        WITH NO DATABASE CONFIGURATION IT DOES NOT START, which makes it the well-behaved member of
        the three entries here that can use an embedded engine. Its embedded file still lives in one
        of its own directories, and that directory must be backed when -- and only when -- the
        embedded engine is the one chosen.

        ITS TWO REQUIRED SECRETS DO DIFFERENT JOBS AND BOTH ARE UNRECOVERABLE. One signs the tokens
        every session and every API caller holds; the other identifies the instance. Changing the
        first logs everybody out, which is survivable and looks like an outage; changing the second
        is worse and looks like nothing.

        ITS BACKGROUND WORK EXISTS ONLY IF SOMEBODY AUTHORED IT. There is no setting: a schedule
        trigger is something an operator builds inside the product, so no variable can be inspected
        and no default can be right. The declaration states whether this instance has any, and that
        statement is what decides whether it may idle at zero -- a scheduled automation on a sleeping
        workload does not run late, it does not run.

        ITS EXTENSION DIRECTORY IS BUILT AT BOOT, into a path inside the image tree. A workload
        running as an identity the image was not built with cannot write there; the failure is a
        warning rather than a crash, and the extensions silently do not load.
      '';
    };

    cv-manager = {
      category = "cv";
      schema = "fixed";

      image = "vincentmakes/cv-manager";
      ports = {
        admin = 3000;
        public = 3001;
      };
      primaryPort = "admin";

      state.data = {
        mountPath = "/app/data";
        readOnly = false;
        required = true;
        embeddedFor = "database";
      };

      corpus = [ "data" ];
      corpusInEngine = "database";

      needs.database = {
        kind = "sql";
        required = true;
        requires = null;
        engines.sqlite = {
          style = "file";
          typeEnv = null;
          typeValue = null;
          env = "DB_PATH";
          prefix = "";
          file = "cv.db";
          state = "data";
        };
      };

      env = { };
      args = [ ];

      readiness = {
        path = "/";
        initialDelaySeconds = 0;
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 6;
      };
      startup = null;

      credentials = { };
      # THE ONLY ENTRY IN THIS CATALOGUE THAT ASKS NOBODY FOR ANYTHING. See the note, and the
      # refusal in ../modules/cluster.nix that follows from it.
      authentication = "none";

      publicUrl = null;

      background = null;

      coldStart = {
        seconds = 10;
        what = "one server process opening an embedded database";
      };

      note = ''
        A curriculum vitae kept as structured records -- positions, dates, skills, attachments --
        rather than as a document, with a published read-only view of the result. It is in the same
        group as the data platform above because both are a shell around records with an interface
        over them; it is a different entry because here the software knows what a record is and the
        schema is not yours to change.

        IT SERVES TWO AUDIENCES ON TWO PORTS FROM ONE PROCESS, and that is the fact that shapes
        everything about declaring it. One port is a full editing interface; the other is the
        read-only publication. Both are in one pod, behind one Service, and the exposure class this
        repository speaks is a property of the WORKLOAD rather than of a port -- so making the
        published half reachable makes the editing half reachable by exactly the same amount.

        IT AUTHENTICATES NOBODY. There is no login on the editing interface at all: whoever can
        reach the port can rewrite the record and read every attachment. Combined with the paragraph
        above, that is why this module refuses to declare it reachable from the internet -- not as
        advice, as a refusal -- and warns even on a private overlay, where reachability is somebody
        else's membership list rather than a password. If the published half has to be public, the
        thing that publishes it is a front that serves the one port, and that front is not this
        workload.

        SQLITE IS ITS ONLY ENGINE AND THE FILE SITS BESIDE THE UPLOADS in one directory. That makes
        the single mount both the corpus and the database, so there is no consistency problem
        between two systems -- the one genuine advantage an embedded engine has, and worth saying in
        a catalogue whose other eleven entries mostly do not get it.
      '';
    };
  };
}
