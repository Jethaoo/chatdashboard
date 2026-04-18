import 'package:flutter/material.dart';

OverlayEntry? _activeErrorOverlay;

void _showTopMessage(
  BuildContext context,
  String message, {
  required Color backgroundColor,
}) {
  if (!context.mounted) return;

  _activeErrorOverlay?.remove();
  _activeErrorOverlay = null;

  final overlay = Overlay.of(context, rootOverlay: true);
  final safeMessage =
      message.length > 300 ? '${message.substring(0, 300)}…' : message;

  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 24,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  safeMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  _activeErrorOverlay = entry;
  overlay.insert(entry);

  Future<void>.delayed(const Duration(seconds: 3), () {
    if (_activeErrorOverlay == entry) {
      _activeErrorOverlay?.remove();
      _activeErrorOverlay = null;
    }
  });
}

void showTopErrorMessage(BuildContext context, String message) {
  _showTopMessage(
    context,
    message,
    backgroundColor: Colors.red.shade700,
  );
}

void showTopSuccessMessage(BuildContext context, String message) {
  _showTopMessage(
    context,
    message,
    backgroundColor: Colors.green.shade700,
  );
}

void showErrorSnackBar(BuildContext context, Object error, {String? prefix}) {
  if (!context.mounted) return;
  final msg = '${prefix ?? 'Error'}: $error';
  showTopErrorMessage(context, msg);
}
