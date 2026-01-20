#!/bin/bash

# Firebase Cloud Functions Quick Deploy Script

echo "🚀 Firebase Cloud Functions Deployment"
echo "========================================"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "📦 Installing Firebase CLI..."
    npm install -g firebase-tools
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js 18 or higher required!"
    echo "Current version: $(node -v)"
    echo "Install from: https://nodejs.org/"
    exit 1
fi

echo "✅ Prerequisites met"
echo ""

# Navigate to functions directory
cd functions

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful"
echo ""

# Navigate back to root
cd ..

# Deploy
echo "🚀 Deploying to Firebase..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "📊 View logs:"
    echo "   firebase functions:log"
    echo ""
    echo "🔍 View in console:"
    echo "   https://console.firebase.google.com/project/cues-1ced9/functions"
    echo ""
else
    echo ""
    echo "❌ Deployment failed!"
    echo "Run with --debug for more info:"
    echo "   firebase deploy --only functions --debug"
fi
