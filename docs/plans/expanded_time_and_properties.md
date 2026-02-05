# Kleene Scenario Schema Enhancement Plan

## Context

The Kleene scenario format is well-documented and functional, but has gaps in how it handles:
1. **Node referencing** - Improvisation outcome nodes appear "unreachable" in static analysis
2. **Consequences** - No location-specific state changes beyond movement
3. **Preconditions** - Only available on options, not on nodes or locations themselves

## Findings from Investigation

### Improvisation System (NOT Broken)

The 10 "unreachable" nodes in the_yabba.yaml are **working as designed**:
- They're outcome nodes for improvisation (`next: improvise`)
- Reached through pattern matching of player's free-text input against `permits[]`/`blocks[]`
- Static graph analysis can't predict player responses, so they appear unreachable
- During gameplay, they ARE reachable when player's response matches patterns

**This is a documentation issue, not a bug.**

### Current Schema Gaps

1. **Location state is ephemeral** - Only `current_location` persists; no per-location flags/properties
2. **Preconditions are choice-only** - Can't gate entire nodes or locations
3. **World vs Character consequences unclear** - Need better taxonomy

## Proposed Schema Enhancements

### 1. Node Referencing Clarification

**Document the distinction:**
- `next_node` = static edge (always in graph)
- `next: improvise` = dynamic edge (pattern-matched at runtime)

**Update kleene-analyze to:**
- Report improvisation nodes separately as "conditionally reachable"
- Show pattern coverage (permits/blocks) for each scripted Unknown option

### 2. Location State System

**Add location-specific state to world:**

```yaml
world:
  current_location: village
  locations:
    village:
      state:
        destroyed: false
        population: 100
      flags:
        quest_completed: false
        npcs_hostile: false
```

**New consequence types:**

```yaml
# Set location-specific flag
- type: set_location_flag
  location: village
  flag: quest_completed
  value: true

# Modify location property
- type: modify_location_property
  location: shrine
  property: sealed
  delta: 1  # or value: true for boolean
```

### 3. Node-Level Preconditions

**Allow preconditions on nodes, not just options:**

```yaml
dragon_lair:
  precondition:  # ← NEW: Node-level precondition
    type: all_of
    conditions:
      - type: has_item
        item: dragon_scale
      - type: trait_minimum
        trait: courage
        minimum: 10

  narrative: |
    You enter the dragon's lair...

  choice:
    options: [...]
```

**If node precondition fails:**
- Don't advance to node (stay at previous)
- Show "blocked" message from precondition
- OR define `blocked_narrative` override

### 4. Location-Level Preconditions

**Gate location access:**

```yaml
initial_world:
  locations:
    - id: shrine
      name: "Ancient Shrine"
      connections: [forest, mountain_path]
      precondition:  # ← NEW: Location-level precondition
        type: all_of
        conditions:
          - type: has_item
            item: shrine_key
          - type: flag_set
            flag: elder_blessing
      blocked_message: "The shrine remains sealed."
```

**If location precondition fails:**
- Location hidden from `move_to` options
- OR shown as locked/unavailable

### 5. Consequence Taxonomy

**Reorganize consequences by scope:**

**Character Consequences** (affect character state):
- `modify_trait`, `set_trait`
- `gain_item`, `lose_item`
- `modify_relationship`
- `character_dies`, `character_departs`

**World Consequences** (affect global state):
- `set_flag`, `clear_flag`
- `advance_time`
- `add_history`

**Location Consequences** (affect location state):
- `move_to` (existing)
- `set_location_flag` (NEW)
- `clear_location_flag` (NEW)
- `modify_location_property` (NEW)
- `set_location_property` (NEW)

### 6. Precondition Taxonomy

**Current (choice-level only):**
- Character: `has_item`, `trait_minimum`, `trait_maximum`, `relationship_minimum`
- World: `flag_set`, `flag_not_set`, `at_location`
- Logic: `all_of`, `any_of`, `none_of`

**Enhanced (all three levels):**

| Level | Where | Purpose |
|-------|-------|---------|
| **Choice** | `options[].precondition` | Gate individual options (existing) |
| **Node** | `nodes[id].precondition` | Gate entire node entry (NEW) |
| **Location** | `locations[].precondition` | Gate location access (NEW) |

## Design Decisions (User-Approved)

