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
