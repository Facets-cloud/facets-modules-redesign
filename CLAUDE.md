# CLAUDE.md - Project Instructions for Claude Code

## Project Overview

This repository contains Facets infrastructure modules with validation and testing workflows.

## Key Files

- `issues.md` - Catalog of all validation error patterns and fixes
- `pending-errors.md` - Current status of module validation errors
- `testing.md` - Testing setup and environment configuration
- `debug-report.md` - Debug findings for CP backend issues

## Validation Error Fix Workflow

**IMPORTANT:** After fixing a module validation error and committing the fix:

### Step 1: Update `pending-errors.md`
- Move the module from "Failed Modules" to "Fixed Modules" section
- Include: error type, original error, root cause, fix applied, commit hash
- Update the Summary table counts (decrement Failed, increment Fixed)
- Strike through the module in "Errors Grouped by Root Cause"
- Strike through in "Priority Fix Order" if applicable

### Step 2: Update `issues.md`
- Check if the error pattern already exists
- If NEW error pattern: add a new numbered section with:
  - Error Pattern (exact error message)
  - Issue description with Incorrect/Correct examples
  - Rule summary
- Update the Summary Table
- Add to "Quick Reference: Validation Checklist" if applicable

### Step 3: Commit doc updates
- Commit the documentation updates separately from the fix

## Testing Commands

```bash
# Set environment
export FACETS_PROFILE=facetsdemo

# Validate all modules
raptor import project-type -f project-type/aws/project-type.yml --modules-dir modules --outputs-dir outputs

# Validate single module
raptor import project-type -f project-type/aws/project-type.yml --modules-dir modules/path/to/module
```

## GitHub Issues

Related issues in https://github.com/Facets-cloud/raptor:
- #38 - CP returns null properties during batch import
- #39 - patternProperties + required validation (FIXED in this repo)
- #42 - CP strips type:object from schemas
- #43 - .terraform/modules scanning issue
