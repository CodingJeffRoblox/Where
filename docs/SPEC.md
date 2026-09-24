<!-- Converted from Where_Product_Requirements_and_Technical_Design_v0.2.docx. The Notion copy is the living version. -->

**WHERE**

*Product Requirements, Technical Architecture & Development Plan*

Working name: Where

Product category: Cross-platform personal digital workspace

Target platforms: Windows, macOS, Linux, Android, iOS, Web

Development model: Local-first, privacy-first, cross-platform

Document status: Concept / Pre-MVP

Version: 0.2

Date: September 24, 2026

# 1. Executive Summary

Where is a cross-platform application designed to solve a simple human
problem: people know that something exists somewhere in their digital
life, but they often cannot remember where it is.

Instead of forcing users to think about which application, folder,
service, or device contains something, Where creates a searchable layer
across the user\'s digital environment.

A user should be able to search for a project, file, note, task, person,
website, application, or previous activity and see the relevant
information together.

The product is designed to work offline whenever possible, keep user
data under the user\'s control, and connect existing tools instead of
requiring users to abandon them.

Core product idea: Do not make people remember where their digital
information lives. Let them ask Where.

# 2. Name and Brand Direction

## Product name: Where

The name is intentionally simple and human. It describes the problem the
software solves without sounding like an AI product, enterprise
platform, cryptocurrency project, or generic technology startup.

The product should avoid unnecessary naming language such as AI, Nexus,
Core, Hub, X, OS, Cloud, Intelligence, Platform, Ecosystem, or Next.

## Brand voice

-   Plain English

-   Direct

-   Human

-   Useful

-   Quietly technical rather than loudly technical

-   No exaggerated claims

-   No unnecessary AI branding

## Possible product line

Where

Find what you\'re looking for.

Alternative supporting line: Everything has a place. Find it.

# 3. The Problem

Modern computing is fragmented. A typical person may have files in the
operating system, notes in a notes application, tasks in a task manager,
projects in several applications, links in a browser, conversations in
messaging services, and work spread across several devices.

The user becomes responsible for remembering where information lives,
which account contains it, what project it belongs to, and what happened
previously.

Where moves part of that organizational burden from the human to the
software.

# 4. Product Vision

Where should become a digital layer that helps people locate,
understand, and connect their information without requiring them to
replace every application they already use.

> Files ───────┐\
> Notes ───────┤\
> Tasks ───────┤\
> Projects ────┤\
> People ──────┼──→ WHERE\
> Links ───────┤\
> Apps ────────┤\
> Activity ────┘

The long-term vision is not to replace the operating system. It is to
make the user\'s digital environment easier to understand and navigate.

# 5. Product Principles

## 5.1 User-owned data

Users should be able to export their data and leave the service without
artificial lock-in.

## 5.2 Local-first

Core functionality should continue to work without an Internet
connection.

## 5.3 Privacy-first

The application should collect as little data as reasonably possible.
Sensitive information should remain local whenever practical.

## 5.4 Cross-platform

The same fundamental product should be available across Windows, macOS,
Linux, Android, iOS, and the web.

## 5.5 Modular

Major capabilities should be separated into modules so the product can
grow without becoming an unmaintainable monolith.

## 5.6 Extensible

Where should eventually support third-party integrations through a
controlled permission system.

## 5.7 Human-readable

Technical information should be explained in normal language whenever
possible.

# 6. What Makes Where Different

Where should not simply be another notes application, task manager,
launcher, file manager, AI chatbot, cloud drive, or knowledge base.

Its central function is connecting information that normally lives in
separate applications.

> Project: Website\
> \
> Files\
> - website.zip\
> - logo.svg\
> \
> Tasks\
> - Fix authentication\
> - Update homepage\
> \
> Notes\
> - Website redesign\
> \
> People\
> - Marco\
> \
> Links\
> - GitHub repository\
> \
> Activity\
> - Recent edits\
> - Recent opens

The user should be able to search for the project and see the relevant
context without manually opening every application.

# 7. Core Concept: Objects

Where treats important pieces of digital information as objects.

-   Person

-   Project

-   File

-   Folder

-   Note

-   Task

-   Application

-   Website

-   Conversation

-   Calendar event

-   Device

-   Bookmark

-   Image

-   Video

-   Repository

-   Organization

Objects have properties and can be related to other objects.

# 8. Relationship Graph

Relationships are central to the product. Where should understand not
only individual items, but how they relate.

