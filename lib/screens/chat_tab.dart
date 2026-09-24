// lib/screens/chat_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/household.dart';
import '../services/chat_service.dart';
import '../theme/design_tokens.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({required this.household, super.key});

  final Household household;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await ChatService.sendMessage(widget.household.id, text);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.streamMessages(widget.household.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(child: Text('Todavía no hay mensajes. Saluda.'));
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  final esMio = m.authorUid == myUid;
                  final autor = widget.household.memberProfiles[m.authorUid]
                          ?.displayName ??
                      'Alguien';
                  return Align(
                    alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: esMio
                            ? ConviveColors.coral.withValues(alpha: 0.22)
                            : ConviveColors.cork,
                        borderRadius: BorderRadius.circular(12),
                        border: esMio ? Border.all(color: ConviveColors.coral.withValues(alpha: 0.5)) : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!esMio)
                            Text(
                              autor,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                color: ConviveColors.paperMuted,
                              ),
                            ),
                          Text(m.text, style: const TextStyle(color: ConviveColors.paper)),
                        ],
                      ),
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
                    decoration: const InputDecoration(hintText: 'Escribe un mensaje...'),
                    onSubmitted: (_) => _enviar(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: ConviveColors.coral), onPressed: _enviar),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
