# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
