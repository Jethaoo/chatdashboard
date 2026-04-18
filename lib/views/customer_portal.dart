import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/format_datetime.dart';
import '../utils/ui_feedback.dart';
import 'user_settings_view.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_brand_title.dart';

const double _customerWideLayoutBreakpoint = 900;
const Duration _customerSessionTimeout = Duration(seconds: 15);
const Duration _customerMessagesTimeout = Duration(seconds: 20);

abstract class _CustomerTimelineItem {
  const _CustomerTimelineItem();
}

class _CustomerMessageItem extends _CustomerTimelineItem {
  final MessageModel message;
  const _CustomerMessageItem(this.message);
}

class _CustomerDateItem extends _CustomerTimelineItem {
  final DateTime date;
  const _CustomerDateItem(this.date);
}

class CustomerPortal extends StatefulWidget {
  const CustomerPortal({super.key});

  @override
  CustomerPortalState createState() => CustomerPortalState();
}

class CustomerPortalState extends State<CustomerPortal> {
  ChatService get _chat =>
      Provider.of<ChatService>(context, listen: false);

  String? _sessionId;
  Object? _sessionError;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  int _messagesRetry = 0;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    setState(() => _sessionError = null);
    try {
      final sid = await _chat
          .getOrCreateSession(user.uid, user.email)
          .timeout(_customerSessionTimeout);
      if (!mounted) return;
      setState(() {
        _sessionId = sid;
        _sessionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sessionError = e);
    }
  }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty || _sessionId == null) return;
    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    try {
      await _chat.sendMessage(
        _sessionId!,
        _msgCtrl.text,
        user.uid,
        user.displayName,
      );
      _msgCtrl.clear();
      _scheduleScrollToLatest();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e, prefix: 'Could not send');
    }
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

  bool _isWideLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _customerWideLayoutBreakpoint;

  Widget _buildMessageBubble(MessageModel msg, String currentUserId) {
    final isMe = msg.senderId == currentUserId;
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

  List<_CustomerTimelineItem> _buildTimelineItems(List<MessageModel> messages) {
    final items = <_CustomerTimelineItem>[];
    for (var i = 0; i < messages.length; i++) {
      final current = messages[i];
      items.add(_CustomerMessageItem(current));
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      if (next == null || !isSameCalendarDate(current.timestamp, next.timestamp)) {
        items.add(_CustomerDateItem(current.timestamp));
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

  Widget _buildMessagesPane(String currentUserId, bool isWideLayout) {
    final messagesStream = _chat.streamMessages(_sessionId!).timeout(
      _customerMessagesTimeout,
      onTimeout: (sink) {
        sink.addError(
          TimeoutException(
            'Loading messages timed out. Check your connection and try again.',
          ),
        );
      },
    );
    return StreamBuilder<List<MessageModel>>(
      key: ValueKey('${_sessionId!}_$_messagesRetry'),
      stream: messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load messages.'),
                  const SizedBox(height: 8),
                  SelectableText(snapshot.error.toString()),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() => _messagesRetry++),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const AppLoadingView(
            compact: true,
            title: 'Loading messages...',
          );
        }

        final msgs = snapshot.data!;
        if (msgs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No messages yet. Send the first message to start the conversation.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final items = _buildTimelineItems(msgs);
        if (msgs.isNotEmpty) {
          _scheduleScrollToLatest(animate: false);
        }
        final list = ListView.builder(
          controller: _messagesScrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is _CustomerDateItem) {
              return _buildDateSeparator(item.date);
            }
            return _buildMessageBubble(
              (item as _CustomerMessageItem).message,
              currentUserId,
            );
          },
        );

        if (!isWideLayout) {
          return list;
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: list,
          ),
        );
      },
    );
  }

  Widget _buildComposer(bool isWideLayout) {
    final composer = Row(
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
              decoration: const InputDecoration(
                hintText: 'Type a message...',
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: _send,
        ),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.all(8),
      child: composer,
    );

    if (!isWideLayout) {
      return padded;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: padded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionError != null) {
      return Scaffold(
        appBar: AppBar(title: const AppBrandTitle()),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not open your chat session.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _sessionError.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _initSession(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_sessionId == null) {
      return const AppLoadingView(
        title: 'Opening your chat...',
        subtitle: 'Setting up your support conversation. This should only take a few seconds.',
      );
    }

    final user = Provider.of<AuthService>(context).currentUser!;
    final isWideLayout = _isWideLayout(context);
    final colorScheme = Theme.of(context).colorScheme;
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
          )
        ],
      ),
      body: Column(
        children: [
          if (isWideLayout)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Card(
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.support_agent,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You are chatting with support. Replies appear here in real time.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _buildMessagesPane(user.uid, isWideLayout),
          ),
          _buildComposer(isWideLayout),
        ],
      ),
    );
  }
}
