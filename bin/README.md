# bin/ Directory

## Note

Most utilities are now **shell functions** in `../shell/functions` for better performance.

These standalone scripts are kept for:
- Compatibility with existing workflows
- Use outside of shell sessions
- Reference implementations

## Available Functions

Run these directly in your shell (no `./` needed):

```bash
branches              # Show recent git branches
coauthor "name"       # Find git co-authors  
get_localip           # Get local IP address
videoconvert in out   # Convert video to MP4
```

## Personal Scripts

Add your own scripts to `~/bin.local/` - automatically added to PATH.
