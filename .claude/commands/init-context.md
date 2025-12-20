# init-context

Analyze the codebase and create a `.claude.ctx` file with context information for future Claude Code instances.

## Instructions

When this command is run:

1. Analyze the repository structure and key files:
   - Build scripts (especially `websubhub-docker-build.sh`)
   - Docker Compose configurations in `docker/*/`
   - Configuration files (`.toml` files)
   - README.md for high-level architecture
   - GitHub workflows

2. Create a `.claude.ctx` file in the repository root with the following sections:
   - **Repository Purpose**: Brief description of what this repository does
   - **Key Architecture Concepts**: Important architectural patterns that require understanding multiple files
   - **Common Commands**: Commands for building, deploying, and validating
   - **Important Constraints**: Critical rules and requirements that must be followed

3. Focus on:
   - Multi-file workflows and dependencies
   - Non-obvious architectural decisions
   - Critical configuration requirements
   - Common commands that developers need

4. Do NOT include:
   - Generic development practices
   - Obvious information that can be easily discovered
   - File-by-file listings of components
   - Made-up information about tasks that don't exist

5. Keep the content concise and focused on what makes this codebase unique.
