# load-context

Load and display the context from the `.claude.ctx` file to refresh understanding of the project.

## Instructions

When this command is run:

1. Check if `.claude.ctx` exists in the repository root:
   - If it doesn't exist, inform the user and suggest running `/init-context` first
   - If it exists, proceed with loading

2. Read the entire `.claude.ctx` file and internalize the information

3. Display a summary to the user with:
   - Repository purpose (brief overview)
   - Number of key architecture concepts documented
   - Available common commands
   - Number of important constraints
   - Any special notes or critical information

4. Confirm the context has been loaded:
   - Let the user know you now have the project context loaded
   - Mention you're ready to work with this understanding
   - Suggest they can ask questions about specific aspects if needed

5. Example output format:
   ```
   ✓ Context loaded from .claude.ctx

   Repository: WSO2 WebSubHub Deployment (deployment-only repo)
   Architecture concepts: 3 documented
   Common commands: Build, Deploy (Kafka/Solace), Validate
   Constraints: 5 critical rules

   Ready to work with full project context. Ask me anything about the deployment setup!
   ```

6. After loading, be prepared to:
   - Answer questions about architecture
   - Suggest appropriate commands for user goals
   - Apply constraints when making changes
   - Reference specific sections when explaining decisions
