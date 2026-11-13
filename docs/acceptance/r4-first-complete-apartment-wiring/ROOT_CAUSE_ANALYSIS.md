# R4 — аудит пользовательского результата

Дата: 2026-11-13. Статус: PARTIAL, не завершённая электропроводка. Проверены production-код и main.dart GUI. База origin/main `2607ffe3ab9d827335dfee71aa80b7063f5d6862`; P12 PR #33 фактически merged в `048b50533ef8688f1923329c68958f9c3be3896a`. Он включён обычным merge `988eac1b`, без предположения о наличии исправлений в main. Локальный main `6a1c93ef` и его изменения analysis_options.yaml/pubspec.lock не тронуты.

Все пути ниже относительно корня репозитория.

| Вопрос | Проверенный механизм / отсутствующая связь |
|---|---|
| 1. Почему щит → розетка недоступен? | `RoomCircuitPanel` (`lib/src/features/editor/room_circuit_panel.dart`, фильтр boards) допускает только `item.surface.spaceId == selected.surface.spaceId`. `EditorP2Session.connectLoadToBoard` (`editor_p2_session.dart`) также возвращает null для разных комнат. GUI: выбранная розетка гостиной сообщает «В этой комнате нет щита», хотя щит коридора виден на плане. |
| 2. Почему блокируются комнаты? | Комнатный AUTO `_buildSegmentsBetween` использует `AutoRouteGraphBuilder` для одного EngineeringSpace. Кнопка группы не строит цепь через construction-aware transitions. `BoundaryConstructionTransitionResolver` существует отдельно и требует реальную геометрию обеих поверхностей, совпадающие материалы/толщины; электрическая совместимость этого не заменяет. |
| 3. UI проходок? | `BoundaryEditPanel`/`OpeningEditDraft` редактируют архитектурные проёмы; `CanonicalWallConstructionEditContract` редактирует профиль стены. `SurfaceTransitionNavigator` и `PhysicalManualCableDraftPersistence` поддерживают физические переходы/продолжение маршрута. Это не готовый квартирный мастер подтверждения всех проходок. В новой квартире GUI фактически показывает No canonical openings / No canonical adjacency. Полная последовательность создания допустимого межкомнатного пути ещё не принята. |
| 4. Цепь, кабель, маршрут? | `CircuitCableRegistry.registerBundle` связывает CircuitRef → CableIdentity → ElectricalCableRoute и проверяет окончания. Но авторинг оборудования/маршрутов идёт через EditorP2State; `CanonicalEngineeringGraph`, `EngineeringCircuit` и project-owned engineering state не становятся автоматически результатом размещения P2. `P12EngineeringReviewPanel` явно сообщает, что прототип групп не заменяет P11/P12. Нужен общий production write/preview bridge, а не ещё одна модель. |
| 5. Несколько розеток в группе? | `EngineeringCircuit.connectionIds` уже допускает ветвление. Registry допускает несколько cable bundles с неизменным общим CircuitRef. Но `connectLoadToBoard` всегда создаёт новый circuit-$suffix для одной нагрузки, а `circuitBundleForLoad` возвращает первое назначение. UI не предоставляет полноценное объединение двух потребителей в S1/S2/S3. |
| 6. Выключатели и светильники? | `ElectricalComponentDefaults` (`electrical_placement.dart`) имеет power-in/control-out у выключателя, power-in/control-in/earth у лампы. `ElectricalPortCompatibility` соединяет powerOut→powerIn и controlOut→controlIn. Defaults не задают полную схему L/N/PE и коммутируемой фазы. Наличие control route или щит→лампа нельзя признать доказательством правильного силового управления. Это остаётся незакрытым R4.2. |
| 7. Работает ли AUTO квартиры? | `UnifiedEditorIconToolbar` вызывает `EditorP2Session.autoRouteSelectedPair`; ровно два выбранных устройства, один room graph. Это работает для локальной пары, не является командой проектирования шести групп квартиры. Общей команды «Проложить электропроводку» пока нет. |
| 8. Видны ли завершённые маршруты? | `_PlanPainter`/`PlanCableRouteProjector` уже рисовали committed P2 segments, но canonical wall без wallIndex пропускался. Исправлено: актуальная CanonicalRoomBoundaryProjection проверяет геометрию каждой комнаты, передаёт реальный edge order; неизвестный edge пропускается. Ранее общий план вообще не рисовал компоненты. Теперь все 13 видимы; слои соблюдаются. Межкомнатные линии не выдумываются. |
| 9. Сохранение? | `EditorProjectDocument.capture/restore` и `JsonFileEditorProjectStore` сохраняют P2 components/routes/bundles/penetrations/constraints в v9. Сохранённая R4-квартира реально закрыта и открыта: 13 устройств с прежними ID. Трасс сейчас 0; это не доказательство сохранения готовой R4-схемы. |
| 10. Почему тесты были зелёными? | Старый `canonical_editor_demo_generation_test` проверял четыре комнаты без оборудования; `plan_p2_cable_overlay_widget_test` проверял одну локальную трассу с ordinal-wall; доменные penetration fixtures не проходили Hub→вся квартира→Apply→Quit/Reopen. Новый `r4_apartment_production_workflow_test` воспроизвёл отдельный RED: видны только selected-room wall devices; исправление проверяет все 13 устройств на плане. Полный acceptance пока не покрыт. |

## Фактически устранено

`ad8e3006`: production «Квартира R4» вместо пустого demo — гостиная 4×3.5 м, спальня 4×3.5 м, кухня 3.5×3.5 м, коридор 11.5×1.5 м; 6 розеток, 3 выключателя, 3 лампы, 1 щит. Комнаты создаются RoomRectangleAuthoringService на общем canonical timeline; оборудование — существующим EditorP2Session.placeComponent, не JSON-инъекцией.

`e77df3c7`: отображение оборудования на плане, проекция canonical-wall трасс по проверенным edge IDs, тест Hub workflow. Это использует существующие данные P2 и поверхностные трансформации. Не добавлены фиктивные проходки, автоматические защиты/сечения или утверждённая схема.

## Следующие необходимые изменения

1. Общая topology transaction поверх CanonicalEngineeringGraph/EngineeringCircuit/CircuitCableRegistry, с несколькими нагрузками и явно проверяемыми проводниками освещения.
2. Canonical doors/adjacency/physical passage authoring, затем apartment routing graph через подтверждённые стены. Дверь сама по себе не разрешает кабельный проход.
3. Frozen wiring proposal → существующий ReservedProjectMutationCoordinator → Diff → atomic Apply, отдельно от P12 нормативного выбора.
4. Ручные обязательные точки/переназначение проходок с повторной геометрической проверкой, Save/Quit/Reopen всей схемы и полноценный native acceptance.
