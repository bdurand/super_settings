# SuperSettings Architecture

SuperSettings is a Ruby gem for managing dynamic application settings at runtime. Settings are persisted in a storage backend and cached in memory for fast, low-latency reads.

---

## High-Level Overview

```mermaid
graph TD
    App["Application Code"] -->|"SuperSettings.get(key)"| Cache["Local Cache"]
    Cache -->|"cache miss / refresh"| Model["Setting Model"]
    Model -->|"read/write"| Storage["Storage Backend"]

    Admin["Admin User"] -->|"HTTP"| WebUI["Web UI"]
    WebUI -->|"REST calls"| API["REST API"]
    API -->|"bulk_update"| Model
```

---

## Core Components

```mermaid
graph LR
    subgraph Core
        SM["SuperSettings module\n(global accessors)"]
        LC["LocalCache\n(in-memory, thread-safe)"]
        Setting["Setting\n(model + validation)"]
        Coerce["Coerce\n(type conversion)"]
    end

    SM --> LC
    LC --> Setting
    Setting --> Coerce
```

| Component | Responsibility |
|---|---|
| `SuperSettings` | Public API — `get`, `integer`, `float`, `enabled?`, `datetime`, `array`, `rand` |
| `LocalCache` | Thread-safe in-memory cache with periodic delta refresh |
| `Setting` | Typed setting model with validation, change tracking, and bulk update |
| `Coerce` | Type coercion for string, integer, float, boolean, datetime, array |

---

## Setting Value Types

```mermaid
graph LR
    Types["Value Types"] --> S["string"]
    Types --> I["integer"]
    Types --> F["float"]
    Types --> B["boolean"]
    Types --> D["datetime"]
    Types --> A["array"]
```

---

## Storage Layer

Storage backends implement a common interface. The active backend is selected at configuration time.

```mermaid
graph TD
    Setting["Setting Model"] --> StorageInterface["Storage Interface"]
    StorageInterface --> AR["ActiveRecordStorage\n(SQL database)"]
    StorageInterface --> Redis["RedisStorage\n(Redis)"]
    StorageInterface --> HTTP["HttpStorage\n(remote REST API)"]
    StorageInterface --> S3["S3Storage\n(AWS S3 JSON file)"]
    StorageInterface --> Mongo["MongoDBStorage\n(MongoDB)"]
    StorageInterface --> JSON["JSONStorage\n(JSON file, abstract base)"]
    StorageInterface --> Null["NullStorage\n(no-op, for CI)"]
    StorageInterface --> Test["TestStorage\n(in-memory, for tests)"]
```

### Storage Interface

Each backend implements:
- `all` / `active` / `updated_since(time)` — bulk reads
- `find_by_key(key)` — single lookup
- `last_updated_at` — used for delta refresh
- `save!` — persist a setting
- `create_history` — record a change event
- `load_asynchronous?` — whether initial load can be deferred to a background thread

---

## Caching and Refresh

```mermaid
sequenceDiagram
    participant App
    participant LC as LocalCache
    participant DB as Storage Backend

    App->>LC: get(key)
    alt cache cold
        LC->>DB: active() — load all settings
        DB-->>LC: settings[]
        LC-->>App: value
    else cache warm, interval elapsed
        LC->>DB: last_updated_at()
        alt data changed
            LC->>DB: updated_since(last_refresh)
            DB-->>LC: changed settings[]
            LC->>LC: merge into frozen cache
        end
        LC-->>App: value
    else cache warm, interval not elapsed
        LC-->>App: value (from cache)
    end
```

Key properties:
- Default refresh interval: **5 seconds**
- `last_updated_at` is itself cached (60s TTL) to reduce storage queries
- Refresh is delta-based — only changed settings are reloaded
- The cache is an **immutable frozen hash** replaced atomically on each refresh
- Initial load can be **asynchronous** (background thread) for some backends

---

## Request Context

Within a request or job, settings are snapshotted so the same key always returns the same value and random numbers are seeded for consistent probabilistic feature flags.

```mermaid
sequenceDiagram
    participant MW as Context Middleware
    participant App as Request Handler
    participant SS as SuperSettings

    MW->>SS: context { ... }
    SS->>SS: snapshot current settings
    SS->>App: yield
    App->>SS: get(key) — returns snapshot value
    App->>SS: rand(key) — seeded RNG
    SS-->>App: consistent values
    SS->>SS: clear snapshot
```

Context is propagated via a thread-local variable and is supported in:
- Rack requests — `Context::RackMiddleware`
- Sidekiq jobs — `Context::SidekiqMiddleware`
- ActiveJob — injected by the Rails Engine

---

## Web Interface and REST API

```mermaid
graph TD
    Browser["Browser / API Client"] -->|HTTP| RackApp["RackApplication\n(routing + auth)"]
    RackApp -->|reads/writes| RestAPI["RestAPI\n(endpoint logic)"]
    RestAPI --> Setting["Setting Model"]

    RackApp -->|renders HTML| Application["Application\n(Web UI / ERB templates)"]
    Application -->|JS calls| RestAPI
```

### REST Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/` | List all active settings |
| GET | `/setting` | Fetch a single setting by key |
| POST | `/settings` | Bulk update settings (atomic) |
| GET | `/history` | Change history for a setting |
| GET | `/settings/last_updated_at` | Timestamp of most recent change |
| GET | `/settings/updated_since` | Settings changed after a given time |

### Authentication

`RackApplication` exposes hooks to integrate with any auth system:
- `authenticated?` — gate all access
- `allow_read?` / `allow_write?` — fine-grained access control

---

## Rails Integration

```mermaid
graph TD
    Engine["SuperSettings::Engine\n(Rails::Engine)"] -->|mounts| Routes["Routes\n(/settings)"]
    Engine -->|inserts| RackMW["Context::RackMiddleware"]
    Engine -->|hooks| ActiveJob["ActiveJob context"]
    Engine -->|hooks| Sidekiq["Sidekiq context\n(if present)"]
    Engine -->|creates| Controller["Dynamic Controller\n(configurable superclass)"]
    Controller --> RackApp["RackApplication"]
```

The engine auto-configures when mounted:
- Inserts context middleware into the Rack stack
- Wraps ActiveJob and Sidekiq execution in a settings context
- Provides a controller with configurable authentication and layout
- Triggers settings load after `Rails.application` initializes

---

## Audit History

Every setting change is recorded as a history entry.

```mermaid
graph LR
    Update["Setting#save!"] -->|creates| History["HistoryItem\n(key, value, changed_by, created_at)"]
    RestAPI -->|"history(key)"| History
```

---

## Component Dependency Summary

```mermaid
graph TD
    SuperSettings --> LocalCache
    SuperSettings --> Context
    LocalCache --> Setting
    Setting --> Storage
    Setting --> Coerce
    Setting --> HistoryItem
    RackApplication --> RestAPI
    RackApplication --> Application
    RestAPI --> Setting
    Engine --> RackApplication
    Engine --> Context
    HttpStorage --> HttpClient
    S3Storage --> JSONStorage
    S3Storage --> HttpClient
```
