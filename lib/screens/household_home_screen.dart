// lib/screens/household_home_screen.dart
//
// Pestañas: Tareas (+ calendario semanal y notas), Chat, Pagos (gastos
// comunes + recordatorios) y Piso. Navegación abajo, como la mayoría de apps.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../models/chat_message.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/note.dart';
import '../services/chat_service.dart';
import '../services/expense_service.dart';
import '../services/household_service.dart';
import '../services/note_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/convive_sheet.dart';
import 'chat_tab.dart';
import 'create_household_screen.dart';
import 'join_household_screen.dart';
import 'notification_prefs_screen.dart';
import 'payments_tab.dart';
import 'settings_screen.dart';
import 'tasks_tab.dart';

class HouseholdHomeScreen extends StatefulWidget {
  const HouseholdHomeScreen({required this.householdId, super.key});

  final String householdId;

  @override
  State<HouseholdHomeScreen> createState() => _HouseholdHomeScreenState();
}

class _HouseholdHomeScreenState extends State<HouseholdHomeScreen> {
  // Stream estable -- la raíz de todo el árbol del piso; sin esto, CADA
  // escritura en users/{uid} (markChatSeen, markNotesSeen, incluso el
  // respaldo optimista) hace que streamActiveHouseholdId() emita y
  // reconstruya HouseholdGateScreen -> este widget -- y sin un stream
  // estable aquí, el StreamBuilder de abajo se desuscribiría/resuscribiría
  // en cascada con cada uno de esos eventos.
  late Stream<Household> _householdStream;

  @override
  void initState() {
    super.initState();
    _householdStream = HouseholdService.streamHousehold(widget.householdId);
  }

  @override
  void didUpdateWidget(covariant HouseholdHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId) {
      _householdStream = HouseholdService.streamHousehold(widget.householdId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Household>(
      stream: _householdStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _HouseholdShell(household: snapshot.data!);
      },
    );
  }
}

class _HouseholdShell extends StatefulWidget {
  const _HouseholdShell({required this.household});

  final Household household;

  @override
  State<_HouseholdShell> createState() => _HouseholdShellState();
}

List<String> _nombresPestanas(AppLocalizations l10n) =>
    [l10n.tabTasks, l10n.tabChat, l10n.tabPayments, l10n.tabHousehold];

class _HouseholdShellState extends State<_HouseholdShell> {
  int _index = 0;
  // Controla el PageView del cuerpo -- permite deslizar entre pestañas con
  // el dedo, no solo tocando la barra de abajo.
  final _pageController = PageController();

  // Streams estables, creados una sola vez por piso -- si en vez de esto se
  // llama a HouseholdService.streamLastSeen()/ChatService.streamMessages()/
  // NoteService.streamNotes() dentro de build(), cada vez que markChatSeen/
  // markNotesSeen escribe en users/{uid} el StreamBuilder de streamLastSeen
  // se reconstruye, lo que vuelve a invocar esas llamadas y les da a los
  // StreamBuilder anidados una instancia de Stream NUEVA en cada rebuild.
  // Como no es el mismo objeto que antes, se desuscriben y se vuelven a
  // suscribir en cada escritura -- justo la escritura que se supone que
  // debía limpiar el contador -- y bajo mala cobertura esa reconexión en
  // bucle nunca llega a asentarse, dejando el badge visualmente atascado
  // aunque el dato en Firestore ya esté bien. Verificado el flujo de datos
  // correcto contra el backend real antes de encontrar este bug -- el fallo
  // era puramente de reconstrucción de widgets, no de la lógica de conteo.
  late Stream<Map<String, dynamic>> _lastSeenStream;
  late Stream<List<ChatMessage>> _chatStream;
  late Stream<List<ConviveNote>> _notesStream;
  late Stream<List<Expense>> _expensesStream;

  // Respaldo optimista local -- streamLastSeen() puede tardar en reflejar
  // un markChatSeen/markNotesSeen reciente bajo mala cobertura (el
  // FieldValue.serverTimestamp() llega como null hasta que el servidor lo
  // confirma, ver el comentario en HouseholdService.streamLastSeen), y
  // mientras tanto el resto del código leía ese null como "nunca visto" --
  // el badge volvía a mostrar TODOS los mensajes/notas como sin leer en
  // cuanto se salía de la pestaña donde el "0" se estaba forzando a mano.
  // Guardando aquí el momento exacto en que se marcó como visto (antes
  // incluso de que la escritura salga), y usando el más reciente entre
  // este valor y el de Firestore, el contador nunca retrocede aunque la
  // confirmación tarde. Persistido en disco (no solo en memoria) porque
  // Android puede matar el proceso en segundo plano en cualquier momento
  // -- si solo viviera en memoria, un simple cambio de app y vuelta podía
  // borrar el respaldo justo antes de que Firestore confirmara la escritura.
  final _chatSeenLocal = <String, DateTime>{};
  final _notesSeenLocal = <String, DateTime>{};
  final _expensesSeenLocal = <String, DateTime>{};