> Project\
> ├── contains → Files\
> ├── contains → Tasks\
> ├── contains → Notes\
> ├── involves → People\
> └── references → Links\
> \
> Task\
> ├── belongs to → Project\
> └── references → File\
> \
> Note\
> └── references → Project / File / Person

This relationship model allows search results to become useful context
rather than a flat list of filenames.

# 9. Universal Search

Search is the primary interaction.

On desktop, the user can open Where with a global keyboard shortcut such
as Ctrl + Space. The exact shortcut should be configurable and
platform-aware.

> Search Where\...\
> \
> website authentication\
> \
> PROJECT\
> Website\
> \
> TASK\
> Fix Firebase authentication\
> \
> FILE\
> auth.dart\
> \
> NOTE\
> Website authentication notes\
> \
> LINK\
> GitHub repository

Search should support both conventional keywords and, later,
natural-language queries.

# 10. Natural-Language Search

Eventually users should be able to write requests such as:

-   Show me the proposal I worked on last week.

-   What was I working on yesterday?

-   Find the notes about the website.

-   Show tasks related to the cybersecurity project.

Natural-language understanding should be an optional layer over the
underlying structured object and search system. Basic search must not
depend on an AI service.

# 11. Universal Actions

The search interface should eventually also act as a command interface.

-   Create a task

-   Create a note

-   Open a project

-   Find files

-   Open a repository

-   Copy a project link

Destructive operations should require explicit confirmation.

# 12. Activity Timeline

Where may optionally maintain a local activity timeline to help users
remember what they were doing.

> TODAY\
> \
> 18:04\
> Opened website repository\
> \
> 17:51\
> Edited login.dart\
> \
> 17:20\
> Downloaded security report\
> \
> 16:43\
> Created \"Fix authentication\" task

Privacy controls are essential. Users should be able to disable activity
tracking, exclude applications or folders, pause tracking, delete
activity, and choose retention periods.

The initial product should not require screenshot capture. Activity can
begin with application, file, and Where-level events.

# 13. File Indexing

Where should not attempt to replace the operating system\'s file
manager. Instead, it should index user-selected locations.

-   Path

-   Filename

-   Extension

-   Size

-   Created date

-   Modified date

-   Hash

-   MIME type

-   Relationships

-   Tags

Indexing should be opt-in and transparent.

# 14. Notes

Notes are first-class objects that can reference projects, files, tasks,
people, websites, and other notes.

> NOTE\
> Website Redesign\
> \
> Related project:\
> Website\
> \
> Related files:\
> homepage.png\
> logo.svg\
> \
> Related tasks:\
> Fix mobile navigation\
> Update footer

# 15. Tasks

Tasks should carry context rather than existing as isolated checklist
entries.

> TASK\
> Fix Firebase authentication\
> \
> Status:\
> In Progress\
> \
> Project:\
> Website\
> \
> Assigned:\
> User\
> \
> Related file:\
> auth.dart

# 16. Projects

Projects provide a useful way to collect related objects.

-   Files

-   Tasks

-   Notes

-   People

-   Links

-   Activity

-   Applications

Projects should automatically surface related information rather than
requiring the user to manually maintain every relationship.

# 17. People

People objects may connect information from approved integrations.

-   Name

-   Organization

-   Email

-   Projects

-   Tasks

-   Notes

-   Files

-   Conversations

-   Links

No private service should be accessed without explicit user
authorization.

# 18. Integrations

Potential integrations include:

-   GitHub

-   Google Drive

-   OneDrive

-   Dropbox

-   Discord

-   Slack

-   Microsoft Teams

-   Google Calendar

-   Outlook

-   Notion

-   Jira

-   Linear

-   Trello

-   GitLab

Integrations should be optional and permission-controlled.

# 19. Plugin System

A future plugin system should let developers extend Where without giving
plugins unrestricted access to the user\'s machine.

> Where\
> ├── Plugin API\
> ├── Permission Manager\
> ├── Plugin Registry\
> └── Plugin Runtime

Every plugin should declare the capabilities it requests.

# 20. Offline Architecture

The local database should remain the primary source for local
information.

> Where Client\
> \|\
> Application Layer\
> \|\
> Domain Services\
> \|\
> +\-\-\-\-\-\-\-\-\-\--+\-\-\-\-\-\-\-\-\-\--+\
> \| \| \|\
> Search Objects Sync\
> \| \| \|\
> +\-\-\-\-\-\-\-\-\-\--+\-\-\-\-\-\-\-\-\-\--+\
> \|\
> SQLite\
> \|\
> Local Disk

Internet connectivity should improve synchronization and integrations,
not determine whether the basic application works.

