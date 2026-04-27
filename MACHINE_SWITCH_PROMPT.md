# Machine-Switch Prompt

Paste this into any future Codex thread when you are about to change machines:

```text
I may switch to another machine soon. Please do a full repo handoff/sync check for this workspace.

Requirements:
- Check the current git state first.
- Identify anything that exists only locally:
  - uncommitted changes
  - local commits not pushed
  - local branches without upstreams
- Do not merge branches unless I explicitly ask.
- If there are uncommitted changes that should be preserved, commit them on their current branch with a clear WIP-style message.
- Push every branch that contains local-only work to its remote, setting upstreams when needed.
- Create or update a `HANDOFF.md` file in the repo root with:
  - current branch/baseline status
  - whether the repo is clean
  - the latest relevant commit
  - current roadmap/project status
  - exact next recommended step
  - any local tooling assumptions needed on the next machine
- Commit and push the handoff file too.
- After that, tell me exactly what was committed, what was pushed, and whether anything is still only local.

Use the repo itself as the source of truth, not chat history.
```
