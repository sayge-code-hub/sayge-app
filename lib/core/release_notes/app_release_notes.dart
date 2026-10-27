/// Curated release notes shown from the version easter egg.
///
/// Versioning: three-part semver (`MAJOR.MINOR.PATCH`). Each production
/// Netlify deploy auto-bumps the **patch** in CI before build.
class AppReleaseNote {
  const AppReleaseNote({
    required this.version,
    required this.releasedAt,
    required this.title,
    required this.highlights,
  });

  /// Semver without the `v` prefix, e.g. `1.0.20`.
  final String version;

  final DateTime releasedAt;
  final String title;
  final List<String> highlights;

  String get label => 'v$version';
}

/// Newest first. Keep in sync when shipping notable deploys.
abstract final class AppReleaseNotes {
  static const currentVersionHint = '1.0.22';

  static final List<AppReleaseNote> all = [
    AppReleaseNote(
      version: '1.0.22',
      releasedAt: DateTime.utc(2026, 10, 27, 6, 15),
      title: 'Any email domain',
      highlights: [
        'Login and invites accept any email domain (not only @sayge.in)',
        'Invite-only signup is unchanged',
      ],
    ),
    AppReleaseNote(
      version: '1.0.21',
      releasedAt: DateTime.utc(2026, 10, 25, 8, 45),
      title: 'Checkout tender & guest menu fix',
      highlights: [
        'Pay sheet shows only UPI/Card and Cash',
        'Guest QR menu no longer crashes on load (splash prefs)',
      ],
    ),
    AppReleaseNote(
      version: '1.0.20',
      releasedAt: DateTime.utc(2026, 10, 25, 8, 15),
      title: 'Guest Detailed View & POS polish',
      highlights: [
        'Guest QR menu uses Detailed View only — search, cart, category dropdown, item detail with add-ons & instructions',
        'Guest brand settings simplified: cafe name + logo (accent, tagline, and layout picker removed)',
        'Branded loading splash with cafe logo and name',
        'Smaller cafe list cards with logo, started date, tables, and status',
        'Tighter POS hub tiles with short subtitles',
        'Release notes screen — tap the version label to open',
      ],
    ),
    AppReleaseNote(
      version: '1.0.19',
      releasedAt: DateTime.utc(2026, 10, 25, 5, 32),
      title: 'Guest menu branding',
      highlights: [
        'Fresh / Gallery guest layouts with brand accent and logo',
        'Guest brand RPC fixes for QR menu look',
      ],
    ),
    AppReleaseNote(
      version: '1.0.18',
      releasedAt: DateTime.utc(2026, 10, 24, 15, 22),
      title: 'POS polish',
      highlights: [
        'Guest category filter improvements',
        'General Cafe POS UI polish',
      ],
    ),
    AppReleaseNote(
      version: '1.0.17',
      releasedAt: DateTime.utc(2026, 10, 24, 15, 6),
      title: 'Configurable guest QR look',
      highlights: [
        'Cafe owners can configure how the guest QR menu looks',
      ],
    ),
    AppReleaseNote(
      version: '1.0.16',
      releasedAt: DateTime.utc(2026, 10, 24, 14, 54),
      title: 'Kitchen & floor',
      highlights: [
        'POS UI cleanup and kitchen fixes',
        'Floor / table settings for dine-in',
      ],
    ),
    AppReleaseNote(
      version: '1.0.15',
      releasedAt: DateTime.utc(2026, 10, 24, 10, 37),
      title: 'Guest QR ordering',
      highlights: [
        'Public guest QR menu and order placement',
        'Terminal polish for cafe staff',
      ],
    ),
  ];

  static AppReleaseNote? find(String version) {
    final v = version.trim().replaceFirst(RegExp(r'^v'), '');
    for (final note in all) {
      if (note.version == v) return note;
    }
    return null;
  }
}
