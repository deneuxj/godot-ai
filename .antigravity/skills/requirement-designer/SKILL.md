---
name: requirement-designer
description: Add and refine project requirements and designs. Use when you need to introduce new features, ensuring they don't conflict with existing requirements in 'requirements.md' and refining them into a concise design plan.
---

# Requirement Designer

Use this skill to systematically add new requirements to the project while maintaining consistency and creating a clear architectural plan.

## Process

### 1. Ingest & Analyze
Read the new requirement(s) provided by the user. Immediately read the existing `requirements.md` file to understand the current project scope.

### 2. Conflict & Overlap Check
Compare the new requirements with the existing ones. Look for:
- **Contradictions:** Does the new requirement violate an existing one?
- **Overlaps:** Is this feature already partially or fully covered?
- **Ambiguity:** Are the boundaries of the new requirement clear?

**MANDATORY:** If any overlaps or contradictions are found, you **MUST** inform the user and stop to discuss and refine the requirement before proceeding.

### 3. Refine into Design
Once the requirements are clarified and consolidated, refine them into a concise design plan.

**Design Persistence & Convention:**
- **Location:** All designs MUST be written into the `design/` directory.
- **Naming:** Follow the `NNNN-category.md` convention (e.g., `0006-chat.md`). The number `NNNN` should correspond to the relative order of the requirement category in `requirements.md` (e.g., `0001` for the first category, `0002` for the second, etc.). If adding a design for an existing category, update the corresponding file.
- **Traceability:** Every design file MUST include a **Requirements Coverage** table at the end, mapping each requirement ID (e.g., `REQ-CHAT-0001`) to its design/implementation detail.

**Design Content Constraints:**
- **Length:** Maximum 250 lines.
- **Organization:** Specify which new files need to be created or which existing files need modification.
- **Content:** Detail the classes, methods, and their responsibilities.
- **Format:** Use high-level descriptions and pseudo-code. **Avoid writing final implementation code.**

### 4. Wait for Approval
**MANDATORY:** You MUST complete or update the design document in the `design/` directory BEFORE starting the implementation. Present the design to the user and wait for their explicit directive to proceed with the execution phase.

## When to Use
- When the user proposes a new feature or change.
- When you identify a missing requirement that needs formalization.
- To ensure project architectural integrity when scaling.

## When NOT to Use
- For simple bug fixes that don't change requirements.
- For documentation updates that don't involve new logic.
- For refactoring that doesn't change behavior.
