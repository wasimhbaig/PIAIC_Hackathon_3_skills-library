# Agent Documentation Generation Prompt

## Task

We are building an AI-powered learning platform using microservices, Kubernetes, and AI agents.
Analyze the agent configurations in the codebase and generate comprehensive AGENTS.md documentation.


## Instructions

1. Scan the codebase for agent definition files
2. Extract agent metadata:
   - Agent names and descriptions
   - Available tools and capabilities
   - Configuration parameters
   - Usage patterns

3. Generate AGENTS.md with the following structure:
   ```markdown
   # Agents

   ## Agent Name

   **Description**: Brief description of the agent's purpose

   **Capabilities**:
   - List of tools and capabilities

   **Usage**:
   ```
   Example usage code or commands
   ```

   **Configuration**:
   - Configuration parameters and options
   ```

4. Ensure consistency in formatting across all agent entries
5. Include practical examples where available

## Rules

- Use clear markdown
- Define at least 4 agents
- Each agent must have:
  - Name
  - Purpose
  - Responsibilities
- Include a section on agent interaction rules
- Do NOT explain your reasoning
- Output ONLY the AGENTS.md content

## Output Format

The output should be a well-formatted Markdown file suitable for developer reference.
