import { NextResponse } from 'next/server';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';

const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
});

export async function GET(request, { params }) {
  try {
    const { month } = await params;
    const bucketName = process.env.S3_BUCKET_NAME;

    if (!bucketName) {
      return NextResponse.json(
        { error: 'S3_BUCKET_NAME not configured' },
        { status: 500 }
      );
    }

    const s3Key = `${month}/monthly_description.txt`;

    try {
      const command = new GetObjectCommand({
        Bucket: bucketName,
        Key: s3Key,
      });

      const response = await s3Client.send(command);
      const description = await response.Body.transformToString();

      return NextResponse.json({ description });
    } catch (s3Error) {
      console.error('Failed to fetch description from S3:', s3Error);

      // Return a default message if file doesn't exist
      return NextResponse.json(
        { description: null },
        { status: 404 }
      );
    }
  } catch (error) {
    console.error('Error loading description:', error);
    return NextResponse.json(
      { error: 'Failed to load description: ' + error.message },
      { status: 500 }
    );
  }
}
