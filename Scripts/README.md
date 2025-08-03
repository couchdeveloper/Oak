# Oak Documentation Scripts

This directory contains utility scripts for working with Oak framework documentation.

## Scripts

### `previewDocs.sh`
Generates and previews Oak framework documentation locally using Swift-DocC.

**Usage:**
```bash
./Scripts/previewDocs.sh

# For VS Code users (if Safari blocks HTTP):
./Scripts/previewDocs.sh --vscode
```

**Features:**
- Automatically builds the project and generates documentation
- Starts a local preview server on port 8081
- Smart browser detection: tries Chrome/Firefox first, falls back to default
- Opens the documentation in your browser at http://localhost:8081/documentation/oak
- `--vscode` flag for VS Code Simple Browser compatibility
- Handles port conflicts automatically
- Colorized output for better readability

**Requirements:**
- Swift 6.0+ with Swift-DocC plugin
- macOS with `open` command available
- For best experience: Chrome, Firefox, or Edge (Safari may require HTTP localhost permission)

### `generateDocs.sh`
Generates static documentation files for deployment.

**Usage:**
```bash
./Scripts/generateDocs.sh
```

**Features:**
- Generates static documentation optimized for web hosting
- Outputs to `generated-docs/` directory
- Includes instructions for local serving
- Suitable for CI/CD and deployment workflows

**Output:**
- Static HTML files in `generated-docs/`
- Access via http://localhost:8080/documentation/oak when served locally
- Ready for deployment to GitHub Pages or other static hosting

## Notes

- Both scripts must be run from the Oak project root directory
- The scripts automatically handle the `--disable-sandbox` flag required by Swift-DocC
- Generated documentation includes all public APIs with documentation comments
- For the best documentation experience, add DocC comments to your Swift code

## Troubleshooting

**Port 8081 already in use:**
The scripts automatically detect and resolve port conflicts.

**Permission denied:**
Make sure the scripts are executable:
```bash
chmod +x Scripts/*.sh
```

**Swift-DocC not available:**
Ensure you have the Swift-DocC plugin dependency in your `Package.swift`.

**Safari HTTP localhost issues:**
Safari may block HTTP connections to localhost. Solutions:
1. The script automatically tries Chrome/Firefox first if available
2. In Safari: Develop menu → Disable Local File Restrictions
3. Or manually open: http://localhost:8081/documentation/oak
4. Or install Chrome/Firefox for better localhost development support
