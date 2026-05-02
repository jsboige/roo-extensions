# Set environment variable and test statusline
$env:ROOSYNC_SHARED_PATH = "C:\Drive\.shortcut-targets-by-id\1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB\.shared-state"

# Test with stdin JSON
$json = '{"model":"glm-5.1","cwd":"c:/dev/roo-extensions"}'
$json | & .\scripts\claude\roosync-statusline.ps1 -Preset normal