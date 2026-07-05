---
name: flutter
description: Flutter and Dart conventions for mobile app development. Use when writing or modifying Flutter widgets, Dart code, pubspec.yaml, or building iOS/Android apps with Flutter.
user-invocable: false
---

When working on Flutter apps, follow these conventions.

**Widgets and layout**
- Small, composable widgets: extract when a build method grows past ~40 lines. Composition over inheritance.
- `const` constructors wherever possible; keys where list items can reorder.
- Material 3 with one central `ThemeData` — no hardcoded colors or text styles inside widgets; read from `Theme.of(context)`.
- `build()` stays pure and fast: no I/O, no heavy computation, no side effects inside it.

**State management**
- Pick ONE approach per project (Riverpod or Bloc are the safe defaults) and stay consistent. `setState` only for trivial local UI state.
- Immutable state objects; business logic lives outside widgets.

**Navigation and structure**
- go_router with typed routes.
- Feature-first folders (`feature/{data,domain,presentation}`) rather than type-first for anything non-trivial.

**Async and data**
- Every async view has explicit loading, empty, and error states — never just the happy path.
- JSON models via code generation (freezed / json_serializable) instead of hand-written `fromJson` for models with many fields.
- Dispose controllers, streams, and subscriptions in StatefulWidgets; no leaks.

**Quality**
- Enable very_good_analysis or flutter_lints; zero analyzer warnings policy.
- Widget tests for interactive components, golden tests for critical screens. Run `flutter analyze && flutter test` before declaring work done.
- Respect platform behavior on both OSes: SafeArea, back gestures, keyboard insets; verify on the smallest supported screen size.
