# R4 — трассировка требований

Это промежуточная матрица, не релизная квалификация.

| Требование | Код / проверка | Фактический статус |
|---|---|---|
| Одна ветка, сохранить P12 | feat/r4-first-complete-apartment-wiring; merge 988eac1b | выполнено |
| Четыре помещения и 13 устройств через GUI | CanonicalEditorDemoGenerator; ProjectHubScreen; canonical_editor_demo_generation_test; r4_apartment_production_workflow_test; native screenshots | PASS для создания/видимости |
| Каноническая геометрия/ID помещений | RoomRectangleAuthoringService; production materializer; persisted canonical repository | PASS |
| Двери и semantic adjacency | ProjectOpeningEntity / ProjectSpaceAdjacencyEntity существуют; fixture не создаёт их | OPEN |
| S1–S3 по две розетки, L1–L3 с управлением | EngineeringCircuit поддерживает ветвление; production P2 connection UI создаёт одну группу на нагрузку | OPEN |
| L/N/PE и коммутируемая фаза | Defaults power/control ports не доказывают conductor topology | OPEN / NOT QUALIFIED |
| Межкомнатная физическая трасса | BoundaryConstructionTransitionResolver; manual physical commit; apartment graph не подключён | BLOCKED в R4 workflow |
| Проложить электропроводку | Команда отсутствует; существующий AUTO — selected pair | OPEN |
| Preview/Diff/Apply всей схемы | ReservedProjectMutationCoordinator имеется; квартирного wiring command нет | OPEN |
| Оборудование на общем плане | editable_spatial_canvas.dart; production Hub widget + native screenshot03 | PASS |
| Canonical-wall route projection | PlanCableRouteProjector; plan_cable_route_projector_test | PASS для проекции существующих маршрутов, не R4 wiring |
| Ручное редактирование трасс | CableRouteEditSession/constraints существуют; квартирный сценарий не принят | PARTIAL |
| Save/Quit/Reopen | 4 помещения, 13 устройств восстановлены; routes=0 | PARTIAL |
| Шесть CI одного SHA + native full E2E | Не достигнуто | NOT QUALIFIED |
| Новые многоэтажные функции | Не разрабатывались | соблюдено |
