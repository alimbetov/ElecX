import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_shell_localizations.dart';
import '../projects/platform_project_hub_screen.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _pin = '';
  Timer? _unlockTimer;

  static final _digitKeys = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  void _press(String digit) {
    if (_pin.length == 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      _unlockTimer?.cancel();
      _unlockTimer = Timer(const Duration(milliseconds: 120), () {
        if (!mounted || _pin.length != 4) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const PlatformProjectHubScreen(),
          ),
        );
      });
    }
  }

  void _backspace() {
    _unlockTimer?.cancel();
    _unlockTimer = null;
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final digit = _digitKeys[event.logicalKey];
    if (digit != null) {
      _press(digit);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppShellLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ElecX',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(l10n.engineerQuickAccess),
                          const SizedBox(height: 32),
                          Semantics(
                            label: '${_pin.length} / 4',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(4, (index) {
                                final filled = index < _pin.length;
                                return Container(
                                  width: 16,
                                  height: 16,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    color: filled
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 28),
                          for (final row in const [
                            ['1', '2', '3'],
                            ['4', '5', '6'],
                            ['7', '8', '9'],
                            ['', '0', '⌫'],
                          ])
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: row.map((value) {
                                return SizedBox(
                                  width: 72,
                                  height: 60,
                                  child: value.isEmpty
                                      ? const SizedBox.shrink()
                                      : value == '⌫'
                                          ? Semantics(
                                              button: true,
                                              label: l10n.deleteLastDigit,
                                              child: ExcludeSemantics(
                                                child: TextButton(
                                                  onPressed: _backspace,
                                                  child: Text(
                                                    value,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineSmall,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : TextButton(
                                              onPressed: () => _press(value),
                                              child: Text(
                                                value,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall,
                                              ),
                                            ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.prototypePinExplanation,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
