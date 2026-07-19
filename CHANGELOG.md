# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.6.1

### Security

- Fixed a stored cross-site scripting (XSS) vulnerability where a setting key was interpolated into the history pagination links in the web UI without HTML escaping. A user with write access could craft a key that executed JavaScript in another user's browser.

### Fixed

- Fixed `Setting.save!` raising a `NoMethodError` in non-Rails applications that relied on the implicit ActiveRecord storage default. The transaction now resolves the storage class through the public accessor instead of the uninitialized instance variable.
- Fixed `LocalCache#to_h` returning only the first element of `array` type settings. It now returns the full array value.
- Fixed `Setting#save!` always updating the `updated_at` timestamp (and triggering a write) even when nothing had changed, which caused unnecessary cache invalidation across processes.
- Fixed a race condition in `LocalCache` where a value read on a cache miss could overwrite a fresher value written by a concurrent refresh.
- Fixed `LocalCache#refresh` never picking up newly added settings if the cache had been loaded while the data store was empty.
- Fixed `LocalCache` returning mutable array values for settings added by a cache refresh or a cache miss. All cached values are now frozen so callers cannot mutate the shared cache.
- Fixed the web UI history view failing to render when a history record has no timestamp.
- Fixed a duplicate-key race in `ActiveRecordStorage#save!` that raised an unhandled `ActiveRecord::RecordNotUnique` when the same key was created concurrently. The conflict is now retried and merged.
- Fixed a bulk update against `HttpStorage` silently reporting success when the remote API rejected the changes. `bulk_update` now returns `false` and `save!` raises a `SuperSettings::Setting::PersistenceError` in this case so storage failures can be distinguished from validation errors.
- Fixed thread-safety issues in the cached S3 and MongoDB clients that could expose a stale client or permanently cache a `nil` client after a transient connection failure.
- Fixed `MongoDBStorage.find_by_key` returning records that reported `persisted?` as `false`.
- Fixed the escaping of `SuperSettings.authentication_url` when injected into the inline web UI JavaScript. URLs containing single quotes previously produced corrupted or invalid JavaScript.
- Fixed the Rack application returning 404 for all routes when mounted under a path (e.g. via `map` or Rails `mount`) without repeating the mount path in the constructor.
- Fixed `HttpClient` corrupting base URLs that include a query string when appending the trailing path separator.
- Fixed `HttpClient` retrying non-idempotent POST requests after a connection error, which could apply an update twice.
- Fixed the `/settings/updated_since` endpoint returning a 500 (or a misleading empty success) when the `time` parameter was missing or unparseable. It now returns a 400 Bad Request.
- Fixed the web UI POST endpoint returning a 500 for malformed JSON request bodies instead of a 400 Bad Request. The endpoint now also returns a 400 Bad Request when the `settings` parameter is missing or is not an array of hashes.
- Fixed an authenticated but unauthorized user being redirected to the login page (a potential redirect loop) instead of receiving a 403 Forbidden.
- Fixed the Rails layout helper using the raw dark mode selector instead of the resolved value, which could render a page with mismatched light/dark styling.
- Fixed `Coerce.boolean` returning `true` for a whitespace-only string.
- Fixed the Rails engine eagerly loading `ActiveJob::Base` during initialization.
- Added a missing `require "time"` so `Time.parse` based coercion works in non-Rails applications.

## 2.6.0

### Added

- Added `SuperSettings::Application#dark_mode_selector` configuration option that allows you to specify a CSS selector that sets dark mode when it matches an element in the page. This is an alternative to using the `color_scheme` option and allows for more flexible control of when dark mode is enabled.

## 2.5.0

### Added

- Updated web UI to match the web UI from the ultra_settings gem. UltraSettings now has a tighter integration with SuperSettings and can be setup to update SuperSettings settings directly from its web UI.
- Added ability to authorize requests with read only permissions. When read only permissions are enabled, users can view settings in the web UI but cannot edit them. API requests that attempt to modify settings will be rejected with a 403 Forbidden response.
- Added internationalization (i18n) support for the web UI with translations for 29 languages. The locale is resolved from a `lang` query parameter, a `super_settings_locale` cookie, or the `Accept-Language` header.
- Added `/authorized` API endpoint that returns the current user's permission level (`read-only` or `read-write`).
- Added `/api.js` endpoint for serving the JavaScript API client separately.

### Fixed

