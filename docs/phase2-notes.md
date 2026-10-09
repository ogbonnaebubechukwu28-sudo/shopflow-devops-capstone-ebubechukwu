# Phase 2 - Git & GitHub Workflow: Notes

## Branching strategy
- main is protected and always deployable. Changes only arrive via pull request.
- feature/<name> for new work, fix/<name> for bug fixes, docs/<name> for documentation.
- Commit messages are short and imperative, e.g. "docs: clean README title".

## Pull requests
- PR #1 (feature/readme-a): updated the README title and removed a duplicated Branching Strategy section.
- PR #2 (feature/readme-b): changed the same title line as readme-a, which caused a merge conflict.

## Intentional merge conflict
- readme-a and readme-b both edited line 1 of README.md from the same starting point.
- After PR #1 was merged, PR #2 showed "This branch has conflicts".
- Resolved locally: git merge origin/main, edited README.md to keep one title,
  removed the <<<<<<<, ======= and >>>>>>> markers, then git add, commit and push.
- Final title: "ShopFlow DevOps Capstone".

## Branch protection
- A GitHub ruleset on main requires changes to go through a pull request.
- Test: a direct git push to main was rejected with
  "GH013: Repository rule violations found - Changes must be made through a pull request".

## Lessons learned
- Pasting multi-line text into the terminal can corrupt files or run commands in the wrong place.
- A branch created from an old main needs git merge main before its PR is clean.
- Always run git pull on main before creating a new branch.

## Commit history
*   f0c4ff5 Merge pull request #2 from ogbonnaebubechukwu28-sudo/feature/readme-b
|\  
| *   c41e906 merge: resolve README title conflict
| |\  
| |/  
|/|   
* |   b45a6ee Merge pull request #1 from ogbonnaebubechukwu28-sudo/feature/readme-a
|\ \  
| * | 7540e1d docs: clean README title and remove duplicate section
| * |   02284f1 nano README.mdMerge branch 'main' into feature/readme-a
| |\ \  
| |/ /  
|/| |   
| * | ee824a8 docs: readme title version A
| | * 251f85f docs: readme title version B
| |/  
|/|   
* | 5b89c54 Refactor Branching Strategy section in README
|/  
* 68e1b35 Update README with branching strategy details
* 4d0b841 Phase 1: fix SQLAlchemy/psycopg driver mismatch, verify full stack locally
* d11b886 Phase 1: dockerize ShopFlow app, run locally with docker compose
*   f0c4ff5 Merge pull request #2 from ogbonnaebubechukwu28-sudo/feature/readme-b
|\  
| *   c41e906 merge: resolve README title conflict
| |\  
| |/  
|/|   
* |   b45a6ee Merge pull request #1 from ogbonnaebubechukwu28-sudo/feature/readme-a
|\ \  
| * | 7540e1d docs: clean README title and remove duplicate section
| * |   02284f1 nano README.mdMerge branch 'main' into feature/readme-a
| |\ \  
| |/ /  
|/| |   
| * | ee824a8 docs: readme title version A
| | * 251f85f docs: readme title version B
| |/  
|/|   
* | 5b89c54 Refactor Branching Strategy section in README
|/  
* 68e1b35 Update README with branching strategy details
* 4d0b841 Phase 1: fix SQLAlchemy/psycopg driver mismatch, verify full stack locally
* d11b886 Phase 1: dockerize ShopFlow app, run locally with docker compose
