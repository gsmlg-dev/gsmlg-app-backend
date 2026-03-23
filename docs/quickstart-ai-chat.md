# 🚀 AI Chat Quick Start Guide

## ⚡ Start Chatting in 3 Steps

### 1️⃣ Open the Application
```
http://localhost:4153
```

### 2️⃣ Sign In
```
Email: admin@example.com
Password: admin123456
```

### 3️⃣ Click "AI Chat" → Select "Mock AI (Testing)" → Start Chatting! 🎉

---

## 🎯 What You Can Do Right Now

### Test Messages to Try:
- `"Hello"` - Get a friendly greeting
- `"What can you do?"` - Learn about features
- `"Test the streaming"` - See real-time responses
- `"How do I add an API key?"` - Get setup help

### Features to Explore:
- ✅ Create multiple conversations
- ✅ Switch between conversations
- ✅ Watch streaming responses animate
- ✅ Delete conversations (hover to see delete button)
- ✅ Messages are auto-saved

---

## 🔑 Want to Use Real AI? (Optional)

### Fastest Option: DeepSeek ($0.14 per 1M tokens)

1. **Get Free API Key**: https://platform.deepseek.com/
2. **Update Database**:
   ```bash
   psql -U gsmlg_app -h localhost -p 5433 -d gsmlg_app_admin_dev

   UPDATE ai_providers
   SET api_key = 'sk-your-actual-key', is_active = true
   WHERE slug = 'deepseek';
   ```
3. **Select "DeepSeek" in chat dropdown** → Start chatting!

---

## 📝 Server Running?

If server isn't running, start it:
```bash
PORT=4153 mix phx.server
```

---

## 🆘 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't sign in | Check credentials above |
| No providers in dropdown | Run: `mix run apps/gsmlg_app_admin/priv/repo/seeds_mock_provider.exs` |
| Server won't start | Kill port 4153: `lsof -ti:4153 \| xargs kill -9` then restart |
| Database error | Start PostgreSQL: `devenv up` |

---

## 📚 Full Documentation

- **Complete Guide**: `AI_CHAT_IMPLEMENTATION_SUMMARY.md`
- **Detailed Setup**: `apps/gsmlg_app_admin/AI_CHAT_SETUP.md`

---

**🎉 That's it! Enjoy your AI Chat!**
