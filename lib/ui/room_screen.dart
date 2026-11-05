import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/chat_controller.dart';
import '../data/room_repository.dart';
import '../models/chat_models.dart';
import 'theme.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.repository,
    required this.identity,
    required this.onToggleTheme,
  });
  final RoomRepository repository;
  final RoomIdentity identity;
  final VoidCallback onToggleTheme;
  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final ChatController chat = ChatController(
    widget.repository,
    widget.identity,
  );
  final composer = TextEditingController();
  final scroll = ScrollController();
  bool acknowledged = false, offline = false;
  StreamSubscription<List<ConnectivityResult>>? connection;
  @override
  void initState() {
    super.initState();
    connection = Connectivity().onConnectivityChanged.listen(_connectivity);
    Connectivity().checkConnectivity().then(_connectivity);
  }

  void _connectivity(List<ConnectivityResult> result) {
    if (mounted) {
      setState(() => offline = result.contains(ConnectivityResult.none));
    }
  }

  @override
  void dispose() {
    connection?.cancel();
    chat.dispose();
    composer.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send() {
    final text = composer.text.trim();
    if (text.isEmpty || text.length > 2000) return;
    chat.send(text);
    composer.clear();
    if (scroll.hasClients) {
      scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    setState(() {});
  }

  Future<void> copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.identity.code));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Room code copied')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AnimatedBuilder(
        animation: chat,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton.filledTonal(
                      key: const Key('leaveRoom'),
                      tooltip: 'Leave room',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: panel(context),
                      ),
                      icon: const Icon(Icons.chevron_left, size: 26),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: copyCode,
                      child: Column(
                        children: [
                          Text(
                            'Room #${widget.identity.code}',
                            key: const Key('roomTitle'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${chat.memberCount} ${chat.memberCount == 1 ? 'member' : 'members'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: const Key('roomMenu'),
                    tooltip: 'Room options',
                    icon: Icon(Icons.more_horiz, color: muted(context)),
                    onSelected: (value) {
                      if (value == 'copy') {
                        copyCode();
                      } else {
                        widget.onToggleTheme();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'copy',
                        child: Text('Copy room code'),
                      ),
                      PopupMenuItem(
                        value: 'theme',
                        child: Text('Toggle theme'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (offline || chat.fromCache && acknowledged)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      offline ? Icons.cloud_off_outlined : Icons.sync,
                      size: 13,
                      color: muted(context),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        offline
                            ? 'Offline · saved chats are available. Messages will send when online.'
                            : 'Connecting · showing saved messages',
                        style: TextStyle(fontSize: 10, color: muted(context)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: acknowledged
                    ? _conversation(context)
                    : _identity(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _identity(BuildContext context) => Padding(
    key: const Key('identityScreen'),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
    child: Column(
      children: [
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: panel(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'For this room, you are',
                style: TextStyle(fontSize: 12, color: muted(context)),
              ),
              const SizedBox(height: 10),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFDE047), lime],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  widget.identity.name.replaceFirst(' ', '\n'),
                  key: const Key('identityName'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 58.59,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'This is your anonymous identifier, visible only\nto others in this room.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: muted(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: lime.withValues(alpha: .2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: FilledButton(
            key: const Key('acknowledge'),
            onPressed: () => setState(() => acknowledged = true),
            child: const Text('Acknowledge and continue'),
          ),
        ),
      ],
    ),
  );
  Widget _conversation(BuildContext context) {
    final messages = chat.messages;
    return Column(
      key: const Key('chatScreen'),
      children: [
        if (chat.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              chat.error!,
              key: const Key('chatError'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KeyMark(size: 44),
                      const SizedBox(height: 16),
                      const Text(
                        'A little mystery. A new conversation.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share this room’s code and say hello.',
                        style: TextStyle(fontSize: 12, color: muted(context)),
                      ),
                      TextButton(
                        onPressed: copyCode,
                        child: Text(
                          'Copy #${widget.identity.code}',
                          style: const TextStyle(color: lime),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const Key('messages'),
                  controller: scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return Center(
                        child: chat.hasMore
                            ? TextButton(
                                key: const Key('loadOlder'),
                                onPressed: chat.loadingHistory
                                    ? null
                                    : chat.loadMore,
                                child: chat.loadingHistory
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Load older messages',
                                        style: TextStyle(
                                          color: muted(context),
                                          fontSize: 12,
                                        ),
                                      ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'The beginning of this rumour',
                                  style: TextStyle(
                                    color: muted(context),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                      );
                    }
                    final message = messages[index];
                    final older = index + 1 < messages.length
                        ? messages[index + 1]
                        : null;
                    final dateBreak =
                        older == null ||
                        !sameDay(message.sortTime, older.sortTime);
                    return Column(
                      children: [
                        if (dateBreak)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: panel(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _dayLabel(message.sortTime),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: muted(context),
                                ),
                              ),
                            ),
                          ),
                        MessageBubble(
                          message: message,
                          mine: message.senderId == widget.repository.uid,
                        ),
                      ],
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('composer'),
                  controller: composer,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    counterText: '',
                    hintStyle: TextStyle(color: muted(context), fontSize: 12),
                    fillColor: panel(context),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('send'),
                tooltip: 'Send message',
                onPressed: composer.text.trim().isEmpty ? null : send,
                style: IconButton.styleFrom(
                  backgroundColor: lime,
                  foregroundColor: const Color(0xFF263216),
                  disabledBackgroundColor: panel(context),
                  minimumSize: const Size(42, 42),
                ),
                icon: Transform.rotate(
                  angle: -.45,
                  child: const Icon(Icons.send_outlined, size: 21),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    if (sameDay(date, now)) return 'Today';
    if (sameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('d MMM yyyy').format(date);
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .8,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 2, right: 2),
              child: Text(
                mine ? 'You' : '@${message.name.replaceAll(' ', '')}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 8),
              decoration: BoxDecoration(
                color: mine ? lime : panel(context),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: mine ? const Color(0xFF263119) : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message.pending || message.serverTime == null
                        ? 'Sending…'
                        : DateFormat('HH:mm').format(message.serverTime!),
                    style: TextStyle(
                      fontSize: 10,
                      color: mine ? const Color(0xFF587138) : muted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
