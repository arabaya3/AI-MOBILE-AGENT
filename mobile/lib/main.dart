import 'bootstrap.dart';
import 'core/config/app_config.dart';

/// Defaults to the dev environment; flavored builds use `main_<flavor>.dart`.
void main() => bootstrap(AppEnvironment.dev);
