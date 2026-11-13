# Routing defect register

Confirmed on baseline 9f15d985, native macOS GUI. No P0 corruption observed; coverage is limited.

| ID | Severity | Finding / reproduction | Classification / disposition |
|---|---|---|---|
| R-D01 | P1 | Place one Corridor board, select Living wall socket: “В этой комнате нет щита”. Cannot select upstream in another room. | UI/domain integration gap; room_circuit_panel filters SpaceId; editor_p2_session also rejects cross-space. Do not remove guard without physical-path/canonical transaction contract. |
| R-D02 | P1 | Draw touching rooms; inspector has no canonical adjacency/openings, canonical wall editor unavailable. Switch room during manual draft: draft disappears, SELECT ready. | Qualified construction/passages authoring blocked in this instance. No teleporting patch. |
| R-D03 | P1 | Four desired canonical circuits and branched C-03 cannot be authored with observed prototype one-load groups. P12 still shows 0 P11. | Canonical authoring/junction integration acceptance gap. Binary route is insufficient proof of branch support. |
| R-D04 | P2 | Persisted route-1 has two segments without IDs, both anchorIds empty. | Stable segment identity contract gap; route IDs do persist. Requires reviewed compatibility strategy. |
| R-D05 | P2 | Switch control route from Wall/Ceiling to Plan: only room geometry visible, no route/equipment overlay (15). | CAD overview integration gap; no claim that all layer states were exhaustively checked. |
| R-D06 | P1 dependency | P12 production source missing, explicit unavailable diagnostics; no authoritative diff/stale GUI journey. | Honest fail-closed behavior; source/evidence integration remains prerequisite, not a safety-gate bug. |

Validated behavior: invalid manual route rejected; delete connected prototype load removes route/bundle; undo restores exact data; save/reopen retains local route. Remaining adversarial scenarios are explicitly not executed in journey matrix. No quick runtime fix was justified: high-impact gaps need architecture contract and owner review, not bypasses.
