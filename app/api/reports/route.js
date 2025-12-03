import { NextResponse } from 'next/server';
import { S3Client, ListObjectsV2Command } from '@aws-sdk/client-s3';

const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
});

export async function GET() {
  try {
    const bucketName = process.env.S3_BUCKET_NAME;

    if (!bucketName) {
      return NextResponse.json(
        { error: 'S3_BUCKET_NAME not configured' },
        { status: 500 }
      );
    }

    // List all objects in the bucket
    const command = new ListObjectsV2Command({
      Bucket: bucketName,
      Delimiter: '/',
    });

    const response = await s3Client.send(command);

    // Extract unique month prefixes (e.g., "2025-11/")
    const prefixes = response.CommonPrefixes || [];
    const months = prefixes
      .map(prefix => prefix.Prefix.replace('/', ''))
      .filter(prefix => /^\d{4}-\d{2}$/.test(prefix)) // Match YYYY-MM format
      .sort()
      .reverse(); // Most recent first

    // Convert to display format
    const reports = months.map(month => {
      const [year, monthNum] = month.split('-');
      const date = new Date(year, parseInt(monthNum) - 1);
      const monthName = date.toLocaleString('en-US', { month: 'long' });

      return {
        value: month,
        label: `${monthName} ${year}`,
      };
    });

    return NextResponse.json({ reports });
  } catch (error) {
    console.error('Error listing S3 prefixes:', error);
    return NextResponse.json(
      { error: 'Failed to list reports: ' + error.message },
      { status: 500 }
    );
  }
}
