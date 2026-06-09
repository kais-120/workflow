// lib/screens/pay/pay_screen.dart
// Full implementation in Part 4
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class PayScreen extends StatelessWidget {
  final bool standalone;
  const PayScreen({super.key, this.standalone = true});

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
              Text('Pay Summary', style: AppText.heading(22)),
              const SizedBox(height: 40),
              const EmptyState(
                icon: '💰',
                title: 'Coming in Part 4',
                subtitle: 'Pay screen will be fully built in Part 4',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
