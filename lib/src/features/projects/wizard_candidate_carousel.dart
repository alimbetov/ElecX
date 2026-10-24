import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/project/wizard/wizard_preview_scene.dart';
import 'project_wizard_localizations.dart';

final class WizardCandidateCard {
  const WizardCandidateCard({
    required this.id,
    required this.title,
    required this.scene,
  });

  final String id;
  final String title;
  final WizardPreviewScene scene;
}

/// Provider-neutral P8 candidate carousel. Candidate selection is presentation
/// state only: browsing never reserves canonical identities or mutates project
/// state. Providers with a single prepared candidate use the same surface.
final class WizardCandidateCarousel extends StatefulWidget {
  const WizardCandidateCarousel({
    required this.candidates,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<WizardCandidateCard> candidates;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<WizardCandidateCarousel> createState() =>
      _WizardCandidateCarouselState();
}

final class _WizardCandidateCarouselState
    extends State<WizardCandidateCarousel> {
  late final PageController _controller;

  int _indexFor(List<WizardCandidateCard> candidates, String selectedId) {
    final index =
        candidates.indexWhere((candidate) => candidate.id == selectedId);
    return index < 0 ? 0 : index;
  }

  int get _selectedIndex => _indexFor(widget.candidates, widget.selectedId);

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _selectedIndex);
  }

  @override
  void didUpdateWidget(covariant WizardCandidateCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId && _controller.hasClients) {
      final oldIndex = _indexFor(oldWidget.candidates, oldWidget.selectedId);
      final newIndex = _selectedIndex;
      final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion || (newIndex - oldIndex).abs() > 1) {
        _controller.jumpToPage(newIndex);
      } else {
        _controller.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index < 0 || index >= widget.candidates.length) return;
    widget.onSelected(widget.candidates[index].id);
  }

  void _onPageChanged(int index) {
    if (index == _selectedIndex) return;
    _select(index);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.candidates.isEmpty) {
      return KeyEventResult.ignored;
    }
    final current = _selectedIndex;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => current - 1,
      LogicalKeyboardKey.arrowRight => current + 1,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => widget.candidates.length - 1,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    final clamped = next < 0
        ? 0
        : next >= widget.candidates.length
            ? widget.candidates.length - 1
            : next;
    _select(clamped);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ProjectWizardLocalizations.of(context);
    if (widget.candidates.isEmpty) {
      return Center(child: Text(l10n.noCandidates));
    }
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.candidates.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final candidate = widget.candidates[index];
                final selected = candidate.id == widget.selectedId;
                return Semantics(
                  selected: selected,
                  label: l10n.candidatePosition(
                    candidate.title,
                    index + 1,
                    widget.candidates.length,
                  ),
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            candidate.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: WizardPreviewCanvas(scene: candidate.scene),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Semantics(
            liveRegion: true,
            label: l10n.selectedCandidate(
              _selectedIndex + 1,
              widget.candidates.length,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${_selectedIndex + 1} / ${widget.candidates.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class WizardPreviewCanvas extends StatelessWidget {
  const WizardPreviewCanvas({required this.scene, super.key});

  final WizardPreviewScene scene;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: scene.semanticLabel,
        child: CustomPaint(
          painter: _WizardPreviewPainter(
            scene: scene,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          child: const SizedBox.expand(),
        ),
      );
}

final class _WizardPreviewPainter extends CustomPainter {
  const _WizardPreviewPainter({required this.scene, required this.color});

  final WizardPreviewScene scene;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final horizontalScale = (size.width / scene.width).clamp(0.05, 100.0);
    final verticalScale = (size.height / scene.height).clamp(0.05, 100.0);
    final fitted =
        horizontalScale < verticalScale ? horizontalScale : verticalScale;
    final dx = (size.width - scene.width * fitted) / 2;
    final dy = (size.height - scene.height * fitted) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(fitted);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final element in scene.elements) {
      if (element is WizardPreviewRect) {
        canvas.drawRect(
          Rect.fromLTWH(
            element.x,
            element.y,
            element.width,
            element.height,
          ),
          stroke,
        );
      } else if (element is WizardPreviewLine) {
        canvas.drawLine(
          Offset(element.x1, element.y1),
          Offset(element.x2, element.y2),
          stroke,
        );
      } else if (element is WizardPreviewText) {
        final painter = TextPainter(
          text: TextSpan(
            text: element.text,
            style: TextStyle(color: color, fontSize: 13),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: scene.width);
        painter.paint(canvas, Offset(element.x, element.y - painter.height));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WizardPreviewPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.color != color;
}
