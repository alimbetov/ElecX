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

final class PreviewViewportState extends ChangeNotifier {
  PreviewViewportState() {
    transformationController.addListener(_onMatrixChanged);
  }

  static const double minScale = 1.0;
  static const double maxScale = 8.0;
  static const double zoomStep = 1.25;

  final TransformationController transformationController =
      TransformationController();

  double get scale => transformationController.value.getMaxScaleOnAxis();

  void zoomIn() => _setScale(scale * zoomStep);
  void zoomOut() => _setScale(scale / zoomStep);
  void resetView() => transformationController.value = Matrix4.identity();

  void _setScale(double requestedScale) {
    final next = requestedScale.clamp(minScale, maxScale).toDouble();
    transformationController.value = Matrix4.diagonal3Values(next, next, 1);
  }

  void _onMatrixChanged() => notifyListeners();

  @override
  void dispose() {
    transformationController.removeListener(_onMatrixChanged);
    transformationController.dispose();
    super.dispose();
  }
}

final class WizardCandidateCarousel extends StatefulWidget {
  const WizardCandidateCarousel({
    required this.candidates,
    required this.selectedId,
    required this.onSelected,
    this.viewportState,
    super.key,
  });

  final List<WizardCandidateCard> candidates;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final PreviewViewportState? viewportState;

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
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
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
    final materialL10n = MaterialLocalizations.of(context);
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
                            child: WizardPreviewCanvas(
                              scene: candidate.scene,
                              viewportState: widget.viewportState,
                            ),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: materialL10n.previousPageTooltip,
                    button: true,
                    enabled: _selectedIndex > 0,
                    child: ExcludeSemantics(
                      child: IconButton(
                        key: const ValueKey('wizard-candidate-previous'),
                        onPressed: _selectedIndex > 0
                            ? () => _select(_selectedIndex - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 64),
                    child: Text(
                      '${_selectedIndex + 1} / ${widget.candidates.length}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Semantics(
                    label: materialL10n.nextPageTooltip,
                    button: true,
                    enabled: _selectedIndex < widget.candidates.length - 1,
                    child: ExcludeSemantics(
                      child: IconButton(
                        key: const ValueKey('wizard-candidate-next'),
                        onPressed: _selectedIndex < widget.candidates.length - 1
                            ? () => _select(_selectedIndex + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class WizardPreviewCanvas extends StatefulWidget {
  const WizardPreviewCanvas(
      {required this.scene, this.viewportState, super.key});

  final WizardPreviewScene scene;
  final PreviewViewportState? viewportState;

  @override
  State<WizardPreviewCanvas> createState() => _WizardPreviewCanvasState();
}

final class _WizardPreviewCanvasState extends State<WizardPreviewCanvas> {
  PreviewViewportState? _ownedViewportState;

  PreviewViewportState get _viewportState =>
      widget.viewportState ?? (_ownedViewportState ??= PreviewViewportState());

  @override
  void didUpdateWidget(covariant WizardPreviewCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportState == null && widget.viewportState != null) {
      _ownedViewportState?.dispose();
      _ownedViewportState = null;
    }
  }

  @override
  void dispose() {
    _ownedViewportState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = _viewportState;
    final l10n = ProjectWizardLocalizations.of(context);
    return Semantics(
      image: true,
      label: widget.scene.semanticLabel,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: viewport.transformationController,
              minScale: PreviewViewportState.minScale,
              maxScale: PreviewViewportState.maxScale,
              panEnabled: true,
              scaleEnabled: true,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: widget.scene.width,
                    height: widget.scene.height,
                    child: CustomPaint(
                      painter: _WizardPreviewPainter(
                        scene: widget.scene,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('wizard-preview-zoom-out'),
                    tooltip: l10n.zoomOut,
                    onPressed: viewport.zoomOut,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    key: const ValueKey('wizard-preview-reset-view'),
                    tooltip: l10n.resetView,
                    onPressed: viewport.resetView,
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                  IconButton(
                    key: const ValueKey('wizard-preview-zoom-in'),
                    tooltip: l10n.zoomIn,
                    onPressed: viewport.zoomIn,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _WizardPreviewPainter extends CustomPainter {
  const _WizardPreviewPainter({required this.scene, required this.color});

  final WizardPreviewScene scene;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final element in scene.elements) {
      if (element is WizardPreviewRect) {
        canvas.drawRect(
          Rect.fromLTWH(element.x, element.y, element.width, element.height),
          stroke,
        );
      } else if (element is WizardPreviewLine) {
        canvas.drawLine(
          Offset(element.x1, element.y1),
          Offset(element.x2, element.y2),
          stroke,
        );
      } else if (element is WizardPreviewPolygon) {
        final path = Path();
        final first = element.points.first;
        path.moveTo(first.x, first.y);
        for (final point in element.points.skip(1)) {
          path.lineTo(point.x, point.y);
        }
        path.close();
        canvas.drawPath(path, stroke);
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
  }

  @override
  bool shouldRepaint(covariant _WizardPreviewPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.color != color;
}
