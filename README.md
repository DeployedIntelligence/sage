# Sage

> Your AI-powered coach for mastering any skill

**Sage** is a skill-agnostic learning platform that helps you master any skill through personalized AI coaching, smart practice tracking, and automated resource curation. Whether you're learning watercolor painting, juggling, SQL optimization, or bread baking —- Sage adapts to your goals.

---

## 🎯 What is Sage?

Sage is a Progressive Web App (PWA) that combines:
- **LLM-Powered Onboarding**: Define any skill you want to learn, and Sage helps you set measurable goals
- **Dynamic Practice Tracking**: Custom metrics that adapt to your specific skill
- **AI Coaching**: Personalized guidance from Claude, tailored to your skill and progress
- **Smart Resource Curation**: Automated discovery of learning materials using web search + AI
- **Progress Analytics**: Charts, streaks, and insights to keep you motivated
- **Google Calendar Integration**: Auto-schedule practice sessions based on your availability
- **Community Features**: Discover what others are learning and find practice partners

---

## 🏗️ Building in Public

This project is being built in public! Follow along on the **[Deployed Intelligence YouTube channel](https://www.youtube.com/@Deployed.Intelligence)** where I document my learnings, progress, challenges, and wins as I build Sage from scratch.

### What You'll See on the Channel:
- 🎥 Weekly development vlogs
- 💡 Technical deep-dives on GCP, Next.js, and Claude API
- 🐛 Real debugging sessions and problem-solving
- 📊 Progress updates and milestone celebrations
- 🧠 Lessons learned from building with AI

**Subscribe to join the journey:** [youtube.com/@Deployed.Intelligence](https://www.youtube.com/@Deployed.Intelligence)

---

## 🛠️ Tech Stack

### Frontend
- **Framework**: Next.js 14 (App Router)
- **UI Library**: React 18 with TypeScript
- **Styling**: Tailwind CSS + shadcn/ui components
- **State Management**: React Context + Hooks
- **Charts**: Recharts
- **PWA**: next-pwa with offline sync (Dexie.js)

### Backend
- **API**: FastAPI
- **Database**: PostgreSQL (Cloud SQL) with pgvector for semantic search
- **Auth**: Firebase Authentication
- **Storage**: Cloud Storage + Firestore
- **Cache**: Memorystore (Redis)
- **Background Jobs**: Cloud Functions + Cloud Tasks

### AI & Integrations
- **LLM**: Claude (Anthropic API)
- **MCP Server**: Custom tool server for resource search
- **Web Search**: Integrated via Claude's tools
- **Calendar**: Google Calendar API
- **Email**: SendGrid
- **Notifications**: Firebase Cloud Messaging

### Infrastructure (GCP)
- **Compute**: Cloud Run (containerized)
- **CI/CD**: Cloud Build
- **CDN**: Cloud CDN
- **Security**: Cloud Armor (DDoS protection, rate limiting)
- **Monitoring**: Cloud Monitoring + Cloud Logging + Error Reporting
- **IaC**: Terraform

---

## 🤝 Contributing

This is primarily a solo learning project built in public, but suggestions and feedback are welcome! 

Ways to contribute:
1. **Watch the YouTube series**: [Deployed Intelligence](https://www.youtube.com/@Deployed.Intelligence)
2. **Leave feedback**: Comment on videos with ideas or suggestions
3. **Report bugs**: Open an issue (once app is live)
4. **Share your experience**: If you build something similar, share your learnings!

---

## 📺 Follow the Journey

Building Sage is a journey of learning:
- **GCP infrastructure** - from basics to production-grade
- **AI integration** - Claude, MCP, LangGraph workflows
- **Product development** - from idea to shipped feature
- **Solo founder challenges** - time management, decision-making

Join me on **[Deployed Intelligence](https://www.youtube.com/@Deployed.Intelligence)** and let's learn together!

---

## 🙏 Acknowledgments

- **Anthropic** - for Claude and the incredible developer experience
- **Google Cloud** - for the robust infrastructure platform
- **Everyone watching on YouTube** - your support keeps me going!

---

## 📬 Contact

- **YouTube**: [@Deployed.Intelligence](https://www.youtube.com/@Deployed.Intelligence)
- **Email**: intelligence.deployed@gmail.com
- **App**: Coming soon

---

**Built with ☕ and 🤖 by a solo developer learning in public**

*Star this repo if you're following along! Subscribe to the [YouTube channel](https://www.youtube.com/@Deployed.Intelligence) for weekly updates.*
