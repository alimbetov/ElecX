# R4 — промежуточная квалификация

**PARTIAL. Релиз/merge запрещён до полного native E2E PASS.**

- Ветка: `feat/r4-first-complete-apartment-wiring` (одна R4 ветка).
- Fetch проверил настоящий origin/main: `2607ffe3ab9d827335dfee71aa80b7063f5d6862`.
- PR #33: https://github.com/alimbetov/ElecX/pull/33 — merged в P12 target, merge SHA `048b50533ef8688f1923329c68958f9c3be3896a`. Это не означает native qualification PASS и не означает наличие исправлений в main.
- База R4: origin/main + обычный merge P12 `988eac1b861595ae858128c42563c5890741c6bf`.
- Fixture: `ad8e3006c42c670d30a71dd08f50c09496e80f7d`.
- Финальный код/тесты этапа: `e77df3c7d2dc2f5f477d981c6bcf38d394957d1e`.
- Локально: 2107 tests PASS, analyzer PASS, format PASS. Native: квартира/13 устройств/Save-Quit-Reopen PASS; полноценная wiring схема NOT RUN/BLOCKED.
- Все 6 required CI одного R4 SHA: **не квалифицированы**. Результаты P12 не переиспользуются для R4.
- R4 PR не создан: пользователь требует создавать его после полного GREEN. Ни main, ни release не сливались.
- Оставшиеся P0: doors/adjacency/physical passage ownership; canonical multi-load grouping и правильная lighting topology; apartment-wide proposal/Diff/atomic Apply; route editing и full Save/Reopen native E2E.

Это отчёт о проверенном этапе, а не объявление R4 завершённым. Полный E2E не может быть заменён количеством unit-тестов.
