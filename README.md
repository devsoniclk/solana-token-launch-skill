# Solana Token Launch Skill

A comprehensive Claude Code skill for designing, simulating, reviewing, and launching SPL tokens on Solana with production-grade tokenomics and safety guardrails.

---

## The Problem

Launching a token on Solana involves dozens of interconnected decisions — supply design, distribution ratios, vesting schedules, liquidity strategy, authority management, metadata, safety checks, and operational readiness. Getting any one of these wrong can lead to:

- **Rug-pull perception** (unlocked LP, unrevealed mint authority)
- **Price collapse** (poor vesting, whale concentration, no demand sink)
- **Failed launch** (technical errors, insufficient liquidity, missing metadata)
- **Legal exposure** (security-like traits, misleading claims)
- **Community distrust** (opaque distribution, insider-heavy allocation)

This skill turns tribal knowledge into a systematic, repeatable process.

---

## What It Does

The skill provides:

| Module | Type | Purpose |
|--------|------|---------|
| **Tokenomics Reviewer** | Agent | Scores tokenomics design on 8 dimensions; flags red flags; compares against JTO, JUP, W, PYTH |
| **Launch Readiness** | Agent | Pre-flight checklist: technical, liquidity, vesting, operational, risk → GO/NO-GO |
| **Design Token** | Command | Interactive guided workflow for designing tokenomics from scratch |
| **Simulate Launch** | Command | Monte Carlo simulations of launch scenarios with price/circulation modeling |
| **Token Safety Rules** | Rules | 12 hard constraints that are never violated (key safety, LP lock, authority revocation, etc.) |
| **Examples** | Examples | Complete walkthroughs for memecoin and utility token launches |
| **Templates** | Templates | Fill-in tokenomics allocation tables |

---

## Installation

### Prerequisites

