# Upload to Play Store Internal Testing (Enables Assistant Testing)

## Why Internal Testing?

- ✅ No public review needed
- ✅ Can test with up to 100 testers
- ✅ Enables App Actions testing
- ✅ Google Assistant can recognize your app
- ✅ Takes ~24 hours for App Actions to activate

## Step 1: Build Release Bundle

\`\`\`bash
cd /Users/amriteshkumar/Developer/cue

# Build release bundle
flutter build appbundle --releas

# Output will be at:
# build/app/outputs/bundle/release/app-release.aab
\`\`\`

## Step 2: Create Play Store Account (If You Don't Have One)

1. Go to: https://play.google.com/console
2. Sign in with Google account
3. Pay one-time $25 registration fee (if first app)
4. Create new application

## Step 3: Upload to Internal Testing

1. In Play Console, go to your app
2. Click **"Testing"** → **"Internal testing"**
3. Click **"Create new release"**
4. Upload the `app-release.aab` file
5. Fill in release notes (can be simple: "Testing release")
6. Click **"Review release"** → **"Start rollout to Internal testing"**

## Step 4: Add Yourself as Tester

1. In **Internal testing** page:
2. Click **"Testers"** tab
3. Create email list with your email
4. Save

## Step 5: Enable App Actions

1. Go to **"App content"** → **"App Actions"**
2. Click **"Get started"**
3. Upload your `actions.xml` file from: `android/app/src/main/res/xml/actions.xml`
4. Add sample queries:
   - "Remind me to buy milk at 5 PM"
   - "Set a reminder to call mom tomorrow"
   - "Create a reminder to workout at 7 AM"
5. Click **"Save"**

## Step 6: Install from Play Store

1. Open the internal testing link (provided in Play Console)
2. Accept being a tester
3. Install the app from Play Store
4. Wait 24-48 hours for Google to index

## Step 7: Test with Google Assistant

After ~24 hours, try:

\`\`\`
"Hey Google, remind me to buy milk at 5 PM"
\`\`\`

Google Assistant should now:
- Show Cue as an option
- OR ask which app to use
- OR automatically use Cue (if you select it as default)

## Alternative: Request Production Review

If you want it to work for everyone:

1. Complete all sections in Play Console
2. Submit for production review
3. Google reviews in 1-3 days
4. After approval, all users can use it

## Cost

- **One-time**: $25 registration (if new developer)
- **Ongoing**: Free

## Timeline

- Upload: 5 minutes
- Processing: 1-2 hours
- App Actions activation: 24-48 hours
- Total: ~2 days

Ready to start? Build the release bundle first!