- Fixed S3Storage `path=` setter which incorrectly produced a literal string containing `.chomp('/')` instead of calling the method, causing all S3 object key lookups to use a malformed path.
- Fixed `bulk_update` silently ignoring a request to delete a non-existent setting key. Previously it would raise an `InvalidRecordError` instead of treating the operation as a no-op.
- Fixed `RestAPI.last_updated_at` raising a `NoMethodError` when called with an empty settings store (no settings yet created).
- Fixed `HttpClient` ignoring the `user` and `password` constructor arguments. HTTP Basic auth credentials are now correctly applied to all requests.
- Fixed `HttpClient` producing a malformed query string (leading `&`) when the base URI includes query parameters but no per-request parameters are provided.
- Fixed `HttpStorage#reload` making two redundant HTTP requests and discarding the result of the first.

### Changed

- Minimum Ruby version is now 2.7.

## 2.4.3

### Fixed

- Model.availability? return false when the connection isn't established or there is no database.


## 2.4.2

### Fixed

- Model.availability? can return false when connection pool connection exists for active record storage


## 2.4.1

### Added

- Incoming links to the web UI now support specifying a description for the setting being edited by passing `description=description_text` in the URL hash. For example, `#edit=port&type=integer&description=Port%20number%20for%20the%20server` will open the setting with the key `port` for editing as an integer and pre-fill the description field.

## 2.4.0

### Added

- Incoming links to the web UI now support specifying the value type for the setting being edited by passing `type=value_type` in the URL hash. For example, `#edit=port&type=integer` will open the setting with the key `port` for editing as an integer.

### Changed

- Web UI significantly updated to be cleaner and more modern using responsive design instead of tables.

## 2.3.1

### Fixed

- Add check if database connection is valid for ActiveRecord storage engine to avoid race conditions where settings were not available until an application model was used.

## 2.3.0

### Changed

- Calling `SuperSettings.get` on a setting stored as an array now returns the array as a multiline string rather than simply calling `to_s` on the array. So an array setting stored as `["foo", "bar"]` will now be returned as `"foo\nbar"` rather than `'["foo", "bar"]'`.
- Calling `SuperSettings.get` on a setting stored as a datetime will now return the value as an ISO-8601 formatted string rather than simply calling `to_s` on the `Time` object.

## 2.2.1

### Added

- Added `SuperSettings::Setting#value_changed?` helper method to return true if the value of the setting has changed.

## 2.2.0

### Changed

- After save callbacks are now called only after the transaction is committed and settings have been persisted to the data store. When updating multiple records the callbacks will be called after all changes have been persisted rather than immediatly after calling `save!` on each record.

## 2.1.2

### Fixed

- Fixed ActiveRecord code ensure there are connections to the database before attempting to checkout a connection to avoid errors when the database is not available.

## 2.1.1

### Fixed

- Added check to ensure that ActiveRecord has a connection to the database to avoid error when settings are checked before the database is connected or when the database doesn't yet exist.

### Added

- Added `:null` storage engine that doesn't store settings at all. This is useful for testing or when the storage engine is no available in your continuous integration environment.

## 2.1.0

## Fixed

- More robust handling of history tracking when keys are deleted and then reused. Previously, the history was not fully recorded when a key was reused. Now the history on the old key is recorded as a delete and the history on the new key is recorded as being an update.

## Changed

- Times are now consistently encoded in UTC in ISO-8601 format with microseconds whenever they are serialized to JSON.

## 2.0.3

### Fixed

- Fixed ActiveRecord code handling changing a setting key to one that had previously been used. The previous code relied on a unique key constraint error to detect this condition, but Postgres does not handle this well since it invalidates the entire transaction. Now the code checks for the uniqueness of the key before attempting to save the setting.

## 2.0.2

### Fixed

- Coercing a string to a boolean is now case insensitive (i.e. "True" is interpreted as `true` and "False" is interpreted as `false`).

## 2.0.1

### Added

- Added support for targeting a editing a specific setting in the web UI by passing `#edit=key` in the URL hash.

## 2.0.0

### Added

- Added controls for sorting settings in the web UI by keys or last modified time.
- Isolated of CSS classes in the web UI to prevent conflicts with other CSS libraries.
- Dark mode support in web UI.
- Added ability to embed the web UI in a view to allow tighter integration with your application's UI.
- Added storage adapter for storing settings in an S3 object.
- Added storage adapter for storing settings in MongoDB.
- HTTP storage adapter now uses keep-alive connections to improve performance.

### Fixed

- Changing a key now works as expected. Previously, a new setting was created with the new key and the old setting was left unchanged. Now, the old setting is properly marked as deleted.
- Consistently handle converting floating point number to timestamps in Redis storage.

### Removed

- Rails 4.2, 5.0, and 5.1 support has been removed.
- Removed support for Ruby 2.5.

## 1.0.2

### Added

- Added SuperSetting.rand method that can return a consistent random number inside of a context block.

### Changed

- Lazy load non-required classes.

## 1.0.1

### Added
- Optimize object shapes for the Ruby interpreter by declaring instance variables in constructors.

## 1.0.0

### Added
- Everything!