- [Solana CLI](https://docs.solanalabs.com/cli/install) v1.18+
- [Anchor](https://www.anchor-lang.com/docs/installation) (for program development)
- [Node.js](https://nodejs.org/) v18+
- [Rust](https://www.rust-lang.org/tools/install) (for Anchor programs)
- [Claude Code](https://claude.ai/code)

### Quick Install

```bash
# Clone the skill into your Claude Code skills directory
git clone https://github.com/devsoniclk/solana-token-launch-skill.git \
  ~/.claude/skills/solana-token-launch-skill

# Run the installer
cd ~/.claude/skills/solana-token-launch-skill
bash scripts/install.sh
```

The installer will:
1. Check for Solana CLI, Anchor, Node.js, npm, and Rust
2. Install npm dependencies (`@solana/web3.js`, `@solana/spl-token`, `@metaplex-foundation/mpl-token-metadata`)
3. Verify Solana configuration
4. Generate a devnet keypair if none exists

### Manual Install

```bash
cd ~/.claude/skills/solana-token-launch-skill
npm install
```

---

## Quick Start

### 1. Design Tokenomics

Ask Claude Code to run the design-token command and walk through 8 guided steps: identity, supply, distribution, vesting, utility, launch mechanics, risk assessment, and review.

### 2. Review Your Design

Feed in your tokenomics document and get a scored review with red flags and improvement suggestions.

### 3. Simulate the Launch

Run Monte Carlo simulations to stress-test your design across bull, bear, sideways, and black swan scenarios.

### 4. Check Launch Readiness

Walk through the pre-flight checklist covering technical, liquidity, vesting, operational, and risk categories. Get a GO/NO-GO verdict.

---

## Module Overview

### Agents

#### `agents/tokenomics-reviewer.md`
Expert auditor that evaluates tokenomics on:
- Supply Design, Distribution Fairness, Vesting Discipline
- Utility & Value Accrual, Launch Mechanics
- Incentive Alignment, Sustainability, Risk Profile

Outputs a structured report with scores, benchmarks, red flags, and improvements.

#### `agents/launch-readiness.md`
Pre-flight checklist agent covering:
- **Technical**: Mint, metadata, authorities, decimals, ATAs
- **Liquidity**: Pool creation, LP seeding, LP locking, price impact
- **Vesting**: Contract deployment, schedule verification, beneficiary wallets
- **Operational**: Documentation, community, multisig, communication plan
- **Risk**: Concentration, rug-pull vectors, smart contract risks, contingency

Outputs GO / NO-GO / CONDITIONAL GO with specific blockers.

### Commands

#### `commands/design-token.md`
Interactive 8-step workflow:
1. Project Identity → 2. Total Supply → 3. Distribution → 4. Vesting → 5. Utility → 6. Launch Mechanics → 7. Risk Assessment → 8. Review & Finalize

Outputs `tokenomics-output.md` and `tokenomics-output.json`.

#### `commands/simulate-launch.md`
Monte Carlo simulation engine:
- Modified GBM price model with jump diffusion
- Supply-side unlock pressure modeling
- Liquidity depth and price impact simulation
- 4 scenario classes: bull, sideways, bear, black swan
- Outputs price trajectories, failure modes, risk metrics

### Rules

#### `rules/token-safety.md`
12 hard safety constraints:
1. Never expose private keys
2. Verify before executing (simulate first)
3. Revoke or delegate mint authority
4. Lock or burn LP tokens
5. No single-wallet >10% concentration
6. Test on devnet first
7. Freeze authority requires justification
8. Verify metadata before promotion
9. Airdrop distribution safety
10. Emergency response plan required
11. No misleading claims
12. Transaction simulation errors are fatal

### Templates

#### `templates/tokenomics-spreadsheet.md`
Fill-in allocation table with categories, percentages, TGE unlock, cliff, vesting duration, and notes. Includes guidance on typical ranges.

### Examples

#### `examples/memecoin-launch.md`
Complete walkthrough of launching a memecoin:
- Fair launch with no pre-sale
- Community-first distribution (60%+ airdrop)
- LP-only liquidity model
- Cultural/meme-driven utility

#### `examples/utility-token-launch.md`
Complete walkthrough of launching a utility token:
- Governance + staking + fee-sharing
- Team/investor vesting with 12-month cliff
- DEX liquidity with locked LP
- Phased airdrop with vesting

---

## Project Structure

```
solana-token-launch-skill/
├── agents/
│   ├── tokenomics-reviewer.md      # Tokenomics scoring agent
│   └── launch-readiness.md         # Pre-flight checklist agent
├── commands/
│   ├── design-token.md             # Interactive tokenomics designer
│   └── simulate-launch.md          # Monte Carlo launch simulator
├── rules/
│   └── token-safety.md             # Hard safety constraints
├── templates/
│   └── tokenomics-spreadsheet.md   # Fill-in allocation template
├── examples/
│   ├── memecoin-launch.md          # Memecoin walkthrough
│   └── utility-token-launch.md     # Utility token walkthrough
├── scripts/
│   └── install.sh                  # Dependency installer
├── package.json                    # Node.js dependencies
├── README.md                       # This file
└── LICENSE                         # MIT License
```

---

## Contributing

Contributions are welcome! This skill improves when more practitioners share their experience.

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b add-new-agent`)
3. **Write** your addition following the existing patterns:
   - Agents: structured markdown with clear input/output formats
   - Commands: step-by-step workflows with flags and options
   - Rules: severity, enforcement logic, rationale
4. **Test** your changes against a real tokenomics design
5. **Submit** a pull request with a clear description

### Areas for Contribution

- **New agents**: Security auditor, CEX listing advisor, regulatory compliance checker
- **New commands**: Token migration wizard, airdrop planner, LP optimization tool
- **New rules**: Additional safety constraints from real-world incidents
- **Simulation improvements**: Better price models, MEV modeling, cross-chain scenarios
- **Examples**: NFT-gated tokens, RWA tokens, DePIN tokens, stablecoins
- **Benchmarks**: Add more successful Solana launches to the comparison database

---

## License

MIT License. See [LICENSE](./LICENSE) for details.

---

## Acknowledgments

Built with reference to successful Solana token launches:
- **Jito (JTO)** — Community-first distribution model
- **Jupiter (JUP)** — Largest airdrop in Solana history; phased community allocation
- **Wormhole (W)** — Ecosystem fund and locked community reserves
- **Pyth Network (PYTH)** — Utility-driven distribution for data publishers
