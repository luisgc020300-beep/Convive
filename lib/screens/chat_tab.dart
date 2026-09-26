// lib/screens/chat_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/chat_message.dart';
import '../models/household.dart';
import '../services/chat_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

// Como máximo una reacción por persona (ver ChatService.setReaction) --
// set fijo y corto a propósito, no un picker completo de emojis.
const _reaccionesDisponibles = ['👍', '❤️', '😂'];

class ChatTab extends StatefulWidget {
  const ChatTab({required this.household, super.key});

  final Household household;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _textCtrl = TextEditingController();
  // Stream estable -- si se llama a ChatService.streamMessages() dentro de
  // build(), cada vez que el padre (_HouseholdShellState) reconstruye este
  // tab (pasa constantemente, sus propios StreamBuilder anidados se
  // reconstruyen con cada mensaje/nota nuevos) el StreamBuilder de aquí
  // recibiría una instancia de Stream distinta y se desuscribiría/
  // resuscribiría sin necesidad -- mismo bug ya encontrado y arreglado en
  // household_home_screen.dart.
  late final _messagesStream = ChatService.streamMessages(widget.household.id);

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    // No se limpia el campo hasta que el envío se confirma -- si falla (red
    // caída, permisos), el mensaje escrito no se pierde y el usuario puede
    // reintentar sin volver a teclearlo.
    try {
      await ChatService.sendMessage(widget.household.id, text);
      if (mounted) _textCtrl.clear();
    } catch (e) {
      if (mounted) AppError.show(context, context.l10n.errorGeneric);
    }
  }

  String _textoSistema(AppLocalizations l10n, ChatMessage m) {
    final d = m.eventData ?? const {};
    final nombre = d['memberName'] as String? ?? l10n.memberUnknown;
    switch (m.event) {
      case 'taskCompleted':
        return l10n.chatSystemTaskCompleted(nombre, d['taskTitle'] as String? ?? '');
      case 'expenseAdded':
        final amount = (d['amount'] as num?)?.toStringAsFixed(2) ?? '0.00';
        return l10n.chatSystemExpenseAdded(nombre, d['description'] as String? ?? '', amount);
      case 'reminderAdded':
        return l10n.chatSystemReminderAdded(nombre, d['title'] as String? ?? '');
      case 'noteAdded':
        return l10n.chatSystemNoteAdded(nombre, d['text'] as String? ?? '');
      default:
        return m.text;
    }
  }

  IconData _iconoSistema(String? event) => switch (event) {
        'taskCompleted' => Icons.check_circle_outline,
        'expenseAdded' => Icons.payments_outlined,
        'reminderAdded' => Icons.event_repeat_outlined,
        'noteAdded' => Icons.push_pin_outlined,
        _ => Icons.info_outline,
      };

  Future<void> _mostrarOpcionesMensaje(ChatMessage m, bool esMio) async {
    final l10n = context.l10n;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    String? miReaccionActual;
    for (final entry in m.reactions.entries) {
      if (entry.value.contains(myUid)) {
        miReaccionActual = entry.key;
        break;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.cork,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _reaccionesDisponibles.map((emoji) {
                  final seleccionado = emoji == miReaccionActual;
                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await ChatService.setReaction(widget.household.id, m.id, emoji);
                      } catch (e) {
                        if (mounted) AppError.show(context, l10n.errorGeneric);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: seleccionado ? context.colors.amber.withValues(alpha: 0.22) : null,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (esMio) ...[
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.delete_outline, color: context.colors.rust),
                title: Text(l10n.chatDeleteMessage, style: TextStyle(color: context.colors.rust)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ChatService.deleteMessage(widget.household.id, m.id);
                  } catch (e) {
                    if (mounted) AppError.show(context, l10n.errorGeneric);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final l10n = context.l10n;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(child: Text(l10n.chatEmpty));
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];

                  if (m.esDeSistema) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_iconoSistema(m.event), size: 13, color: context.colors.paperMuted),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _textoSistema(l10n, m),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: context.colors.paperMuted),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final esMio = m.authorUid == myUid;
                  final autor = widget.household.memberProfiles[m.authorUid]
                          ?.displayName ??
                      l10n.memberUnknown;
                  final reaccionesConGente = m.reactions.entries.where((e) => e.value.isNotEmpty).toList();

                  return Align(
                    alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onLongPress: () => _mostrarOpcionesMensaje(m, esMio),
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: esMio
                                  ? context.colors.coral.withValues(alpha: 0.22)
                                  : context.colors.cork,
                              borderRadius: BorderRadius.circular(12),
                              border: esMio ? Border.all(color: context.colors.coral.withValues(alpha: 0.5)) : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!esMio)
                                  Text(
                                    autor,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                      color: context.colors.paperMuted,
                                    ),
                                  ),
                                Text(m.text, style: TextStyle(color: context.colors.paper)),
                              ],
                            ),
                          ),
                        ),
                        if (reaccionesConGente.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2),
                            child: Wrap(
                              spacing: 4,
                              children: reaccionesConGente.map((e) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.colors.cork,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: context.colors.paperMuted.withValues(alpha: 0.3)),
                                  ),
                                  child: Text('${e.key} ${e.value.length}', style: const TextStyle(fontSize: 11)),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: InputDecoration(hintText: l10n.chatHint),
                    onSubmitted: (_) => _enviar(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                IconButton(icon: Icon(Icons.send, color: context.colors.coral), onPressed: _enviar),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
