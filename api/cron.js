// External Cron Job - runs every 2 hours
export default async function handler(req, res) {
  try {
    // Test direct call to generate-news
    const baseUrl = req.headers.host ? `https://${req.headers.host}` : 'https://globaldatingchat.online';
    const newsResponse = await fetch(`${baseUrl}/api/generate-news`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    if (!newsResponse.ok) {
      throw new Error(`Generate-news failed: ${newsResponse.status}`);
    }

    const newsData = await newsResponse.json();
    
    res.status(200).json({
      success: true,
      articlesGenerated: newsData.generated || 0,
      keywords: newsData.keywords || [],
      errors: newsData.errors || [],
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Cron job failed:', error.message);
    res.status(500).json({ 
      error: 'Cron job failed',
      details: error.message
    });
  }
}