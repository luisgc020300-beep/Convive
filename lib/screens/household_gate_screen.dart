// lib/screens/household_gate_screen.dart
//
// Placeholder de la Fase 0/1 — decide si el usuario ya tiene un piso activo.
// La Fase 1 sustituye esto por el flujo real de crear/unirse a un piso.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HouseholdGateScreen extends StatelessWidget {
  const HouseholdGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
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
            children: [
              const Icon(Icons.home_outlined, size: 48),
              const SizedBox(height: 16),
              Text('Sesión iniciada como $email'),
              const SizedBox(height: 8),
              const Text('Crear/unirse a un piso llega en la Fase 1.'),
            ],
          ),
        ),
      ),
    );
  }
}
