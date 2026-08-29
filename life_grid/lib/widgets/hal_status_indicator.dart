import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// A small glowing eye, styled after HAL 9000, that reflects whether the
/// app is currently connected to its data source (local storage). Green
/// when the last read/write succeeded, red when it failed.
class HalStatusIndicator extends StatefulWidget {
  HalStatusIndicator({super.key, this.size = 28});
  final double size;

  @override
  State<HalStatusIndicator> createState() => _HalStatusIndicatorState();
}

class _HalStatusIndicatorState extends State<HalStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: StorageService.connectionStatus,
      builder: (context, connected, _) {
        final asset = connected
            ? 'assets/icon/hal_green.png'
            : 'assets/icon/hal_red.png';
        final glow = connected
            ? Color(0xFF2EE678)
            : Color(0xFFFF2818);
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = _pulse.value; // 0..1
            return Tooltip(
              message: connected
                  ? 'Connected to data source'
                  : 'Disconnected from data source',
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withOpacity(0.35 + 0.25 * t),
                      blurRadius: 6 + 6 * t,
                      spreadRadius: 0.5 + 1.5 * t,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(asset, fit: BoxFit.cover),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
