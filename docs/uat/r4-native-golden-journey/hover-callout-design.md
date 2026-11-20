# ElecX UX-HOVER-01 — Smart Engineering Callout
## Техническое задание и критерии native-приёмки

- **Repository:** `alimbetov/ElecX`
- **Branch:** `feat/p12a8-engineering-preview-diff`
- **Status:** SPEC / IMPLEMENTATION NOT YET QUALIFIED
- **Scope:** Flutter Desktop, инженерный 2D-план
- **Release boundary:** R4 UX Native Golden Journey остаётся самостоятельным обязательным gate.
- **Restrictions:** NO MERGE TO MAIN; NO NEW BRANCH; NO AUTO-ROUTING EXPANSION.

## 1. Назначение

При наведении указателя на инженерный объект показывать **одну** контекстную выноску: графическая линия от объекта к компактной рамке с типом, названием и назначением. Линия и рамка мягко светятся, интенсивность свечения плавно пульсирует. При уходе курсора вся выноска исчезает. Это **read-only presentation layer**: выноска никогда не изменяет инженерную модель, топологию, выбор портов, геометрию трассы и сериализованные данные проекта.

**Целевые объекты:** розетки, выключатели, светильники, электрощиты; кабельные трассы и сегменты — при наличии корректного hit-testing и достоверных метаданных.

**Не входит в scope:** автоматическая генерация маршрутов, изменения схемы EngineeringGraph, доменных ID, электрических правил, persistence, новая система выбора объектов.

## 2. Принципы UX

1. Наведение (pointer hover) не равно фокусу клавиатуры и не равно выделению (selection). Эти состояния независимы.
2. Hover **не перехватывает** pointer events: карточка и линия рендерятся через `IgnorePointer` либо эквивалентный неинтерактивный слой.
3. Приоритет: active drag / route-edit / connecting ports > select > hover callout.
4. Одновременно видна только одна выноска, без закреплённых или «застрявших» экземпляров.
5. Не выдавать неизвестные технические значения (мощность, ток, статус подключения) за факты.
6. Пульсация ограничена свечением/opacity, **не меняет размеры, позицию и hit areas**.
7. При отключённой анимации / reduced motion — статический callout без пульсации.
8. Ввод с клавиатуры: для доступных focusable объектов предусмотреть эквивалентное текстовое описание через существующий semantics/focus UX; hover не должен нарушать shortcut/navigation.

## 3. Функциональные сценарии

| ID | Событие | Ожидаемое поведение |
| --- | --- | --- |
| UX-01 | Cursor enters hit region устройства | После ~150 ms появляется выноска без изменения selection |
| UX-02 | Pointer leaves target | Отменить pending show; если показана — fade-out ~120 ms с полным удалением |
| UX-03 | Hover на другом объекте | Старый target отменяется, новый отображается после debounce, без двух выносок |
| UX-04 | Начало drag | Скрыть выноску немедленно; drag продолжается штатно |
| UX-05 | Port connection / cable routing / waypoint edit | Выноску не показывать и не перехватывать событие |
| UX-06 | Pan / zoom / viewport resize | Правильно пересчитать anchor в viewport; не «оторвать» линию |
| UX-07 | Удаление объекта, смена страницы/проекта | Clear pending timers, animation and overlay references |
| UX-08 | Наведение на плотный кластер / порт поверх корпуса | Использовать приоритет существующего hit-testing; не красть попадание у порта |
| UX-09 | Наведение у края viewport | Карточка видима и не перекрывает объект по возможности |
| UX-10 | Missing optional metadata | Не выводить строку; обязательные имя/тип — из реальной модели или безопасный нейтральный fallback |
| UX-11 | Theme change | Контрастные цвета, без жёстко вшитых цветов для одной темы |
| UX-12 | Reduced motion | Нет pulse, текст и линия остаются читаемыми |

### Контент

- **Тип:** локализованный тип объекта (например, «Розетка»).
- **Название:** фактическое displayName/label или устойчивый идентификатор объекта.
- **Назначение:** данное пользователем/моделью описание; если отсутствует — нейтральная фраза по типу, явно без утверждений о конкретной функции подключения.
- **Опционально:** помещение; группа/цепь/статус — только если достоверны.
- Длинные поля должны обрезаться/переноситься; никаких горизонтальных переполнений; локализация не должна ломать layout.

