# Example: Launching a Utility Token

This walkthrough demonstrates launching a utility token with governance, staking, and fee-sharing using the solana-token-launch-skill. We'll create `$LNDX` — the token for a fictional decentralized lending protocol called LendX.

---

## Step 1: Design Tokenomics

```bash
claude design-token --style utility
```

### Walkthrough Answers

**Step 1 — Project Identity:**
- Name: LendX
- Ticker: LNDX
- Purpose: Utility — governance, staking, fee sharing
- Problem: Centralized lending protocols extract value; LendX distributes it to token holders
- Target audience: DeFi users, yield seekers, DAO governance participants

**Step 2 — Total Supply:**
- Supply: 100,000,000 (100 million)
- Type: Fixed supply with emissions from treasury
- Decimals: 6

**Step 3 — Distribution:**

| Category | % | Tokens | Notes |
|----------|---|--------|-------|
| Community / Airdrop | 30% | 30,000,000 | Early users, liquidity providers, borrowers |
| Staking Rewards | 15% | 15,000,000 | Staking incentives over 4 years |
| Ecosystem / Growth | 15% | 15,000,000 | Grants, integrations, partnerships |
| Team | 15% | 15,000,000 | Core contributors, locked |
| Investors | 10% | 10,000,000 | Seed + Series A |
| Treasury / DAO | 10% | 10,000,000 | Governance-controlled reserves |
| Liquidity | 5% | 5,000,000 | DEX pool seeding |

**Step 4 — Vesting:**

| Category | TGE Unlock | Cliff | Vesting | Revocable |
|----------|-----------|-------|---------|-----------|
| Community Airdrop | 50% | — | 6mo linear for remaining 50% | No |
| Staking Rewards | 0% | — | 48mo linear emissions | N/A |
| Ecosystem | 0% | 6mo | 36mo linear | No |
| Team | 0% | 12mo | 36mo linear | Yes |
| Investors | 0% | 12mo | 24mo linear | No |
| Treasury | 0% | — | DAO-governed | N/A |
| Liquidity | 100% | — | Locked 12mo | No |

**Step 5 — Utility:**
- Governance: Vote on protocol parameters (LTV ratios, supported assets, fee structures)
- Staking: Stake LNDX to earn protocol revenue share (50% of lending fees)
- Fee discount: Holders get 25% discount on borrowing fees
- Collateral: LNDX accepted as collateral (70% LTV)

**Step 6 — Launch Mechanics:**
- Method: LBP (Liquidity Bootstrapping Pool) on Meteora for fair price discovery
- Initial price: $0.10 / LNDX
- Target raise: $2M (20% of supply at $0.10 = $2M initial MC, $10M FDV)
- LBP duration: 72 hours
- Post-LBP: Transition to Raydium concentrated liquidity pool

---

## Step 2: Review Tokenomics

```bash
claude tokenomics-reviewer < tokenomics-output.md
```

### Expected Review Output (excerpt):

```
# Tokenomics Review Report: LendX ($LNDX)

## Summary
- Overall Score: 81/100
- Rating: Strong
- Recommendation: Launch Ready (with minor improvements)

## Dimension Scores
| Dimension | Score | Assessment |
|-----------|-------|------------|
| Supply Design | 10/12.5 | 100M fixed supply; appropriate for DeFi utility |
| Distribution Fairness | 9/12.5 | 30% community; insiders at 25% (borderline) |
| Vesting Discipline | 10/12.5 | 12mo cliff + 36mo team vest; 12mo LP lock; excellent |
| Utility & Value Accrual | 10/12.5 | Governance + staking + fee discount + collateral; strong |
| Launch Mechanics | 9/12.5 | LBP provides fair price discovery; 72h is solid |
| Incentive Alignment | 9/12.5 | Revenue sharing aligns holders with protocol success |
| Sustainability | 7/12.5 | 4yr staking emissions; treasury reserves adequate |
| Risk Profile | 7/12.5 | Smart contract risk inherent in lending; audit required |

## Comparison vs Benchmarks
| Metric | LNDX | JTO | JUP | W | PYTH |
|--------|-------|-----|-----|---|------|
| Community % | 30% | 34.5% | 40% | 17% | 58% |
| Insider % | 25% | 40.7% | 20% | 30.8% | 22% |
| Vest (team) | 4yr | 3yr | 2yr | 4yr | — |
| Utility Type | Staking + Gov | Fee share | Gov | Gov | Data |

## Red Flags
| # | Severity | Issue | Recommendation |
|---|----------|-------|----------------|
| 1 | 🟡 Medium | Insider allocation at 25% (borderline) | Reduce investor allocation by 5%, add to community |
| 2 | 🟡 Medium | LBP may have low volume if poorly marketed | Engage KOLs 2 weeks before LBP |
| 3 | 🔵 Low | No burn mechanism | Consider quarterly buyback-and-burn from protocol fees |
```

