# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a skills library for PIAIC Hackathon 3 focused on "Reusable Intelligence". The repository is designed to house Claude Code skills that can be reused across different projects.

## Repository Structure

Each skill is a standalone directory at the root level with the following structure:

```
skill-name/
├── README.md           # Skill documentation
├── skill.yaml          # Skill configuration
├── prompt.md           # (Optional) Skill prompt template
├── scripts/            # (Optional) Supporting scripts
├── helm/               # (Optional) Helm charts for K8s skills
└── example-output/     # (Optional) Example outputs
```

### Current Skills

- **agents-md-gen/**: Generates AGENTS.md documentation files
  - Contains prompt template and example outputs

- **k8s-foundation/**: Kubernetes foundation setup
  - Includes cluster check and base installation scripts
  - Contains Helm charts for nginx and other base services

## Skills Development

### Skill Structure Requirements

Each skill must include:
1. **skill.yaml**: Defines the skill configuration, parameters, and metadata
2. **README.md**: Documents what the skill does, how to use it, and any prerequisites
3. **Supporting files**: Scripts, templates, configs, or examples as needed

### Adding New Skills

When creating a new skill:
1. Create a new directory at the root level with a descriptive kebab-case name
2. Add `skill.yaml` with the skill configuration
3. Add `README.md` documenting the skill's purpose and usage
4. Include any supporting files (scripts, templates, helm charts, etc.)
5. If applicable, add an `example-output/` directory with sample results
6. Test the skill thoroughly before committing

### Skill Categories

Skills in this library fall into these categories:
- **Documentation Generation**: Skills that create or update documentation (e.g., agents-md-gen)
- **Infrastructure Setup**: Skills that configure infrastructure (e.g., k8s-foundation)

## Development Workflow

1. **Create/Modify**: Add or update skill directories with all required files
2. **Test**: Validate that scripts execute correctly and configurations are valid
3. **Document**: Ensure README.md clearly explains usage and examples are provided
4. **Commit**: Commit the complete skill directory to the repository

## Notes

- This is a hackathon project focusing on creating reusable AI skills
- The repository is in early stages and may evolve as skills are added
- Skills should be designed for maximum reusability across different projects
