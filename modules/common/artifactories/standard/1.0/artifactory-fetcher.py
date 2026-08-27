"""Resolve the environment's container-registry (artifactory) list for Terraform.

Works on both IaC frameworks, without reimplementing either one:

  * Legacy framework — the framework's own fetcher is on disk at a known path and
    already owns this contract, so we hand off to it and let it answer. Its
    behavior stays owned by the legacy repo; nothing is duplicated here.

  * CRD-driven framework — that script is not present. The release pod runs in
    /workspace and the operator inflates the Release CRD to /config/release.yaml,
    whose spec.artifactories carries the registry records. That is the only case
    this file implements.

Output shape is identical either way, so the module's data.external contract does
not change.
"""

import json
import os
import sys
import traceback

LEGACY_SCRIPT = (
    "/sources/primary/capillary-cloud-tf/tfmain/scripts"
    "/artifactory-fetch-secret/artifactory-fetcher.py"
)
RELEASE_YAML_PATH = os.getenv("RELEASE_YAML_PATH", "/config/release.yaml")


def delegate_to_legacy():
    """Hand off to the legacy framework's fetcher when it is present.

    Uses exec rather than a subprocess so the legacy script inherits this
    process outright: its stdout becomes our stdout verbatim and its exit status
    becomes ours, which is what data.external reads. On success this call does
    not return.
    """
    if not os.path.isfile(LEGACY_SCRIPT):
        return False
    python = sys.executable or "python3"
    os.execv(python, [python, LEGACY_SCRIPT] + sys.argv[1:])


def _normalize(artifactory):
    """Reconcile the two spellings of the ECR account-id field.

    ReleaseCrdMapper emits awsAccountID; the module indexes awsAccountId (see
    ecr-token-refresher.tf), which is the spelling the legacy deployment context
    used. Membership is not enough — a key present but explicitly null must not
    shadow the populated spelling, or the module writes a null aws_account into
    the refresher's config secret and the apply fails.
    """
    normalized = dict(artifactory)
    if not normalized.get("awsAccountId") and normalized.get("awsAccountID"):
        normalized["awsAccountId"] = normalized["awsAccountID"]
    return normalized


def _parse_release_yaml(text):
    """Extract spec.artifactories from the inflated Release CRD.

    PyYAML is used when the release image ships it. The hand-rolled fallback is
    deliberately narrow: it only walks the top-level spec -> artifactories
    sequence, whose entries are flat maps of scalars (name, uri,
    artifactoryType, awsKey, awsSecret, awsRegion, awsAccountID, username,
    password). Anything else raises rather than guessing.
    """
    try:
        import yaml  # noqa: PLC0415 — optional dependency, absent on some images
    except ImportError:
        return _parse_artifactories_block(text)

    spec = (yaml.safe_load(text) or {}).get("spec", {}) or {}
    return spec.get("artifactories", []) or []


def _strip_inline_comment(value):
    """Drop a trailing `# ...` comment, ignoring `#` inside quotes."""
    quote = None
    for i, ch in enumerate(value):
        if quote is not None:
            if ch == quote:
                quote = None
        elif ch in ("'", '"'):
            quote = ch
        elif ch == "#" and (i == 0 or value[i - 1] in (" ", "\t")):
            return value[:i]
    return value


_NON_SCALAR_PREFIXES = ("|", ">", "[", "{", "&", "*", "!")


def _scalar(raw_value, raw_line):
    """Return a scalar value, or None when the key opens a nested block.

    A *quoted* empty string is a legitimate scalar (the CP serializes absent
    optional fields that way); a *bare* empty value means a nested block, which
    this parser deliberately refuses to guess at.
    """
    value = _strip_inline_comment(raw_value).strip()
    if not value:
        return None
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    if value[0] in _NON_SCALAR_PREFIXES:
        raise ValueError(
            "unsupported non-scalar value under spec.artifactories: %r" % raw_line
        )
    return value


