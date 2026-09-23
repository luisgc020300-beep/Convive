// lib/screens/household_onboarding_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_household_screen.dart';
import 'join_household_screen.dart';

class HouseholdOnboardingScreen extends StatelessWidget {
  const HouseholdOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.home_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Todavía no tienes un piso',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CreateHouseholdScreen())),
                child: const Text('Crear un piso'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const JoinHouseholdScreen())),
                child: const Text('Unirme con un código'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
