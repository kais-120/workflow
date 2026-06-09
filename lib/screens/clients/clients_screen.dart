// lib/screens/clients/clients_screen.dart
// Full implementation in Part 3
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ClientsScreen extends StatelessWidget {
  final bool standalone;
  const ClientsScreen({super.key, this.standalone = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Clients', style: AppText.heading(22)),
              const SizedBox(height: 40),
              const EmptyState(
                icon: '👥',
                title: 'Coming in Part 3',
                subtitle: 'Clients screen will be fully built next',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
