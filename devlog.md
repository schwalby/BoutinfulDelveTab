# BountifulDelveTab — Development Archive

## Overview
A World of Warcraft addon for the Midnight expansion (patch 12.0) that adds a tab to the World Map
showing all Midnight delves and their current bountiful status. Built using LibWorldMapTabs by LanceDH.

---

## Iteration 1 — Initial Scaffold
**Goal:** Get a tab to appear on the world map at all.

**Approach:**
- Used `LibWorldMapTabs:CreateTab()` with `activeAtlas = "delves-bountiful"`
- Created a content frame via `CreateContentFrameForTab()`
- Content populated via `C_AreaPoiInfo.GetAreaPOIForMap(mapID)`
- Initialized on `PLAYER_LOGIN` inside a `pcall` for safe failure

**Problems discovered:**
- TOC `## Interface` was set to `110107` — incorrect for Midnight. Must be `120000`
- `C_AreaPoiInfo.GetAreaPOIForMap()` returned 0 results for all Midnight maps
- Tab icon did not render (atlas name unresolved in this context)

**Lessons:**
- Always use `120000` as the interface version for Midnight
- `C_AreaPoiInfo` is not how Midnight exposes delve POIs

---

## Iteration 2 — Discovering the Correct API
**Goal:** Find where delve data actually lives in Midnight.

**Debugging process (via `/run` commands in-game):**
- Confirmed `C_DelvesUI` exists but only contains companion/curio/season functions — no map data
- Confirmed `C_Delves` does not exist
- Dumped `WorldMapFrame.pinPools` keys — found `DELVEENTRANCEPINTEMPLATE` listed
- Querying the pool for active pins returned 0 even with delve icons visible on screen
- Dumped `WorldMapFrame:GetCanvas():GetChildren()` — found pins are unnamed frames
- Filtered canvas children by `pin.pinTemplate == "DelveEntrancePinTemplate"` — found 2 pins on Silvermoon map
- Dumped `pin.poiInfo` fields and confirmed:
  - `poiInfo.atlasName == "delves-regular"` for normal delves
  - `poiInfo.atlasName == "delves-bountiful"` for bountiful delves
  - `poiInfo.name` contains the delve name
  - `poiInfo.areaPoiID` contains the unique POI ID

**Approach:**
- Replaced `C_AreaPoiInfo` with canvas child iteration
- Filter by `pin.pinTemplate == "DelveEntrancePinTemplate"`
- Detect bountiful status via `pin.poiInfo.atlasName`
- Click handler forwarded to `pin:OnClick("LeftButton")`

**Problems discovered:**
- Click handler caused Lua error: `attempt to index a nil value` on `pin.owningMap`
  — pin's `owningMap` is nil when called outside the map's own click context

---

## Iteration 3 — Background Styling
**Goal:** Match the dark parchment background of the quest log panel.

**Debugging process:**
- Tried `DialogBorderDarkTemplate` — covered entire screen, unusable
- Tried `SetBackdrop()` — API does not exist in Midnight (removed by Blizzard)
- Used `/fstack` over the quest log panel — revealed `WORLDMAPFRAME.SCROLLCONTAINER.CHILD.TILEDBACKGROUND`
  and source from `SharedUIPanelTemplates.xml`
- Reviewed WorldQuestTab source files (`WorldQuestTab.xml`, `WorldQuestTabUtilities.xml`, `Templates.xml`)
- Found WQT uses:
  - `atlas="QuestLog-main-background"` on their list container background texture
  - `inherits="QuestLogBorderFrameTemplate"` for the border frame
  - `self.Bg:SetAlpha(0.65)` only applies to their fullscreen floating container, not the tab panel

**Solution:**
```lua
local bg = contentFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(contentFrame)
bg:SetAtlas("QuestLog-main-background", false)

local borderFrame = CreateFrame("Frame", nil, contentFrame, "QuestLogBorderFrameTemplate")
borderFrame:SetAllPoints(contentFrame)
```

---

## Iteration 4 — Hardcoded Delve List + Cache System
**Goal:** Show all delves even when the map is closed, with cached bountiful status.

**Problem with canvas-only approach:**
- Pins only exist in the canvas when the map is open AND showing a zone with delves
- Closing the map or navigating away clears the pins

**Solution:**
- Hardcoded all 10 Midnight delves with their `areaPoiID` values
- `ScanMapPins()` runs on every `OnMapChanged` event and caches bountiful status per `areaPoiID`
- Display list always shows all 10 delves, using cached status where available
- Three display states:
  - **Bountiful** — gold name, green "Bountiful Delve" label, bountiful icon
  - **Regular** — normal name, grey "Delve" label, regular icon
  - **Unknown** — greyed out name, desaturated icon, "Status unknown — open map to refresh"
- Sort order: Bountiful → Unknown → Regular, alphabetical within each group
- Scan runs at multiple delays (0.1s, 0.3s, 0.6s, 1.0s, 2.0s) after map change to catch late-loading pins

**areaPoiIDs confirmed in-game on patch 12.0:**
| Delve | areaPoiID |
|---|---|
| Atal'Aman | 8444 |
| Collegiate Calamity | 8425 |
| Shadowguard Point | 8431 |
| Sunkiller Sanctum | 8430 |
| The Darkway | 8440 |
| The Grudge Pit | 8434 |
| The Gulf of Memory | 8435 |
| The Shadow Enclave | 8437 |
| Torment's Rise | 8445 |
| Twilight Crypts | 8441 |

---

## Iteration 5 — Click Handler Fix
**Goal:** Fix Lua error when clicking a delve row.

**Error:**
```
SharedMapPoiTemplates.lua:505: attempt to index a nil value
```
Caused by forwarding click to `pin:OnClick()` — the pin's `owningMap` is nil
when called outside the map's own input context.

**Fix:**
Replaced pin click forwarding with direct `C_SuperTrack` API call:
```lua
C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, capturedID)
```
This works regardless of map state and doesn't require a live pin reference.

---

## Iteration 6 — Polish & Credits
**Goal:** Final polish and attribution.

**Changes:**
- Fixed subheader text bleeding outside the panel — added `TOPRIGHT` anchor and `SetWordWrap(true)`
- Scrollbar removed — list is short enough, mousewheel still works
- Added credit comment block to top of Lua
- Updated TOC with correct author, interface version, and credits

**Credits:**
- **LanceDH** — LibWorldMapTabs library and TextureAtlasViewer
- **Kemayo** — DelverView (confirmed delve atlas naming conventions)
- **Thunderz96** — DelveGuide (confirmed `delves-bountiful`/`delves-regular` atlas names)
- **WorldQuestTab team** — `QuestLog-main-background` atlas and `QuestLogBorderFrameTemplate` usage

---

## Key Technical Findings

| Topic | Finding |
|---|---|
| Midnight interface version | `120000` |
| Delve pin template | `DelveEntrancePinTemplate` |
| How to find pins | Iterate `WorldMapFrame:GetCanvas():GetChildren()`, filter by `pin.pinTemplate` |
| Bountiful atlas | `delves-bountiful` |
| Regular atlas | `delves-regular` |
| Bountiful detection | `pin.poiInfo.atlasName == "delves-bountiful"` |
| Panel background atlas | `QuestLog-main-background` |
| Panel border template | `QuestLogBorderFrameTemplate` |
| Super-track API | `C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, id)` |
| `C_AreaPoiInfo` usable? | No — returns 0 results for Midnight maps |
| `C_Delves` exists? | No |
| `C_DelvesUI` exists? | Yes — but only companion/curio/season data, no map data |
| `GetBackdrop()` exists? | No — removed by Blizzard in Midnight |
