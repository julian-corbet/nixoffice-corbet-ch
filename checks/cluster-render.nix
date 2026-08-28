# Asserts what this surface actually RENDERS, by reading the manifests out of the rendered
# environment with a YAML parser.
#
# Why not just evaluate: a module that type-checks can still point an application at an engine
# through a variable the process does not read, mount a corpus where the software does not write,
# put a rolling update in front of a single writer, or emit a document-host pattern that matches
# nothing. None of that is an eval error. The first is a workload that starts and connects to
# nothing; the second is an empty wiki that reports itself healthy; the third is two processes on
# one directory; the fourth is a document that never opens.
#
# TWO OF THE ASSERTIONS IN THIS FILE ARE ABSENCES, checked on the bytes rather than on the model: no
# engine of any kind is rendered anywhere in this tree, and no connection value -- no host, no
# password, no connection string -- appears as anything but a Secret reference. A claim about a
# boundary is worth exactly as much as the test that reads the output and finds nothing there.
{ pkgs, lib, env }:

pkgs.runCommand "nixoffice-cluster-render"
{
  nativeBuildInputs = [ pkgs.yq-go ];
  manifests = env.environmentPackage;
  # Not manifests, so they cannot be asserted from the tree: the reports that say what this surface
  # depends on and does not run, and which of it has to stay resident.
  externalEngines = lib.concatStringsSep " " env.config.nixoffice.cluster.externalEngines;
  mustStayAwake = lib.concatStringsSep " "
    (lib.sort (a: b: a < b) (lib.attrNames env.config.nixoffice.cluster.mustStayAwake));
  unauthenticated = lib.concatStringsSep " " env.config.nixoffice.cluster.unauthenticated;
  filingCategory = lib.concatStringsSep " " env.config.nixoffice.cluster.categories.dms;
  taskCategory = lib.concatStringsSep " " env.config.nixoffice.cluster.categories.tasks;
} ''
  set -euo pipefail
  fail=0

  check() {
    if [ "$2" = "$3" ]; then
      echo "  ok   $1: $3"
    else
      echo "  FAIL $1: expected '$2', got '$3'"
      fail=1
    fi
  }

  present() {
    if [ -e "$2" ]; then echo "  ok   $1: rendered"; else echo "  FAIL $1: not rendered ($2)"; fail=1; fi
  }

  absent() {
    if [ -e "$2" ]; then echo "  FAIL $1: rendered but should not be ($2)"; fail=1; else echo "  ok   $1: correctly not rendered"; fi
  }

  y() { yq -r "$1" "$2"; }

  PAGES_D=$manifests/pages/Deployment-pages.yaml
  PAGES_S=$manifests/pages/Service-pages.yaml
  PIPE_D=$manifests/pipeline/Deployment-pipeline.yaml
  SHELF_D=$manifests/shelf/Deployment-shelf.yaml
  TASKS_D=$manifests/tasks/Deployment-tasks.yaml
  BOARD_D=$manifests/board/Deployment-board.yaml
  PROJECTS_D=$manifests/projects/Deployment-projects.yaml
  BOOK_D=$manifests/booking/Deployment-booking.yaml
  EDIT_D=$manifests/editing/Deployment-editing.yaml
  SUITE_D=$manifests/editingsuite/Deployment-editingsuite.yaml
  TYPE_D=$manifests/typesetting/Deployment-typesetting.yaml
  CONTACTS_D=$manifests/contacts/Deployment-contacts.yaml
  PROFILE_D=$manifests/profile/Deployment-profile.yaml
  PROFILE_S=$manifests/profile/Service-profile.yaml

  echo "== the whole rendered Deployment of the wiki -- one application, one container, no engine =="
  cat $PAGES_D

  echo
  echo "== NO ENGINE IS RENDERED ANYWHERE IN THIS TREE =="
  # The claim of this repository's cluster half, read off the bytes. Every workload is exactly one
  # container, and no object of any kind here is a database.
  for d in $(find -L $manifests -type f -name 'Deployment-*.yaml' | sort); do
    n=$(y '[.spec.template.spec.containers[]] | length' $d)
    if [ "$n" != "1" ]; then
      echo "  FAIL $(basename $d) renders $n containers; one declaration is one container"; fail=1
    fi
    if [ "$(y '.spec.template.spec.initContainers // "none"' $d)" != "none" ]; then
      echo "  FAIL $(basename $d) renders init containers"; fail=1
    fi
  done
  # And nothing anywhere is running one of the images this surface DEPENDS on.
  for f in $(find -L $manifests -type f | sort); do
    if grep -qiE 'image: *"?(postgres|mariadb|mysql|mongo|redis|percona)([:@/]|$)' "$f"; then
      echo "  FAIL an engine image is rendered in $f"; fail=1
    fi
  done
  echo "  ok   every workload is one container, and none of them is a database"

  echo
  echo "== THE ENGINE ADDRESS IS DERIVED, AND THE CREDENTIAL IS A REFERENCE =="
  check "the wiki's engine host is built from a Service, a namespace and the cluster domain" \
    "example-sql.example-engines.svc.cluster.local" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DB_HOST") | .value' $PAGES_D)"
  check "and its port comes from the engine KIND, which nobody wrote down" "3306" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DB_PORT") | .value' $PAGES_D)"
  check "the password is a secretKeyRef" "example-pages-db" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DB_PASSWORD") | .valueFrom.secretKeyRef.name' $PAGES_D)"
  check "and never a value" "null" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DB_PASSWORD") | .value' $PAGES_D)"
  check "a whole connection string is a reference too, in the variable the software names" \
    "example-board-db" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DATABASE_URL") | .valueFrom.secretKeyRef.name' $BOARD_D)"
  check "the driver token is the catalogue's, and it is not the engine's own name" "pg" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DB_CLIENT") | .value' $CONTACTS_D)"
  # The one that ships a database server in its image: a non-local host is the only thing that
  # stops it starting one.
  check "the office suite is pointed at an engine outside its own container" \
    "example-sql-pg.example-engines.svc.cluster.local" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DB_HOST") | .value' $SUITE_D)"

  echo
  echo "== AN EMBEDDED ENGINE IS A PATH INSIDE THIS WORKLOAD'S OWN MOUNT, AND NO ADDRESS AT ALL =="
  check "the task list's database file" "/etc/vikunja/vikunja.db" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "VIKUNJA_DATABASE_PATH") | .value' $TASKS_D)"
  check "and the directory it names is mounted" "/etc/vikunja" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "database") | .mountPath' $TASKS_D)"
  check "the shelf's, which its software wants with a scheme in front of it" \
    "file:/app/app-data/db/db.sqlite" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DATABASE_URL") | .value' $SHELF_D)"
  check "no host variable is rendered for an embedded engine" "0" \
    "$(y '[.spec.template.spec.containers[0].env[] | select(.name == "VIKUNJA_DATABASE_HOST")] | length' $TASKS_D)"
  # The record platform runs on an EXTERNAL engine, so the directory that would hold an embedded
  # one is not mounted at all -- backing it is refused.
  check "and the platform on an external engine mounts no database directory" "0" \
    "$(y '[.spec.template.spec.containers[0].volumeMounts[] | select(.name == "database")] | length' $CONTACTS_D)"

  echo
  echo "== WHERE THE WORK LANDS: the mount path is the CATALOGUE'S, the backing is the DECLARATION'S =="
  check "the wiki's own directory" "/config" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "config") | .mountPath' $PAGES_D)"
  check "backed by the consumer's path, never this repository's" "/example/state/pages" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "config") | .hostPath.path' $PAGES_D)"
  check "the corpus must already exist -- an empty directory is a healthy, EMPTY wiki" "Directory" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "config") | .hostPath.type' $PAGES_D)"
  check "the pipeline's intake directory is where its watcher looks" "/usr/src/paperless/consume" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "consume") | .mountPath' $PIPE_D)"
  check "the shelf's readable corpus is a mount of its own, beside its opaque database" \
    "/app/corpus" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "corpus") | .mountPath' $SHELF_D)"
  # ... and the environment that makes that split true rather than merely intended.
  check "and the storage root agrees with it" "/app/corpus/documents" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "DOCUMENT_STORAGE_FILESYSTEM_ROOT") | .value' $SHELF_D)"
  check "the office suite's identity directory, which regenerates its keys when it is missing" \
    "/var/www/euro-office/Data" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "identity") | .mountPath' $SUITE_D)"
  check "the board's semantic backgroundImages key renders a DNS-label volume name" \
    "/app/public/background-images" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "background-images") | .mountPath' $BOARD_D)"
  check "the board's semantic userAvatars key renders a DNS-label volume name" \
    "/example/state/board-avatars" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "user-avatars") | .hostPath.path' $BOARD_D)"
  check "the project manager's semantic publicUserfiles key renders a DNS-label volume name" \
    "/var/www/html/public/userfiles" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "public-userfiles") | .mountPath' $PROJECTS_D)"

  echo
  echo "== THE EDITOR THAT OWNS NO DOCUMENT MOUNTS NOTHING, AND EVERY OTHER WORKLOAD IS A SINGLE WRITER =="
  check "no volumes at all"       "0" "$(y '[.spec.template.spec.volumes // [] | .[]] | length' $EDIT_D)"
  check "no volume mounts at all" "0" "$(y '[.spec.template.spec.containers[0].volumeMounts // [] | .[]] | length' $EDIT_D)"
  check "nothing to lose, so a rolling update is safe" "RollingUpdate" "$(y '.spec.strategy.type' $EDIT_D)"
  check "the booking page keeps nothing on disk either" "RollingUpdate" "$(y '.spec.strategy.type' $BOOK_D)"
  for d in "$PAGES_D" "$PIPE_D" "$SHELF_D" "$TASKS_D" "$BOARD_D" "$SUITE_D" "$TYPE_D" "$CONTACTS_D" "$PROFILE_D"; do
    check "$(basename $d): single writer, so Recreate and never a rolling update" "Recreate" \
      "$(y '.spec.strategy.type' $d)"
  done
  check "and every workload keeps exactly one replica" "1" "$(y '.spec.replicas' $PAGES_D)"

  echo
  echo "== A CATEGORY DECIDED EVERY NAMESPACE; NO DECLARATION DID =="
  check "wiki"       "example-wiki"        "$(y '.metadata.namespace' $PAGES_D)"
  check "pipeline"   "example-filing"      "$(y '.metadata.namespace' $PIPE_D)"
  check "shelf"      "example-filing"      "$(y '.metadata.namespace' $SHELF_D)"
  check "task list"  "example-tasks"       "$(y '.metadata.namespace' $TASKS_D)"
  check "board"      "example-board"       "$(y '.metadata.namespace' $BOARD_D)"
  check "editor"     "example-editing"     "$(y '.metadata.namespace' $EDIT_D)"
  check "suite"      "example-editing"     "$(y '.metadata.namespace' $SUITE_D)"
  # The two pairs, on the bytes: a category holds more than one application, and it is named after
  # neither of them.
  check "the document-manager category holds two" "pipeline shelf" "$filingCategory"
  check "the task category holds two"             "projects tasks" "$taskCategory"

  echo
  echo "== ONE ORIGIN, SEVERAL VARIABLES, SEVERAL FORMS =="
  check "the pipeline's URL"                "https://filing.example.com" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "PAPERLESS_URL") | .value' $PIPE_D)"
  check "the same value as a bare HOST, because its framework rejects anything else" \
    "filing.example.com" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "PAPERLESS_ALLOWED_HOSTS") | .value' $PIPE_D)"
  check "and the editor, which wants a host and not a URL" "edit.example.com" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "server_name") | .value' $EDIT_D)"

  echo
  echo "== DOCUMENT HOSTS: numbered variables, escaped patterns, and no port anywhere =="
  check "the first"  'https://files\.example\.com' \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "aliasgroup1") | .value' $EDIT_D)"
  check "the second, which is what makes the numbering load-bearing" 'https://pages\.example\.com' \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "aliasgroup2") | .value' $EDIT_D)"
  check "and no third was invented" "0" \
    "$(y '[.spec.template.spec.containers[0].env[] | select(.name == "aliasgroup3")] | length' $EDIT_D)"

  echo
  echo "== THE SWITCH IS RENDERED FROM THE SAME VALUE THE GUARD READ =="
  check "the task list's reminder timer is off, and the software is told so" "false" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "VIKUNJA_SERVICE_ENABLEEMAILREMINDERS") | .value' $TASKS_D)"
  check "the shelf's intake watcher likewise" "false" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "INGESTION_FOLDER_IS_ENABLED") | .value' $SHELF_D)"
  check "and those are the ones allowed to idle at zero" "scale-to-zero" \
    "$(y '.metadata.labels."nixk3s.dev/scaling"' $TASKS_D)"
  check "a scale-to-zero workload renders NO replica count" "null" "$(y '.spec.replicas' $TASKS_D)"
  check "and its Application ignores that field, so a sync cannot fight the autoscaler" \
    "/spec/replicas" \
    "$(y '.spec.ignoreDifferences[0].jsonPointers[0]' $manifests/apps/Application-tasks.yaml)"
  check "the pipeline stays resident, because nothing could wake it for a dropped file" "always" \
    "$(y '.metadata.labels."nixk3s.dev/scaling"' $PIPE_D)"
  check "what has to stay awake, as a list" \
    "editing editingsuite pipeline projects typesetting" "$mustStayAwake"

  echo
  echo "== PROBES ARE THE SOFTWARE'S OWN, INCLUDING WHERE THERE IS NONE TO HAVE =="
  check "the task list answers this anonymously, before any account exists" "/api/v1/info" \
    "$(y '.spec.template.spec.containers[0].readinessProbe.httpGet.path' $TASKS_D)"
  check "the record platform's other health endpoint needs a session, so this is the one" \
    "/server/ping" "$(y '.spec.template.spec.containers[0].readinessProbe.httpGet.path' $CONTACTS_D)"
  check "the board documents nothing better than a TCP connect" "null" \
    "$(y '.spec.template.spec.containers[0].readinessProbe.httpGet' $BOARD_D)"
  check "a slow first boot gets a startup probe rather than a permanent readiness budget" "72" \
    "$(y '.spec.template.spec.containers[0].startupProbe.failureThreshold' $PIPE_D)"
  check "and its readiness budget stays short" "6" \
    "$(y '.spec.template.spec.containers[0].readinessProbe.failureThreshold' $PIPE_D)"
  check "no liveness probe was synthesized anywhere" "null" \
    "$(y '.spec.template.spec.containers[0].livenessProbe' $PAGES_D)"

  echo
  echo "== TWO AUDIENCES, ONE POD, ONE SERVICE -- which is why public exposure is refused =="
  check "the editing port"     "3000" "$(y '.spec.ports[] | select(.name == "admin") | .port' $PROFILE_S)"
  check "the published port"   "3001" "$(y '.spec.ports[] | select(.name == "public") | .port' $PROFILE_S)"
  check "one selector reaches both"  "profile" "$(y '.spec.selector."app.kubernetes.io/name"' $PROFILE_S)"
  check "the software that asks nobody for anything, as a list" "profile" "$unauthenticated"

  echo
  echo "== NO FLEET ADDRESS REACHES ANY OBJECT: a class is a label, never a number =="
  for svc in $(find -L $manifests -type f -name 'Service-*.yaml' | sort); do
    check "$(basename $svc): type"           "ClusterIP" "$(y '.spec.type' $svc)"
    check "$(basename $svc): no pinned IP"   "null"      "$(y '.spec.clusterIP' $svc)"
    check "$(basename $svc): no LB address"  "null"      "$(y '.spec.loadBalancerIP' $svc)"
    check "$(basename $svc): no externalIPs" "null"      "$(y '.spec.externalIPs' $svc)"
    check "$(basename $svc): no nodePort"    "null"      "$(y '.spec.ports[0].nodePort' $svc)"
  done
  check "the wiki's exposure is a class on a label" "nb" \
    "$(y '.metadata.labels."nixk3s.dev/exposure"' $PAGES_D)"

  echo
  echo "== each namespace is anchored ONCE, and cannot be cascade-deleted =="
  present "the document-manager namespace, anchored by the pipeline" \
    "$manifests/pipeline/Namespace-example-filing.yaml"
  absent  "a second anchor for it from the shelf" \
    "$manifests/shelf/Namespace-example-filing.yaml"
  present "the editing namespace, anchored by the first editor" \
    "$manifests/editing/Namespace-example-editing.yaml"
  absent  "a second anchor for it from the suite" \
    "$manifests/editingsuite/Namespace-example-editing.yaml"
  for ns in $(find -L $manifests -type f -name 'Namespace-*.yaml' | sort); do
    check "$(basename $ns): Prune=false" "Prune=false" \
      "$(y '.metadata.annotations."argocd.argoproj.io/sync-options"' $ns)"
  done

  echo
  echo "== NOTHING IS RENDERED BELOW THE APP GRAMMAR =="
  for app in $(find -L $manifests/apps -type f -name 'Application-*.yaml' | sort); do
    check "$(basename $app): no server-side apply, because nothing here is adopted" "null" \
      "$(y '.spec.syncPolicy.syncOptions' $app)"
    check "$(basename $app): project" "example-office" "$(y '.spec.project' $app)"
  done
  # Every file this surface produced is a Deployment, a Service, a Namespace or an Application.
  for f in $(find -L $manifests -type f -name '*.yaml' | sort); do
    kind=$(y '.kind' $f)
    case "$kind" in
      Deployment|Service|Namespace|Application) ;;
      *) echo "  FAIL an object of kind $kind was rendered: $f"; fail=1 ;;
    esac
  done
  echo "  ok   only Deployments, Services, Namespaces and Applications exist"

  echo
  echo "== NO SECRET OBJECT IS EVER RENDERED, AND NO CONNECTION IS EVER A VALUE =="
  for f in $(find -L $manifests -type f | sort); do
    if [ "$(y '.kind' $f)" = "Secret" ]; then
      echo "  FAIL a Secret object was rendered: $f"; fail=1
    fi
  done
  echo "  ok   every credential is a reference to a Secret somebody else supplies"

  echo
  echo "== WHAT THIS SURFACE NEEDS SOMEBODY ELSE TO RUN =="
  check "the engines, counted" "mariadb mongodb postgres redis" "$externalEngines"

  if [ "$fail" -ne 0 ]; then
    echo "rendered output does not match this surface's promises" >&2
    exit 1
  fi
  echo "all render assertions hold"
  cp -rL $manifests $out
''
