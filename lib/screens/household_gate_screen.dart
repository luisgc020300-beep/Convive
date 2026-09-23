// lib/screens/household_gate_screen.dart
//
// Decide, en vivo, si el usuario ya tiene un piso activo: si no, muestra el
// flujo de crear/unirse; si sí, entra directamente al piso.
import 'package:flutter/material.dart';

import '../services/household_service.dart';
import 'household_home_screen.dart';
import 'household_onboarding_screen.dart';

class HouseholdGateScreen extends StatelessWidget {
  const HouseholdGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: HouseholdService.streamActiveHouseholdId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final householdId = snapshot.data;
        if (householdId == null) return const HouseholdOnboardingScreen();
        return HouseholdHomeScreen(householdId: householdId);
      },
    );
  }
}
