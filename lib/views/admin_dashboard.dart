import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat_session_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/format_datetime.dart';
import '../utils/ui_feedback.dart';
import 'user_settings_view.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_brand_title.dart';

bool _useWindowsFirestorePolling() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

const double _adminWideLayoutBreakpoint = 900;

abstract class _AdminTimelineItem {
  const _AdminTimelineItem();
}

class _AdminMessageItem extends _AdminTimelineItem {
  final MessageModel message;
  const _AdminMessageItem(this.message);
}

class _AdminDateItem extends _AdminTimelineItem {
  final DateTime date;
  const _AdminDateItem(this.date);
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  AdminDashboardState createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {
  ChatService get _chat => Provider.of<ChatService>(context, listen: false);

  String? _selectedSessionId;
  String? _selectedSessionEmail;
  String? _selectedSessionStatus;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  int _sessionsRetry = 0;
  int _messagesRetry = 0;
  bool _firestoreReady = false;

  Timer? _pollTimer;
  List<ChatSessionModel> _polledSessions = [];
  List<MessageModel> _polledMessages = [];
  Object? _pollSessionsError;
  Object? _pollMessagesError;
  bool _pollSessionsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _firestoreReady = true);
      if (_useWindowsFirestorePolling()) {
        _refreshPolledData();
        _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (mounted) _refreshPolledData();
        });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  bool _isWideLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _adminWideLayoutBreakpoint;

  Future<void> _openSession(String sessionId, String customerEmail) async {
    setState(() {
      _selectedSessionId = sessionId;
      _selectedSessionEmail = customerEmail;
      _selectedSessionStatus = _findSessionById(sessionId)?.status;
      _polledMessages = [];
      _pollMessagesError = null;
    });
    if (_useWindowsFirestorePolling()) {
      await _loadPolledMessages();
    }
  }

  void _closeSession() {
    setState(() {
      _selectedSessionId = null;
      _selectedSessionEmail = null;
      _selectedSessionStatus = null;
      _pollMessagesError = null;
    });
  }

  ChatSessionModel? _findSessionById(String sessionId) {
    for (final session in _polledSessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  void _scheduleScrollToLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_messagesScrollController.hasClients) return;
      if (animate) {
        await _messagesScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _messagesScrollController.jumpTo(0);
      }
    });
  }

  KeyEventResult _handleComposerKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _send();
    return KeyEventResult.handled;
  }

  Future<void> _refreshPolledData() async {
    await _loadPolledSessions();
    if (_selectedSessionId != null) {
      await _loadPolledMessages();
    }
  }

  Future<void> _loadPolledSessions() async {
    try {
      final list = await _chat.fetchSessionsOnce();
      if (!mounted) return;
      setState(() {
        _polledSessions = list;
        _pollSessionsError = null;
        _pollSessionsLoading = false;
        if (_selectedSessionId != null) {
          final selected = _findSessionById(_selectedSessionId!);
          if (selected != null) {
            _selectedSessionEmail = selected.customerEmail;
            _selectedSessionStatus = selected.status;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pollSessionsError = e;
        _pollSessionsLoading = false;
      });
    }
  }

  Future<void> _loadPolledMessages() async {
    final id = _selectedSessionId;
    if (id == null) return;
    try {
      final list = await _chat.fetchMessagesOnce(id);
      if (!mounted || _selectedSessionId != id) return;
      setState(() {
        _polledMessages = list;
        _pollMessagesError = null;
      });
      _scheduleScrollToLatest(animate: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pollMessagesError = e);
    }
  }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty || _selectedSessionId == null) return;
    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    try {
      await _chat.sendMessage(
        _selectedSessionId!,
        _msgCtrl.text,
        user.uid,
        user.displayName,
      );
      _msgCtrl.clear();
      _scheduleScrollToLatest();
      if (_useWindowsFirestorePolling()) {
        await _refreshPolledData();
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e, prefix: 'Could not send');
    }
  }

  Future<void> _resolve(String sessionId) async {
    try {
      await _chat.resolveSession(sessionId);
      if (_useWindowsFirestorePolling()) {
        await _refreshPolledData();
      } else if (_selectedSessionId == sessionId) {
        setState(() => _selectedSessionStatus = 'resolved');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e, prefix: 'Could not resolve');
    }
  }

  Future<void> _reopen(String sessionId) async {
    try {
      await _chat.reopenSession(sessionId);
      if (_useWindowsFirestorePolling()) {
        await _refreshPolledData();
      } else if (_selectedSessionId == sessionId) {
        setState(() => _selectedSessionStatus = 'active');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e, prefix: 'Could not reopen');
    }
  }

  Widget _buildErrorPane({
    required String title,
    required Object error,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text('Conversations', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _useWindowsFirestorePolling()
                ? _refreshPolledData
                : () => setState(() => _sessionsRetry++),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(ChatSessionModel session) {
    final isResolved = session.status == 'resolved';
    return ListTile(
      title: Text(session.customerEmail),
      subtitle: Text(
        '${formatShortDateTime(session.lastActivity)} • ${isResolved ? 'Resolved' : 'Active'}',
      ),
      selected: _selectedSessionId == session.id,
      onTap: () => _openSession(session.id, session.customerEmail),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(isResolved ? 'Resolved' : 'Active'),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: isResolved ? 'Reopen chat' : 'Resolve chat',
            icon: Icon(
              isResolved ? Icons.undo : Icons.check_circle,
              color: isResolved ? Colors.orange : Colors.green,
            ),
            onPressed: () =>
                isResolved ? _reopen(session.id) : _resolve(session.id),
          ),
        ],
      ),
    );
  }

  Widget _buildPollingSessionsPane() {
    if (_pollSessionsLoading) {
      return const AppLoadingView(
        compact: true,
        title: 'Loading conversations...',
      );
    }
    if (_pollSessionsError != null) {
      return _buildErrorPane(
        title: 'Could not load sessions.',
        error: _pollSessionsError!,
        onRetry: () {
          setState(() {
            _pollSessionsError = null;
            _pollSessionsLoading = true;
          });
          _loadPolledSessions();
        },
      );
    }
    if (_polledSessions.isEmpty) {
      return const Center(child: Text('No conversations yet.'));
    }
    return ListView.builder(
      itemCount: _polledSessions.length,
      itemBuilder: (context, index) => _buildSessionTile(_polledSessions[index]),
    );
  }

  Widget _buildStreamSessionsPane() {
    return StreamBuilder<List<ChatSessionModel>>(
      key: ValueKey(_sessionsRetry),
      stream: _chat.streamSessions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorPane(
            title: 'Could not load sessions.',
            error: snapshot.error ?? 'Unknown error',
            onRetry: () => setState(() => _sessionsRetry++),
          );
        }
        if (!snapshot.hasData) {
          return const AppLoadingView(
            compact: true,
            title: 'Loading conversations...',
          );
        }
        final sessions = snapshot.data!;
        if (sessions.isEmpty) {
          return const Center(child: Text('No conversations yet.'));
        }
        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) => _buildSessionTile(sessions[index]),
        );
      },
    );
  }

  Widget _buildSessionsPane() {
    return Column(
      children: [
        _buildSessionsHeader(),
        const Divider(height: 1),
        Expanded(
          child: _useWindowsFirestorePolling()
              ? _buildPollingSessionsPane()
              : _buildStreamSessionsPane(),
        ),
      ],
    );
  }

  Widget _buildChatHeader(bool isWideLayout) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          if (!isWideLayout)
            IconButton(
              tooltip: 'Back to chats',
              onPressed: _closeSession,
              icon: const Icon(Icons.arrow_back),
            ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedSessionEmail ?? 'Conversation',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedSessionStatus != null)
                  Chip(
                    label: Text(
                      _selectedSessionStatus == 'resolved'
                          ? 'Resolved'
                          : 'Active',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, UserModel user) {
    final isMe = msg.senderId == user.uid;
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isMe
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final messageColor = isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final metaColor = isMe
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.72)
        : colorScheme.onSurfaceVariant;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: IntrinsicWidth(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe && (msg.senderName?.trim().isNotEmpty ?? false)) ...[
                  Text(
                    msg.senderName!.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: metaColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  msg.text,
                  textAlign: isMe ? TextAlign.right : TextAlign.left,
                  style: TextStyle(color: messageColor),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMessageTime(msg.timestamp),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: metaColor,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_AdminTimelineItem> _buildTimelineItems(List<MessageModel> messages) {
    final items = <_AdminTimelineItem>[];
    for (var i = 0; i < messages.length; i++) {
      final current = messages[i];
      items.add(_AdminMessageItem(current));
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      if (next == null || !isSameCalendarDate(current.timestamp, next.timestamp)) {
        items.add(_AdminDateItem(current.timestamp));
      }
    }
    return items;
  }

  Widget _buildDateSeparator(DateTime date) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Text(
            formatChatDateLabel(date),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Focus(
              onKeyEvent: (_, event) => _handleComposerKey(event),
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(hintText: 'Type a reply...'),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            icon: const Icon(Icons.send),
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody(List<MessageModel> messages, UserModel user) {
    final items = _buildTimelineItems(messages);
    if (messages.isNotEmpty) {
      _scheduleScrollToLatest(animate: false);
    }
    return messages.isEmpty
        ? const Center(child: Text('No messages yet.'))
        : ListView.builder(
            controller: _messagesScrollController,
            reverse: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is _AdminDateItem) {
                return _buildDateSeparator(item.date);
              }
              return _buildMessageBubble((item as _AdminMessageItem).message, user);
            },
          );
  }

  Widget _buildPollingChatPane(UserModel user, bool isWideLayout) {
    if (_selectedSessionId == null) {
      return const Center(child: Text('Select a session from the sidebar'));
    }

    Widget content;
    if (_pollMessagesError != null) {
      content = _buildErrorPane(
        title: 'Could not load messages.',
        error: _pollMessagesError!,
        onRetry: () {
          setState(() => _pollMessagesError = null);
          _loadPolledMessages();
        },
      );
    } else {
      content = _buildChatBody(_polledMessages, user);
    }

    return Column(
      children: [
        _buildChatHeader(isWideLayout),
        const Divider(height: 1),
        Expanded(child: content),
        _buildComposer(),
      ],
    );
  }

  Widget _buildStreamChatPane(UserModel user, bool isWideLayout) {
    if (_selectedSessionId == null) {
      return const Center(child: Text('Select a session from the sidebar'));
    }

    return Column(
      children: [
        _buildChatHeader(isWideLayout),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            key: ValueKey('${_selectedSessionId!}_$_messagesRetry'),
            stream: _chat.streamMessages(_selectedSessionId!),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorPane(
                  title: 'Could not load messages.',
                  error: snapshot.error ?? 'Unknown error',
                  onRetry: () => setState(() => _messagesRetry++),
                );
              }
              if (!snapshot.hasData) {
                return const AppLoadingView(
                  compact: true,
                  title: 'Loading messages...',
                );
              }
              return _buildChatBody(snapshot.data!, user);
            },
          ),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildResponsiveBody(UserModel user) {
    final isWideLayout = _isWideLayout(context);
    final sessionsPane = _buildSessionsPane();
    final chatPane = _useWindowsFirestorePolling()
        ? _buildPollingChatPane(user, isWideLayout)
        : _buildStreamChatPane(user, isWideLayout);

    if (!isWideLayout) {
      return _selectedSessionId == null ? sessionsPane : chatPane;
    }

    return Row(
      children: [
        SizedBox(width: 320, child: sessionsPane),
        const VerticalDivider(width: 1),
        Expanded(child: chatPane),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'User Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UserSettingsView(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Provider.of<AuthService>(context, listen: false).signOut(),
          ),
        ],
      ),
      body: !_firestoreReady
          ? const AppLoadingView(
              title: 'Preparing admin dashboard...',
              subtitle: 'Loading conversations and recent activity.',
            )
          : _buildResponsiveBody(user),
    );
  }
}