### Location State Storage: Hybrid Approach ✓
- **Static definitions** remain in `initial_world.locations[]` (name, description, connections)
- **Mutable state** stored in separate `world.location_state{}` dict
- Benefits: Clean separation, O(1) lookups, only tracks changed locations, backwards compatible

### Location Access Control: Three Modes ✓
- **filter**: Hide inaccessible options (default, backwards compatible)
- **show_locked**: Show with disabled indicator and reason
- **show_normal**: Show normally, fails with message if selected

### Timeline: 5-Phase Approach ✓
- Phase 1: Location State Foundation (Week 1)
- Phase 2: Node-Level Preconditions (Week 2)
- Phase 3: Location-Level Preconditions (Week 3)
- Phase 4: Temporal System & Advanced Consequences (Week 4)
- Phase 5: Analysis Enhancement & Migration (Week 5)

## Expanded Scope: Temporal & World Systems

Beyond location state, the schema needs comprehensive temporal and world-state enhancements:

### 1. Temporal System (NEW - Major Addition)

**Node-Level Temporal Metadata:**
```yaml
nodes:
  morning_after:
    # Time elapsed since previous node
    elapsed_since_previous:
      amount: 8
      unit: hours  # seconds, minutes, hours, days, weeks, months, years

    # Duration of this node's events
    duration:
      amount: 2
      unit: hours

    narrative: |
      You wake as dawn breaks. Two hours of breakfast and preparation pass...
```

**World-Level Time Tracking:**
```yaml
initial_world:
  time:
    # Current absolute time
    current:
      # Real-world calendar (Unix epoch)
      real_time: 1704067200  # 2024-01-01 00:00:00 UTC

      # Fantasy calendar
      fantasy_time:
        epoch: "Garagth II's Reign"
        year: 427
        month: "2nd Moon"
        day: 15
        hour: 6

    # Scheduled off-camera events
    scheduled_events:
      - id: dragon_awakens
        trigger_at:
          real_time: 1704153600  # 24 hours later
        consequences:
          - type: set_flag
            flag: dragon_awake
            value: true
          - type: set_location_property
            location: dragon_lair
            property: heat_level
            value: 1000
```

**Temporal Consequences:**
```yaml
# Schedule future event
- type: schedule_event
  event_id: dragon_awakens
  delay:
    amount: 24
    unit: hours
  consequences:
    - type: set_flag
      flag: dragon_awake
      value: true

# Advance time (existing, enhanced)
- type: advance_time
  amount: 8
  unit: hours  # NEW: Support units beyond generic counter

# Set absolute time
- type: set_time
  real_time: 1704067200
  fantasy_time:
    year: 427
    month: "2nd Moon"
    day: 15
```

**Temporal Preconditions:**
```yaml
# Check if time has passed
precondition:
  type: time_elapsed_minimum
  amount: 24
  unit: hours
  since: game_start  # or node_id, or event_id

# Check absolute time
precondition:
  type: time_after
  real_time: 1704153600

precondition:
  type: fantasy_time_after
  year: 427
  month: "3rd Moon"
  day: 1

# Check if event has triggered
precondition:
  type: event_triggered
  event_id: dragon_awakens
```

### 2. NPC Location Tracking (NEW)

**World-Level NPC State:**
```yaml
world:
  npc_locations:
    doc: docs_shack
    jock: pub
    janette: hotel
    tim: tims_house
```

**NPC Movement Consequences:**
```yaml
# Move NPC to location
- type: move_npc
  npc: doc
  location: pub

# Move NPC relative to player
- type: move_npc
  npc: jock
  location: current  # Moves to player's location
```

**NPC Location Preconditions:**
```yaml
# Check if NPC is at location
precondition:
  type: npc_at_location
  npc: doc
  location: current  # Or specific location ID

# Check if NPC is anywhere except
precondition:
  type: npc_not_at_location
  npc: janette
  location: hotel
```

### 3. Environment Effects (NEW)

**Location Environment State:**
```yaml
world:
  location_state:
    shrine:
      environment:
        lighting: dim
        weather: rain
        temperature: cold
        ambiance: eerie
      flags:
        sealed: false
```

**Environment Consequences:**
```yaml
# Set environmental condition
- type: set_environment
  location: shrine  # Omit for current_location
  property: lighting
  value: dark

# Modify numeric environment property
- type: modify_environment
  location: dragon_lair
  property: temperature
  delta: 500
```

