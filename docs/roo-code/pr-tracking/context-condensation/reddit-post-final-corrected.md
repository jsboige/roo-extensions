# [Roo-Code] Context Condensation: New Architecture for Managing Long Conversations

After 6 months of heavy Roo-Code usage (10,000+ tasks), I've contributed a context condensation architecture to address cost and performance issues with long conversations.

---

## 🔄 **My Roo Journey: 6 Months, 10k Tasks, 20k$ in Credits**

About six months ago, I decided to go all-in on Roo-Code for my entire professional activity as a developer, professor, and AI trainer. This wasn't a casual adoption - it was a complete commitment to transforming how I work.

### **Background & Previous Experience**

Before Roo, I had significant experience with semantic-kernel, where I contributed a multi-LLM differential router (PR #2323). That project eventually migrated to an external repository, which unfortunately became one of Claude 4's first casualties in my Roo journey when a filter-branch operation destroyed it. I'll rebuild it when I find time.

### **Scale of Adoption**

Since May, my usage has been intensive:
- **10,000+ tasks** across 6 machines
- **4 Roo instances per office** with color-coded theming
- **20,000$+ in credits** spent across multiple models
- **Remote desktop workflow** constantly switching between machines

My current setup looks like this: [Photo would be hosted on Reddit-compatible service] - four themed Roo windows per office, constantly rearranging them back to their corners. It's the best UX I've found for distributed workload management.

### **Model Evolution & Costs**

My model journey reflects the broader AI landscape:
- Started with **Claude Sonnet 4** until a series of issues (including repository destruction) cooled my enthusiasm
- Switched to **Gemini Pro** for most of the summer
- Returned to **Claude 4.5** 
- Recently split usage between **Claude 4.5** and **GLM 4.6**

The recent context condensation features and CLI subscriptions have helped reduce costs significantly, but my medium-term goal is to scale while decreasing expenses through open-source models like Qwen 3 32B, which fits perfectly on my two RTX 4090s with usable context sizes (130k+ tokens).

---

## 🛠️ **Building Tools to Survive the Roo Experience**

Like many in the community, my results with Roo have been variable. I've had to build extensive tooling to maximize workflow robustness.

### **Custom Extensions & MCP Servers**

I created two main projects:
- **roo-extensions**: https://github.com/jsboige/roo-extensions
- **roo-state-manager MCP**: https://github.com/jsboige/jsboige-mcp-servers/tree/main/servers/roo-state-manager

Documentation is in French, but any Roo agent can explain the principles. These tools aim to customize and extend Roo's capabilities.

### **Real-World Pain Points**

The challenges have been numerous. For example, in my argumentation project for a class of students (https://github.com/jsboigeEpita/2025-Epita-Intelligence-Symbolique/), four Gemini agents and I made every possible vibe-coding error. I'm still cleaning up that project months later.

### **The Grounding Revelation**

Semantic indexing was a game-changer. It allowed me to "reground" my agents, making grounding central to my thinking about Roo workflow robustness. I developed an SDDD (Semantic Documentation Driven Design) protocol:

1. Generate task follow-up reports
2. Verify semantic discoverability  
3. Drive orchestrator regrounding through semantic search results
4. Validate documentation that validates code

This protocol keeps expanding with new grounding methods - conversational access to task clusters via roo-state-manager, soon GitHub project grounding through my MCP, and inter-agent grounding via roo-state-manager's cross-environment messaging.

---

## 😤 **The Frustration Factor**

Here's the honest truth: while Roo rapidly introduced essential technical features, the UI and execution engine have remained fragile. Countless crashes have worn me down.

The breaking point came when I realized I was doing Ctrl-A/Ctrl-C before every message submission because I had a 1-in-5 chance of losing my input. This seems related to a race condition from when message input during agent execution was enabled.

I've now dedicated an agent (currently GLM 4.6) to submit PRs for issues that matter to me but seem to stagnate. My first PR targets this message loss problem: https://github.com/RooCodeInc/Roo-Code/pull/8438. I hope it gets merged before I develop ulcers from frustration.

---

## Why Context Condensation Matters

Context condensation addresses a critical cost issue: long conversations become exponentially more expensive with each cache miss. This architecture provides a systematic way to reduce costs while preserving essential information.

That said, I'm actually counting more on the upcoming SDDD protocol iteration with its 2-level simple/complex task division to reduce task sizes. But condensation remains valuable for conversations that do grow long.

My context condensation PR addresses two fundamental needs:

### **1. Less Destructive Than Current Summarization**

Unlike the current message queue summarization, this approach differentiates content types, continuing my SDDD reflection. Some content deserves preservation, some can be safely compressed.

### **2. Extensible Architecture for Community Solutions**

Since this is an unsolicited major evolution, I believe everyone should be able to propose alternative solutions. The pluggable provider system allows the community to experiment and innovate.

---

## 🔧 **The Technical Solution: Provider-Based Architecture**

I implemented a pluggable Context Condensation Provider system that gives complete control over conversation history processing. This isn't just an improvement - it's a different approach to the problem.

### **Four Providers as Illustrative Prototypes**

**1. Native Provider** - Zero change, maintains existing behavior
**2. Lossless Provider** - Deduplication with zero information loss
**3. Truncation Provider** - Chronological preservation with size reduction
**4. Smart Provider** - Multi-pass system with differentiated content types (messages, tool parameters, tool results), differentiated reduction types (preservation, summarization, truncation, deletion, batch summarization), and different trigger thresholds for each pass and content type

*Note: These are illustrative prototypes. In practice, the real choice is between Smart and Native providers.*

### **Smart Provider Presets**

The Smart Provider has three presets:

**Conservative**: Gentle context reduction, starts by removing redundant results and tool parameters, then summarizes messages using mainly summarization techniques.

**Balanced**: Same principle but more aggressive, with lower thresholds for summarization and using truncation instead of certain summaries to speed up the process.

**Aggressive**: Uses only truncation and deletion for speed, with the hypothesis that even such a provider should give better results than the current provider since it better preserves old messages.

### **Built-In Safeguards**

I included practical protection mechanisms:
- Loop prevention (max 3 attempts per task)
- Hysteresis logic (trigger at 90%, stop at 70%)
- Gain estimation to skip unnecessary condensation
- Provider-specific limits and comprehensive error handling

---

## 📊 **What This Actually Represents**

This is a substantial contribution that also explains why I'm posting:
- **152 files modified** across core logic, UI, and documentation
- **37,000+ lines of code** added (mostly fixture data though)
- **1700+ lines of comprehensive tests**
- **8,000+ lines of technical documentation**
- **Complete quality audit** with all corrections applied

The architecture is backward compatible and includes an intuitive settings interface for both casual users and power users.

The review process for acceptance will likely be long, and we'll need to calibrate metrics and parameters on real conditions. Everyone is welcome to help move this forward.

---

## 🧪 **Testing & Feedback**

If you're a heavy Roo user, I'd appreciate your feedback on different providers with long conversations. **PR**: https://github.com/RooCodeInc/Roo-Code/pull/8743

---

*P.S. This post was written in Roo - excuse the typical AI slop.*
