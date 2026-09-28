import 'package:go_router/go_router.dart';
import '../screens/main_screen.dart';
import '../screens/create_card_screen.dart';
import '../screens/edit_card_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stops_screen.dart';
import '../screens/cards_screen.dart';
import '../screens/add_stop_screen.dart';

/// App router configuration
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/create',
      name: 'create',
      builder: (context, state) => const CreateCardScreen(),
    ),
    GoRoute(
      path: '/edit/:cardId',
      name: 'edit',
      builder: (context, state) {
        final cardId = state.pathParameters['cardId']!;
        return EditCardScreen(cardId: cardId);
      },
    ),
    GoRoute(
      path: '/cards',
      name: 'cards',
      builder: (context, state) => const CardsScreen(),
    ),
    GoRoute(
      path: '/stops',
      name: 'stops',
      builder: (context, state) => const StopsScreen(),
      routes: [
        GoRoute(
          path: 'add',
          name: 'addStop',
          builder: (context, state) => const AddStopScreen(),
        ),
      ],
    ),
    // Same screen as adding a stop: saving is one option among looking
    GoRoute(
      path: '/search',
      name: 'searchStops',
      builder: (context, state) => const AddStopScreen(explore: true),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
