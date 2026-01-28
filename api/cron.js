// Vercel Cron Job - runs every hour
export default async function handler(req, res) {
  // Allow both Vercel cron and external cron services
  const validUserAgents = ['vercel-cron/1.0', 'cron-job.org'];
  if (!validUserAgents.includes(req.headers['user-agent'])) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    // Trigger news generation
    const newsResponse = await fetch(`${process.env.VERCEL_URL || 'https://globaldatingchat.online'}/api/generate-news`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    const newsData = await newsResponse.json();
    
    res.status(200).json({
      success: true,
      articlesGenerated: newsData.generated || 0,
      keywords: newsData.keywords || [],
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Cron job failed:', error);
    res.status(500).json({ error: 'Cron job failed' });
  }
}