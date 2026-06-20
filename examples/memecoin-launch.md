# Example: Launching a Memecoin

This walkthrough demonstrates launching a memecoin from scratch using the solana-token-launch-skill. We'll create `$MEOWCAT` — a community-driven cat meme token on Solana.

---

## Step 1: Design Tokenomics

Run the interactive designer:

```bash
claude design-token --style memecoin
```

### Walkthrough Answers

**Step 1 — Project Identity:**
- Name: MeowCat
- Ticker: MEOWCAT
- Purpose: Memecoin — community, culture, cat memes
- Target audience: Solana degens, cat lovers, meme traders

**Step 2 — Total Supply:**
- Supply: 1,000,000,000 (1 billion)
- Type: Fixed (no inflation)
- Decimals: 6

**Step 3 — Distribution:**

| Category | % | Tokens | Notes |
|----------|---|--------|-------|
| Community Airdrop | 50% | 500,000,000 | Distributed to active Solana users |
| Ecosystem / Partnerships | 10% | 100,000,000 | Future collaborations, cat NFT holders |
| Team | 5% | 50,000,000 | Core contributors, locked |
| Liquidity | 20% | 200,000,000 | DEX pool seeding |
| Marketing | 10% | 100,000,000 | KOLs, campaigns, airdrop 2.0 |
| Treasury | 5% | 50,000,000 | DAO-controlled reserves |

**Step 4 — Vesting:**
- Community Airdrop: 100% liquid at TGE (memecoins need immediate circulating supply)
- Ecosystem: 0% TGE, 6-month cliff, 12-month linear vest
- Team: 0% TGE, 12-month cliff, 24-month linear vest
- Liquidity: 100% at TGE (locked in LP)
- Marketing: 25% TGE, 75% vested over 6 months
- Treasury: 0% TGE, DAO-governed unlock

**Step 5 — Utility:**
- Primary: Memetic value and community culture
- Secondary: Access to exclusive cat meme channels
- Future: NFT minting fees paid in MEOWCAT

**Step 6 — Launch Mechanics:**
- Method: Fair launch (no pre-sale, no VC)
- DEX: Raydium AMM
- Initial liquidity: 100M MEOWCAT + 50 SOL (~$7,500 at SOL=$150)
- Target initial MC: ~$15,000
- LP: Burned permanently

### Output: `tokenomics-output.md`

```markdown
# MeowCat ($MEOWCAT) — Tokenomics

## Overview
- Total Supply: 1,000,000,000 MEOWCAT
- Token Standard: SPL (Solana)
- Decimals: 6
- Type: Fixed supply, no inflation

## Distribution
| Category | % | Tokens | TGE Unlock | Cliff | Vesting |
|----------|---|--------|------------|-------|---------|
| Community Airdrop | 50% | 500,000,000 | 100% | — | — |
| Ecosystem | 10% | 100,000,000 | 0% | 6mo | 12mo linear |
| Team | 5% | 50,000,000 | 0% | 12mo | 24mo linear |
| Liquidity | 20% | 200,000,000 | 100% | — | Locked in LP |
| Marketing | 10% | 100,000,000 | 25% | — | 6mo linear |
| Treasury | 5% | 50,000,000 | 0% | — | DAO-governed |

## Airdrop Criteria
- Holders of popular Solana memecoins (BONK, WEN, WIF, POPCAT)
- Active Raydium LPs
- Solana wallet age >3 months
- Sybil resistance: minimum 0.1 SOL balance, unique wallet cluster detection
```

---

## Step 2: Review Tokenomics

```bash
claude tokenomics-reviewer < tokenomics-output.md
```

### Expected Review Output (excerpt):

```
# Tokenomics Review Report: MeowCat ($MEOWCAT)

## Summary
- Overall Score: 72/100
- Rating: Adequate
- Recommendation: Needs Minor Revisions

## Dimension Scores
| Dimension | Score | Assessment |
|-----------|-------|------------|
| Supply Design | 10/12.5 | Clean fixed supply at 1B; standard |
| Distribution Fairness | 9/12.5 | 50% community is strong; team only 5% |
| Vesting Discipline | 8/12.5 | Team vest is good; ecosystem cliff is short |
| Utility & Value Accrual | 6/12.5 | Memetic value only; no real demand sink |
| Launch Mechanics | 9/12.5 | Fair launch is ideal for memecoins |
| Incentive Alignment | 7/12.5 | LP burned; but marketing tokens at risk |
| Sustainability | 6/12.5 | No burn mechanism; no revenue model |
| Risk Profile | 7/12.5 | Low insider concentration; memecoin volatility |

## Red Flags
| # | Severity | Issue | Recommendation |
|---|----------|-------|----------------|
| 1 | 🟡 Medium | No demand sink for token | Add buyback from NFT mint fees |
| 2 | 🟡 Medium | Marketing tokens partially liquid | Reduce TGE to 0%, vest all |
| 3 | 🔵 Low | No burn mechanism | Add periodic community burn votes |

## Suggested Improvements
1. Add a buyback-and-burn from NFT mint revenue to create deflationary pressure
2. Reduce marketing TGE unlock to 0% to prevent early dump pressure
3. Consider a "cat tax" — 1% swap fee on DEX trades directed to treasury
```

