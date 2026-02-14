# Kleene Troubleshooting Guide

Solutions to common issues. If you don't find your answer here, check the [FAQ](FAQ.md) or [open an issue](https://github.com/hiivmind/kleene/issues).

---

## Quick Diagnostics

**Start here if something's wrong:**

1. **Check temperature:** `/kleene temperature` - Many issues are temperature-related
2. **Validate scenario:** `/kleene analyze your_scenario` - Catches structural issues
3. **Check save location:** `ls saves/` - Verify saves are being created
4. **Restart Claude Code:** Sometimes a fresh session helps

---

## Playing Issues

### Free-Text Actions Aren't Working

**Symptom:** You type improvised actions but nothing happens, or you only see predefined options.

**Cause:** Temperature is set to 0

**Solution:**
```bash
/kleene temperature 5
```

Free-text improvisation requires temperature > 0. At temp 0, scenarios play verbatim with no AI adaptation.

**Verify it's working:**
- Temperature should show in game header
- Try typing a creative action
- You should get a narrative response

---

### Scenario Won't Load

**Symptom:** Error when trying to play a scenario, or game doesn't start.

**Common causes and solutions:**

**1. YAML Syntax Error**
```bash
# Check for errors
/kleene analyze your_scenario
```

Common YAML mistakes:
- Missing colons
- Incorrect indentation (use spaces, not tabs)
- Unclosed quotes
- Missing required fields

**2. Missing Required Fields**
Every scenario needs:
- `name`
- `start_node`
- `initial_character`
- At least one node
- At least one ending

**3. File Not Found**
- Check filename spelling
- Ensure file is in `scenarios/` directory
- Use `/kleene sync` to update registry

**4. Large Scenario**
If file is very large (>100KB):
- This is expected - lazy loading will handle it
- First load may be slow
- Subsequent nodes load quickly

---

### Can't Reach Certain Endings

**Symptom:** You know an ending exists but can't figure out how to reach it.

**Causes:**

**1. Preconditions Too Restrictive**
```bash
/kleene analyze your_scenario
```

Check for:
- Trait requirements that are impossible to meet
- Items that can't be obtained
- Flags that never get set

**2. Path Requires Specific Choices**
Some endings require:
- Specific conversation options
- Certain items collected
- Relationships above/below thresholds
- Prior story beats completed

**Solution:**
- Read the scenario YAML to understand requirements
- Try different paths
- Use `/kleene analyze` to see all paths

**3. Missing Precondition**
If creating your own scenario:
- Ensure path to ending is actually reachable
- Check that preconditions can be satisfied
- Test at temp 0 first (removes variables)

---

### Game Feels Repetitive

**Symptom:** Every playthrough feels the same, no variety.

**Cause:** Temperature too low

**Solution:**
```bash
/kleene temperature 7
```

Higher temps add:
- Narrative adaptation
- Contextual references
- Bonus options
- Emergent storytelling

**Also try:**
- Use more free-text actions
- Explore instead of just picking fastest path
- Replay scenarios you've already completed

---

### Too Random/Chaotic

**Symptom:** Story feels incoherent, too much variation, hard to follow.

**Cause:** Temperature too high for first playthrough

**Solution:**
```bash
/kleene temperature 0
```

**Recommended approach:**
1. First playthrough at temp 0 (learn the story)
2. Second playthrough at temp 5-7 (balanced)
3. Experimental runs at temp 10 (full emergence)

---

### Saves Not Persisting

**Symptom:** Game state isn't saved, or saves aren't found when resuming.

**Checks:**

**1. Verify saves directory exists**
```bash
ls saves/
ls saves/dragon_quest/  # Or your scenario name
```

**2. Check write permissions**
```bash
ls -la saves/
```

Kleene needs write permission in current directory.

**3. Hooks not configured**
The PreToolUse hook should auto-approve save operations.

Check: `.claude/hooks/PreToolUse`

**4. Manual save**
```bash
/kleene save
```

Force a save to test if it's working.

---

### Performance is Slow

**Symptom:** Long delays between turns, high token usage.

**Causes and solutions:**

**1. High Temperature + Large Scenario**
- Lower temp reduces AI processing: `/kleene temperature 3`
- Lazy loading helps, but adaptation is compute-intensive

**2. Complex Improvisation**
- Free-text actions at high temp cost more tokens
- This is expected behavior
- Use predefined options more often if concerned about costs

**3. First Load of Large Scenario**
- Initial load of 100KB+ scenarios takes longer
- Subsequent turns are faster (lazy loading)
- This is normal

**Optimization tips:**
- Start at temp 0 for first playthrough
- Increase temp for replay
- Use predefined options when they fit
- Save frequently to avoid re-processing

---

## Creating Issues

### YAML Validation Errors

**Symptom:** `/kleene analyze` reports errors.

**Common issues:**

