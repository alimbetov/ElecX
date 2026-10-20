from pathlib import Path
import subprocess

BASELINE = '252f814a5f4ace569c934366f9bcf1413039982b'
CANVAS = 'lib/src/features/editor/surface_canvas.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one match, got {count}')
    return text.replace(old, new, 1)


text = subprocess.check_output(
    ['git', 'show', f'{BASELINE}:{CANVAS}'],
    text=True,
)

text = replace_once(
    text,
    """    _routeFlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
""",
    """    _routeFlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
""",
    'route flow init',
)

text = replace_once(
    text,
    """    controller.cableUi.addListener(_onInteractionChanged);
  }

  @override
  void didUpdateWidget""",
    """    controller.cableUi.addListener(_onInteractionChanged);
    _syncRouteFlowAnimation();
  }

  @override
  void didUpdateWidget""",
    'init sync',
)

text = replace_once(
    text,
    """      controller.cableUi.addListener(_onInteractionChanged);
    }
  }

  @override
  void dispose""",
    """      controller.cableUi.addListener(_onInteractionChanged);
      _syncRouteFlowAnimation();
    }
  }

  @override
  void dispose""",
    'controller replacement sync',
)

text = replace_once(
    text,
    """  void _onViewportCommand() {
""",
    """  void _syncRouteFlowAnimation() {
    final shouldAnimate = controller.routeSelection.selectedRouteId != null;
    if (shouldAnimate) {
      if (!_routeFlow.isAnimating) _routeFlow.repeat();
      return;
    }
    if (_routeFlow.isAnimating) _routeFlow.stop();
    if (_routeFlow.value != 0) _routeFlow.value = 0;
  }

  void _onViewportCommand() {
""",
    'flow sync helper',
)

text = replace_once(
    text,
    """  void _onP2Changed() {
    if (mounted) setState(() {});
  }
""",
    """  void _onP2Changed() {
    controller.routeSelection.normalize();
    _syncRouteFlowAnimation();
    if (mounted) setState(() {});
  }
""",
    'p2 sync',
)

text = replace_once(
    text,
    """  void _onRouteChanged() {
    controller.routeSelection.normalize();
    if (mounted) setState(() {});
  }
""",
    """  void _onRouteChanged() {
    controller.routeSelection.normalize();
    _syncRouteFlowAnimation();
    if (mounted) setState(() {});
  }
""",
    'route sync',
)

text = replace_once(
    text,
    """      }
    }
  }

  void _drawHostedSegmentsOnHost(""",
    """      }
      for (var edge = 0; edge < segment.points.length - 1; edge++) {
        final a = projection.surfaceToViewport(segment.points[edge]);
        final b = projection.surfaceToViewport(segment.points[edge + 1]);
        final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        canvas.drawRect(
          Rect.fromCenter(center: midpoint, width: 9, height: 9),
          Paint()
            ..style = PaintingStyle.fill
            ..color = controller.cableUi.isSegmentLocked(selected.id, s)
                ? scheme.outline
                : scheme.tertiary,
        );
      }
    }
  }

  void _drawHostedSegmentsOnHost(""",
    'segment handle visibility',
)

Path(CANVAS).write_text(text)

test_path = Path('test/surface_canvas_interaction_test.dart')
test_text = test_path.read_text()
import_line = "import 'package:elecx/src/features/editor/cable_edit_access.dart';\n"
if import_line not in test_text:
    anchor = "import 'package:elecx/src/features/editor/editor_controller.dart';\n"
    if anchor not in test_text:
        raise SystemExit('test import anchor missing')
    test_text = test_text.replace(anchor, import_line + anchor, 1)
test_path.write_text(test_text)
