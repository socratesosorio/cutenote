#!/bin/bash

# GranolaLocal Setup Script
echo "🥣 Setting up GranolaLocal..."

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This app is designed for macOS only"
    exit 1
fi

# Check macOS version
macos_version=$(sw_vers -productVersion)
required_version="13.0"

if [[ $(echo "$macos_version $required_version" | tr " " "\n" | sort -V | head -n1) != "$required_version" ]]; then
    echo "❌ macOS 13.0 or later required. Current version: $macos_version"
    exit 1
fi

echo "✅ macOS version check passed ($macos_version)"

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store"
    exit 1
fi

echo "✅ Xcode found"

# Check Xcode version
xcode_version=$(xcodebuild -version | head -n1 | sed 's/Xcode //')
echo "📱 Xcode version: $xcode_version"

# Navigate to project directory
cd "$(dirname "$0")/GranolaLocal" || {
    echo "❌ Could not find GranolaLocal directory"
    exit 1
}

# Check if project file exists
if [[ ! -f "GranolaLocal.xcodeproj/project.pbxproj" ]]; then
    echo "❌ Xcode project file not found"
    exit 1
fi

echo "✅ Project structure validated"

# Create necessary directories
echo "📁 Creating data directories..."
mkdir -p ~/Documents/GranolaLocal/{Notes,Recordings,Exports,Logs}

# Check for BlackHole
echo "🔍 Checking for BlackHole audio driver..."
if system_profiler SPAudioDataType | grep -q "BlackHole"; then
    echo "✅ BlackHole found"
else
    echo "⚠️  BlackHole not detected. You'll need to install it for system audio capture."
    echo "   Download from: https://github.com/ExistentialAudio/BlackHole"
    echo "   This is required to capture meeting audio from Zoom, Teams, etc."
fi

# Build the project
echo "🔨 Building GranolaLocal..."
xcodebuild -project GranolaLocal.xcodeproj -scheme GranolaLocal -configuration Release build > build.log 2>&1

if [[ $? -eq 0 ]]; then
    echo "✅ Build successful!"
    
    # Find the built app
    built_app=$(find ~/Library/Developer/Xcode/DerivedData -name "GranolaLocal.app" -type d 2>/dev/null | head -n1)
    
    if [[ -n "$built_app" ]]; then
        echo "📱 App built at: $built_app"
        echo ""
        echo "🚀 To run GranolaLocal:"
        echo "   1. Open the built app or run from Xcode"
        echo "   2. Grant microphone permissions when prompted"
        echo "   3. Follow the onboarding to set up BlackHole"
        echo "   4. Configure your OpenAI API key for AI features"
        echo ""
        echo "📖 See README.md for detailed setup instructions"
        
        # Ask if user wants to open the app
        read -p "Would you like to open GranolaLocal now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open "$built_app"
        fi
    else
        echo "⚠️  Build succeeded but couldn't locate the app. Run from Xcode instead."
    fi
else
    echo "❌ Build failed. Check build.log for details:"
    tail -20 build.log
    exit 1
fi

echo ""
echo "🎉 Setup complete! Enjoy using GranolaLocal for your meetings."
echo ""
echo "💡 Quick tips:"
echo "   • Install BlackHole for best audio capture"
echo "   • Use Apple Silicon Mac for fastest transcription"
echo "   • Configure OpenAI API key for AI features"
echo "   • Check Settings for customization options"
