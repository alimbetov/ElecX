# ElecX R4 Native Golden Journey

Независимый аудит macOS production entrypoint `lib/main.dart`, 20 ноября 2026.

Ветка: `feat/p12a8-engineering-preview-diff`. Baseline: `048b50533ef8688f1923329c68958f9c3be3896a`. Исправления находятся в следующем коммите этой ветки (точный идентификатор см. Git history; отчёт входит в тот же коммит).

**Вердикт: R4 BLOCKED — NO MERGE TO MAIN.** Локальный сценарий устройства/портов/кабеля/сохранения выполнен в настоящем приложении. Полная квартира с межкомнатной ручной проводкой не квалифицирована. Это не GUI BLOCKED: управление настоящим macOS GUI доступно.

- [Окружение](environment.md)
- [Smoke и regression](smoke-results.md)
- [Матрица Golden Journey](golden-journey-results.md)
- [Визуальная проверка](visual-review.md)
- [Дефекты](defect-register.md)
- [Release gate](release-gate.md)
- [Первичные наблюдения до исправлений](baseline-findings.md)

Скриншоты сняты с настоящего приложения. JSON в logs читался после GUI-операций для сравнения, не использовался для создания модели. Старый пользовательский проект и его аварийная копия не перезаписывались.

Точный SHA исправленного кода: `925aa0fc585fc957180097741c8dd29daeabb370`. Итоговые format/analyze/test относятся к этому содержимому. Отчёт добавлен следующим документальным коммитом.
