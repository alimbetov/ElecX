import 'package:flutter/material.dart';

import '../projects/project_hub_screen.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _pin = '';

  void _press(String digit) {
    if (_pin.length == 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const ProjectHubScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ElecX', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                const Text('Быстрый вход инженера'),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final filled = index < _pin.length;
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        color: filled
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    );
                  }),
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
                            : TextButton(
                                onPressed: value == '⌫'
                                    ? () => setState(() {
                                        if (_pin.isNotEmpty) {
                                          _pin = _pin.substring(
                                            0,
                                            _pin.length - 1,
                                          );
                                        }
                                      })
                                    : () => _press(value),
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
                  'Prototype: PIN — локальная быстрая разблокировка, '
                  'не замена учётной записи.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
