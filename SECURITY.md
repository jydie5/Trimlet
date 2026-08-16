# Security policy

## Supported versions

Trimlet is currently a proof of concept and has no supported public binary release. Security fixes will target the default development branch until a versioned support policy is published.

## Reporting a vulnerability

Do not include exploitable details, private media, or personal paths in a public issue.

After the GitHub repository is published, use GitHub private vulnerability reporting from the repository Security tab. Maintainers must enable that feature before announcing the repository as ready for outside contributions.

Reports should include the affected revision, operating system, impact, reproduction steps using synthetic media where possible, and whether FFmpeg/ffprobe is involved.

Trimlet processes untrusted media locally. Treat parsing, path handling, temporary files, child-process arguments, output replacement, and cache cleanup as security-sensitive areas.
