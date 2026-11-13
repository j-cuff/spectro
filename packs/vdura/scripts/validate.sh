#!/usr/bin/env bash
# Offline checks for every pack in packs/. Never contacts a Kubernetes cluster.
#
#   - pack.json is valid and has name/displayName/version/layer, version has no leading "v"
#   - logo.png and README.md exist
#   - every chart archive in pack.json exists and has a matching charts.<name> block in values.yaml
#   - helm lint and helm template pass using the pack values (plus test values for
#     REQUIRED fields), with the release name and namespace Palette would use
#   - every public image the charts render is listed in pack.content.images
#   - with --images: every image in pack.content.images exists in its registry (needs crane)
#
# Requires: helm, yq (mikefarah v4), jq, tar. Optional: crane.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CHECK_IMAGES=false
[ "${1:-}" = "--images" ] && CHECK_IMAGES=true

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
failures=0
fail() { echo "  FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "  ok:   $*"; }

# Placeholder answers for REQUIRED values so the charts can render. Not real credentials.
# Images on registry.example.com stand in for VDURA's private registry and are not
# expected in pack.content.images.
PRIVATE_REGISTRY=registry.example.com
test_values() {
  case "$1" in
    csi-panfs-registry-secret) cat <<'EOF'
registry: {server: registry.example.com, username: test-user, password: test-password}
EOF
      ;;
    csi-panfs) cat <<'EOF'
dfc: {privateRegistry: registry.example.com/vdura, version: 0.0.0-test}
kmm:
  kernelMappings:
    - regexp: '^.*.x86_64$'
      containerImage: "registry.example.com/vdura/panfs-kmm:${KERNEL_FULL_VERSION}-0.0.0-test"
EOF
      ;;
    csi-panfs-storageclass) cat <<'EOF'
realm: {address: panfs.example.com, username: test-user, password: test-password}
EOF
      ;;
    *) echo "{}" ;;
  esac
}

for pack in "$ROOT"/packs/*/; do
  pack=${pack%/}
  echo "== $(basename "$pack")"
  pj=$pack/pack.json
  pv=$pack/values.yaml

  if ! jq empty "$pj" 2>/dev/null; then fail "pack.json is not valid JSON"; continue; fi
  for key in name displayName version layer; do
    [ -n "$(jq -r ".$key // empty" "$pj")" ] || fail "pack.json is missing $key"
  done
  case "$(jq -r .version "$pj")" in v*) fail "pack.json version must not start with v" ;; esac
  [ -f "$pack/logo.png" ] && pass "logo.png" || fail "logo.png missing"
  [ -f "$pack/README.md" ] && pass "README.md" || fail "README.md missing"
  yq e '.' "$pv" >/dev/null 2>&1 || { fail "values.yaml is not valid YAML"; continue; }

  ns=$(yq -r '.pack.namespace // "default"' "$pv")
  yq -r '.pack.content.images[].image' "$pv" | sort -u > "$WORK/listed"
  [ -s "$WORK/listed" ] && pass "pack.content.images lists $(wc -l < "$WORK/listed" | tr -d ' ') images" || fail "pack.content.images is empty"
  : > "$WORK/rendered-images"

  for tgz_rel in $(jq -r '.charts[]?' "$pj"); do
    tgz=$pack/$tgz_rel
    [ -f "$tgz" ] || { fail "$tgz_rel listed in pack.json but missing (run scripts/build.sh)"; continue; }
    chart=$(tar -xzOf "$tgz" "$(tar -tzf "$tgz" | awk -F/ 'NF==2 && $2=="Chart.yaml" {print; exit}')" | yq -r .name)
    if [ "$(NAME=$chart yq -r '.charts[env(NAME)] | type' "$pv")" != "!!map" ]; then
      fail "values.yaml has no charts.$chart block"; continue
    fi
    release=$(NAME=$chart yq -r '.pack.releaseNameOverride[env(NAME)] // env(NAME)' "$pv")
    NAME=$chart yq '.charts[env(NAME)]' "$pv" > "$WORK/$chart.pack.yaml"
    test_values "$chart" > "$WORK/$chart.test.yaml"

    if out=$(helm lint "$tgz" --namespace "$ns" -f "$WORK/$chart.pack.yaml" -f "$WORK/$chart.test.yaml" 2>&1); then
      pass "helm lint $chart"
    else
      fail "helm lint $chart"; echo "$out" | sed 's/^/        /'
    fi
    if helm template "$release" "$tgz" --namespace "$ns" \
         -f "$WORK/$chart.pack.yaml" -f "$WORK/$chart.test.yaml" > "$WORK/$chart.out.yaml" 2> "$WORK/$chart.err"; then
      if grep -q '<no value>' "$WORK/$chart.out.yaml"; then
        fail "helm template $chart rendered '<no value>'"
      else
        pass "helm template $chart ($(grep -c '^kind:' "$WORK/$chart.out.yaml") objects, release $release, namespace $ns)"
      fi
      # Container images plus KMM's RELATED_IMAGE_* env values.
      yq ea -N 'select(.kind != "CustomResourceDefinition") | .. | select(tag == "!!map")
                | select(has("image")) | .image | select(tag == "!!str")' \
        "$WORK/$chart.out.yaml" >> "$WORK/rendered-images"
      yq ea -N 'select(.kind != "CustomResourceDefinition") | .. | select(tag == "!!map")
                | select(has("name") and has("value")) | select(.name | test("^RELATED_IMAGE_")) | .value' \
        "$WORK/$chart.out.yaml" >> "$WORK/rendered-images"
    else
      fail "helm template $chart"; sed 's/^/        /' "$WORK/$chart.err"
    fi
  done

  sort -u "$WORK/rendered-images" | grep -v -e "^$PRIVATE_REGISTRY/" -e '^---$' -e '^null$' -e '^$' > "$WORK/public" || true
  missing=$(comm -23 "$WORK/public" "$WORK/listed")
  if [ -n "$missing" ]; then
    fail "rendered images not listed in pack.content.images:"; echo "$missing" | sed 's/^/        /'
  elif [ -s "$WORK/public" ]; then
    pass "all $(wc -l < "$WORK/public" | tr -d ' ') rendered public images are listed in pack.content.images"
  fi

  if $CHECK_IMAGES; then
    command -v crane >/dev/null || { fail "--images needs crane"; continue; }
    while read -r img; do
      crane manifest "$img" >/dev/null 2>&1 && pass "image exists: $img" || fail "image not found: $img"
    done < "$WORK/listed"
  fi
done

echo
if [ "$failures" -eq 0 ]; then echo "All checks passed."; else echo "$failures check(s) failed."; exit 1; fi
