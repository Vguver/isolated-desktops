# Security Policy

## Supported versions

The maintainer aims to support the latest published release line.

| Version line | Supported |
| --- | --- |
| 1.6.x | Yes |
| 1.5.x and older | No |

## Reporting a vulnerability

Please **do not open a public issue with exploit details** for a sensitive security problem.

Preferred reporting path:

1. Use GitHub's **private vulnerability reporting** feature for this repository if it is enabled.
2. If private reporting is not available, use the maintainer contact option on the GitHub profile if available.
3. If neither option is available, open a minimal public issue that says a private security concern exists **without including reproduction steps, payloads, secrets, or exploit details**.

Please include:

- affected version
- operating system and shell version
- exact command used
- expected behavior
- actual behavior
- logs with secrets, tokens, private URLs, and personal data removed
- whether the issue requires local access, a crafted manifest, a malicious repository, or elevated privileges

## Response expectations

Best effort targets:

- initial acknowledgement within 7 days
- status update after triage when reproducible
- a fix or mitigation in the next reasonable patch release for confirmed issues

## Scope notes

This project manages profile-scoped session state, but it can launch **third-party installers** that may change host-wide packages, services, and system files.

Security reports are most useful when they distinguish between:

- bugs in **this project**
- behavior caused by an **upstream third-party installer**

## Disclosure policy

Please allow time for triage and a fix before publishing a detailed write-up.

Once a fix is available, coordinated public disclosure is welcome.