## 4. Визуальная система (ориентиры, не блокирующие hardcoded значения)

| Элемент | Рекомендация |
| --- | --- |
| Пауза перед появлением | 150 ms (допуск 100–200 ms) |
| Fade-in | 140 ms |
| Fade-out | 120 ms |
| Pulse | 1.6 s, easeInOut, низкая амплитуда |
| Stroke | 1–1.5 logical px |
| Card radius | 8–12 logical px |
| Max card width | 240–280 logical px, с адаптацией на малом viewport |
| Shadow/glow | Умеренный, без вспышек, без изменения layout |
| Offset from target | Достаточен для читаемости и видимости объекта |

Линия должна приходить к границе рамки. Геометрия может быть elbow / 2-segment. Выбирать сторону с учётом свободного пространства; применять clamp внутри viewport. Линия и рамка должны скрываться как единая сущность.

## 5. Предварительный архитектурный аудит (обязателен до реализации)

Codex должен определить и письменно зафиксировать **реальные** классы/файлы:
- editor canvas, объектный painter/overlay и зум/пан/coordinate transforms;
- hit testing для устройств, портов, кабельных сегментов и waypoints;
- selection, pointer lifecycle, drag, connection и routing modes;
- источник labels, object IDs, назначений и room associations;
- существующие design tokens, темы, локализацию и semantics;
- текущие тесты редактора и native entrypoint `lib/main.dart`.

**Повторное использование существующих сервисов — обязательно.** Не создавать вторую независимую систему hit-testing. Наименования ниже — концептуальные, а не предписание создавать все классы.

### Рекомендуемое разделение

- `HoverTarget`: immutable view model {id, kind, displayName, purpose?, roomName?, anchorWorld, boundsWorld?}.
- `HoverCalloutCoordinator`: явное состояние `hidden / pending / visible / fading`, отмена таймеров, приоритет interaction modes, одно активное target ID.
- `CalloutPlacement`: перевод world → viewport, clipping, side selection, card/leader layout.
- `CalloutOverlay`: `IgnorePointer`, карточка, CustomPainter линии, один animation controller; минимизация repaint.

**Инварианты координат:** единый pipeline world ↔ viewport; `anchor` должен принадлежать исходному объекту и оставаться корректным при pan/zoom. Flutter global/screen coordinates не смешивать с canvas-local без явной конверсии.

**Инварианты жизненного цикла:** dispose timers/controllers/overlays; late callbacks игнорировать с generation token или аналогом; не делать setState после dispose; при PointerHoverEvent не создавать новый animation controller. Никакой персистенции callout, его координат или состояния.

## 6. Безопасность интеграции с R4

Обязательные регрессии:
1. Размещение/выделение/перемещение розетки мышью.
2. Выбор электрического порта, соединение розетки со щитом.
3. Ручное создание и редактирование кабельной трассы, waypoints и переходы между поверхностями.
4. Повторное перемещение подключённой розетки с сохранением electrical connection.
5. Save → close → reopen; проверка неизменности идентичности объектов, endpoints и маршрута.
6. Undo/redo, если поддерживается этими командами, остаются корректными.

Любой новый P0/P1 по этим сценариям блокирует UX-HOVER-01. Успех UX-HOVER-01 **не заменяет** подтверждение полного R4 Golden Journey.

## 7. Тесты

### Automated

- pending delay, rapid enter/exit, cancel on target switch;
- single active callout; отсутствие «призрачных» overlays;
- suppression: drag, port-connect, routing, waypoint edit;
- no hit-test interference, including port overlap;
- world→viewport при pan/zoom и крайних scale;
- viewport edge placement, small windows, long localized text;
- theme, reduced motion, lifecycle/dispose;
- zero domain mutations, zero changes to serialized project snapshot;
- 1k+ hover transitions без накопления listeners/timers/overlays (stress or deterministic unit test).

### Native macOS GUI smoke

