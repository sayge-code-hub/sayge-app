import 'package:flutter_web_plugins/url_strategy.dart';

/// Use path URLs (`/set-password`) so Supabase auth hash fragments
/// (`#access_token=…`, `#sb…`) are not treated as go_router locations.
void configureAppUrlStrategy() {
  usePathUrlStrategy();
}