def _parse_artifactories_block(text):
    entries = []
    current = None
    in_spec = False
    spec_child_indent = None
    key_indent = None  # indent of the `artifactories:` key, once found

    def flush():
        # Must run on every exit from the block, including a new top-level key
        # (a CRD carries `status:` after `spec:`) — otherwise the last entry,
        # often the only one, is silently dropped and the module tears down
        # every registry secret it manages.
        nonlocal current
        if current is not None:
            entries.append(current)
            current = None

    for raw in text.splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if stripped in ("---", "..."):
            flush()
            in_spec = False
            spec_child_indent = None
            key_indent = None
            continue

        indent = len(line) - len(line.lstrip())

        if indent == 0:
            flush()
            if key_indent is not None:
                break  # the block is behind us; nothing left to collect
            in_spec = stripped == "spec:"
            spec_child_indent = None
            continue

        if not in_spec:
            continue

        # The first child line of `spec:` fixes the depth at which a direct
        # child key lives. Gating on it keeps a nested `artifactories:` — the
        # artifactories module's own instance spec appears under
        # spec.modules[].resources[].spec — from being mistaken for this one.
        if spec_child_indent is None:
            spec_child_indent = indent

        if key_indent is None:
            if indent != spec_child_indent:
                continue
            key, _, value = stripped.partition(":")
            if key.strip() != "artifactories":
                continue
            inline = _strip_inline_comment(value).strip()
            if inline in ("[]", "{}"):
                return []
            if inline:
                raise ValueError(
                    "unsupported inline spec.artifactories value: %r" % raw
                )
            key_indent = indent
            continue

        # A sibling (or shallower) key ends the block. Sequence entries are
        # allowed to sit at the key's own indent, which is why `- ` is checked
        # before the indent guard.
        is_item = stripped.startswith("- ")
        if not is_item and indent <= key_indent:
            flush()
            break

        if is_item:
            flush()
            current = {}
            stripped = stripped[2:].strip()
            if not stripped:
                continue

        if current is None or ":" not in stripped:
            raise ValueError(
                "unsupported YAML shape under spec.artifactories: %r" % raw
            )

        key, _, value = stripped.partition(":")
        scalar = _scalar(value, raw)
        if scalar is None:
            raise ValueError(
                "unsupported nested block under spec.artifactories: %r" % raw
            )
        current[key.strip()] = scalar

    flush()
    return entries


def load_artifactories(path=None):
    with open(path or RELEASE_YAML_PATH, "r", encoding="utf-8") as f:
        return _parse_release_yaml(f.read())


class ArtifactoryFetcher:
    def __init__(self, include_all, artifactory_names):
        self.include_all = include_all.lower() == "true"
        self.artifactory_names = json.loads(artifactory_names) if artifactory_names else []

    def should_include(self, artifactory_name):
        """Check if artifactory should be included based on filters"""
        if self.include_all:
            return True
        return artifactory_name in self.artifactory_names

    def run(self):
        artifactory_list = load_artifactories()

        artifactories_ecr = {}
        artifactories_dockerhub = {}

        for artifactory in artifactory_list:
            artifactory = _normalize(artifactory)
            name = artifactory.get("name")
            artifactory_type = artifactory.get("artifactoryType", "ECR")

            # Both output maps are keyed by name, and the module indexes
            # artifactory["name"] downstream. A nameless record would key the
            # map under "null" and surface as an opaque Terraform error far
            # from the cause, so reject it here with the record in the message.
            if not name:
                raise ValueError("artifactory record has no name: %r" % (artifactory,))

            if not self.should_include(name):
                continue

            if artifactory_type == "ECR":
                artifactories_ecr[name] = artifactory
            else:
                artifactories_dockerhub[name] = artifactory

        # Return as JSON strings since data.external only supports flat string maps
        output = {
            "artifactories_ecr": json.dumps(artifactories_ecr),
            "artifactories_dockerhub": json.dumps(artifactories_dockerhub)
        }
        print(json.dumps(output))


if __name__ == "__main__":
    try:
        delegate_to_legacy()  # does not return when the legacy script is present
        include_all = sys.argv[1] if len(sys.argv) > 1 else "true"
        artifactory_names = sys.argv[2] if len(sys.argv) > 2 else "[]"
        ArtifactoryFetcher(include_all, artifactory_names).run()
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
