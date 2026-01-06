# Track Validation Fix

Track and document module validation error fixes in the project documentation.

## When to Use

Invoke this skill with `/track-validation-fix` after fixing a module validation error and committing the fix.

## Arguments

- `module` (optional): Module path like `ingress/nginx_k8s`. If not provided, will detect from recent commit.
- `commit` (optional): Commit hash. Defaults to HEAD.

## Workflow

### Step 1: Gather Fix Information

1. Read the recent git commit (HEAD or specified commit):
   ```bash
   git show --stat HEAD
   git diff HEAD~1 HEAD
   ```

2. Extract:
   - Module name/path from changed files
   - Error type from commit message
   - Fix description from commit message

### Step 2: Update pending-errors.md

1. Read `pending-errors.md`

2. Find the module in "Failed Modules" section

3. Move to "Fixed Modules" section with:
   ```markdown
   ### [checkmark] module/name

   **Error Type:** <error type>

   **Original Error:**
   ```
   <original error message>
   ```

   **Root Cause:** <explanation>

   **Fix Applied:** <what was changed>

   **Commit:** `<hash>` - <commit message>
   ```

4. Update Summary table counts:
   - Decrement "Failed" count
   - Increment "Fixed" count

5. Update "Errors Grouped by Root Cause":
   - Strike through fixed module
   - Add "[checkmark] FIXED" if all modules in group are fixed

6. Update "Priority Fix Order":
   - Strike through fixed item

### Step 3: Check issues.md for Error Pattern

1. Read `issues.md`

2. Search for matching error pattern:
   - Look for similar error message in existing sections
   - Check if root cause matches an existing issue type

3. If error pattern is NEW (not documented):
   - Add new numbered section before "Summary Table"
   - Follow the existing format:
     ```markdown
     ## N. Error Type Name

     ### Error Pattern
     ```
     <exact error message pattern>
     ```

     ### Issue: Specific Problem Description
     **Module:** `module/name`

     **Problem:** Explanation of what causes this error.

     **Incorrect:**
     ```yaml
     # code that causes the error
     ```

     **Correct:**
     ```yaml
     # fixed code
     ```

     **Rule:** One-line summary of how to avoid this error.

     ---
     ```

4. Update "Summary Table":
   - Add new row if new error type
   - Update count if existing error type

5. Update "Quick Reference: Validation Checklist":
   - Add new checkbox item if applicable

### Step 4: Verify Updates

1. Ensure all markdown formatting is correct
2. Check that section numbers are sequential
3. Verify counts match actual entries

## Example Usage

```
/track-validation-fix
```

Or with arguments:
```
/track-validation-fix module=ingress/nginx_k8s commit=c3dfccb
```

## Files Modified

- `pending-errors.md` - Move error to fixed, update counts
- `issues.md` - Add new error pattern if not documented

## Notes

- Always preserve existing content structure
- Use strikethrough (`~~text~~`) for fixed items, don't delete them
- Include commit hash for traceability
- Match the existing documentation style exactly