**1. Indentation**
```yaml
# ❌ Wrong (mixed spaces and tabs)
nodes:
\tintro:
    narrative: "Text"

# ✅ Right (consistent spaces)
nodes:
  intro:
    narrative: "Text"
```

**2. Node References**
```yaml
# ❌ Wrong (node doesn't exist)
next_node: nonexistent_node

# ✅ Right (node exists)
next_node: intro
```

**3. Missing Endings**
Every `next_node` must point to either:
- Another node
- An ending defined in `endings:`

**4. Orphaned Nodes**
If analyzer warns about orphaned nodes:
- They're defined but never referenced
- Either delete them or add paths to them

---

### Preconditions Not Working

**Symptom:** Options appear when they shouldn't, or don't appear when they should.

**Debug steps:**

**1. Check precondition syntax**
```yaml
# ✅ Correct
precondition:
  type: has_item
  item: sword

# ❌ Wrong (missing 'type')
precondition:
  item: sword
```

**2. Verify game state**
Add temporary logging:
- Check what traits/items/flags player has
- Manually trace precondition logic
- Test at temp 0 (removes adaptation variables)

**3. Complex preconditions**
```yaml
# Make sure logic is correct
precondition:
  type: all_of
  conditions:
    - type: has_item
      item: key
    - type: trait_minimum
      trait: strength
      minimum: 5
```

**4. Common mistakes:**
- `minimum` vs `maximum` confusion
- `flag_set` vs `flag_not_set` logic
- Checking wrong trait/item name
- Typos in IDs

---

### Consequences Not Applying

**Symptom:** Actions don't change character stats, items aren't gained/lost.

**Checks:**

**1. Consequence syntax**
```yaml
# ✅ Correct
consequence:
  - type: modify_trait
    trait: courage
    delta: 2

# ❌ Wrong (missing 'type')
consequence:
  - trait: courage
    delta: 2
```

**2. Multiple consequences**
Must be an array:
```yaml
consequence:
  - type: gain_item
    item: sword
  - type: modify_trait
    trait: strength
    delta: 3
```

**3. Verify names match**
- Trait names must match `initial_character.traits`
- Item names are case-sensitive
- Flag names must be consistent

---

### Generation Issues

**Symptom:** `/kleene generate` produces invalid scenarios or fails.

**Solutions:**

**1. Be Specific**
```bash
# ❌ Too vague
/kleene generate mystery

# ✅ Detailed
/kleene generate a noir detective mystery set in 1940s Los Angeles with a femme fatale and corrupt cops
```

**2. Validate Generated Content**
```bash
/kleene generate ...
/kleene analyze generated_scenario
```

Always validate - generators can occasionally produce invalid YAML.

**3. Edit Generated Content**
Use generated scenarios as starting points:
- Fix any validation errors
- Adjust difficulty/balance
- Add more branches/endings

---

## Installation Issues

### Plugin Not Found

**Symptom:** `/kleene` command doesn't work.

**Solutions:**

**1. Verify installation**
- Check plugins directory
- Ensure `plugin.json` exists
- Restart Claude Code

**2. Check Claude Code version**
Requires Claude Code with plugin support.

**3. Re-install**
- Remove plugin
- Re-install from marketplace
- Restart

---

### Permission Errors

**Symptom:** Can't write saves, can't load scenarios.

**Cause:** File system permissions

**Solutions:**

**1. Check directory permissions**
```bash
ls -la
ls -la scenarios/
ls -la saves/
```

**2. Run from writable directory**
```bash
cd ~/my-game-folder
/kleene play
```

**3. Fix permissions**
```bash
chmod -R u+w scenarios/ saves/
```

---

## Advanced Issues

### Lazy Loading Not Working

**Symptom:** Large scenarios fail to load or are very slow.

**Check:**
1. File size: `ls -lh scenarios/your_scenario.yaml`
2. Token limit in error message
3. Whether lazy loading kicked in

**Expected behavior:**
- Files >20KB trigger lazy loading
- First 200 lines loaded initially
- Nodes loaded on-demand
- This should be transparent

**If failing:**
- Reduce scenario size
- Split into multiple smaller scenarios
- Check for structural issues

---

### Temperature Not Affecting Gameplay

**Symptom:** Game plays the same at all temperatures.

**Checks:**

**1. Verify temp is set**
```bash
/kleene temperature
```

**2. Requires player action**
Temperature only matters when:
- You use free-text actions
- You've made discoveries to reference
- Scenario has improvisation contexts

**3. Some scenarios are temp-agnostic**
If scenario has:
- Very linear structure
- No improvisation contexts
- No optional content

Then temp has less impact.

---

### Improvisation Context Issues

**Symptom:** Scripted "improvise" options don't work correctly.

**Debug:**

