# R4 — выполнение тестов

Toolchain: Flutter 3.47.7 / Dart 3.13.5, macOS arm64. Worktree ElecX-p12-r3-audit, ветка R4. Логи вне Git: ElecX-r4-evidence-20261113 рядом с worktree.

| Фаза / команда | Результат | Лог |
|---|---|---|
| flutter --no-version-check test --no-pub test/canonical_editor_demo_generation_test.dart (RED) | expected Коридор, actual Санузел | fixture-red.log |
| Тот же тест после fixture | 2 PASS; 13 устройств, 0 предварительно applied routes, JSON IDs stable | fixture-green.log |
| test/plan_p2_cable_overlay_widget_test.dart RED | plan-component отсутствует | plan-red.log |
| Projector + overlay + fixture | 7 PASS, первая версия | plan-green.log |
| Production Hub all-room test RED | Розетка 1 не видна, selected-room-only resolution | plan-all-rooms-red.log |
| Hub + projector + layer overlay после исправления | 7 PASS | plan-all-rooms-green.log |
| flutter analyze --no-pub (первый) | 1 lint, добавлены фигурные скобки | analyze.log |
| flutter --no-version-check analyze --no-pub (финальный) | PASS, no issues | analyze-final.log |
| Полный flutter test, первая версия | 2106 PASS; не включает поздний all-room regression | full.log |
| Полный flutter --no-version-check test --no-pub, финальная версия | 2107 PASS, 2m11s | full-final.log |
| dart format --output=none --set-exit-if-changed lib test qualification_test tool integration_test test_driver | PASS, 953 files, 0 changes | format.log |
| flutter --no-version-check run --no-pub -d macos -t lib/main.dart | native build/start PASS; production GUI отдельно | native.log, native-plan.log, native-final.log |

Перед full-final завершены все code/test изменения. RED-тесты не отключены и не ослаблены. Неудовлетворённые требования полного R4 перечислены отдельно; проходящие 2107 тестов не объявлены полным E2E. Повторное присоединение CUA после Quit временно давало noWindowsAvailable; reset CUA восстановил управление, после чего реальная финальная проверка выполнена.
