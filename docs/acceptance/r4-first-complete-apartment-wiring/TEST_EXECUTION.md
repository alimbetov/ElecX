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

## Дополнение 2026-11-19

- Профильный прогон `cable_route_edit_session_test`, `cable_canvas_hit_testing_test`, `r4_apartment_production_workflow_test`: 15 PASS. Включает добавление изгибов с durable anchors, блокировку недопустимых preview, неподвижность концов, пакет из 8 новых трасс + существующая, 6 групп, Undo/Redo и вход из плана в редактор поверхности.
- RED при добавлении режима: несовпадение active wall ref и canonical route host. Исправлено разрешение host через проверенную проекцию.
- Тестовое ожидание pumpAndSettle заменено ограниченным pump только после перехода к выбранной трассе: её direction animation непрерывна. Проверки результата и идентичности host сохранены.
- Native GUI: изменение 5100→5500 мм, Undo/Redo, Save→Quit→Reopen; полное равенство сохранённых routes/components/circuitBundles.
- Финальный analyzer: no issues. Format: 959 files, 0 changes.

Полный финальный `flutter --no-version-check test --no-pub --reporter expanded`: **2109 PASS**, 2m29s (`full-trajectory.log`). Статический анализ и форматирование выполнены на том же содержимом кода.
