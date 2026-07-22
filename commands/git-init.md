---
name: spx:git-init
description: "Initialize a Git repository with an initial commit"
---

# Initialize Git Repository

Initialize a Git repository in the current project directory if one does not already exist.

## Execution

Run the script from the project root:

- **Bash**: `${CLAUDE_PLUGIN_ROOT}/scripts/git/initialize-repo.sh`

If the script is not found, fall back to:

- **Bash**: `git init && git add . && git commit -m "Initial commit from Specify template"`

The script handles all checks internally:

- Skips if Git is not available
- Skips if already inside a Git repository
- Runs `git init`, `git add .`, and `git commit` with an initial commit message

## Customization

Replace the script to add project-specific Git initialization steps:

- Custom `.gitignore` templates
- Default branch naming (`git config init.defaultBranch`)
- Git LFS setup
- Git hooks installation
- Commit signing configuration
- Git Flow initialization

## Output

On success:

- `[OK] Git repository initialized`

## Graceful Degradation

If Git is not installed:

- Warn the user
- Skip repository initialization
- The project continues to function without Git (specs can still be created under `specs/`)

If Git is installed but `git init`, `git add .`, or `git commit` fails:

- Surface the error to the user
- Stop this command rather than continuing with a partially initialized repository
