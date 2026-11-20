# Smoke и regression

| Проверка | Baseline 048b5053 | Исправления |
|---|---|---|
| pub get | PASS | зависимости не обновлялись |
| format | PASS, 952 файла, 0 изменений | PASS, 953 файла, 0 изменений |
| analyze | PASS, no issues | PASS, no issues |
| flutter test | PASS, 2105 | PASS, 2109 (2 мин 11 с) |
| focused regression | До исправлений ожидаемые FAIL сохранены | PASS, 27 тестов |
| Native production Debug build/launch | PASS | исправления отображения проверены hot reload; отдельный clean build/relaunch всей финальной ревизии NOT TESTED |
| Native локальный Save/Quit/Reopen | PASS | полный повтор после всех исправлений NOT TESTED |

2105/2109 — общее число выполненных unit/widget тестов из flutter test, без отдельного native integration-suite. Native действия выполнялись отдельно мышью через CUA. Flaky тестов в успешных полных прогонах не наблюдалось; повторные стресс-прогоны не выполнялись.

Evidence: logs/format-baseline.log, analyze-baseline.log, test-baseline.log; logs/format-final.log, analyze-final.log, test-final.log, regression-final.log.

История отладки сохранена: regression-red.log — намеренно показанные исходные дефекты; canonical-host-regression.log — промежуточная утечка SemanticsHandle в новом тесте. Она исправлена, итоговые 27/2109 проходят. В native-baseline-reopen.log также могут находиться промежуточные ошибки hot reload во время редактирования; это не результат окончательного clean build и не основание объявлять весь native journey GREEN.

Точный SHA исправленного кода: `925aa0fc585fc957180097741c8dd29daeabb370`. Итоговые format/analyze/test относятся к этому содержимому. Отчёт добавлен следующим документальным коммитом.
