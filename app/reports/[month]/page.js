'use client';

import { useState, useEffect } from 'react';
import { useParams } from 'next/navigation';

export default function MonthlyReport() {
  const params = useParams();
  const month = params.month;
  const [reportData, setReportData] = useState(null);
  const [description, setDescription] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch the report data for this month
    Promise.all([
      fetch(`/api/clips?month=${month}`).then(res => res.json()),
      fetch(`/api/description/${month}`).then(res => res.json())
    ])
      .then(([clipsData, descData]) => {
        setReportData(clipsData);
        setDescription(descData.description);
        setLoading(false);
      })
      .catch(err => {
        console.error('Failed to load report:', err);
        setLoading(false);
      });
  }, [month]);

  const getS3FileName = (clip) => {
    // Extract from file_path: /home/azamat/frigate/storage/recordings/2025-11-30/03/living_room/17.12.mp4
    // Result should be: living_room_17.12.mp4
    const parts = clip.file_path.split('/');
    const fileName = parts[parts.length - 1]; // e.g., "17.12.mp4"
    const camera = parts[parts.length - 2]; // e.g., "living_room"

    return `${camera}_${fileName}`;
  };

  const handleDownload = async (clip, e) => {
    e.preventDefault();
    try {
      const s3FileName = getS3FileName(clip);

      // Get presigned URL with month parameter
      const response = await fetch(`/api/video/${encodeURIComponent(s3FileName)}?month=${month}`);
      const data = await response.json();

      // Download the file
      const link = document.createElement('a');
      link.href = data.url;
      link.download = s3FileName;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (err) {
      console.error('Failed to download video:', err);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0000AA] flex items-center justify-center" style={{ fontFamily: 'VT323, monospace' }}>
        <div style={{ color: '#FFFFFF', fontSize: '2rem' }}>Loading...</div>
      </div>
    );
  }

  if (!reportData || !reportData.summary) {
    return (
      <div className="min-h-screen bg-[#0000AA] flex items-center justify-center" style={{ fontFamily: 'VT323, monospace' }}>
        <div style={{ color: '#FFFFFF', fontSize: '2rem' }}>Report not found</div>
      </div>
    );
  }

  // Parse month for display
  const [year, monthNum] = month.split('-');
  const date = new Date(year, parseInt(monthNum) - 1);
  const monthName = date.toLocaleString('en-US', { month: 'long' });
  const displayTitle = `${monthName} ${year}`;

  // Calculate total duration in seconds
  const totalSeconds = reportData.valid_clips.reduce((sum, clip) => sum + clip.duration_seconds, 0);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = Math.floor(totalSeconds % 60);

  const getTypeColor = (type) => {
    const colors = {
      'bark': '#7aa2f7',
      'bow-wow': '#bb9af7',
      'howl': '#ff9e64',
      'growl': '#f7768e',
      'yip': '#73daca',
    };
    return colors[type] || '#8b949e';
  };

  return (
    <div className="min-h-screen bg-[#0000AA] p-8" style={{ fontFamily: 'VT323, monospace' }}>
      <div className="max-w-7xl mx-auto">
        {/* Header and Description */}
        <div className="text-center mb-12">
          <h1 className="tracking-wide mb-10" style={{ color: '#FFFFFF', textShadow: '2px 2px 0px #000', fontSize: '4rem' }}>
            {displayTitle}
          </h1>

          {description ? (
            <p className="leading-relaxed mb-8 whitespace-pre-line" style={{ color: '#FFFFFF', fontSize: '2rem' }}>
              {description}
            </p>
          ) : (
            <p className="leading-relaxed mb-8" style={{ color: '#FFFFFF', fontSize: '2rem' }}>
              In {displayTitle}, my Frigate home security system recorded only{' '}
              <span style={{ color: '#FFFF55' }}>{reportData.summary.valid_dog_noises}</span> valid dog noise clips,
              totaling just <span style={{ color: '#FFFF55' }}>{Math.round(totalSeconds)}</span> seconds
              ({minutes} minute{minutes !== 1 ? 's' : ''} and {seconds} second{seconds !== 1 ? 's' : ''})
              of dog noise for the entire month.
            </p>
          )}

          <a
            href="/"
            className="inline-block px-16 py-8"
            style={{
              fontFamily: 'VT323, monospace',
              backgroundColor: '#FFFFFF',
              color: '#0000AA',
              border: '5px solid #000',
              textDecoration: 'none',
              cursor: 'pointer',
              fontSize: '3rem'
            }}
          >
            Back to Home
          </a>
        </div>

        {/* Video Grid */}
        <div className="grid grid-cols-8 md:grid-cols-10 lg:grid-cols-12 xl:grid-cols-15 gap-12 mt-12">
          {reportData.valid_clips.map((clip, idx) => (
            <a
              key={idx}
              href="#"
              onClick={(e) => handleDownload(clip, e)}
              className="block p-1 text-center flex flex-col justify-center"
              style={{
                backgroundColor: '#FFFFFF',
                border: '2px solid #000',
                textDecoration: 'none',
                cursor: 'pointer',
                color: '#0000AA',
                aspectRatio: '1 / 1'
              }}
            >
              <div className="font-bold" style={{
                fontFamily: 'VT323, monospace',
                wordBreak: 'break-all',
                fontSize: '1.5rem'
              }}>
                {clip.file_name}
              </div>
              <div className="font-bold" style={{
                fontFamily: 'VT323, monospace',
                color: getTypeColor(clip.sound_type),
                fontSize: '2rem'
              }}>
                {clip.sound_type.toUpperCase()}
              </div>
              <div style={{ fontFamily: 'VT323, monospace', fontSize: '1.7rem' }}>
                {clip.duration_seconds.toFixed(1)}s
              </div>
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