# 21. Recommended Technology Stack

  -----------------------------------------------------------------------
  Layer                   Technology              Purpose
  ----------------------- ----------------------- -----------------------
  Main UI                 Flutter / Dart          Cross-platform
                                                  application interface

  Native/system core      Rust                    Filesystem, indexing,
                                                  security-sensitive and
                                                  system-level
                                                  functionality

  Local database          SQLite                  Offline-first local
                                                  storage

  Local search            SQLite FTS5             Fast keyword and
                                                  full-text search

  Cloud API               Rust + Axum             Authentication,
                                                  synchronization and
                                                  service APIs

  Cloud database          PostgreSQL              Account and
                                                  synchronization
                                                  metadata

  Object storage          S3-compatible           Optional cloud
                                                  files/backups

  Authentication          OIDC / OAuth 2          Account and identity
                                                  integrations

  API specification       OpenAPI                 Documented service
                                                  contracts

  Security baseline       OWASP ASVS              Security requirements
                                                  and verification

  CI/CD                   GitHub Actions          Automated builds and
                                                  tests

  Containers              Docker                  Development and
                                                  deployment consistency
  -----------------------------------------------------------------------

# 22. Why Flutter + Rust + SQLite

## Flutter

Flutter provides one primary UI technology that can target Android, iOS,
Windows, macOS, Linux, and web. This fits the cross-platform goal while
avoiding six separate UI implementations.

## Rust

Rust is appropriate for filesystem indexing, hashing, background
processing, native operating-system integration, synchronization logic,
and security-sensitive functionality.

## SQLite

SQLite is embedded, serverless, zero-configuration, transactional,
mature, and cross-platform. It fits the local-first architecture
particularly well.

These choices should be validated with a small prototype before
committing to the full product.

# 23. Suggested Repository Structure

> where/\
> ├── apps/\
> │ ├── where_flutter/\
> │ └── where_web/\
> ├── crates/\
> │ ├── where_core/\
> │ ├── where_search/\
> │ ├── where_storage/\
> │ ├── where_sync/\
> │ ├── where_security/\
> │ ├── where_indexer/\
> │ └── where_plugins/\
> ├── server/\
> │ ├── api/\
> │ ├── auth/\
> │ ├── sync/\
> │ └── storage/\
> ├── plugins/\
> │ ├── github/\
> │ ├── calendar/\
> │ └── example/\
> ├── docs/\
> ├── tests/\
> └── infrastructure/

# 24. Local Search

The MVP should use SQLite full-text search for filenames, notes, tasks,
project names, and indexed metadata.

Later, search can become hybrid:

> Keyword search\
> +\
> Metadata filters\
> +\
> Relationship graph\
> +\
> Optional semantic search

This keeps the core useful without requiring cloud AI.

# 25. AI and Automation

AI should not define the product. It should be an optional capability
that helps interpret requests, summarize relationships, and improve
search.

Where should support a provider abstraction so users or organizations
can choose whether AI runs locally or through an approved cloud
provider.

The system should send only the minimum relevant context required for a
request.

The first MVP should contain no mandatory AI dependency.

# 26. Security Model

Security should be built into the architecture rather than added after
the application works.

-   Least privilege

-   Explicit permissions

-   Encrypted transport

-   Secure credential storage

-   Plugin restrictions

-   Signed updates

-   Signed plugins when the ecosystem matures

-   Audit logging for sensitive actions

-   Secure defaults

-   Minimal telemetry

OWASP ASVS can provide a structured baseline for the web/API security
model. Desktop-specific security requirements should also be considered
for the native client.

# 27. Privacy Dashboard

> PRIVACY\
> \
> Indexed files: 4,238\
> Notes: 182\
> Activity records: 3,102\
> \
> Cloud sync: ON\
> Cloud AI: OFF\
> Local AI: OFF\
> Activity tracking: ON\
> Browser tracking: OFF\
> Screen capture: OFF

The exact statistics will depend on the user\'s configuration. The
important principle is that the user can see what Where knows and
control it.

# 28. Data Export

Users should be able to export their information.

-   JSON

-   Markdown

-   CSV

-   SQLite database

-   ZIP archive

Exports should preserve object relationships whenever possible.

# 29. MVP Scope

The first version should be deliberately small.

-   Flutter desktop application

-   Rust core

-   SQLite database

-   User-selected folder indexing

-   Universal local search

-   Notes

-   Tasks

-   Projects

-   Object relationships

-   Command palette

-   Keyboard navigation

-   Dark and light themes

-   Local-only operation

-   Data export

No cloud account should be required for the first usable version.

