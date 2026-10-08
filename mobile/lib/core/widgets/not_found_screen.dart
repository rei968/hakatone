import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import 'screen_placeholder.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenPlaceholder(
        title: 'Такої сторінки немає',
        note: 'Посилання застаріло або містить помилку.',
        actions: [
          FilledButton(
            onPressed: () => context.go(AppRoutes.meta),
            child: const Text('На головну'),
          ),
        ],
      ),
    );
  }
}
