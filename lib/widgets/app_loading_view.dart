import 'package:flutter/material.dart';

class AppLoadingView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool compact;

  const AppLoadingView({
    super.key,
    this.title = 'Loading chat...',
    this.subtitle,
    this.compact = false,
  });

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _skeletonBar(double widthFactor, double opacity) {
    return FadeTransition(
      opacity: Tween<double>(begin: opacity, end: opacity + 0.18).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: widget.compact ? 44 : 56,
          height: widget.compact ? 44 : 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        SizedBox(height: widget.compact ? 12 : 16),
        Text(
          widget.title,
          style: widget.compact
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.compact ? 220 : 280),
          child: Column(
            children: [
              _skeletonBar(1, 0.45),
              const SizedBox(height: 10),
              _skeletonBar(0.78, 0.38),
              const SizedBox(height: 10),
              _skeletonBar(0.56, 0.32),
            ],
          ),
        ),
      ],
    );

    if (widget.compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: content,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ),
      ),
    );
  }
}
