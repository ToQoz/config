## General

### Language

- Communicate with user in "Japanese". But think in English.
- Write anything like code, comments, document and commit messages in English.
- Exception rule: Documents and dictionary files whose file names or directory names contain locale should be written in the language corresponding to that locale.

### Working directory for thinking

- Use `<PROJECT_ROOT>/,` directory to write down plans, progress actively and record anything.
- If the directory does not exist, create it.

For example:

- `<PROJECT_ROOT>/,/abc-feature-plan.md`
- `<PROJECT_ROOT>/,/abc-feature-testing-plan.md`

## Git

### Commit frequently

- Commit each change with as little granularity as possible.
- If multiple logical changes can already be included, stage and commit each uncommitted change after splitting it into the smallest change that logically makes sense as one.
  - Split up changes within a single file, if necessary. 
- If you stash during the work process, clean up afterwards.

### Commit Message

- Follow Conventional Commits.
- Write commit messages in English, but follow the project's rules.

### GitHub Pull Request

- Write Pull Request title and description in English, but follow the project's rules.

### Comments

- As mentioned in A Philosophy of Software Design, 2nd Edition, write comments to achieve abstraction beyond what can be expressed in function signatures.
- Write "why" instead of "what".

## Node.js

### Package Manager

- Use pnpm as the package manager.
- However, follow the project's configuration.
- The project's configuration is determined by the presence of package.json, package-lock.json, yarn.lock, bun.lockb, or pnpm-lock.yaml.