---

## Step 3: Create the Token (Devnet First!)

### 3a. Set up devnet

```bash
solana config set --url devnet
solana airdrop 2
```

### 3b. Create the SPL token mint

```bash
# Create mint with 6 decimals
spl-token create-token --decimals 6

# Output: Creating token AQoKY... (example mint address)
```

### 3c. Create metadata

```json
// metadata.json
{
  "name": "MeowCat",
  "symbol": "MEOWCAT",
  "description": "The cat that launched a thousand memes. Community-first memecoin on Solana.",
  "image": "https://arweave.net/YOUR_IMAGE_TX_ID",
  "attributes": [],
  "properties": {
    "category": "image",
    "files": [
      {
        "uri": "https://arweave.net/YOUR_IMAGE_TX_ID",
        "type": "image/png"
      }
    ]
  }
}
```

```bash
# Upload metadata to Arweave first (using metaboss or Arweave CLI)
metaboss create metadata \
  --mint AQoKY... \
  --data-file metadata.json \
  --keypair ~/.config/solana/id.json
```

### 3d. Create token accounts and mint supply

```bash
# Create token account for deployer
spl-token create-account AQoKY...

# Mint total supply (1B tokens with 6 decimals = 1000000000000000)
spl-token mint AQoKY... 1000000000

# Verify supply
spl-token supply AQoKY...
# Output: 1000000000
```

### 3e. Revoke mint authority (CRITICAL for memecoins)

```bash
spl-token authorize AQoKY... mint --disable

# Verify: mint authority should be "disabled"
spl-token display AQoKY...
```

### 3f. Revoke freeze authority

```bash
spl-token authorize AQoKY... freeze --disable
```

---

## Step 4: Set Up Liquidity

### 4a. Create Raydium AMM Pool

Using Raydium SDK or UI:

```bash
# Via Raydium CLI (simplified)
# Pool: MEOWCAT/SOL
# Base: 200,000,000 MEOWCAT (20% of supply)
# Quote: 50 SOL
```

### 4b. Burn LP Tokens

```bash
# Send LP tokens to burn address
spl-token transfer <LP_MINT> <LP_AMOUNT> 11111111111111111111111111111111 \
  --fund-recipient --allow-unfunded-recipient
```

**Verify**: LP tokens are at the dead address. This is permanent — liquidity cannot be removed.

---

## Step 5: Distribute Airdrop

### 5a. Build merkle tree

```bash
# Using the skill's airdrop tool (conceptual)
node scripts/build-merkle-tree.js \
  --recipients airdrop-list.csv \
  --output merkle-proofs.json
```

### 5b. Execute airdrop

Test with 3 wallets first:
```bash
# Test batch
spl-token transfer AQoKY... 1000 <TEST_WALLET_1>
spl-token transfer AQoKY... 1000 <TEST_WALLET_2>
spl-token transfer AQoKY... 1000 <TEST_WALLET_3>
```

Then full merkle distribution:
```bash
# Merkle distributor contract deployment and claiming
# (Uses Solana merkle distributor program)
```

---

## Step 6: Launch Readiness Check

```bash
claude launch-readiness
```

### Expected Output:

```
# Launch Readiness Report: MeowCat ($MEOWCAT)

## Verdict: 🟢 GO

| Category | Status | Passed | Failed | Warnings |
|----------|--------|--------|--------|----------|
| Technical | ✅ | 6/6 | 0 | 0 |
| Liquidity | ✅ | 4/4 | 0 | 0 |
| Vesting | ⚠️ | 2/2 | 0 | 1 |
| Operational | ✅ | 5/5 | 0 | 0 |
| Risk | ✅ | 4/4 | 0 | 0 |

## Warnings
| # | Warning | Mitigation |
|---|---------|------------|
| 1 | No vesting dashboard for ecosystem tokens | Use vesting explorer link in docs |
```

---

## Step 7: Go Live

### Switch to mainnet

```bash
solana config set --url mainnet-beta
```

### Repeat Steps 3–5 on mainnet

Execute the same flow on mainnet. The devnet test ensures no surprises.

### Announce

Post announcement with:
- Token mint address
- DEX pool link (Raydium/Jupiter)
- Tokenomics document link
- "Mint authority revoked, LP burned" proof links
- Airdrop claim link (if applicable)

---

## Key Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Supply | 1B fixed | Standard for memecoins; psychologically accessible |
| Community allocation | 50% | Matches JUP's community-first ethos |
| Team allocation | 5% | Low for memecoin; builds trust |
| Vesting | Team only, 12mo cliff | Minimal insider risk |
| LP strategy | Burned | Permanent liquidity; trust signal |
| Launch method | Fair launch | No VC, no pre-sale; maximally fair |
| Utility | Memetic + NFT fees | Foundation for future value accrual |

---

## Lessons from This Example

1. **Memecoins live or die on trust signals**: LP burned, mint revoked, small team allocation
2. **Fair launch is the meta on Solana**: No pre-sale, no VC allocation
3. **Devnet testing prevents costly mistakes**: Always test the full flow first
4. **Airdrop is marketing**: 50% community allocation generates more awareness than any paid campaign
5. **Burn LP early, burn LP always**: This is the single most important trust signal
