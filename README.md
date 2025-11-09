# Softcover

A lightweight, native [Hardcover.app](https://hardcover.app) client for iOS written in Swift. 

## Features

- Browse and search for books
- Track your currently reading books
- Manage your Want to Read and Finished lists
- View your reading statistics and goals
- Update reading progress (by page, time, or percentage)
- Full audiobook support with hour:minute time tracking
- Release notifications for upcoming books
- Home screen widgets showing your reading progress
- Multi-language support (English & Swedish)

## Requirements

- Xcode 15.0 or later
- iOS 17.0 or later
- A [Hardcover.app](https://hardcover.app) account and API key

## Getting Your Hardcover API Key

1. Go to [hardcover.app](https://hardcover.app) and sign in
2. Navigate to Settings → Developer
3. Generate a new API key
4. Copy the key for use in the app

## Building and Running

### Using Xcode

1. **Clone the repository**
   ```bash
   git clone https://github.com/komadorirobin/Softcover.git
   cd Softcover
   ```

2. **Open the project**
   ```bash
   open "Softcover.xcodeproj"
   ```
   Or simply double-click `Softcover.xcodeproj` in Finder

3. **Select your target device**
   - In Xcode, select your iPhone or iPad from the device dropdown (top toolbar)
   - Or choose "Any iOS Device" to build for physical devices
   - Or select an iOS Simulator

4. **Build and run**
   - Press `Cmd + R` or click the Play button
   - For physical devices, you'll need to:
     - Connect your device via USB or WiFi
     - Trust your development certificate on the device
     - Enable Developer Mode (Settings → Privacy & Security → Developer Mode)

5. **First launch setup**
   - When you first open the app, you'll be prompted to enter your Hardcover API key
   - Paste the API key you generated from hardcover.app
   - The app will save this securely and use it for all API requests

### Building from Command Line

```bash
# Build for simulator
xcodebuild -project Softcover.xcodeproj -scheme "Hardcover Reading Widget" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build for device (requires signing configuration)
xcodebuild -project Softcover.xcodeproj -scheme "Hardcover Reading Widget" -destination 'generic/platform=iOS' build
```

## Project Structure

- **Hardcover Reading Widget/** - Main iOS app
  - `ContentView.swift` - Main book list and progress tracking UI
  - `SearchBooksView.swift` - Book search functionality
  - `ApiKeySettingsView.swift` - Settings and configuration
  - `HardcoverService*.swift` - API client for Hardcover GraphQL API
  - `StatsView.swift` - Reading statistics and goals
- **ReadingProgressWidget/** - Home screen widgets
  - `ReadingProgressWidget.swift` - Main widget implementation
  - `ReadingGoalWidget.swift` - Reading goal widget

## Troubleshooting

**"Failed to build" errors:**
- Make sure you have Xcode 15.0 or later installed
- Clean build folder: Product → Clean Build Folder (Cmd + Shift + K)
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`

**Code signing issues:**
- Open the project in Xcode
- Select the project in the navigator
- Go to "Signing & Capabilities" tab
- Change the Team to your Apple Developer account
- Change the Bundle Identifier to something unique

**Widget not appearing:**
- Make sure the widget extension is enabled in your build scheme
- Check that you have the correct App Group configured
- Try removing and re-adding the widget from the home screen

## Contributing

Contributions are welcome! Feel free to:
- Report bugs by opening an issue
- Suggest new features
- Submit pull requests

## License

This project is open source. Please check the LICENSE file for details.

## Acknowledgments

Built with love for the [Hardcover.app](https://hardcover.app) community.
