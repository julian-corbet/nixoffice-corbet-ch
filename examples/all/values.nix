# Placeholder values for the cluster module — the file that makes the render check real.
# `nix flake check` renders the whole surface from here, so a module that stops evaluating, or that
# grows a required value nobody supplies, fails in CI rather than in somebody's cluster.
#
# NOTHING HERE IS REAL. Every namespace, path, name, number, origin and image is invented for this
# file, and no credential appears in any form — only the NAMES of Secrets that would hold them.
#
# The declarations are chosen to put ONE WORKLOAD OF EVERY GROUP in one render, and to cover the
# paths that differ in what gets RENDERED rather than merely in what evaluates:
#
#   - a wiki whose pages are in an engine and whose pictures are on disk, wired by SEPARATE
#     variables, so the engine's address is derived here from a Service name and a namespace;
#   - two document managers in ONE category, which is what a category is for: a pipeline that
#     cannot sleep and a shelf that can, the second with its intake watcher switched off;
#   - two trackers in two categories, one of them scaled to zero because its reminder timer is
#     declared off — and this module renders that switch from the same value;
#   - a booking page taking its whole connection as one string in a Secret, scaled to zero so the
#     caller-driven warning fires;
#   - a collaborative editor with no state, no engine and no scale-to-zero option, whose document
#     hosts are given as ordinary origins and come out as numbered escaped patterns;
#   - a typesetting service needing TWO engines of two different families, one by connection string
#     and one by fields;
#   - a record platform on an external engine, which is what makes its embedded-engine directory
#     refused rather than merely unused.
{
  # Required by the nixidy environment itself, not by any module here.
  nixidy.target.repository = "https://example.com/example-org/example-gitops.git";
  nixidy.target.branch = "main";

  # A cluster fact the app grammar refuses to guess: which node holds the directories that
  # node-path state lives on. Set once here instead of on every workload.
  nixk3s.appPlatform.hostPathNodeSelector = { "kubernetes.io/hostname" = "example-node"; };

  # The band model, with the layout a consumer would supply. Every value is invented: the model
  # ships no band, no base and no binding, because which category owns which run of the number
  # space is the shape of somebody's fleet — and so does this repository.
  nixk3s.addressing = {
    enable = true;
    bands.example-documents = {
      base = 0;
      size = 16;
      description = "where the written work happens";
    };
    bindings.nixoffice = "example-documents";
  };

  nixoffice.cluster.platform = {
    # ONE NAMESPACE PER CATEGORY, and none of them named after an application in the catalogue or
    # after a workload declared in it — evaluation refuses both. Two of these hold two applications
    # each, which is exactly what a category is for.
    namespaces = {
      wiki = "example-wiki";
      cal = "example-booking";
      office = "example-editing";
      cv = "example-profile";
      crm = "example-records";
      latex = "example-typesetting";
      dms = "example-filing";
      tasks = "example-tasks";
      kanban = "example-board";
    };
    project = "example-office";
    # Hands the workloads' slots to the band model above. Null (the default) everywhere that model
    # is not part of the render.
    origin = "nixoffice";
  };

  # A wiki. Its pages are rows in an engine this repository does not run and its pictures are files
  # in the directory below; neither half is usable without the other, and the module says so.
  nixoffice.cluster.wikis.pages = {
    wiki = "bookstack";
    version = "0.0.0";
    slot = 0;
    exposure = "nb";
    createNamespace = true;
    publicUrl = "https://pages.example.com";
    state.config.hostPath = "/example/state/pages";
    connections.database = {
      # SEPARATE VARIABLES, so the address is DERIVED: a Service name, a namespace, and the
      # platform's cluster domain. Nothing here writes a host.
      engine = "mariadb";
      service = "example-sql";
      namespace = "example-engines";
      database = "example_pages";
      user = "example_pages";
      password = { secret = "example-pages-db"; key = "password"; };
    };
    credentials.appKey = { secret = "example-pages"; key = "appKey"; };
  };

  # THE FIRST OF TWO DOCUMENT MANAGERS, in the category they share. A pipeline: it watches an intake
  # directory and OCRs, classifies and files what appears there, so it cannot idle at zero — a file
  # copied into a directory produces no request for anything to wake it.
  nixoffice.cluster.filings.pipeline = {
    filing = "paperless";
    version = "0.0.0";
    slot = 1;
    exposure = "nb";
    createNamespace = true;
    publicUrl = "https://filing.example.com";
    state = {
      data.hostPath = "/example/state/pipeline-data";
      media.hostPath = "/example/documents/filed";
      consume.hostPath = "/example/documents/intake";
    };
    connections = {
      database = {
        engine = "postgres";
        service = "example-sql-pg";
        namespace = "example-engines";
        database = "example_filing";
        user = "example_filing";
        password = { secret = "example-filing-db"; key = "password"; };
      };
      # A SECOND ENGINE, of a different family, taken as one connection string. This URL contains
      # no credential, so its host is derived from a bare Service name and platform facts instead
      # of being hidden, unchecked, in a Secret.
      broker = {
        engine = "redis";
        serviceDsn = {
          scheme = "redis";
          service = "example-broker";
          port = 6379;
        };
      };
    };
    credentials.secretKey = { secret = "example-filing"; key = "secretKey"; };
    # Addresses of two converter services this repository names and does not run. An address is a
    # value, so it arrives here rather than from the catalogue.
    env = {
      PAPERLESS_TIKA_ENABLED = "true";
      PAPERLESS_TIKA_ENDPOINT = "http://example-extract.example-filing.svc.cluster.local:9998";
      PAPERLESS_TIKA_GOTENBERG_ENDPOINT = "http://example-convert.example-filing.svc.cluster.local:3000";
    };
  };

  # THE SECOND, in the same category and answering the same question differently. A shelf: it keeps
  # the file it was given. Its intake watcher is off here, which is what would let it sleep.
  nixoffice.cluster.filings.shelf = {
    filing = "papra";
    version = "0.0.0";
    slot = 2;
    exposure = "nb";
    backgroundWork = false;
    publicUrl = "https://shelf.example.com";
    state = {
      appdata.hostPath = "/example/state/shelf";
      corpus.hostPath = "/example/documents/shelf";
    };
    # An EMBEDDED engine, chosen deliberately rather than arrived at by saying nothing — and the
    # directory holding it is backed above.
    connections.database.engine = "sqlite";
    credentials.authSecret = { secret = "example-shelf"; key = "authSecret"; };
  };

  # A task list, sharing a category with a project manager. Its reminder timer is declared off, and
  # this module renders the software's own switch from that same value — which is what makes the
  # scale-to-zero below safe rather than hopeful.
  nixoffice.cluster.trackers.tasks = {
    tracker = "vikunja";
    version = "0.0.0";
    slot = 3;
    exposure = "nb";
    createNamespace = true;
    scaling = "scale-to-zero";
    backgroundWork = false;
    publicUrl = "https://tasks.example.com";
    state = {
      files.hostPath = "/example/state/tasks-files";
      database.hostPath = "/example/state/tasks-db";
    };
    connections.database.engine = "sqlite";
    credentials.jwtSecret = { secret = "example-tasks"; key = "jwtSecret"; };
  };

  # A board, in a category of its own: the same KIND of software as the list above, read by
  # different people and separated by blast radius rather than by taxonomy. One connection string.
  nixoffice.cluster.trackers.board = {
    tracker = "planka";
    version = "0.0.0";
    slot = 4;
    exposure = "nb";
    createNamespace = true;
    publicUrl = "https://board.example.com";
    state = {
      attachments.hostPath = "/example/state/board-attachments";
      backgroundImages.hostPath = "/example/state/board-backgrounds";
      userAvatars.hostPath = "/example/state/board-avatars";
    };
    connections.database = {
      engine = "postgres";
      dsn = { secret = "example-board-db"; key = "url"; };
    };
    credentials.secretKey = { secret = "example-board"; key = "secretKey"; };
  };

  # Booking. Scaled to zero on purpose: its scheduled work is fired from OUTSIDE the pod, so nothing
  # is lost and the caller pays the cold start — the middle case this repository warns about rather
  # than refusing.
  nixoffice.cluster.schedulers.booking = {
    scheduler = "calcom";
    version = "0.0.0";
    slot = 5;
    exposure = "public";
    createNamespace = true;
    scaling = "scale-to-zero";
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

  # A collaborative editor: no state, no engine, no corpus — and no `scale-to-zero` in its enum at
  # all. Its document hosts go in as ordinary origins and come out as numbered escaped patterns.
  nixoffice.cluster.coeditors.editing = {
    coeditor = "collabora";
    version = "0.0.0";
    slot = 6;
    exposure = "public";
    createNamespace = true;
    # This imaginary editor already existed before the owner declaration. It is the positive
    # adoption fixture; every other workload remains fresh and is the negative control.
    adopt = true;
    # It wants the HOST rather than the origin, and the module strips the scheme.
    publicUrl = "https://edit.example.com";
    documentHosts = [ "https://files.example.com" "https://pages.example.com" ];
  };

  # THE SECOND EDITOR, in the SAME category and therefore the same namespace — and it does not
  # anchor it, because exactly one workload may. Unlike the first it keeps two directories and needs
  # an engine, and it is the entry whose image ships a database server that only a non-local host
  # name suppresses.
  nixoffice.cluster.coeditors.editingsuite = {
    coeditor = "eurooffice";
    version = "0.0.0";
    slot = 10;
    exposure = "public";
    state = {
      cache.hostPath = "/example/state/editingsuite-cache";
      identity.hostPath = "/example/state/editingsuite-identity";
    };
    connections.database = {
      engine = "postgres";
      service = "example-sql-pg";
      namespace = "example-engines";
      database = "example_editing";
      user = "example_editing";
      password = { secret = "example-editing-db"; key = "password"; };
    };
  };

  # THE SECOND TRACKER IN THE TASK CATEGORY, answering the same question with a different unit: a
  # project rather than a task. Its scheduler is not optional, so it stays resident — which is the
  # whole difference from the list above.
  nixoffice.cluster.trackers.projects = {
    tracker = "leantime";
    version = "0.0.0";
    slot = 11;
    exposure = "nb";
    publicUrl = "https://projects.example.com";
    state = {
      userfiles.hostPath = "/example/state/projects-userfiles";
      publicUserfiles.hostPath = "/example/state/projects-public";
    };
    connections.database = {
      engine = "mariadb";
      service = "example-sql";
      namespace = "example-engines";
      database = "example_projects";
      user = "example_projects";
      password = { secret = "example-projects-db"; key = "password"; };
    };
    credentials.sessionPassword = { secret = "example-projects"; key = "sessionPassword"; };
  };

  # Typesetting: the heaviest thing here, and the only workload needing two engines of two different
  # families at once — one by connection string, one by fields.
  nixoffice.cluster.compilers.typesetting = {
    compiler = "overleaf";
    version = "0.0.0";
    slot = 7;
    exposure = "nb";
    createNamespace = true;
    publicUrl = "https://typeset.example.com";
    state.data.hostPath = "/example/state/typesetting";
    connections = {
      database = {
        engine = "mongodb";
        dsn = { secret = "example-typesetting"; key = "documentStore"; };
      };
      cache = {
        engine = "redis";
        service = "example-keyvalue";
        namespace = "example-engines";
      };
    };
    credentials.session = { secret = "example-typesetting"; key = "session"; };
  };

  # A record platform on an EXTERNAL engine — which is exactly why its embedded-engine directory is
  # absent below: backing it would be refused, because nothing would ever write in it.
  nixoffice.cluster.records.contacts = {
    record = "directus";
    version = "0.0.0";
    slot = 8;
    exposure = "nb";
    createNamespace = true;
    backgroundWork = false;
    publicUrl = "https://records.example.com";
    state = {
      uploads.hostPath = "/example/state/records-uploads";
      extensions.hostPath = "/example/state/records-extensions";
    };
    connections.database = {
      engine = "postgres";
      service = "example-sql-pg";
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

  # The one application here that asks nobody for anything. `public` on it is refused; a private
  # overlay warns, because whatever grants membership of that class IS the access control.
  nixoffice.cluster.records.profile = {
    record = "cv-manager";
    # A whole reference rather than a version: pinned by digest, which is what the grammar asks for
    # and what every other declaration above deliberately does not do.
    image = "registry.example.com/example-org/example-profile:0.0.0@sha256:0000000000000000000000000000000000000000000000000000000000000000";
    version = "0.0.0";
    slot = 9;
    exposure = "nb";
    createNamespace = true;
    state.data.hostPath = "/example/state/profile";
    connections.database.engine = "sqlite";
  };
}
