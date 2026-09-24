# 4. CLI binary is `where-cli`, not `where`

Date: 2026-09-24 · Status: Accepted

Windows ships `where.exe` (locate executables) on every PATH, and Windows is
the alpha platform. Shadowing it would break users' scripts. The developer
CLI is therefore `where-cli`. Product naming (spec §44) is unaffected.
