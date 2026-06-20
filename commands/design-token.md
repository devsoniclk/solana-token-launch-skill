# Design Token Command

**Command**: `design-token`
**Purpose**: Interactive, guided workflow for designing tokenomics from scratch or refining an existing design.

---

## Usage

```
claude design-token [--existing <path-to-tokenomics-file>] [--style <memecoin|utility|governance|hybrid>]
```

### Options

| Flag | Description |
|------|-------------|
| `--existing` | Path to an existing tokenomics markdown/JSON to refine |
| `--style` | Pre-fill defaults for a specific token archetype |
| `--output` | Output file path (default: `tokenomics-output.md`) |
| `--skip-reviews` | Skip the tokenomics reviewer agent step |

---

## Workflow Steps

The command walks through 8 guided steps. Each step asks targeted questions and provides expert context to help the user make informed decisions.

### Step 1: Project Identity

```
→ What is your project name?
→ What is your token ticker? (e.g., MYTKN)
→ What is the primary purpose of your token?
   [1] Utility — access, payments, fees
   [2] Governance — voting, proposals
   [3] Memecoin — community, culture
   [4] Hybrid — multiple purposes
→ What problem does your project solve?
→ Who is your target audience?
```

**Context provided**: Explain how token purpose drives every downstream decision.

### Step 2: Total Supply

```
→ What is your total token supply?
   [1] Small: 1M–10M (high per-unit price, premium feel)
   [2] Medium: 100M–1B (standard for utility tokens)
   [3] Large: 1B–10B (common for governance/memecoins)
   [4] Custom: enter exact number
→ Fixed supply or inflationary?
   [1] Fixed — no new tokens ever minted
   [2] Inflationary — with decreasing emissions schedule
   [3] Deflationary — burns reduce supply over time
→ What are your token decimals? (default: 6 for SPL, 9 for human-readable)
```

**Context provided**: Explain FDV implications, psychological pricing, and SPL conventions. Reference JUP (10B), JTO (1B), BONK (tens of trillions).

### Step 3: Distribution Allocation

Present an interactive table to fill in:

```
Allocate 100% of your token supply:

Category               | %     | Notes
-----------------------|-------|------
Community / Airdrop    | ___%  | Fair launch, early users, rewards
Ecosystem / Growth     | ___%  | Grants, partnerships, integrations
Team                   | ___%  | Founders, core contributors
Investors / Advisors   | ___%  | Seed, Series A, angels
Treasury / DAO         | ___%  | Long-term reserves, governance
Liquidity              | ___%  | DEX pools, market making
Staking Rewards        | ___%  | Staking incentives
Marketing              | ___%  | KOLs, campaigns, airdrops 2.0
                        ------|
Total                  | 100%  |

→ Adjust percentages until they sum to 100%.
```

**Context provided**: 
- Compare against JTO, JUP, W, PYTH allocations
- Warn if community <30% or insiders >25%
- Recommend liquidity be 5–15% of supply
- Advise against marketing >10% without a clear plan

### Step 4: Vesting Schedules

For each allocation category that isn't 100% liquid at TGE:

```
For each category, define vesting:

Category: [Team]
→ Tokens liquid at TGE (unlock at launch): ___% [default: 0%]
→ Cliff period: ___ months [default: 12]
→ Vesting duration: ___ months [default: 36]
→ Unlock frequency: [1] Monthly [2] Quarterly [3] Linear per second
→ Revocable? [1] Yes (for terminated contributors) [2] No

Category: [Investors / Advisors]
→ Tokens liquid at TGE: ___% [default: 0%]
→ Cliff period: ___ months [default: 12]
→ Vesting duration: ___ months [default: 24]
→ Unlock frequency: [1] Monthly [2] Quarterly
→ Revocable? [1] Yes [2] No

[Repeat for each non-liquid category]
```

**Context provided**:
- Best practice: 0% TGE for team, 12-month cliff minimum
- JUP model: 0% TGE, 2-year linear vest for team
- JTO model: 0% TGE, 12-month cliff, 3-year vest
- Warn against >20% TGE for any insider category