# 30. MVP User Interface

> WHERE\
> \
> What are you looking for?\
> \
> \[ Search everything\... \]\
> \
> Recent\
> - Website project\
> - Security report\
> - Fix authentication\
> \
> Projects\
> Tasks\
> Notes\
> Files\
> People\
> \
> Settings

The interface should be clean and restrained. Avoid excessive gradients,
neon effects, unnecessary animations, and decorative UI that does not
help users accomplish something.

# 31. User Experience Goal

The defining moment should be extremely simple.

A user thinks: \"Where did I put that?\"

They open Where, type what they remember, and get the relevant
information.

The product succeeds when the user does not have to remember the exact
application or folder where something was stored.

# 32. Development Roadmap

## Phase 0 --- Research and Validation

2--4 weeks

-   Competitor analysis

-   User interviews

-   Data model validation

-   Prototype

-   Security model

-   Technical feasibility testing

## Phase 1 --- Foundation

4--8 weeks

-   Flutter shell

-   Rust core

-   SQLite

-   Object model

-   Navigation

-   Settings

-   Logging

-   Automated tests

## Phase 2 --- MVP

8--12 weeks

-   Search

-   Notes

-   Tasks

-   Projects

-   File indexing

-   Relationships

-   Command palette

## Phase 3 --- Synchronization

6--10 weeks

-   Authentication

-   Encrypted synchronization

-   Device management

-   Conflict handling

-   Backups

## Phase 4 --- Integrations

-   GitHub

-   Google Drive

-   Calendar

-   Discord

-   Microsoft services

## Phase 5 --- Advanced Search

-   Natural-language search

-   Optional semantic search

-   Relationship-aware results

-   Context summaries

## Phase 6 --- Plugin Platform

-   Plugin SDK

-   Permission system

-   Plugin registry

-   Signing

-   Sandboxing

-   Developer documentation

## Phase 7 --- Collaboration

-   Shared projects

-   Shared objects

-   Comments

-   Permissions

-   Team workspaces

# 33. Competitive Landscape

The idea exists in a broader market and should not be presented as if no
related products exist.

## Notion

Notion provides an all-in-one workspace combining notes, projects,
knowledge management, and AI.

Where\'s intended distinction: Where is designed as a layer across the
user\'s broader digital environment rather than requiring the user\'s
information to primarily live inside Where.

## Raycast

Raycast demonstrates the usefulness of keyboard-driven launching,
searching, and extensions.

Where\'s intended distinction: the command interface is connected to a
persistent object and relationship model.

## Capacities

Capacities demonstrates object-based information organization and
linking.

Where\'s intended distinction: Where extends the object concept toward
operating-system files, applications, activity, and external services.

## Anytype

Anytype demonstrates local-first and interconnected information
management.

Where\'s intended distinction: Where combines this approach with
system-wide search, actions, and external integrations.

## Windows Recall

Microsoft Recall demonstrates a model for retrieving previous PC
activity.

Where\'s intended distinction: Where is intended to be cross-platform
and should not depend on screenshot capture as its fundamental data
model.

# 34. Business Model

## Free

-   Local application

-   Local database

-   Basic search

-   Notes

-   Tasks

-   Projects

-   Basic indexing

## Personal

-   Cloud synchronization

-   Backups

-   Advanced search

-   Optional AI features

## Pro

-   Advanced integrations

-   Automation

-   More storage

-   Developer features

## Team

-   Shared workspaces

-   Permissions

-   Administration

-   Audit logs

Pricing should be determined after user research and operating-cost
analysis.

# 35. Success Metrics

-   Daily active users

-   Weekly active users

-   Searches per user

-   Successful searches

-   Objects created

-   Objects connected

-   Time to first useful result

-   Retention

-   Crash rate

-   Synchronization failures

## Primary product metric

Search success rate: how often users find what they were looking for.

# 36. Major Risks

## Scope

The largest risk is trying to build an operating system, search engine,
cloud platform, AI assistant, plugin marketplace, and collaboration
suite at the same time.

## Privacy

System-wide indexing can expose sensitive information if poorly
designed. Indexing must be transparent, configurable, and conservative.

## Cross-platform differences

Operating systems expose different APIs and permissions. The
architecture should separate shared application logic from OS-specific
functionality.

## Synchronization complexity

Multi-device synchronization can become a distributed-systems problem.
It should be introduced only after the local product is stable.

## AI dependency

The product should remain useful if AI is unavailable, disabled, too
expensive, or undesirable for privacy reasons.

# 37. Platform Strategy

Build the first production-quality version for desktop while keeping the
architecture cross-platform.

