# Mobile architecture

This is an independent Flutter application. Run Flutter commands from this directory.
The workspace migration plan is `../ARCHITECTURE_MIGRATION.md`.

## Ownership and flow

`app/` owns startup and the root widget. `routes/` owns this app's routes.
`core/` owns configuration, errors, networking, storage, theme, icons and controls.
`data/` holds only cross-feature contracts. Feature-specific models, repository
interfaces, implementations, providers, viewmodels, views and widgets belong in
`features/<feature>/`. CRM's existing `roles/` and `shared/` remain supported.

Views watch providers and send intents to viewmodels. Viewmodels own validation,
state and orchestration; repositories coordinate services; services own HTTP and
storage. Do not call Dio or write credentials from a screen.

## Riverpod patterns

* `Provider`: dependency injection for services and repositories.
* `FutureProvider`: cached, read-only resources such as dashboard metadata.
* `StreamProvider`: external event subscriptions (`sessionEventsProvider` in new apps).
* `NotifierProvider`: synchronous immutable UI state such as dashboard search.
* `AsyncNotifierProvider`: asynchronous commands and paginated resources.

Use `AsyncValue.when` for loading/error/data. Empty collections are successful
empty states. Prefer feature-scoped auto-disposed providers for screen resources.
Use `ref.onDispose` for subscriptions, CancelTokens, Dio and controllers; watch a
provider instead of starting requests inside `build()`.

Subclass `core/utils/paginated_viewmodel.dart` inside a feature; implement
`fetchPage(cursor, cancelToken)` by delegating to its repository, and expose it
with `AsyncNotifierProvider.autoDispose`. `loadMore` deduplicates requests, keeps
existing results on failure and exposes a retryable `moreError`. `refresh` cancels
old requests and ignores stale completions. The first page uses AsyncValue for
loading/error/empty handling. The caller must supply stable server cursors.

Small immutable models use explicit JSON validation. Introduce Freezed and
json_serializable for more complex contracts when useful, with generated files
committed and generators pinned compatibly; they are not required for the small
session/catalog contracts in this setup.

## Design system

Use `core/theme/app_colors.dart`, `AppTypography`, bundled Inter 400/500/600/700,
and `core/icons/remix_icon.dart`. The font license is under `assets/fonts/OFL.txt`.
Typography works offline. Import controls from `core/widgets/app_<name>.dart`;
implementations live in `app_widgets.dart` so they cannot drift within the app.
Legacy CRM widgets stay in place to preserve existing constructor behavior.

Use RemixIcon/AppIcon for new UI and explicit labels for icon-only controls.
LegacyRemixIcons maps existing glyph names to Remix constants. Use LayoutBuilder,
SafeArea and scrollable forms; do not fix card heights around user text. Dashboard
layout is tested at 320px and 1024px width with 2x text scale.

## Configuration and validation

```
flutter pub get
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=https://your-api.example/api/v1
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

APP_ENV accepts development, staging and production. API_BASE_URL must be an
absolute HTTP(S) URL without credentials, query or fragment. Staging, production
and all release builds require HTTPS. Do not embed API keys or secrets in Dart
defines. Each app has its own lockfile and native bundle identifiers.

Android release manifests include INTERNET. New apps disable automatic backups;
iOS uses per-app keychain entitlements. OS domain app/universal links require a
real owned domain and association files; GoRouter already resolves internal paths.
Native release signing and device-level authentication/keychain verification are
separate from debug/simulator build validation.

## Current implementation

Customer and Production use independent GoRouter configurations. Session loading
gates protected pages. Login redirects retain the requested local deep link;
logout and protected-request 401 responses clear the secure session. There is no
silent token refresh yet: expired sessions require sign-in. Tokens are never
stored in SharedPreferences by the new apps. Preferences are injected at bootstrap.
Dio uses timeouts, token interception and metadata-only debug logging.

The login service follows CRM's existing wrapped/unwrapped mobile login response.
Business feature destinations are clearly marked as unconnected; the catalog is
navigation metadata, not mock business data. Integrate real feature repositories
incrementally against confirmed APIs; do not invent endpoints or return fake
success for unavailable features. API_BASE_URL is intentionally required before
network use; launching the app without it still shows the sign-in screen.
