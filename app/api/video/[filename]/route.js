import { NextResponse } from 'next/server';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

// Initialize S3 client (uses IAM role credentials on EC2, or local AWS credentials)
const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
});

export async function GET(request, { params }) {
  try {
    const { filename } = await params;
    const { searchParams } = new URL(request.url);
    const month = searchParams.get('month');

    const bucketName = process.env.S3_BUCKET_NAME;

    // Use month from query param if provided, otherwise use env variable
    const clipPrefix = month ? `${month}/` : (process.env.S3_CLIPS_PREFIX || '');

    if (!bucketName) {
      return NextResponse.json(
        { error: 'S3_BUCKET_NAME not configured' },
        { status: 500 }
      );
    }

    // Generate presigned URL (expires in 1 hour)
    const command = new GetObjectCommand({
      Bucket: bucketName,
      Key: `${clipPrefix}${filename}`,
    });

    const url = await getSignedUrl(s3Client, command, { expiresIn: 3600 });

    return NextResponse.json({ url });
  } catch (error) {
    console.error('Error generating presigned URL:', error);
    return NextResponse.json(
      { error: 'Failed to generate video URL: ' + error.message },
      { status: 500 }
    );
  }
}
