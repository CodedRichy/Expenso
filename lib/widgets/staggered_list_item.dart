import 'package:flutter/material.dart';

/// Wraps [child] and runs a short enter animation with delay based on [index]
/// (delay = index * [delayMs]). Use for list item stagger.
class StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final int delayMs;
  final int durationMs;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.delayMs = 50,
    this.durationMs = 220,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    final staggerCap = 10;
    final effectiveIndex = widget.index.clamp(0, staggerCap);
    final delay = effectiveIndex * widget.delayMs;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _controller.forward();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
