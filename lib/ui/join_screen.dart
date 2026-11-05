import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/room_repository.dart';
import '../models/chat_models.dart';
import 'room_screen.dart';
import 'theme.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({
    super.key,
    required this.repository,
    required this.onToggleTheme,
  });
  final RoomRepository repository;
  final VoidCallback onToggleTheme;
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final code = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> enter({bool create = false, String? recentCode}) async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final identity = create
          ? await widget.repository.create()
          : await widget.repository.join(recentCode ?? code.text.trim());
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoomScreen(
            repository: widget.repository,
            identity: identity,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is RoomException
            ? e.message
            : e is FirebaseAuthException
            ? 'Could not connect anonymously. Check your connection and retry.'
            : 'Could not enter the room. Check your connection and retry.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recent = widget.repository.store.rooms;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 42),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(child: KeyMark()),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Toggle theme',
                            onPressed: widget.onToggleTheme,
                            icon: Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 20,
                              color: muted(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: (constraints.maxHeight * .235).clamp(70, 195),
                    ),
                    const Text(
                      'Join A Room',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter the code to join the anon chat\nroom',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: muted(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        key: const Key('roomCode'),
                        controller: code,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.go,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textAlign: TextAlign.center,
                        enabled: !busy,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: '------',
                          hintStyle: TextStyle(color: muted(context)),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF272729)
                              : panel(context),
                          contentPadding: const EdgeInsets.fromLTRB(
                            24,
                            14,
                            12,
                            14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: lime),
                          ),
                        ),
                        onChanged: (_) => setState(() => error = null),
                        onSubmitted: (_) => enter(),
                        onEditingComplete: () {},
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          key: const Key('joinError'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 280,
                      child: FilledButton(
                        key: const Key('joinRoom'),
                        onPressed: busy || !validRoomCode(code.text)
                            ? null
                            : () => enter(),
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Join room'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('createRoom'),
                      onPressed: busy ? null : () => enter(create: true),
                      child: Text(
                        'Create a new room',
                        style: TextStyle(
                          color: muted(context),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (recent.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'RECENT ROOMS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: muted(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final room in recent.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            key: Key('recent_${room.code}'),
                            enabled: !busy,
                            onTap: () => enter(recentCode: room.code),
                            tileColor: panel(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: const Icon(
                              Icons.key_rounded,
                              color: lime,
                              size: 21,
                            ),
                            title: Text(
                              'Room #${room.code}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              room.name,
                              style: TextStyle(
                                color: muted(context),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: muted(context),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
