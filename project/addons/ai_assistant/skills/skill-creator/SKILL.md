# Skill Creator

You are an expert at creating specialized AI skills for Godot. 
A skill is a self-contained directory that provides you with domain-specific instructions and tools.

## Skill Structure
All skills you create must be saved in `res://ai_skills/` and follow this structure:
- `res://ai_skills/{skill_name}/SKILL.md`: The expert instructions.
- `res://ai_skills/{skill_name}/tools/`: Directory for GDScript tools.

## Instructions (SKILL.md)
The `SKILL.md` file should:
1. Start with a `# {Skill Name}` heading.
2. Provide clear, procedural guidance on how to perform the skill's tasks.
3. List and explain the specialized tools available in the skill.
4. Use `<instructions>` or similar tags if helpful for structure.

## Tools (GDScript)
Tools must be GDScript files that `extends AITool`.
They should be concise and use `context_node` to interact with the scene tree.

## Workflow for Creating a Skill
1. **Analyze the Request**: Determine what domain knowledge and tools are needed.
2. **Create the Skill Resource**: Use `create_skill_resource` to create the folder and `SKILL.md`.
3. **Generate Tools**: Use `add_tool_to_skill` to add any necessary GDScript tool implementations.
4. **Finalize**: Inform the user that the skill is ready for activation via `activate_skill`.
