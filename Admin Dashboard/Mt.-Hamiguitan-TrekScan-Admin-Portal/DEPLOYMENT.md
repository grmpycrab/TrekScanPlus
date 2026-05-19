# Firebase Hosting Deployment Guide

This guide will help you deploy your Mt. Hamiguitan TrekScan Admin Portal to Firebase Hosting.

## Quick Reference

**Current Project Configuration:**
- Firebase Project ID: `trekscanplus`
- Build Output: `dist` folder
- Deploy Command: `npm run deploy`

**Quick Deploy:**
```bash
npm run deploy
```

## Prerequisites

1. **Firebase Account**: Make sure you have a Firebase account and a Firebase project created
2. **Node.js**: Ensure Node.js is installed (v16 or higher recommended)
3. **Firebase CLI**: Install Firebase CLI globally

## Step 1: Install Firebase CLI

If you haven't installed Firebase CLI yet, run:

```bash
npm install -g firebase-tools
```

## Step 2: Login to Firebase

```bash
firebase login
```

This will open a browser window for you to authenticate with your Google account.

## Step 3: Initialize Firebase Hosting (Already Done)

**Note**: Firebase Hosting is already initialized for this project. The configuration files (`.firebaserc` and `firebase.json`) are already set up.

If you need to reinitialize or set up a new project, run:

```bash
firebase init hosting
```

When prompted:
- **Select an existing project** or create a new one
- **Public directory**: Enter `dist` (this is where Vite builds your app)
- **Configure as a single-page app**: Yes (enter `y`)
- **Set up automatic builds and deploys with GitHub**: No (enter `n` for now, you can set this up later)
- **Overwrite index.html**: No (enter `n`)

## Step 4: Verify Firebase Configuration

The project is currently configured with the Firebase project ID: **`trekscanplus`**

You can verify this in `.firebaserc`:

```json
{
  "projects": {
    "default": "trekscanplus"
  }
}
```

If you need to change the project, update the `.firebaserc` file with your Firebase project ID (you can find it in Firebase Console).

## Step 5: Build Your Application

Before deploying, build your production-ready application:

```bash
npm run build
```

This will create a `dist` folder with optimized production files.

## Step 6: Deploy to Firebase

Deploy your application using the convenient npm script (recommended):

```bash
npm run deploy
```

This command will:
1. Build your application (`npm run build`)
2. Deploy to Firebase Hosting (`firebase deploy --only hosting`)

Alternatively, you can deploy manually:

```bash
firebase deploy --only hosting
```

## Step 7: Access Your Deployed App

After deployment, Firebase will provide you with a hosting URL. For this project, it should be:
```
https://trekscanplus.web.app
```
or
```
https://trekscanplus.firebaseapp.com
```

## Environment Variables

If your app uses environment variables (like `VITE_FIREBASE_API_KEY`), you need to set them up:

1. Create a `.env.production` file in your project root:
```env
VITE_FIREBASE_API_KEY=your-api-key
VITE_FIREBASE_PROJECT_ID=your-project-id
VITE_API_URL=your-api-url
```

2. These variables will be included in the build when you run `npm run build`

## Updating Your Deployment

To update your deployed app:

1. Make your changes
2. Deploy using the npm script (builds and deploys in one step):
   ```bash
   npm run deploy
   ```

   Or manually:
   ```bash
   npm run build
   firebase deploy --only hosting
   ```

## Troubleshooting

### Build fails
- Make sure all dependencies are installed: `npm install`
- Check for any linting errors: `npm run lint`

### Deployment fails
- Verify you're logged in: `firebase login`
- Check your project ID in `.firebaserc` matches your Firebase project
- Ensure `dist` folder exists (run `npm run build` first)

### App doesn't load correctly
- Check that `firebase.json` has the correct rewrite rules for SPA routing
- Verify environment variables are set correctly
- Check browser console for any errors

## Custom Domain (Optional)

To use a custom domain:

1. Go to Firebase Console > Hosting
2. Click "Add custom domain"
3. Follow the instructions to verify domain ownership
4. Update your DNS records as instructed

## Continuous Deployment (Optional)

You can set up automatic deployments using GitHub Actions or Firebase CI/CD:

1. Connect your GitHub repository to Firebase
2. Set up GitHub Actions workflow or use Firebase's built-in CI/CD
3. Configure automatic deployments on push to main branch

## Additional Resources

- [Firebase Hosting Documentation](https://firebase.google.com/docs/hosting)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)

