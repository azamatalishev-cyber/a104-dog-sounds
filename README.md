# Dog Bark Clips Archive

A Next.js web application for browsing and reviewing dog bark detection clips from Frigate security cameras, analyzed with PANN audio model.

## Prerequisites

**Node.js 20+** is required. Check your version:
```bash
node --version  # Should be >= 20.9.0
```

If you need to upgrade Node.js:
```bash
# Using Homebrew (macOS):
brew install node@20

# Or download from: https://nodejs.org/
```

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Add your report data:**
   ```bash
   # Copy your report.json file to the data directory
   cp /path/to/your/report.json ./data/report.json
   ```

3. **Configure environment variables:**

   Edit `.env.local` and set your AWS S3 bucket information:
   ```bash
   AWS_REGION=us-east-1
   S3_BUCKET_NAME=your-bucket-name
   S3_CLIPS_PREFIX=clips/
   ```

4. **Ensure AWS credentials are configured:**

   For local development:
   ```bash
   aws configure
   ```

   For EC2 deployment:
   - Attach an IAM role with S3 read permissions to your EC2 instance
   - No credentials needed in .env.local

## Running Locally

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Building for Production

```bash
npm run build
npm start
```

## Deploying to EC2

1. Install Node.js 20+ on EC2
2. Clone/upload this project
3. Run `npm install`
4. Run `npm run build`
5. Use PM2 to run in production: `pm2 start npm --name "dog-clips" -- start`

## Features

- Browse all detected dog bark clips
- Filter by confidence threshold
- Filter by sound type (bark, yip, howl, etc.)
- Sort by confidence, duration, or date
- View detailed scores for each clip
- Secure video playback via S3 presigned URLs

## Tech Stack

- Next.js 14 (App Router)
- React 19
- Tailwind CSS 4
- AWS SDK v3
- S3 for video storage
# a104-dog-sounds
