# Skills Library - Reusable Intelligence

A curated collection of reusable skills for AI agents and automation workflows, developed for PIAIC Hackathon 3.

## Overview

This repository contains production-ready skills that can be integrated into AI agent systems, automation pipelines, and development workflows. Each skill is self-contained with documentation, configuration, and all necessary resources.

## Available Skills

### 📝 agents-md-gen
Generate comprehensive AGENTS.md documentation for AI agent systems.

**Features:**
- Analyzes agent configurations in your codebase
- Generates structured documentation with roles, responsibilities, and interaction rules
- Enforces minimum 4 agents with required fields (Name, Purpose, Responsibilities)
- Outputs clean markdown without explanatory text

**Use Cases:**
- Documenting multi-agent systems
- Creating onboarding documentation for AI workflows
- Maintaining agent configuration reference

[View Details →](./agents-md-gen/)

### ⚙️ k8s-foundation
Automate Kubernetes foundation infrastructure setup with validation.

**Features:**
- Cluster health validation (nodes, DNS, storage)
- Automated Nginx ingress controller installation
- Base namespace structure creation
- Helm-based deployment with customizable values

**Use Cases:**
- Setting up new Kubernetes clusters
- Validating cluster readiness
- Standardizing infrastructure deployment

[View Details →](./k8s-foundation/)

## Skill Structure

Each skill follows a consistent structure:

```
skill-name/
├── README.md              # Detailed documentation
├── skill.yaml             # Configuration and metadata
├── prompt.md              # (Optional) Prompt template
├── scripts/               # (Optional) Automation scripts
├── helm/                  # (Optional) Helm charts
└── example-output/        # (Optional) Sample outputs
```

### skill.yaml Format

```yaml
name: skill-name
description: Brief description
version: 1.0.0
category: documentation|infrastructure|automation

parameters:
  - name: param_name
    description: Parameter description
    required: true|false
    default: "value"

prerequisites:
  - Required tool or permission

success_criteria:
  - Validation criteria for successful execution
```

## Using Skills

### Prerequisites
- Review individual skill README.md for specific requirements
- Ensure prerequisites are installed (kubectl, helm, etc.)

### Integration
1. Clone the repository or copy specific skill directories
2. Review the skill's README.md for usage instructions
3. Customize skill.yaml parameters as needed
4. Execute scripts or integrate into your workflow

## Contributing

### Adding a New Skill

1. Create a new directory with a kebab-case name
2. Add required files:
   - `README.md` - Document purpose, usage, and prerequisites
   - `skill.yaml` - Define configuration and success criteria
3. Add supporting files as needed (scripts, templates, etc.)
4. Include example outputs when applicable
5. Test thoroughly before committing

### Skill Categories
- **Documentation**: Skills that generate or update documentation
- **Infrastructure**: Skills that configure infrastructure
- **Automation**: Skills that automate development workflows
- **Analysis**: Skills that analyze codebases or systems

## Quality Standards

Each skill must include:
- ✅ Clear, actionable documentation
- ✅ Well-defined success criteria in skill.yaml
- ✅ Tested scripts with appropriate error handling
- ✅ Example outputs demonstrating expected results
- ✅ Version information and prerequisites

## License

This project is part of PIAIC Hackathon 3.

## Repository Structure

```
skills-library/
├── README.md              # This file
├── CLAUDE.md              # Guidance for Claude Code
├── agents-md-gen/         # Agent documentation generator
└── k8s-foundation/        # Kubernetes foundation setup
```

---

**PIAIC Hackathon 3** - Reusable Intelligence Track