**Environment Preconditions:**
```yaml
# Require specific environment
precondition:
  type: environment_is
  location: shrine
  property: lighting
  value: lit

precondition:
  type: environment_minimum
  location: dragon_lair
  property: temperature
  minimum: 800
```

### 4. World Events System (NEW)

**Event Definitions:**
```yaml
initial_world:
  events:
    - id: dragon_awakens
      trigger:
        type: time_elapsed
        amount: 24
        unit: hours
        since: game_start
      consequences:
        - type: set_flag
          flag: dragon_awake
          value: true
        - type: modify_location_property
          location: dragon_lair
          property: heat_level
          delta: 400

    - id: town_evacuation
      trigger:
        type: flag_set
        flag: dragon_approaching
      consequences:
        - type: set_location_flag
          location: village
          flag: evacuated
          value: true
        - type: move_npc
          npc: elder
          location: forest_camp
```

**Event Consequences:**
```yaml
# Trigger event immediately
- type: trigger_event
  event_id: dragon_awakens

# Schedule event
- type: schedule_event
  event_id: town_evacuation
  delay:
    amount: 2
    unit: hours

# Cancel scheduled event
- type: cancel_event
  event_id: dragon_awakens
```

## Complete Schema Structure

### World State (Enhanced)
```yaml
world:
  # Existing
  current_location: village
  flags: {}

  # NEW: Location-specific mutable state
  location_state:
    village:
      flags: {quest_completed: true}
      properties: {population: 85}
      environment: {lighting: dim, weather: rain}

  # NEW: NPC location tracking
  npc_locations:
    doc: docs_shack
    jock: pub

  # NEW: Enhanced time system
  time:
    elapsed: 24  # Legacy counter
    current:
      real_time: 1704067200
      fantasy_time:
        epoch: "Garagth II's Reign"
        year: 427
        month: "2nd Moon"
        day: 15
        hour: 6

  # NEW: Scheduled events
  scheduled_events:
    - event_id: dragon_awakens
      trigger_at: 1704153600
      consequences: [...]

  # NEW: Triggered events history
  triggered_events: [town_bells, elder_speech]
```

### Node Structure (Enhanced)
```yaml
nodes:
  node_id:
    # NEW: Node-level precondition
    precondition:
      type: all_of
      conditions: [...]
    blocked_narrative: "Custom message when blocked"

    # NEW: Temporal metadata
    elapsed_since_previous:
      amount: 2
      unit: hours
    duration:
      amount: 1
      unit: hours

    # Existing
    narrative: "..."
    scene_break: true
    choice:
      prompt: "..."
      options: [...]
```

### Location Structure (Enhanced)
```yaml
locations:
  - id: shrine
    name: "Ancient Shrine"
    description: "..."
    connections: [forest]
    items: [scroll]

    # NEW: Location-level precondition
    precondition:
      type: flag_not_set
      flag: shrine_sealed
    access_denied_narrative: "The wards block your path."
    access_mode: show_locked  # filter | show_locked | show_normal

    # NEW: Initial state (usually omitted)
    initial_state:
      flags: {discovered: false}
      properties: {blessing_power: 100}
      environment: {lighting: dim, ambiance: sacred}
```

## New Consequence Types (Complete List)

### Location Consequences
- `set_location_flag` - Set boolean flag on location
- `clear_location_flag` - Clear boolean flag on location
- `modify_location_property` - Modify numeric property (delta)
- `set_location_property` - Set property to absolute value

### Environment Consequences
- `set_environment` - Set environmental condition (lighting, weather, etc.)
- `modify_environment` - Modify numeric environment property (delta)

### NPC Consequences
- `move_npc` - Move NPC to specific location or current location

### Temporal Consequences
- `advance_time` - Enhanced with units (seconds, minutes, hours, days, etc.)
- `set_time` - Set absolute time (real_time or fantasy_time)
- `schedule_event` - Schedule event to trigger after delay
- `trigger_event` - Trigger event immediately
- `cancel_event` - Cancel scheduled event

## New Precondition Types (Complete List)

### Location Preconditions
- `location_flag_set` - Check if location flag is true
- `location_flag_not_set` - Check if location flag is false/missing
- `location_property_minimum` - Check location property >= value
- `location_property_maximum` - Check location property <= value