---

## Step 3: Build the Token Program (Anchor)

### 3a. Initialize Anchor project

```bash
# If using Anchor for the lending program with built-in token logic
anchor init lendx --template multiple
cd lendx
```

### 3b. Create SPL Token Mint

```bash
spl-token create-token --decimals 6
# Mint: LNDX_ADDRESS_HERE
```

### 3c. Create Metadata

```json
{
  "name": "LendX",
  "symbol": "LNDX",
  "description": "Governance and utility token for LendX decentralized lending protocol on Solana.",
  "image": "https://arweave.net/LNDX_IMAGE_TX_ID",
  "external_url": "https://lendx.fi",
  "attributes": [],
  "properties": {
    "category": "image",
    "files": [
      {
        "uri": "https://arweave.net/LNDX_IMAGE_TX_ID",
        "type": "image/png"
      }
    ]
  }
}
```

```bash
metaboss create metadata --mint LNDX_ADDRESS --data-file metadata.json
```

### 3d. Mint Supply and Distribute

```bash
# Mint total supply
spl-token mint LNDX_ADDRESS 100000000

# Distribute to allocation wallets
# Community airdrop wallet (15M at TGE = 50% of 30M)
spl-token transfer LNDX_ADDRESS 15000000 $COMMUNITY_WALLET

# Liquidity wallet (5M at TGE = 100% of 5M)
spl-token transfer LNDX_ADDRESS 5000000 $LIQUIDITY_WALLET

# Marketing/first airdrop tranche from community (included in community allocation)
```

### 3e. Deploy Vesting Contracts

```bash
# Using a vesting program (e.g., Solana Vesting Program or custom)

# Team vesting: 15M tokens, 0% TGE, 12mo cliff, 36mo linear, revocable
# Deploy via vesting program instruction
```

Vesting contract parameters:
```
{
  "beneficiary": "TEAM_MULTISIG_ADDRESS",
  "mint": "LNDX_ADDRESS",
  "total_amount": 15000000000000,  // 15M tokens (6 decimals)
  "cliff_time": 31536000,          // 12 months in seconds
  "cliff_amount": 0,
  "start_time": LAUNCH_TIMESTAMP,
  "end_time": LAUNCH_TIMESTAMP + 126144000,  // 48 months total
  "frequency": 2592000,            // Monthly unlocks
  "revocable": true
}
```

### 3f. Manage Authorities

```bash
# Delegate mint authority to multisig (inflationary via treasury governance)
spl-token authorize LNDX_ADDRESS mint $MULTISIG_ADDRESS

# Revoke freeze authority (DeFi protocol, no freeze needed)
spl-token authorize LNDX_ADDRESS freeze --disable
```

---

## Step 4: Set Up Liquidity via LBP

### 4a. Create Meteora LBP Pool

```bash
# Via Meteora LBP UI or SDK
# Starting weight: 95% LNDX / 5% USDC
# Ending weight: 50% LNDX / 50% USDC
# Duration: 72 hours
# Starting price: ~$0.10
```

### 4b. Post-LBP: Transition to Concentrated Liquidity

After the LBP ends:
1. Collect LBP proceeds (USDC raised + remaining LNDX)
2. Create Raydium concentrated liquidity pool
3. Seed with LBP-derived liquidity
4. Lock LP for 12 months

```bash
# Lock LP tokens
# Via Meteora lock or similar
```