Запустить **обычный** `flutter run -d macos -t lib/main.dart` в реальном GUI; визуально проверить розетку, выключатель, светильник, щит, край окна, pan/zoom, drag suppression, портовое соединение и cable editing. Скриншоты снять из настоящего приложения (не mock render).

Для анимации одного скриншота недостаточно: приложить короткую screen recording либо последовательность time-stamped кадров и зафиксировать, что пульсация мягкая и не отвлекающая.

При отсутствии доступа к реальному GUI писать `GUI BLOCKED` и **не объявлять Native PASS**.

### Качество/производительность

`flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`. Записать реальное число PASS/FAIL. Оценить frame timings в native GUI; стремиться к 60 FPS при обычной сцене, не считать это универсальной гарантией. Пульсация должна перерисовывать только локальный overlay, не весь CAD canvas.

## 8. Порядок работы Codex

1. Убедиться, что checkout = `feat/p12a8-engineering-preview-diff`, зафиксировать HEAD и состояние worktree, не терять чужие изменения.
2. Выполнить baseline smoke/test и краткий аудит расположения кода.
3. Обновить этот документ фактическими файлами и архитектурными решениями (без необоснованных предположений).
4. Реализовать минимальное изменение на существующих механизмах pointer/hit-test/transform.
5. Добавить widget/unit/integration регрессии.
6. Повторно запустить analyzer и тесты.
7. Провести реальный native GUI smoke + снять evidence.
8. Исправить найденные дефекты и повторить проверки.
9. Сделать итоговую таблицу PASS/FAIL/BLOCKED/NOT TESTED; отдельно указать статус R4.

**Git restrictions:** никакого merge в `main`, создания веток, destructive reset, изменений в автоматической маршрутизации; commits только в текущую feature branch. Наличие грязного worktree не повод стирать данные.

## 9. Документация и evidence

Хранить результаты по путям:
- `docs/uat/r4-native-golden-journey/hover-callout-design.md` — это ТЗ;
- `docs/uat/r4-native-golden-journey/hover-callout-test-results.md`;
- `docs/uat/r4-native-golden-journey/hover-callout-visual-review.md`;
- `docs/uat/r4-native-golden-journey/hover-callout-defects.md`;
- `docs/uat/r4-native-golden-journey/screenshots/hc-*.png`;
- `docs/uat/r4-native-golden-journey/logs/`.

Отчёт обязан содержать точный SHA, OS/Flutter/Dart, изменённые файлы, полный test command output/summary, screenshot/video evidence, исходные и исправленные дефекты.

## 10. Acceptance matrix / Definition of Done

| Gate | PASS condition |
| --- | --- |
| HC-01 Hover object | Корректно показывает карточку и выноску |
| HC-02 Exit / switch | Не остаются старые или двойные выноски |
| HC-03 Content | Верный тип, имя, назначение; нет вымышленных полей |
| HC-04 Appearance | Мягкая пульсация без смещения; reduced motion работает |
| HC-05 Geometry | Anchor и рамка верны при zoom/pan и краях окна |
| HC-06 Interaction | Drag, selection, ports, routing и editing не нарушены |
| HC-07 Lifecycle | Нет отложенных callbacks после dispose / утечек |
| HC-08 Persistence | Project snapshot неизменен от hover |
| HC-09 Test gate | Automated tests + analyzer GREEN |
| HC-10 Native evidence | Реальный macOS GUI smoke со скриншотами и записью анимации |

Вердикты: `UX-HOVER PASS`, `PARTIAL`, `BLOCKED`, `NOT QUALIFIED`. Только **UX-HOVER PASS** после полного HC-01…HC-10 даёт статус готовности UX-HOVER-01. **R4 продолжает быть HOLD**, пока отдельная полная native Golden Journey не получила PASS.

## 11. Непосредственное поручение Codex

Изучи этот документ и исходный код **текущей** ветки. Сначала дополни архитектурный аудит конкретными файлами и baseline-результатами; затем внедри callout в существующий Flutter Desktop editor, добавь тесты и проведи реальный native smoke. Исправляй выявленные дефекты в границах scope. Не выдавай отсутствие GUI-проверки за PASS; не объединяй с main.