### Step 5: Utility & Value Accrual

```
→ What utility does your token provide? (select all that apply)
   [ ] Governance voting
   [ ] Staking (yield from protocol fees)
   [ ] Fee payment (discounted platform fees)
   [ ] Access (premium features, gated content)
   [ ] Collateral (lending/borrowing)
   [ ] Revenue sharing (direct fee distribution)
   [ ] Burn mechanism (deflationary pressure)
   [ ] Memetic value (culture, community, memes)
   [ ] Other: ____________

→ How does the token capture value? (demand sinks)
   [ ] Protocol fees paid in token
   [ ] Buyback and burn from revenue
   [ ] Staking lock reduces circulating supply
   [ ] Required for protocol operation
   [ ] Other: ____________

→ What is your projected Year 1 revenue/fee volume? (for sustainability check)
```

**Context provided**: 
- Explain the difference between real utility and "governance theater"
- JTO: MEV tip distribution via staking
- JUP: Governance over protocol treasury
- Warn if no clear demand sink exists

### Step 6: Launch Mechanics

```
→ How will tokens initially enter circulation?
   [1] Airdrop — distribute to existing users/holders
   [2] IDO / Token Sale — raise funds publicly
   [3] LBP (Liquidity Bootstrapping Pool) — Balancer-style fair launch
   [4] Fair Launch — LP only, no pre-sale
   [5] Centralized Exchange Listing — launch on CEX
   [6] Combination: ____________

→ What is your target initial market cap?
→ What is your target FDV?
→ What DEX will host the initial liquidity?
   [1] Raydium (standard AMM)
   [2] Meteora (dynamic pools)
   [3] Jupiter (aggregated)
   [4] Orca (concentrated liquidity)
   [5] Other: ____________
```

**Context provided**:
- Explain market cap vs FDV difference
- Initial liquidity sizing (typically 5–15% of FDV)
- LP locking importance
- MEV protection strategies

### Step 7: Risk Assessment

```
→ Has a legal review been conducted? [Yes/No/Planned]
→ Is the team fully doxxed? [Yes/Partial/No]
→ Is there a multisig for treasury? [Yes/No/Planned]
→ What is the emergency response plan? [Written/In Progress/None]
→ Has the tokenomics been reviewed by the tokenomics-reviewer agent? [Yes/No]
→ Are there any regulatory concerns in target jurisdictions?
```

### Step 8: Review & Finalize

```
→ Display the complete tokenomics summary
→ Run the tokenomics-reviewer agent automatically (unless --skip-reviews)
→ Generate the tokenomics output document
→ Optionally export to JSON for programmatic use
```

---

## Output Files

The command produces:

1. **`tokenomics-output.md`** — Human-readable tokenomics document
2. **`tokenomics-output.json`** — Machine-readable version for scripts
3. **`tokenomics-review.md`** — Reviewer agent output (unless skipped)

### Output Document Structure

```markdown
# [PROJECT_NAME] ($TICKER) — Tokenomics

## Overview
- Total Supply: X
- Token Standard: SPL (Solana)
- Decimals: X
- Mint Address: [TBD / actual address]

## Distribution

| Category | % | Tokens | TGE Unlock | Cliff | Vesting |
|----------|---|--------|------------|-------|---------|
| Community | X% | X | X% | — | — |
| Team | X% | X | 0% | 12mo | 36mo linear |
| ... | | | | | |

## Vesting Schedule

[Detailed unlock schedule]

## Utility

[Token utility description]

## Launch Plan

[Launch mechanics description]

## Risk Mitigation

[Risk assessment summary]
```

---

## Expert Tips Shown During Flow

- **"Airdrop is the best marketing spend on Solana."** — JUP airdrop cost ~$70M in tokens but generated billions in awareness and loyalty.
- **"Never launch with mint authority unrevealed."** — Rug-pull signal #1. Plan to revoke or delegate to multisig before launch.
- **"LP lock is non-negotiable."** — Unlocked LP is the #1 red flag for traders and bots scanning new tokens.
- **"Your FDV is your reputation."** — Starting too high creates permanent bagholders. Start modest, let the market discover.