---

## Step 5: Simulate Launch Scenarios

```bash
claude simulate-launch \
  --tokenomics tokenomics-output.json \
  --scenarios 1000 \
  --horizon 365 \
  --initial-mc 2000000 \
  --initial-fdv 10000000 \
  --dex-liquidity 2000000
```

### Key Findings (excerpt):

```
## Summary Statistics
| Metric | Mean | P5 (Bear) | P95 (Bull) |
|--------|------|-----------|------------|
| Price Day 30 | $0.12 | $0.06 | $0.25 |
| Price Day 90 | $0.15 | $0.04 | $0.45 |
| Price Day 365 | $0.22 | $0.03 | $1.20 |

## Vesting Impact Analysis
| Unlock Event | Day | Tokens | % Supply | Avg Price Impact |
|-------------|-----|--------|----------|-----------------|
| TGE | 0 | 20M | 20% | — |
| Investor cliff end | 365 | 10M | 10% | -15% avg |
| Team cliff end | 365 | 15M | 15% | -20% avg |
| Community vest complete | 180 | 15M | 15% | -8% avg |

## Recommendations
1. First year cliff unlocks (Day 365) create significant sell pressure
   → Consider staggered cliffs: 6mo for investors, 12mo for team
2. LBP price discovery reduces initial dump risk
   → Good design choice for DeFi tokens
3. Staking rewards offset sell pressure by 30-40% in simulations
   → Ensure staking is live before any vesting unlock
```

---

## Step 6: Launch Readiness Check

```bash
claude launch-readiness
```

### Expected Verdict: 🟢 CONDITIONAL GO

```
## Verdict: 🟢 CONDITIONAL GO

| Category | Status | Passed | Failed | Warnings |
|----------|--------|--------|--------|----------|
| Technical | ✅ | 8/8 | 0 | 0 |
| Liquidity | ✅ | 5/5 | 0 | 0 |
| Vesting | ✅ | 4/4 | 0 | 1 |
| Operational | ⚠️ | 6/7 | 0 | 1 |
| Risk | ✅ | 5/5 | 0 | 0 |

## Warnings
| # | Warning | Mitigation |
|---|---------|------------|
| 1 | Smart contract audit pending | Engage OtterSec or Halborn; 2-week turnaround |
| 2 | No vesting dashboard link | Deploy vesting explorer before TGE |
```

---

## Step 7: Go Live

### LBP Launch (Mainnet)

```bash
solana config set --url mainnet-beta

# 1. Deploy vesting contracts on mainnet
# 2. Create LBP on Meteora
# 3. Announce LBP start (72h window)
# 4. Monitor LBP in real-time
```

### Post-LBP Transition

```bash
# 1. Close LBP, collect proceeds
# 2. Create concentrated liquidity pool on Raydium
# 3. Seed with LBP proceeds
# 4. Lock LP for 12 months
# 5. Enable staking contract
# 6. Open governance proposals
```

---

## Key Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Supply | 100M fixed | DeFi token; every token has utility weight |
| Community allocation | 30% | Strong but could be higher; benchmark against JUP (40%) |
| Insider allocation | 25% | Borderline; justified by vesting discipline |
| Vesting | Team 12mo cliff + 36mo | Matches JTO standards |
| LP strategy | 12-month lock | Not burned (need to adjust later); locked is acceptable |
| Launch method | LBP | Fair price discovery; no front-running; DeFi-native |
| Staking emissions | 48 months | Long runway; aligned with protocol growth |
| Revenue sharing | 50% to stakers | Primary value accrual mechanism |

---

## Lessons from This Example

1. **Utility tokens need real revenue**: Governance alone isn't enough. Fee sharing creates genuine demand.
2. **LBP > IDO for DeFi tokens**: Fair price discovery without sniping bots.
3. **Staking emissions offset vesting dumps**: Time your staking launch before major unlock events.
4. **Audit is non-negotiable for DeFi**: One exploit kills the protocol permanently.
5. **DAO treasury is your insurance fund**: 10% treasury with governance control provides flexibility.
6. **Vesting contracts must be verifiable**: Users need to see unlock schedules on-chain.