  String _clavePrefsChat(String householdId) => 'lastSeenChatLocal_$householdId';
  String _clavePrefsNotas(String householdId) => 'lastSeenNotesLocal_$householdId';
  String _clavePrefsPagos(String householdId) => 'lastSeenExpensesLocal_$householdId';

  Future<void> _cargarRespaldoLocal(String householdId) async {
    final prefs = await SharedPreferences.getInstance();
    final chatMs = prefs.getInt(_clavePrefsChat(householdId));
    final notasMs = prefs.getInt(_clavePrefsNotas(householdId));
    final pagosMs = prefs.getInt(_clavePrefsPagos(householdId));
    if (chatMs == null && notasMs == null && pagosMs == null) return;
    if (!mounted) return;
    setState(() {
      if (chatMs != null) _chatSeenLocal[householdId] = DateTime.fromMillisecondsSinceEpoch(chatMs);
      if (notasMs != null) _notesSeenLocal[householdId] = DateTime.fromMillisecondsSinceEpoch(notasMs);
      if (pagosMs != null) _expensesSeenLocal[householdId] = DateTime.fromMillisecondsSinceEpoch(pagosMs);
    });
  }

  void _marcarChatVisto(String householdId) {
    final ahora = DateTime.now();
    _chatSeenLocal[householdId] = ahora;
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_clavePrefsChat(householdId), ahora.millisecondsSinceEpoch));
    HouseholdService.markChatSeen(householdId);
  }

  void _marcarNotasVistas(String householdId) {
    final ahora = DateTime.now();
    _notesSeenLocal[householdId] = ahora;
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_clavePrefsNotas(householdId), ahora.millisecondsSinceEpoch));
    HouseholdService.markNotesSeen(householdId);
  }

  void _marcarPagosVistos(String householdId) {
    final ahora = DateTime.now();
    _expensesSeenLocal[householdId] = ahora;
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_clavePrefsPagos(householdId), ahora.millisecondsSinceEpoch));
    HouseholdService.markExpensesSeen(householdId);
  }

  DateTime? _masReciente(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  @override
  void initState() {
    super.initState();
    _lastSeenStream = HouseholdService.streamLastSeen();
    _iniciarStreamsDelPiso();
    _cargarRespaldoLocal(widget.household.id);
    // La pestaña por defecto es Tareas -- "entrar" en ella ya cuenta como
    // haber visto las notas, igual que tocarla a mano.
    _marcarNotasVistas(widget.household.id);
  }

  void _iniciarStreamsDelPiso() {
    _chatStream = ChatService.streamMessages(widget.household.id);
    _notesStream = NoteService.streamNotes(widget.household.id);
    _expensesStream = ExpenseService.streamExpenses(widget.household.id);
  }

  @override
  void didUpdateWidget(covariant _HouseholdShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.household.id != widget.household.id) {
      _iniciarStreamsDelPiso();
      _cargarRespaldoLocal(widget.household.id);
      // Cambiaste de piso -- "entrar" en él marca como vista la pestaña que
      // ya tuvieras seleccionada, en ese piso nuevo.
      if (_index == 0) _marcarNotasVistas(widget.household.id);
      if (_index == 1) _marcarChatVisto(widget.household.id);
      if (_index == 2) _marcarPagosVistos(widget.household.id);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Disparado tanto al tocar la barra de abajo (jumpToPage) como al
  // deslizar con el dedo (onPageChanged del PageView) -- un único punto
  // para "qué pestaña se ve ahora", sin duplicar la lógica de marcar visto.
  void _onPageChanged(int i) {
    setState(() => _index = i);
    if (i == 0) _marcarNotasVistas(widget.household.id);
    if (i == 1) _marcarChatVisto(widget.household.id);
    if (i == 2) _marcarPagosVistos(widget.household.id);
  }

  void _cambiarPestana(int i) {
    // Salto directo, sin animación -- igual que el IndexedStack de antes.
    // El deslizar con el dedo ya tiene su propia animación nativa del
    // PageView; tocar una pestaña lejana no debería sobrevolar las de en
    // medio.
    _pageController.jumpToPage(i);
  }

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    final l10n = context.l10n;
    final tabs = [
      _KeepAlivePage(child: TasksTab(household: household)),
      _KeepAlivePage(child: ChatTab(household: household)),
      _KeepAlivePage(child: PaymentsTab(household: household)),
      _KeepAlivePage(child: _PisoTab(household: household)),
    ];
    return StreamBuilder<Map<String, dynamic>>(
      stream: _lastSeenStream,
      builder: (context, lastSeenSnapshot) {
        final lastSeenChat = lastSeenSnapshot.data?['chat'] as Map<String, dynamic>? ?? const {};
        final lastSeenNotes = lastSeenSnapshot.data?['notes'] as Map<String, dynamic>? ?? const {};
        final lastSeenExpenses = lastSeenSnapshot.data?['expenses'] as Map<String, dynamic>? ?? const {};
        final desdeChat = _masReciente(
          (lastSeenChat[household.id] as Timestamp?)?.toDate(),
          _chatSeenLocal[household.id],
        );
        final desdeNotas = _masReciente(
          (lastSeenNotes[household.id] as Timestamp?)?.toDate(),
          _notesSeenLocal[household.id],
        );
        final desdePagos = _masReciente(
          (lastSeenExpenses[household.id] as Timestamp?)?.toDate(),
          _expensesSeenLocal[household.id],
        );

        return StreamBuilder<List<ChatMessage>>(
          stream: _chatStream,
          builder: (context, chatSnapshot) {
            final myUid = FirebaseAuth.instance.currentUser?.uid;
            var sinLeerChat = (chatSnapshot.data ?? [])
                .where((m) => m.authorUid != myUid)
                .where((m) => desdeChat == null || (m.createdAt?.isAfter(desdeChat) ?? false))
                .length;
            if (_index == 1 && sinLeerChat > 0) {
              // Ya estás mirando el chat -- si algo nuevo llega mientras
              // sigues aquí (sin haber "vuelto a entrar"), el badge no debe
              // mostrar número, y hay que confirmar como visto para que no
              // reaparezca al cambiar de pestaña y volver.
              sinLeerChat = 0;
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _marcarChatVisto(household.id));
            }

            return StreamBuilder<List<ConviveNote>>(
              stream: _notesStream,
              builder: (context, notesSnapshot) {
                var sinLeerNotas = (notesSnapshot.data ?? [])
                    .where((n) => n.authorUid != myUid)
                    .where((n) => desdeNotas == null || (n.createdAt?.isAfter(desdeNotas) ?? false))
                    .length;
                if (_index == 0 && sinLeerNotas > 0) {
                  sinLeerNotas = 0;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _marcarNotasVistas(household.id));
                }

                return StreamBuilder<List<Expense>>(
                  stream: _expensesStream,
                  builder: (context, expensesSnapshot) {
                    var sinLeerPagos = (expensesSnapshot.data ?? [])
                        .where((e) => e.paidByUid != myUid)
                        .where((e) => desdePagos == null || (e.createdAt?.isAfter(desdePagos) ?? false))
                        .length;
                    if (_index == 2 && sinLeerPagos > 0) {
                      sinLeerPagos = 0;
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _marcarPagosVistos(household.id));
                    }

                    return _buildScaffold(context, household, l10n, tabs, sinLeerNotas, sinLeerChat, sinLeerPagos);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    Household household,
    AppLocalizations l10n,
    List<Widget> tabs,
    int sinLeerNotas,
    int sinLeerChat,
    int sinLeerPagos,
  ) {
    return Scaffold(
                  appBar: AppBar(
                    toolbarHeight: 44,
                    // En la pestaña Piso (índice 3) se muestra el nombre real
                    // del piso en vez de la palabra genérica "Piso" -- así
                    // cada compañero ve "Piso Pedro Antonio 2026" y no un
                    // rótulo igual para todos los pisos.
                    title: Text(_index == 3 ? household.name : _nombresPestanas(l10n)[_index]),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, size: 22),
                        tooltip: l10n.notifTitle,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationPrefsScreen()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 22),
                        tooltip: l10n.settingsTitle,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                  body: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: tabs,
                  ),
                  bottomNavigationBar: NavigationBar(
                    height: 56,
                    selectedIndex: _index,
                    onDestinationSelected: _cambiarPestana,
                    backgroundColor: context.colors.wall,
                    indicatorColor: context.colors.amber.withValues(alpha: 0.18),
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                    destinations: [
                      NavigationDestination(
                        icon: Badge(
                          label: Text('$sinLeerNotas'),
                          isLabelVisible: sinLeerNotas > 0,
                          child: const Icon(Icons.checklist_rounded),
                        ),
                        label: l10n.tabTasks,
                      ),
                      NavigationDestination(
                        icon: Badge(
                          label: Text('$sinLeerChat'),
                          isLabelVisible: sinLeerChat > 0,
                          child: const Icon(Icons.forum_outlined),
                        ),
                        label: l10n.tabChat,
                      ),
                      NavigationDestination(
                        icon: Badge(
                          label: Text('$sinLeerPagos'),
                          isLabelVisible: sinLeerPagos > 0,
                          child: const Icon(Icons.payments_outlined),
                        ),
                        label: l10n.tabPayments,
                      ),
                      NavigationDestination(icon: const Icon(Icons.home_outlined), label: l10n.tabHousehold),
                    ],
                  ),
    );
  }
}

// Sin esto, el PageView desmonta cada pestaña en cuanto sale de la
// pantalla al deslizar (a diferencia del IndexedStack de antes, que las
// mantenía todas montadas) -- reconstruiría TasksTab/ChatTab/etc. desde
// cero cada vez que vuelves a ella, perdiendo la posición de scroll y
// re-suscribiendo sus streams sin necesidad.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _PisoTab extends StatefulWidget {
  const _PisoTab({required this.household});

  final Household household;

  @override
  State<_PisoTab> createState() => _PisoTabState();
}

class _PisoTabState extends State<_PisoTab> {
  late final _nicknameCtrl = TextEditingController(text: _miNombreActual());
  late final _householdNameCtrl = TextEditingController(text: widget.household.name);
  bool _guardando = false;
  bool _guardandoNombrePiso = false;

  String _miNombreActual() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return widget.household.memberProfiles[uid]?.displayName ?? '';
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _householdNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarNickname() async {
    final nombre = _nicknameCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardando = true);
    try {
      await HouseholdService.updateNickname(nombre);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _guardarNombrePiso() async {
    final nombre = _householdNameCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardandoNombrePiso = true);
    try {
      await HouseholdService.updateHouseholdName(widget.household.id, nombre);
    } finally {
      if (mounted) setState(() => _guardandoNombrePiso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    final colors = context.colors;
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoPiso(household: household),
        const SizedBox(height: 24),
        Text(l10n.householdFlatNameLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _householdNameCtrl,
                decoration: InputDecoration(hintText: l10n.householdFlatNameHint),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _guardandoNombrePiso ? null : _guardarNombrePiso,
              child: _guardandoNombrePiso
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.householdYourName, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nicknameCtrl,
                decoration: InputDecoration(hintText: l10n.householdNameHint),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _guardando ? null : _guardarNickname,
              child: _guardando
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.householdYourHouseholds, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _MisPisos(activeHouseholdId: household.id),
        const SizedBox(height: 24),
        Text(l10n.householdJoinCode(household.joinCode),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Text(l10n.householdMembers(household.members.length),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...household.members.map((uid) {
          final profile = household.memberProfiles[uid];
          return ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(profile?.displayName ?? l10n.memberUnknown),
            trailing: uid == household.ownerUid ? Chip(label: Text(l10n.householdOwner)) : null,
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmarSalir(context, household),
          icon: Icon(Icons.logout_outlined, size: 18, color: colors.rust),
          label: Text(l10n.householdLeave, style: TextStyle(color: colors.rust)),
        ),
      ],
    );
  }

  Future<void> _confirmarSalir(BuildContext context, Household household) async {
    final l10n = context.l10n;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.householdLeaveConfirmTitle),
        content: Text(l10n.householdLeaveConfirmBody(household.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.rust),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await HouseholdService.leaveHousehold(household.id);
    }
  }
}

class _InfoPiso extends StatefulWidget {
  const _InfoPiso({required this.household});

  final Household household;

  @override
  State<_InfoPiso> createState() => _InfoPisoState();
}

class _InfoPisoState extends State<_InfoPiso> {
  late Stream<String> _infoStream;

  @override
  void initState() {
    super.initState();
    _infoStream = HouseholdService.streamInfoPiso(widget.household.id);
  }

  @override
  void didUpdateWidget(covariant _InfoPiso oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.household.id != widget.household.id) {
      _infoStream = HouseholdService.streamInfoPiso(widget.household.id);
    }
  }

  Future<void> _editar(BuildContext context, Household household, String actual) async {
    final ctrl = TextEditingController(text: actual);
    final l10n = context.l10n;
    await showConviveSheet<void>(
      context: context,
      title: l10n.householdInfoTitle,
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 8,
            minLines: 4,
            decoration: InputDecoration(hintText: l10n.householdInfoHint),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              try {
                await HouseholdService.actualizarInfoPiso(household.id, ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) AppError.show(ctx, l10n.errorGeneric);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    final colors = context.colors;
    final l10n = context.l10n;
    return StreamBuilder<String>(
      stream: _infoStream,
      builder: (context, snapshot) {
        final texto = snapshot.data ?? '';
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(l10n.householdInfoTitle,
                        style: TextStyle(fontWeight: FontWeight.w700, color: colors.paper)),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: colors.paperMuted),
                    onPressed: () => _editar(context, household, texto),
                    tooltip: l10n.householdInfoEdit,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                texto.isEmpty ? l10n.householdInfoEmpty : texto,
                style: TextStyle(
                  color: texto.isEmpty ? colors.paperMuted : colors.paper,
                  fontSize: 13,
                  fontStyle: texto.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MisPisos extends StatefulWidget {
  const _MisPisos({required this.activeHouseholdId});

  final String activeHouseholdId;

  @override
  State<_MisPisos> createState() => _MisPisosState();
}

class _MisPisosState extends State<_MisPisos> {
  // No depende de ningún campo que cambie (siempre el mismo usuario), pero
  // se estabiliza igual por consistencia con el resto de streams del piso.
  late final _idsStream = HouseholdService.streamMyHouseholdIds();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return StreamBuilder<List<String>>(
      stream: _idsStream,
      builder: (context, snapshot) {
        final ids = snapshot.data ?? [widget.activeHouseholdId];
        return Container(
          decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              ...ids.map((id) => _PisoRow(
                    key: ValueKey(id),
                    householdId: id,
                    esActivo: id == widget.activeHouseholdId,
                  )),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.add, color: colors.amber),
                title: Text(l10n.householdAddAnother, style: TextStyle(color: colors.amber)),
                onTap: () => _mostrarOpciones(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _mostrarOpciones(BuildContext context) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.cork,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_home_outlined),
              title: Text(l10n.householdCreateNew),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateHouseholdScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text(l10n.householdJoinWithCode),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinHouseholdScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PisoRow extends StatefulWidget {
  const _PisoRow({required this.householdId, required this.esActivo, super.key});

  final String householdId;
  final bool esActivo;

  @override
  State<_PisoRow> createState() => _PisoRowState();
}

class _PisoRowState extends State<_PisoRow> {
  // Seguro cachear una sola vez: cada _PisoRow lleva key: ValueKey(id) en
  // _MisPisos, así que Flutter siempre empareja esta instancia con el
  // MISMO householdId aunque la lista se reordene -- no es el caso que
  // causó el bug de chat_tab.dart, donde el widget SÍ cambiaba de piso
  // bajo la misma instancia.
  late final _householdStream = HouseholdService.streamHousehold(widget.householdId);

  @override
  Widget build(BuildContext context) {
    final householdId = widget.householdId;
    final esActivo = widget.esActivo;
    final colors = context.colors;
    final l10n = context.l10n;
    return StreamBuilder<Household>(
      stream: _householdStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final household = snapshot.data!;
        return ListTile(
          leading: Icon(Icons.home_outlined, color: esActivo ? colors.amber : colors.paperMuted),
          title: Text(household.name, style: TextStyle(color: esActivo ? colors.amber : colors.paper)),
          subtitle: Text(l10n.householdPeopleCount(household.members.length)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (esActivo) ...[
                Chip(label: Text(l10n.householdActive), backgroundColor: colors.amber.withValues(alpha: 0.18)),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: colors.paperMuted),
                tooltip: l10n.householdLeave,
                onPressed: () => _confirmarSalir(context, household),
              ),
            ],
          ),
          onTap: esActivo ? null : () => HouseholdService.switchActiveHousehold(householdId),
        );
      },
    );
  }

  Future<void> _confirmarSalir(BuildContext context, Household household) async {
    final l10n = context.l10n;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.householdLeaveConfirmTitle),
        content: Text(l10n.householdLeaveConfirmBody(household.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.rust),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await HouseholdService.leaveHousehold(household.id);
    }
  }
}
