# SuperSettings

[![Continuous Integration](https://github.com/bdurand/super_settings/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/super_settings/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

This gem provides a mechanism for application runtime settings. Settings are stored in a database using ActiveRecord, but cached locally in memory for quick, efficient access.

The motivation behind this is that an application tends to accumulate a lot of settings over time. A lot of these may end up in environment variables or hard coded in YAML files or sprinkled through various models as additional columns. All of these methods of configuration have their place and are completely appropriate for various purposes. However, this can lead to issues if you need to change a value quickly in production:

* If you need to change a value in an environment variable, then you will need to restart processes to get the new value loaded. This can be disruptive and take a bit of time to properly roll the application. You'll also need to handle data formatting and validation in your code since you can only store strings.

* If you need to change a value hard coded in a YAML file, then you'll need to redeploy your application with an updated file.

* If you store application settings in your models, you may need to provide a caching scheme around them so that you don't slam your database with thousands of queries for values that change very infrequently.

This gem provides an out of the box web UI as well as a REST API for administering settings. You can specify data types for your settings (string, integer, float, boolean, datetime, or array) and be assured that values will be valid. You can also supply documentation for each setting so that it's obvious what each one does and how it is used.

There is also a thread safe caching mechanism that provides in memory performance while significantly limiting database load. You can tune how frequently the cache is refreshed and each refresh call is tuned to be highly efficient.

SuperSettings can be used on its own, or as a part of a larger configuration strategy for your application.

## Usage

### Getting Values

This gem is in essence a key/value store. Settings are identified by unique keys and contain a typed value. You can access setting values using methods on the `SuperSettings` object.

```ruby
TODO
```

There is also a method to get multiple settings at once structured as a Hash.

```ruby
TODO
```

When you request a setting, you can also specify a default value to use if the setting does not have a value.

```ruby
TODO
```

When you read a setting using these methods, you are actually reading from an in memory cache. All of the settings are read into this local cache and the cache is checked periodically so see if it needs to be refreshed (defaults to every five seconds, but this can be customized by setting `SuperSettings.refresh_interval`). When the cache does need to be refreshed, only updated records are re-read from the database and only by a single thread. Thus, you don't have to worry about overloading your database by reading settings values and the performance only has a slight overhead vs. reading values from a Hash.

### Data Model

TODO

### History

A history of all settings changes is kept every time the value is changed. You can use this information to see what values were in effect at what time. You can optionally alse record who made the changes.

### Usage Tracking

An optional feature you can turn on is to track when settings are used. This can be useful as a audit feature so you can cleanup old feature flags, etc. that are no longer in use. The timestamp of when a setting was last used will only be updated at most once per hour, so this adds very little overhead. However, it does require write access on the database connection.

### Secrets

You can specify that a setting is a secret by setting the value type to "secret". This will obscure the value in the UI (thoough it can still be seen when editing) as well as not record the values in the setting history. You can also specify an encryption secret that is used to encrypt these settings in the database.

It is highly recommended that if you store secrets in your settings that you enable this feature. The enryption secret can either be set by setting `SuperSettings.secret` or by setting the `SUPER_SETTINGS_SECRET` environment variable.

If you need to roll your secrets, you can set the value as an array (or as a space delmited list in the environment variable). The first secret will be the one used to encrypt values. However, all the secrets will be tried when decrypting values. This allows you to change the secret without raising decryption errors. If you do change your secret, you can run this rake task to re-encrypt all values using the new secret:

```bash
rake super_settings:encrypt_secrets
```

### Rails Engine

TODO

#### Web UI

TODO

#### REST API

TODO

#### Configuration

TODO

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'super_settings'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install super_settings
```

## Contributing

Open a pull request on GitHub.

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
