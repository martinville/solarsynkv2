#!/bin/bash

# Script to set up git hooks for version management

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Create post-merge hook
cat > .git/hooks/post-merge << 'EOL'
#!/bin/bash

# This hook runs after a successful git pull or merge operation
# It updates the version in config.yaml based on the tag with highest version number

# Path to config.yaml relative to repository root
CONFIG_FILE="config.yaml"

# Get all tags, sort them by version number (assuming semantic versioning), and get the highest one
# This handles tags like v1.2.3 or 1.2.3 and sorts them properly
LATEST_TAG=$(git tag | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)

# Exit if no tags found
if [ -z "$LATEST_TAG" ]; then
  echo "No valid version tags found, skipping version update"
  exit 0
fi

echo "Found highest version tag: $LATEST_TAG"

# Update the version in config.yaml
if [ -f "$CONFIG_FILE" ]; then
  # Use sed to replace the version line
  sed -i "s/^version: .*$/version: \"$LATEST_TAG\"/" "$CONFIG_FILE"
  echo "Updated version in $CONFIG_FILE to $LATEST_TAG"
else
  echo "Warning: $CONFIG_FILE not found"
fi

exit 0
EOL

# Make the hook executable
chmod +x .git/hooks/post-merge

echo "Git hooks installed successfully"
echo "Version in config.yaml will be updated automatically after git pull"