**1. Check structure**
```yaml
- id: observe
  text: "Wait and observe"
  next: improvise  # Note: 'next' not 'next_node'
  improvise_context:
    theme: "description"
    permits: ["keyword1", "keyword2"]
    blocks: ["keyword3"]
    limbo_fallback: "Text"
  outcome_nodes:
    discovery: node_id
    constraint: node_id
```

**2. Verify patterns**
- Patterns are case-insensitive
- They're regex patterns
- Test your patterns match intended inputs

**3. Check outcome nodes exist**
All referenced nodes must be defined.

---

## Getting More Help

### Before Asking for Help

1. ✅ Read this guide
2. ✅ Check [FAQ](FAQ.md)
3. ✅ Run `/kleene analyze` on your scenario
4. ✅ Try at temp 0 (eliminates adaptation variables)
5. ✅ Check for typos in YAML

### When Asking for Help

Include:
- **Description:** What's happening vs what you expected
- **Steps to reproduce:** How to trigger the issue
- **Scenario:** Which scenario (or share YAML if custom)
- **Temperature:** What temp setting
- **Error messages:** Copy/paste any errors
- **Environment:** OS, Claude Code version

### Where to Ask

- **GitHub Issues:** [github.com/hiivmind/kleene/issues](https://github.com/hiivmind/kleene/issues)
- **Community:** Claude Code forums/Discord
- **Documentation:** Might already have your answer

---

## Error Message Glossary

### "Node 'X' not found"
**Meaning:** A `next_node` references a node that doesn't exist
**Fix:** Define the node or change the reference

### "Invalid precondition type"
**Meaning:** Precondition uses unrecognized type
**Fix:** Check spelling, see [format specification](../lib/framework/formats/scenario-format.md)

### "Missing required field: X"
**Meaning:** Scenario is missing a required field
**Fix:** Add the field (name, start_node, etc.)

### "YAML syntax error"
**Meaning:** YAML is malformed
**Fix:** Check indentation, quotes, colons

### "Token limit exceeded"
**Meaning:** Scenario is very large
**Fix:** This triggers lazy loading - should work automatically

### "Circular reference detected"
**Meaning:** Nodes form an infinite loop
**Fix:** Add exit paths or endings

---

## Export Issues

### Export File Not Created

**Symptom:** Running `/kleene export` produces no file.

**Solutions:**

**1. Check write permissions**
```bash
ls -la
```

Kleene needs write permission in current directory.

**2. Verify exports directory**
```bash
mkdir -p exports
```

**3. Use explicit path**
```bash
/kleene export --output ./my_export.md
```

---

### Export Missing Content

**Symptom:** Exported file is missing parts of your game.

**Explanation:** By design, exports filter mechanical artifacts:
- Bash commands and tool outputs
- yq queries
- System messages

**Solutions:**

**1. Use maximum granularity**
```bash
/kleene export --granularity=beat
```

**2. Use summary mode**
Summary mode includes analysis that might be filtered in transcript:
```bash
/kleene export summary
```

**3. Check beat_log**
Content is only exportable if it was logged during gameplay.

---

### Branch Export Confusion

**Symptom:** Branch export shows confusing timeline splits.

**Solution:**
```bash
/kleene export --split-branches
```

This creates separate files per timeline. Each branch file shows the point where the timeline diverged.

---

## Rewind Issues

### Rewind Command Not Working

**Symptom:** `/kleene rewind` produces an error or nothing happens.

**Check notation:**
- `T6.2.3` - Turn 6, Scene 2, Beat 3 (capital T)
- `-1` - Go back 1 beat
- `--1` - Go back 1 scene

**Common mistakes:**
- Lowercase `t6.2.3` (use uppercase T)
- Spaces in notation
- Target doesn't exist in beat_log

**Quick test:**
```bash
/kleene rewind -1
```

This basic rewind should always work if you've made at least one move.

---

### Lost Progress After Rewind

**Symptom:** Your original timeline seems to have disappeared.

**Explanation:** Rewind creates a branch - your original timeline is preserved.

**To see all timelines:**
```bash
/kleene export branches
```

Or use `--split-branches` to create separate files per timeline.

**To resume from a save:**
```bash
/kleene continue [scenario]
```

---

### Can't Rewind to Specific Point

**Symptom:** Rewind to a specific T.S.B point fails.

**Causes:**

**1. Point not in beat_log**
You can only rewind to points you've actually played in the current session.

**2. Check available saves**
```bash
/kleene continue [scenario]
```

This shows all available save points with their T.S.B notation.

**3. Start a new session from save**
If the point exists in a save file, use `/kleene continue` to load it.

---

## Still Stuck?

If this guide didn't solve your problem:

1. [Open an issue](https://github.com/hiivmind/kleene/issues) with details
2. Check [FAQ](FAQ.md) for related questions
3. Ask in the community (Claude Code Discord/forums)

We're here to help! 🎮✨
