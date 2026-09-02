# GCP Folder

Creates a single Google Cloud **resource-hierarchy folder** under an
organization or under another folder. Use it to build the landing-zone tree —
compose the module multiple times to nest folders. It emits a `@facets/gcp_folder`
output that downstream modules (projects, org policies, more folders) attach to
as their parent.

- **Clouds:** gcp
- **Resources created:** one `google_folder`
- **Output type:** `@facets/gcp_folder`

---

## Architecture

```
   INPUTS                                  THIS module (main.tf)          OUTPUT
   ┌────────────────────────────┐
   │ cloud_account              │  org_name (fallback parent)
   │  @facets/gcp_org_account   │ ─────────────┐
   │  attributes.org_name       │              │
   └────────────────────────────┘              ▼
                                        ┌─────────────────────┐
   ┌────────────────────────────┐       │ google_folder.this  │      @facets/gcp_folder
   │ parent_folder  (optional)  │ ────► │  display_name       │ ───► attributes:
   │  @facets/gcp_folder        │ parent│  parent             │        folder_id
   │  attributes.folder_name    │       │  deletion_protection│        folder_name
   └────────────────────────────┘       └─────────────────────┘        parent
```

Parent selection: if `parent_folder` is wired, its `folder_name` is the parent;
otherwise the folder is created directly under the org (`cloud_account.org_name`).

---

## Usage

### Top-level folder (directly under the org)

```yaml
kind: gcp_folder
flavor: standard
version: "1.0"
spec:
  display_name: my-platform
  deletion_protection: true
```

### Nested folder (under another gcp_folder)

Wire the parent folder resource into the `parent_folder` input; the module then
creates this folder beneath it.

```yaml
kind: gcp_folder
flavor: standard
version: "1.0"
spec:
  display_name: my-app-stage
  deletion_protection: true
```

---

## Inputs

| Name | Type | Required | Purpose |
|------|------|----------|---------|
| `cloud_account` | `@facets/gcp_org_account` (provider `google`) | Yes | GCP org credentials and provider. Supplies `org_name`, used as the parent when no `parent_folder` is given. |
| `parent_folder` | `@facets/gcp_folder` | No | Parent folder to nest under. Omit to create the folder at the org root. |

---

## Spec

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `display_name` | Yes | — | Folder display name. Must be unique among sibling folders. |
| `deletion_protection` | No | `true` | Prevents accidental folder deletion. |

---

## Outputs — `@facets/gcp_folder`

No interfaces. Attributes:

| Attribute | Description |
|-----------|-------------|
| `folder_id` | Numeric folder id (e.g. `folders/1234567890` → `1234567890`, as returned by `google_folder.folder_id`). |
| `folder_name` | Full resource name (`folders/<id>`). Used as the `parent` value by child folders. |
| `parent` | This folder's parent (`organizations/<id>` or `folders/<id>`). |

---

## Notes

- **Parent resolution** uses `coalesce(parent_folder.folder_name, cloud_account.org_name)`.
  If neither is present, apply fails — a valid org account is always required.
- **`deletion_protection` defaults to `true`.** GCP refuses to delete a folder
  while it holds resources or has protection on; disable it deliberately before
  tearing down a branch.
- **Nesting is by composition**, not by config — one module instance is one
  folder. Build depth by chaining instances through the `parent_folder` input.
- **`display_name` is mutable** but must stay unique among siblings; `folder_id`
  is assigned by GCP and never changes.
