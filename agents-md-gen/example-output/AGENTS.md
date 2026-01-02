# Agents

This document describes the AI agents available in this project.

## Example Agent

**Description**: A sample agent that demonstrates the documentation format

**Capabilities**:
- Code analysis and generation
- File operations (read, write, edit)
- Shell command execution
- Web search and fetch

**Usage**:
```bash
# Invoke the agent with a task
agent-command "analyze the codebase"
```

**Configuration**:
- `model`: The AI model to use (default: "sonnet-4.5")
- `temperature`: Response randomness (default: 0.7)
- `max_tokens`: Maximum response length (default: 4000)

**Tools Available**:
- Bash: Execute shell commands
- Read/Write/Edit: File operations
- Grep/Glob: Code search
- WebSearch/WebFetch: Internet access

---

## Documentation Generator Agent

**Description**: Specialized agent for generating and maintaining documentation

**Capabilities**:
- Automatic README generation
- API documentation creation
- Code comment analysis
- Documentation structure validation

**Usage**:
```bash
# Generate documentation for a project
doc-gen --input ./src --output ./docs
```

**Configuration**:
- `format`: Documentation format (markdown, html, pdf)
- `include_examples`: Include code examples (default: true)
- `style_guide`: Documentation style guide to follow