### Environment Preconditions
- `environment_is` - Check if environment property equals value
- `environment_minimum` - Check environment property >= value
- `environment_maximum` - Check environment property <= value

### NPC Preconditions
- `npc_at_location` - Check if NPC is at specific location
- `npc_not_at_location` - Check if NPC is NOT at location

### Temporal Preconditions
- `time_elapsed_minimum` - Check if time has elapsed since reference
- `time_elapsed_maximum` - Check if time has NOT exceeded limit
- `time_after` - Check if absolute time is after timestamp (real_time)
- `time_before` - Check if absolute time is before timestamp
- `fantasy_time_after` - Check fantasy calendar time is after date
- `fantasy_time_before` - Check fantasy calendar time is before date
- `event_triggered` - Check if event has been triggered
- `event_not_triggered` - Check if event has NOT been triggered

## Implementation Phases (Detailed)

### Phase 1: Location State Foundation (Week 1)

**Goals:**
- Implement `world.location_state{}` storage
- Add location flag/property consequences
- Add location flag/property preconditions
- Update save format to v4
- Maintain 100% backwards compatibility

**Deliverables:**
1. Update game state model in kleene-play/SKILL.md
2. Implement consequence evaluation:
   - `set_location_flag`, `clear_location_flag`
   - `modify_location_property`, `set_location_property`
3. Implement precondition evaluation:
   - `location_flag_set`, `location_flag_not_set`
   - `location_property_minimum`, `location_property_maximum`
4. Update save/load to handle `location_state` (default `{}` if missing)
5. Create test scenario demonstrating location state

**Files to Modify:**
- `kleene/skills/kleene-play/SKILL.md` (lines 1-800: state model, consequence/precondition logic)
- `kleene/lib/framework/scenario-format.md` (consequence/precondition docs)
- `kleene/lib/framework/savegame-format.md` (save format v4 spec)

**Validation:**
- All existing scenarios load without errors
- Location state persists across save/load
- Location preconditions correctly gate options

---

### Phase 2: Node-Level Preconditions (Week 2)

**Goals:**
- Add `precondition` and `blocked_narrative` to node schema
- Implement node-entry validation in turn flow
- Generate fallback messages for blocked nodes
- Add temporal metadata (elapsed_since_previous, duration)

**Deliverables:**
1. Update node schema documentation
2. Add node precondition evaluation before narrative display
3. Implement fallback message generation
4. Add temporal metadata parsing (non-functional for now)
5. Update turn flow to handle blocked node entry

**Files to Modify:**
- `kleene/lib/framework/scenario-format.md` (node schema docs)
- `kleene/skills/kleene-play/SKILL.md` (turn flow logic, lines 400-600)
- `kleene/scenarios/TEMPLATES/intermediate.yaml` (add examples)

**Validation:**
- Blocked nodes display appropriate messages
- Turn counter doesn't increment on blocked entry
- Player returns to previous node with choices re-presented

---

### Phase 3: Location-Level Preconditions (Week 3)

**Goals:**
- Add `precondition`, `access_denied_narrative`, `access_mode` to location schema
- Implement move_to validation
- Support three access modes (filter, show_locked, show_normal)
- Add environment consequences and preconditions

**Deliverables:**
1. Update location schema documentation
2. Modify `move_to` consequence to validate location access
3. Implement access mode filtering in choice presentation
4. Add environment state to location_state
5. Implement environment consequences:
   - `set_environment`, `modify_environment`
6. Implement environment preconditions:
   - `environment_is`, `environment_minimum`, `environment_maximum`

**Files to Modify:**
- `kleene/lib/framework/scenario-format.md` (location schema, environment docs)
- `kleene/skills/kleene-play/SKILL.md` (move_to validation, choice filtering)

**Validation:**
- Failed move_to displays denial message
- Access modes correctly filter/show_locked/show_normal
- Environment state persists and affects gameplay

---

### Phase 4: Temporal System & Advanced Consequences (Week 4)

**Goals:**
- Implement enhanced time system (real_time, fantasy_time)
- Add NPC location tracking
- Add world events system
- Implement temporal consequences and preconditions
- Process node temporal metadata

**Deliverables:**
1. Enhance world time structure:
   - `time.current.real_time` (Unix timestamp)
   - `time.current.fantasy_time` (custom calendar)
