// lib/screens/join_household_screen.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/household_service.dart';

class JoinHouseholdScreen extends StatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  State<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends State<JoinHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _unirse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _cargando = true; _error = null; });
    try {
      await HouseholdService.joinHousehold(_codeCtrl.text.trim());
      // La HouseholdGateScreen reacciona sola al stream de activeHouseholdId.
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = switch (e.code) {
        'not-found' => 'No existe ningún piso con ese código.',
        'failed-precondition' => 'Ese piso ya tiene el máximo de miembros.',
        _ => 'No se pudo unir al piso: ${e.message}',
      });
    } catch (e) {
      setState(() => _error = 'No se pudo unir al piso: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirse a un piso')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Código del piso',
                  hintText: 'Ej: A3B7K9',
                ),
                validator: (v) => (v == null || v.trim().length < 4)
                    ? 'Introduce el código que te han pasado'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _cargando ? null : _unirse,
                child: _cargando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Unirme'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
