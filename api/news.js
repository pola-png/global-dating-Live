// Simplified News API
export default async function handler(req, res) {
    try {
        // Simple mock news data for now
        const articles = [
            {
                title: "Breaking: Global Technology Advances in 2024",
                description: "Major technological breakthroughs are reshaping industries worldwide with AI and automation leading the charge.",
                link: "#",
                publishedAt: new Date().toISOString(),
                category: "Technology",
                source: "Tech News",
                image: "https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=800&h=400&fit=crop",
                trafficScore: 85
            },
            {
                title: "Entertainment Industry Sees Major Changes",
                description: "Streaming platforms and digital content creation are transforming how we consume entertainment.",
                link: "#",
                publishedAt: new Date(Date.now() - 3600000).toISOString(),
                category: "Entertainment",
                source: "Entertainment Weekly",
                image: "https://images.unsplash.com/photo-1489599904472-af35ff2c7c3f?w=800&h=400&fit=crop",
                trafficScore: 75
            },
            {
                title: "Sports World Celebrates New Records",
                description: "Athletes around the globe are breaking records and setting new standards in their respective sports.",
                link: "#",
                publishedAt: new Date(Date.now() - 7200000).toISOString(),
                category: "Sports",
                source: "Sports Central",
                image: "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800&h=400&fit=crop",
                trafficScore: 90
            },
            {
                title: "Business Markets Show Strong Growth",
                description: "Global markets are experiencing unprecedented growth with new investment opportunities emerging.",
                link: "#",
                publishedAt: new Date(Date.now() - 10800000).toISOString(),
                category: "Business",
                source: "Business Today",
                image: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&h=400&fit=crop",
                trafficScore: 70
            },
            {
                title: "Health Innovations Transform Healthcare",
                description: "Revolutionary medical technologies are improving patient care and treatment outcomes worldwide.",
                link: "#",
                publishedAt: new Date(Date.now() - 14400000).toISOString(),
                category: "Health",
                source: "Health News",
                image: "https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=800&h=400&fit=crop",
                trafficScore: 65
            },
            {
                title: "Climate Action Gains Global Momentum",
                description: "Countries worldwide are implementing new policies to combat climate change and promote sustainability.",
                link: "#",
                publishedAt: new Date(Date.now() - 18000000).toISOString(),
                category: "Environment",
                source: "Green News",
                image: "https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=800&h=400&fit=crop",
                trafficScore: 80
            }
        ];
        
        res.status(200).json({ 
            articles: articles,
            count: articles.length,
            status: 'success'
        });
        
    } catch (error) {
        res.status(500).json({ 
            error: 'Failed to fetch news',
            articles: [],
            count: 0
        });
    }
}