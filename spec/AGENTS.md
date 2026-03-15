## Testing

Avoid using double and instance_double in favor of using real instances of classes when possible.

Avoid building stub classes to mock behavior of classes defined in the project for use in tests. Use the real classes instead to write integration tests rather than pure unit tests.
