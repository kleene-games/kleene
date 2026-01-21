# Kleene Scenario Templates

Use these templates to quickly start creating your own scenarios. Each template demonstrates different levels of complexity.

---

## Templates Available

### minimal.yaml - Start Here
**Complexity:** Beginner
**Nodes:** 2
**Endings:** 1
**Playtime:** 2 minutes

The absolute minimum needed for a working scenario. Use this for:
- Learning the basic structure
- Quick prototyping
- Testing single mechanics

**Features demonstrated:**
- Basic node structure
- Single choice
- Simple ending

**Try it:**
```bash
/kleene play TEMPLATES/minimal
```

---

### basic.yaml - Core Features
**Complexity:** Intermediate
**Nodes:** 6
**Endings:** 4
**Playtime:** 15-20 minutes

A complete basic scenario with branching paths and multiple endings. Use this for:
- Learning branching narratives
- Understanding preconditions and consequences
- Creating short adventures

**Features demonstrated:**
- Multiple branching paths
- Preconditions (trait checks)
- Consequences (trait modifications, items, flags)
- Inventory system
- Character flags
- World flags
- Multiple ending types

**Try it:**
```bash
/kleene play TEMPLATES/basic
```

---

### intermediate.yaml - Advanced Techniques
**Complexity:** Advanced
**Nodes:** 12
**Endings:** 5
**Playtime:** 30-40 minutes

A sophisticated scenario showcasing advanced features. Use this for:
- Creating rich, complex narratives
- Implementing relationship systems
- Adding improvisation options
- Building layered choice structures

**Features demonstrated:**
- NPC relationships
- Complex preconditions (all_of logic)
- Improvisation contexts (scripted Unknown paths)
- Multiple trial paths
- Moral choices affecting stats
- Training/character development
- Hidden secrets and optional content
- Different ending types based on character arc

**Try it:**
```bash
/kleene play TEMPLATES/intermediate
```

---

## How to Use Templates

### Quick Start

1. **Copy a template:**
   ```bash
   cp scenarios/TEMPLATES/basic.yaml scenarios/my_adventure.yaml
   ```

2. **Customize it:**
   - Change the name and description
   - Modify the narrative text
   - Add/remove nodes and options
   - Create your own endings

3. **Test it:**
   ```bash
   /kleene analyze my_adventure
   /kleene play my_adventure
   ```

### Progressive Learning Path

1. **Start with minimal.yaml**
   - Understand the basic structure
   - Change the narrative text
   - Add one more node

2. **Move to basic.yaml**
   - Study the branching structure
   - See how preconditions work
   - Learn consequence types

3. **Explore intermediate.yaml**
   - Understand relationships
   - See complex preconditions
   - Study improvisation contexts

4. **Create your own**
   - Combine techniques from all templates
   - Add your unique ideas
   - Test at multiple temperatures

---

## Template Modification Guide

### Changing the Story

**Minimal changes needed:**
- `name:` - Your scenario title
- `description:` - Brief description
- `narrative:` - The story text in each node
- `text:` - Option text players see

**Keep the structure:**
- Node IDs can be descriptive: `forest_entrance`, `dragon_lair`
- Option IDs should be unique per node: `fight`, `flee`, `negotiate`
- Ending IDs should be unique: `ending_victory`, `ending_death`

### Adding Features

**Want inventory?**
```yaml
initial_character:
  inventory:
    - sword
    - shield
    - potion
```

**Want relationships?**
```yaml
initial_character:
  relationships:
    ally: 10
    enemy: -5
```

**Want world locations?**
```yaml
initial_world:
  current_location: "village"
  locations:
    - id: village
      connections: [forest, castle]
```

### Common Modifications

**Add a new path:**
1. Create a new node
2. Add an option pointing to it
3. Make the node lead somewhere (ending or back to main path)

**Add a new ending:**
1. Create ending in `endings:` section
2. Point an option's `next_node` to it

**Add a locked path:**
```yaml
- id: secret_option
  text: "Take the hidden path"
  precondition:
    type: flag_set
    flag: found_secret
    value: true
  next_node: secret_area
```

---

## Template Comparison

| Feature | Minimal | Basic | Intermediate |
|---------|---------|-------|--------------|
| **Branching paths** | ❌ | ✅ | ✅ |
| **Multiple endings** | ❌ | ✅ | ✅ |
| **Preconditions** | ❌ | ✅ | ✅ |
| **Consequences** | ❌ | ✅ | ✅ |
| **Inventory** | ❌ | ✅ | ✅ |
| **Flags** | ❌ | ✅ | ✅ |
| **Relationships** | ❌ | ❌ | ✅ |
| **Complex preconditions** | ❌ | ❌ | ✅ |
| **Improvisation** | ❌ | ❌ | ✅ |
| **Multiple trials** | ❌ | ❌ | ✅ |

---

## Next Steps

**After using templates:**
1. Read the [Scenario Authoring Guide](../../docs/SCENARIO_AUTHORING.md)
2. Study the bundled scenarios in `scenarios/`
3. Check the [format specification](../../lib/framework/formats/scenario-format.md)
4. Share your creation - see [CONTRIBUTING.md](../../CONTRIBUTING.md)

**Need help?**
- [FAQ](../../docs/FAQ.md)
- [Troubleshooting](../../docs/TROUBLESHOOTING.md)
- [GitHub Issues](https://github.com/hiivmind/kleene/issues)

---

## Tips for Template Users

1. **Start small** - Don't try to use all features at once
2. **Test frequently** - Run `/kleene analyze` after every few changes
3. **Playtest at multiple temps** - 0, 5, and 10 behave differently
4. **Read the comments** - Templates include inline explanations
5. **Compare to bundled scenarios** - See real examples in `scenarios/`

Happy creating! 🎮✨
