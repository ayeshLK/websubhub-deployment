# update-context

Update the existing `.claude.ctx` file with new information about the project.

## Instructions

When this command is run:

1. Check if `.claude.ctx` exists in the repository root:
   - If it doesn't exist, inform the user and suggest running `/init-context` first
   - If it exists, proceed with the update

2. Review recent changes in the repository:
   - Check git status to see modified files
   - Analyze any new files or directories
   - Review recent modifications to build scripts, Docker configs, or workflows
   - Check for new broker configurations or deployment options

3. Identify what needs updating in `.claude.ctx`:
   - New architecture patterns or workflows
   - Additional commands or deployment options
   - Updated constraints or requirements
   - New broker support or configuration changes
   - Modified build processes

4. Update the `.claude.ctx` file by:
   - Adding new sections if needed
   - Updating existing sections with new information
   - Removing outdated information
   - Keeping the structure consistent with the original

5. Inform the user of what was updated:
   - List the sections that were modified
   - Briefly describe what changed
   - Note any removed outdated information

6. Keep updates focused on:
   - Architectural changes that affect how developers work with the code
   - New workflows or commands
   - Critical constraint changes
   - Avoid minor cosmetic changes
