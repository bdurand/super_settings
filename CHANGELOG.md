# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0 - unreleased

### Added

- Added controls for sorting settings in the web UI by keys or last modified time.
- Isolated of CSS classes in the web UI to prevent conflicts with other CSS libraries.
- Dark mode support in web UI.
- Added ability to embed the web UI in a view to allow tighter integration with your application's UI.
- Added storage adapter for storing settings in an S3 object.
- Added abstract storage adapter for storing settings in a JSON file.

### Fixed

- Changing a key now works as expected. Previously, a new setting was created with the new key and the old setting was left unchanged. Now, the old setting is properly marked as deleted.

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
