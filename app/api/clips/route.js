import { NextResponse } from 'next/server';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import fs from 'fs';
import path from 'path';

const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
});

export async function GET(request) {
  try {
    // Get month parameter from query string
    const { searchParams } = new URL(request.url);
    const month = searchParams.get('month');

    let reportData;

    if (month) {
      // Fetch from S3: s3://bucket/2025-11/analysis_2025-11.json
      const bucketName = process.env.S3_BUCKET_NAME;

      if (!bucketName) {
        return NextResponse.json(
          { error: 'S3_BUCKET_NAME not configured' },
          { status: 500 }
        );
      }

      const s3Key = `${month}/analysis_${month}.json`;

      try {
        const command = new GetObjectCommand({
          Bucket: bucketName,
          Key: s3Key,
        });

        const response = await s3Client.send(command);
        const bodyString = await response.Body.transformToString();
        reportData = JSON.parse(bodyString);
      } catch (s3Error) {
        console.error('S3 fetch failed, trying local file:', s3Error);

        // Fallback to local file if S3 fetch fails
        const localPath = path.join(process.cwd(), 'data', `analysis_${month}.json`);

        if (!fs.existsSync(localPath)) {
          return NextResponse.json(
            { error: `Report not found in S3 or locally: ${s3Key}` },
            { status: 404 }
          );
        }

        reportData = JSON.parse(fs.readFileSync(localPath, 'utf8'));
      }
    } else {
      // Default to local report.json
      const reportPath = path.join(process.cwd(), 'data', 'report.json');

      if (!fs.existsSync(reportPath)) {
        return NextResponse.json(
          { error: 'Report file not found. Please add report.json to the data/ directory.' },
          { status: 404 }
        );
      }

      reportData = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
    }

    return NextResponse.json(reportData);
  } catch (error) {
    console.error('Error loading clips:', error);
    return NextResponse.json(
      { error: 'Failed to load clips: ' + error.message },
      { status: 500 }
    );
  }
}
