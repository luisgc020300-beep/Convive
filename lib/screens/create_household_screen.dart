// lib/screens/create_household_screen.dart
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/household_service.dart';

class CreateHouseholdScreen extends StatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  State<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends State<CreateHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _cargando = true; _error = null; });
    final l10n = context.l10n;
    try {
      final result = await HouseholdService.createHousehold(_nombreCtrl.text.trim());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.createHouseholdSuccessTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.createHouseholdSuccessBody),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  result.joinCode,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.continueLabel),
            ),
          ],
        ),
      );
      // La HouseholdGateScreen reacciona sola al stream de activeHouseholdId
      // y cambia el piso mostrado -- pero si esta pantalla se abrió por
      // encima de otra (p.ej. desde el selector de pisos en la pestaña
      // Piso, no solo desde el arranque en frío), hay que cerrarla para que
      // se vea lo de debajo ya actualizado.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = l10n.createHouseholdError(e.toString()));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createHouseholdTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: l10n.createHouseholdNameLabel,
                  hintText: l10n.createHouseholdNameHint,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.createHouseholdNameRequired
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _cargando ? null : _crear,
                child: _cargando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.createHouseholdButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
