// External Cron Job - runs every 2 hours
export default async function handler(req, res) {
  // Allow all requests for external cron services

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