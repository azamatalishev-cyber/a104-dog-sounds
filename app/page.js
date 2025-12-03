'use client';

import { useState, useEffect } from 'react';

export default function Home() {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/reports')
      .then(res => res.json())
      .then(data => {
        setReports(data.reports || []);
        setLoading(false);
      })
      .catch(err => {
        console.error('Failed to load reports:', err);
        setLoading(false);
      });
  }, []);

  return (
    <div className="min-h-screen bg-[#0000AA] p-8 flex flex-col items-center justify-center" style={{ fontFamily: 'VT323, monospace' }}>
      <div className="max-w-3xl text-center mb-12">
        <div className="leading-relaxed space-y-4" style={{ color: '#FFFFFF', fontSize: '1.5rem' }}>
          <h1 className="tracking-wide mb-8" style={{ color: '#FFFFFF', textShadow: '2px 2px 0px #000', fontSize: '3rem' }}>
            Pacific Bluff A104 - Dog Activity
          </h1>

          <p className="mb-4">
            <span style={{ color: '#FFFF55' }}>DETECTION SYSTEM</span>
          </p>

          <p>
            Our monitoring system utilizes Wyze and Amcrest cameras integrated with Frigate NVR,
            running default detection models for continuous audio surveillance. The Frigate audio
            classification model captures all potential dog vocalizations in real-time.
          </p>

          <p>
            <span style={{ color: '#FFFF55' }}>PROCESSING PIPELINE</span>
          </p>

          <p>
            All flagged recordings undergo secondary analysis through a two-stage verification process:
          </p>

          <p>
            1. Audio extraction via FFmpeg<br/>
            2. Classification through PANN (Pretrained Audio Neural Networks)
          </p>

          <p>
            <span style={{ color: '#FFFF55' }}>ACCURACY & RELIABILITY</span>
          </p>

          <p>
            Both detection models operate with intentionally low confidence thresholds, ensuring
            comprehensive capture of all canine vocalizations while eliminating false positives through
            dual-stage neural network verification. This approach guarantees maximum detection sensitivity
            while maintaining classification accuracy.
          </p>

          <p className="mt-6" style={{ color: '#55FF55' }}>
            RESULT: Verified, high-confidence dog activity events
          </p>
        </div>
      </div>

      {/* Monthly Reports */}
      <div className="text-center">
        <h2 className="tracking-wide mb-4" style={{ color: '#FFFFFF', textShadow: '2px 2px 0px #000', fontSize: '2.5rem' }}>
          Monthly Reports
        </h2>
        {loading ? (
          <div style={{ color: '#FFFFFF', fontSize: '1.5rem' }}>Loading...</div>
        ) : (
          <div className="flex flex-wrap gap-4 justify-center">
            {reports.map(report => (
              <a
                key={report.value}
                href={`/reports/${report.value}`}
                className="inline-block px-10 py-5"
                style={{
                  fontFamily: 'VT323, monospace',
                  backgroundColor: '#FFFFFF',
                  color: '#0000AA',
                  border: '4px solid #000',
                  textDecoration: 'none',
                  cursor: 'pointer',
                  fontSize: '2rem'
                }}
              >
                {report.label}
              </a>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