2. Add `world.npc_locations{}` dict
3. Add `world.scheduled_events[]` and `world.triggered_events[]`
4. Implement NPC consequences:
   - `move_npc`
5. Implement NPC preconditions:
   - `npc_at_location`, `npc_not_at_location`
6. Implement temporal consequences:
   - Enhanced `advance_time` with units
   - `set_time`, `schedule_event`, `trigger_event`, `cancel_event`
7. Implement temporal preconditions:
   - `time_elapsed_minimum`, `time_elapsed_maximum`
   - `time_after`, `time_before`
   - `fantasy_time_after`, `fantasy_time_before`
   - `event_triggered`, `event_not_triggered`
8. Process node temporal metadata:
   - Apply `elapsed_since_previous` on node entry
   - Track node `duration` for event scheduling

**Files to Modify:**
- `kleene/lib/framework/scenario-format.md` (temporal system, NPC tracking, events)
- `kleene/skills/kleene-play/SKILL.md` (time tracking, event processing, NPC management)
- `kleene/lib/framework/savegame-format.md` (time structure in saves)

**Validation:**
- Time advances correctly with units
- Scheduled events trigger at correct times
- NPCs move and their locations are tracked
- Temporal preconditions gate choices appropriately
- Node temporal metadata affects world time

---

### Phase 5: Analysis Enhancement & Migration (Week 5)

**Goals:**
- Update kleene-analyze to handle dynamic edges (improvisation)
- Add validation for all new features
- Create comprehensive template scenarios
- Write migration guide
- Update existing scenario documentation

**Deliverables:**
1. Rewrite reachability algorithm:
   - Distinguish static edges (next_node) from dynamic edges (next: improvise)
   - Report improvisation outcome nodes as "conditionally reachable"
   - Show pattern matching info for dynamic edges
2. Add validation checks:
   - Location state consistency
   - Node precondition reachability
   - Location precondition circular dependencies
   - Temporal event consistency
   - NPC location references
3. Create advanced template scenario demonstrating all features
4. Write migration guide with before/after examples
5. Document best practices for:
   - Location state management
   - Temporal design patterns
   - NPC movement patterns
   - Event scheduling strategies

**Files to Create/Modify:**
- `kleene/skills/kleene-analyze/SKILL.md` (reachability algorithm, validation)
- `kleene/scenarios/TEMPLATES/advanced.yaml` (new comprehensive template)
- `kleene/scenarios/TEMPLATES/temporal_example.yaml` (time system showcase)
- `kleene/lib/authoring/migration-v2.md` (migration guide)
- `kleene/lib/authoring/best-practices.md` (design patterns)
- `kleene/lib/framework/core.md` (clarify improvisation routing)

**Validation:**
- Improvisation nodes reported correctly (not "unreachable")
- All new schema elements validated
- Templates demonstrate all features without errors
- Migration guide successfully applied to test scenarios

---

## Formal Schema Definition

The scenario format currently exists only as markdown documentation. We need a formal, machine-readable schema for validation and tooling.

### JSON Schema Definition

**Location:** `kleene/lib/schema/scenario-schema.json`

**Purpose:**
- Validate scenario YAML files before gameplay
- Provide IDE autocomplete and validation
- Generate documentation automatically
- Enable schema-aware tooling

