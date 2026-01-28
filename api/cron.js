// Vercel Cron Job - runs every hour
export default async function handler(req, res) {
  // Only allow cron requests
  if (req.headers['user-agent'] !== 'vercel-cron/1.0') {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    // Trigger news generation
    const newsResponse = await fetch(`${process.env.VERCEL_URL || 'https://globaldatingchat.online'}/api/news`, {
      method: 'GET',
      headers: { 'User-Agent': 'NewsBot/1.0' }
    });

    const newsData = await newsResponse.json();
    
    res.status(200).json({
      success: true,
      articlesGenerated: newsData.count || 0,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Cron job failed:', error);
    res.status(500).json({ error: 'Cron job failed' });
  }
}