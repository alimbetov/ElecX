# R4 — реестр дефектов

| ID | Приоритет | RED / причина | Исправление / статус |
|---|---|---|---|
| R4-D01 | P0 | Демо содержало Санузел вместо Коридора и 0 устройств; production demo test RED | ad8e3006: R4 fixture через production authoring, 13 устройств; 2 tests GREEN |
| R4-D02 | P0 | На плане нет оборудования; widget RED: plan-component не найден; native screenshot01 | e77df3c7: символы реальных placements, слои, выбор; GREEN |
| R4-D03 | P0 | Canonical стены пропускались projector; первая правка показывала лишь выбранную комнату; Hub test RED | e77df3c7: проверка каждой canonical boundary без зависимости от selection; Hub 13 devices GREEN; native screenshot03 |
| R4-D04 | P0 | Щит коридора не предлагается розетке: same-space filter в panel и connectLoadToBoard; native screenshot04 | OPEN: нужен физически валидированный apartment graph, не удаление проверки |
| R4-D05 | P0 | Одна группа на нагрузку; отсутствует production bridge к canonical branching circuits | OPEN |
| R4-D06 | P0 | Нет доказанной силовой схемы выключатель/лампа с L/N/PE | OPEN / NOT QUALIFIED |
| R4-D07 | P0 | Нет общей команды wiring proposal / Diff / atomic Apply | OPEN |
| R4-D08 | P0 | R4 fixture пока без doors/adjacency и подтверждённых проходок | OPEN; фиктивные переходы не создавались |

Ни один OPEN не считается PASS из-за зелёных unit-тестов. Нативная проверка первой версии D03 выявила дефект, который локальный single-room тест не ловил; это исправлено отдельным production Hub regression.