**Structure:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Kleene Scenario Schema v2",
  "type": "object",
  "required": ["name", "start_node", "nodes", "initial_character", "initial_world"],
  "properties": {
    "name": {"type": "string"},
    "description": {"type": "string"},
    "version": {"type": "string", "default": "2.0"},
    "start_node": {"type": "string"},

    "nodes": {
      "type": "object",
      "patternProperties": {
        "^[a-z_]+$": {"$ref": "#/definitions/Node"}
      }
    },

    "initial_character": {"$ref": "#/definitions/CharacterState"},
    "initial_world": {"$ref": "#/definitions/WorldState"},
    "endings": {"$ref": "#/definitions/Endings"}
  },

  "definitions": {
    "Node": {
      "type": "object",
      "required": ["narrative", "choice"],
      "properties": {
        "precondition": {"$ref": "#/definitions/Precondition"},
        "blocked_narrative": {"type": "string"},
        "elapsed_since_previous": {"$ref": "#/definitions/TimeAmount"},
        "duration": {"$ref": "#/definitions/TimeAmount"},
        "narrative": {"type": "string"},
        "scene_break": {"type": "boolean"},
        "choice": {"$ref": "#/definitions/Choice"}
      }
    },

    "Choice": {
      "type": "object",
      "required": ["options"],
      "properties": {
        "prompt": {"type": "string"},
        "options": {
          "type": "array",
          "items": {"$ref": "#/definitions/Option"}
        }
      }
    },

    "Option": {
      "type": "object",
      "required": ["id", "text"],
      "properties": {
        "id": {"type": "string"},
        "text": {"type": "string"},
        "cell": {"enum": ["chooses", "unknown", "avoids"]},
        "precondition": {"$ref": "#/definitions/Precondition"},
        "consequence": {
          "type": "array",
          "items": {"$ref": "#/definitions/Consequence"}
        },
        "narrative": {"type": "string"},
        "next_node": {"type": "string"},
        "next": {"enum": ["improvise"]},
        "improvise_context": {"$ref": "#/definitions/ImproviseContext"},
        "outcome_nodes": {"$ref": "#/definitions/OutcomeNodes"}
      }
    },

    "Precondition": {
      "type": "object",
      "required": ["type"],
      "oneOf": [
        {"$ref": "#/definitions/HasItemPrecondition"},
        {"$ref": "#/definitions/TraitMinimumPrecondition"},
        {"$ref": "#/definitions/LocationFlagSetPrecondition"},
        {"$ref": "#/definitions/NPCAtLocationPrecondition"},
        {"$ref": "#/definitions/TimeElapsedMinimumPrecondition"},
        {"$ref": "#/definitions/AllOfPrecondition"},
        // ... all 27 precondition types
      ]
    },

    "Consequence": {
      "type": "object",
      "required": ["type"],
      "oneOf": [
        {"$ref": "#/definitions/ModifyTraitConsequence"},
        {"$ref": "#/definitions/SetLocationFlagConsequence"},
        {"$ref": "#/definitions/MoveNPCConsequence"},
        {"$ref": "#/definitions/ScheduleEventConsequence"},
        {"$ref": "#/definitions/SetEnvironmentConsequence"},
        // ... all 22 consequence types
      ]
    },

    "WorldState": {
      "type": "object",
      "required": ["current_location", "locations"],
      "properties": {
        "current_location": {"type": "string"},
        "flags": {"type": "object"},
        "locations": {
          "type": "array",
          "items": {"$ref": "#/definitions/Location"}
        },
        "location_state": {"$ref": "#/definitions/LocationStateDict"},
        "npc_locations": {"type": "object"},
        "time": {"$ref": "#/definitions/TimeState"},
        "events": {
          "type": "array",
          "items": {"$ref": "#/definitions/WorldEvent"}
        }
      }
    },

    "Location": {
      "type": "object",
      "required": ["id", "name", "connections"],
      "properties": {
        "id": {"type": "string"},
        "name": {"type": "string"},
        "description": {"type": "string"},
        "connections": {
          "type": "array",
          "items": {"type": "string"}
        },
        "items": {
          "type": "array",
          "items": {"type": "string"}
        },
        "precondition": {"$ref": "#/definitions/Precondition"},
        "access_denied_narrative": {"type": "string"},
        "access_mode": {"enum": ["filter", "show_locked", "show_normal"]},
        "initial_state": {"$ref": "#/definitions/LocationState"}
      }
    },

    "TimeState": {
      "type": "object",
      "properties": {
        "elapsed": {"type": "number"},
        "current": {
          "type": "object",
          "properties": {
            "real_time": {"type": "number", "description": "Unix timestamp"},
            "fantasy_time": {"$ref": "#/definitions/FantasyTime"}
          }
        }
      }
    },

    "FantasyTime": {
      "type": "object",
      "properties": {
        "epoch": {"type": "string"},
        "year": {"type": "number"},
        "month": {"type": "string"},
        "day": {"type": "number"},
        "hour": {"type": "number"}
      }
    },

    "TimeAmount": {
      "type": "object",
      "required": ["amount", "unit"],
      "properties": {
        "amount": {"type": "number"},
        "unit": {"enum": ["seconds", "minutes", "hours", "days", "weeks", "months", "years"]}
      }
    }
  }
}
```

### Schema Validation Integration

**Phase 1 Addition:**
1. Create JSON Schema file with all types defined
2. Add schema validation to kleene-play on scenario load:
   ```python
   import jsonschema

   def load_scenario(path):
       with open(path) as f:
           scenario = yaml.safe_load(f)

       # Validate against schema
       with open('kleene/lib/schema/scenario-schema.json') as f:
           schema = json.load(f)

       try:
           jsonschema.validate(scenario, schema)
       except jsonschema.ValidationError as e:
           print(f"Schema validation error: {e.message}")
           print(f"At path: {' -> '.join(str(p) for p in e.path)}")
           raise

       return scenario
   ```

3. Add schema validation to kleene-analyze:
   ```
   SCHEMA VALIDATION
   ─────────────────
   ✓ Schema valid (v2.0)
   ✓ All required fields present
   ✓ All node references valid
   ✗ Invalid consequence type at nodes.intro.choice.options[2].consequence[1]
       Expected one of: modify_trait, gain_item, set_location_flag, ...
       Got: invalid_type
   ```

### Schema Generation

**Automate schema updates:**
- Generate JSON Schema from TypeScript types (if we add types later)
- Or maintain JSON Schema as source of truth
- Generate markdown documentation from schema
- Generate example YAML snippets

**Tools:**
- `ajv` for JSON Schema validation (JavaScript/Node)
- `jsonschema` for validation (Python)
- `yaml-language-server` for IDE integration (VS Code, etc.)

### IDE Integration

**VS Code YAML Extension:**

Create `.vscode/settings.json`:
```json
{
  "yaml.schemas": {
    "kleene/lib/schema/scenario-schema.json": "scenarios/*.yaml"
  }
}
```

This enables:
- Autocomplete for field names
- Inline validation errors
- Hover documentation
- Schema-aware formatting

## Critical Files for Implementation

### Phase 1 (Core Implementation + Schema)
1. **`kleene/skills/kleene-play/SKILL.md`** - Game engine, state model, consequence/precondition evaluation, turn flow
2. **`kleene/lib/framework/scenario-format.md`** - Complete schema documentation (human-readable)
3. **`kleene/lib/schema/scenario-schema.json`** - Formal JSON Schema definition (machine-readable) **[NEW]**
4. **`kleene/lib/framework/savegame-format.md`** - Save format v4 with all new state

### Phase 5 (Analysis & Migration)
5. **`kleene/skills/kleene-analyze/SKILL.md`** - Static analysis, validation with schema checking
6. **`kleene/lib/framework/core.md`** - Improvisation system clarification
7. **`kleene/scenarios/TEMPLATES/*.yaml`** - Reference implementations

## Backwards Compatibility Strategy

**100% Compatible via Graceful Defaults:**
- Missing `world.location_state` → defaults to `{}`
- Missing `world.npc_locations` → defaults to `{}`
- Missing `world.time.current` → defaults to legacy `time` counter
- Missing node/location `precondition` → always accessible
- Old consequence/precondition types → unchanged behavior
- Save format v2/v3 → loads with new fields initialized to defaults

**No Breaking Changes:**
- All existing scenarios (dragon_quest, the_yabba, etc.) work without modification
- Old save files load correctly
- New features are opt-in only

## Verification Strategy

### Unit Tests
- Location state operations (set/modify flags/properties)
- Environment state operations
- NPC movement and tracking
- Time advancement with units
- Event scheduling and triggering
- All new consequence evaluations
- All new precondition evaluations

### Integration Tests
- Full scenario playthrough with location gating
- Node precondition blocking
- Temporal event triggers
- Save/load with all new state
- Backwards compatibility with old saves

### Manual Testing
- Create test scenario using all features
- Verify the_yabba.yaml still works
- Test migration guide on sample scenario
- Verify analysis reports dynamic edges correctly

## Risk Mitigation

### Risk: Temporal System Complexity
**Impact:** High (new concept)
**Mitigation:** Comprehensive documentation, clear examples, optional feature

### Risk: Save File Size Growth
**Impact:** Low (minimal increase)
**Mitigation:** Only track changed state, lazy initialization

### Risk: Breaking Existing Scenarios
**Impact:** High (user disruption)
**Mitigation:** 100% backwards compatibility, extensive testing, graceful defaults