-   Alpha: Windows

-   Next: macOS and Linux

-   Then: Android and iOS

-   Later: web companion

Flutter allows the shared UI architecture to begin cross-platform even
if system-level features are initially implemented on one desktop
platform.

# 38. First Technical Prototype

The first prototype should prove five things:

1.  Can Where index a user-selected folder?

2.  Can it store objects locally?

3.  Can it search those objects quickly?

4.  Can objects be connected?

5.  Can the results be displayed clearly and quickly?

If these five things work well, the core product concept has been
technically validated.

# 39. Example Prototype

> Create project:\
> Cybersecurity Lab\
> \
> Add:\
> Task --- Build network monitor\
> Note --- Monitoring dashboard ideas\
> File --- network-design.pdf\
> \
> Where creates relationships:\
> \
> Cybersecurity Lab\
> ├── Build network monitor\
> ├── Monitoring dashboard ideas\
> └── network-design.pdf\
> \
> Search:\
> network\
> \
> Results:\
> Cybersecurity Lab\
> Build network monitor\
> Monitoring dashboard ideas\
> network-design.pdf

# 40. Product Boundaries

Where should not initially become:

-   An antivirus

-   A password manager

-   A replacement operating system

-   A system that automatically deletes files

-   A system that automatically sends messages

-   A system that executes arbitrary commands without confirmation

-   A covert monitoring tool

-   A product that uploads private data by default

Keeping these boundaries clear will help the product remain
understandable and trustworthy.

# 41. Final Product Definition

Where is a cross-platform, local-first digital workspace that connects a
user\'s files, notes, tasks, projects, people, applications, activity,
and approved external services into a searchable relationship system.

It is designed to work offline, respect user ownership, minimize data
collection, connect existing tools, and provide one simple way to find
information.

The central experience is:

Do not remember where your digital life is. Ask Where.

# 42. Recommended First Milestone

WHERE ALPHA 0.1

-   Flutter desktop application

-   Rust core

-   SQLite

-   File indexing

-   Universal search

-   Notes

-   Tasks

-   Projects

-   Relationships

-   Command palette

-   Dark/light themes

-   Keyboard navigation

-   Local-only operation

-   Export

The first release should prove the core experience before adding
accounts, cloud synchronization, AI, or a plugin marketplace.

# 43. Research Basis

The product direction was informed by current documentation and products
relevant to cross-platform development, local-first storage, search,
object-based organization, extensions, activity retrieval, plugin
architecture, and application security.

-   Flutter platform documentation: supported deployment targets and
    platform architecture.

-   SQLite documentation: embedded, serverless, zero-configuration
    database architecture.

-   Raycast documentation: launcher and extension model.

-   Capacities documentation: object-based information organization.

-   Anytype documentation and repository: local-first and interconnected
    information architecture.

-   Microsoft Recall documentation: activity retrieval and user
    controls.

-   WebAssembly Component Model documentation: potential future
    component/plugin architecture.

-   OWASP ASVS: application security verification guidance.

Research should be repeated before launch for current competitors,
pricing, licensing, trademark availability, security requirements, and
platform policies.

# 44. Naming and Legal Check Before Launch

The name Where is a product concept, not a completed trademark
clearance.

Before committing to the name, check:

-   USPTO trademark database

-   State and international trademark conflicts where relevant

-   Major app stores

-   GitHub

-   Package registries

-   Domain availability

-   Social handles

-   Existing software products using the same name

The final brand should only be selected after this check.

# 45. Bottom Line

Where should be built around one ordinary question:

\"Where is it?\"

Everything else supports that question.

Files are indexed so they can be found.

Notes are connected so their context can be found.

Tasks are connected so their projects can be found.

Projects are connected so their files and people can be found.

Integrations bring approved external information into the same search
experience.

The result is not another application that asks the user to move their
entire digital life into it. The goal is a layer that helps the user
find and understand the digital life they already have.

# 46. Reference Links

Flutter supported platforms:
https://docs.flutter.dev/reference/supported-platforms

SQLite: https://sqlite.org/about.html

Raycast Extensions: https://manual.raycast.com/extensions

Capacities content types:
https://docs.capacities.io/reference/content-types

Anytype documentation repository: https://github.com/anyproto/docs

Microsoft Recall:
https://support.microsoft.com/en-US/Windows/Ai/Ai-Features/retrace-your-steps-with-recall

WebAssembly Component Model:
https://component-model.bytecodealliance.org/

OWASP ASVS:
https://owasp.github.io/www-project-application-security-verification-standard/
