import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';

/// Ephemeral, non-interactive view data. Never serialized into a project.
@immutable
class EngineeringHoverInfo {
  const EngineeringHoverInfo({
    required this.id,
    required this.type,
    required this.label,
    required this.anchor,
    this.room,
  });

  final String id;
  final ElectricalComponentType type;
  final String label;
  final Offset anchor;
  final String? room;

  String get typeName => switch (type) {
        ElectricalComponentType.socketOutlet => 'Розетка',
        ElectricalComponentType.switchControl => 'Выключатель',
        ElectricalComponentType.lightingPoint => 'Светильник',
        ElectricalComponentType.distributionBoard => 'Электрощит',
        ElectricalComponentType.junctionBox => 'Распределительная коробка',
        ElectricalComponentType.powerSource => 'Источник питания',
        ElectricalComponentType.curtainMotor => 'Привод штор',
        ElectricalComponentType.custom => 'Устройство',
      };

  String get purpose => switch (type) {
        ElectricalComponentType.socketOutlet => 'Точка подключения электропитания',
        ElectricalComponentType.switchControl => 'Управление освещением',
        ElectricalComponentType.lightingPoint => 'Точка освещения',
        ElectricalComponentType.distributionBoard => 'Распределение электрических цепей',
        ElectricalComponentType.junctionBox => 'Соединение электрических проводников',
        ElectricalComponentType.powerSource => 'Источник электрической энергии',
        ElectricalComponentType.curtainMotor => 'Электропривод',
        ElectricalComponentType.custom => 'Инженерный компонент',
      };
}

/// A single hover overlay. The canvas owns hit-testing and interaction priority.
class EngineeringHoverCallout extends StatefulWidget {
  const EngineeringHoverCallout({
    required this.target,
    required this.viewportSize,
    super.key,
    this.showDelay = const Duration(milliseconds: 150),
  });

  final EngineeringHoverInfo? target;
  final Size viewportSize;
  final Duration showDelay;

  @override
  State<EngineeringHoverCallout> createState() =>
      _EngineeringHoverCalloutState();
}

class _EngineeringHoverCalloutState extends State<EngineeringHoverCallout>
    with SingleTickerProviderStateMixin {
  Timer? _pending;
  EngineeringHoverInfo? _shown;
  bool _visible = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _queue(widget.target);
  }

  void _queue(EngineeringHoverInfo? target) {
    _pending?.cancel();
    _pending = null;
    if (target == null) {
      if (_visible) setState(() => _visible = false);
      _pulse.stop();
      return;
    }
    if (_shown?.id == target.id && _visible) return;
    if (_visible) setState(() => _visible = false);
    _pulse.stop();
    _pending = Timer(widget.showDelay, () {
      if (!mounted || widget.target?.id != target.id) return;
      setState(() {
        _shown = widget.target;
        _visible = true;
      });
      if (!MediaQuery.disableAnimationsOf(context)) {
        _pulse.repeat(reverse: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant EngineeringHoverCallout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target?.id != oldWidget.target?.id) {
      _queue(widget.target);
    } else if (_visible && widget.target != null) {
      // Updating the camera changes the leader anchor without restarting
      // the hover delay or animation.
      _shown = widget.target;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (_visible && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _shown;
    if (info == null || widget.viewportSize.isEmpty) {
      return const SizedBox.shrink();
    }
    final width = math.min(260.0, math.max(0, widget.viewportSize.width - 16));
    if (width < 100 || widget.viewportSize.height < 96) {
      return const SizedBox.shrink();
    }
    const height = 94.0;
    const gap = 26.0;
    final toRight = info.anchor.dx + gap + width + 8 <= widget.viewportSize.width;
    final left = (toRight ? info.anchor.dx + gap : info.anchor.dx - width - gap)
        .clamp(8.0, math.max(8.0, widget.viewportSize.width - width - 8)).toDouble();
    final top = (info.anchor.dy - height - 20)
        .clamp(8.0, math.max(8.0, widget.viewportSize.height - height - 8)).toDouble();
    final end = Offset(
      toRight ? left : left + width,
      (top + height / 2).clamp(top + 8, top + height - 8).toDouble(),
    );
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: true,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: Duration(milliseconds: _visible ? 140 : 120),
        onEnd: () {
          if (!_visible && mounted && widget.target == null) {
            setState(() => _shown = null);
          }
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = reduceMotion ? 0.15 : 0.12 + 0.11 * _pulse.value;
            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CalloutLeaderPainter(
                        from: info.anchor,
                        to: end,
                        color: accent,
                        glow: glow,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.75)),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: glow),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${info.typeName} · ${info.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            info.purpose,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (info.room != null && info.room!.isNotEmpty)
                            Text(
                              info.room!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CalloutLeaderPainter extends CustomPainter {
  const _CalloutLeaderPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.glow,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final elbow = Offset((from.dx + to.dx) / 2, to.dy);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: glow)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(from, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CalloutLeaderPainter old) =>
      from != old.from || to != old.to || color != old.color || glow != old.glow;
}
