# 06 — Launch Day Execution Plan

## Pre-Launch Checklist

### T-7 Days (One Week Before)

| Task | Owner | Status |
|------|-------|--------|
| Token mint created on devnet, tested | Dev | ☐ |
| Metadata URI live (Arweave/IPFS) | Dev | ☐ |
| Vesting contracts deployed and tested | Dev | ☐ |
| Liquidity wallet funded (SOL + tokens) | Ops | ☐ |
| Smart contract audit complete (if applicable) | Security | ☐ |
| Telegram/Discord bots configured | Community | ☐ |
| Website + docs final copy | Marketing | ☐ |
| Influencer/KOL commitments confirmed | Marketing | ☐ |
| DEX pool creation scripts tested on devnet | Dev | ☐ |
| Jito bundle submission tested | Dev | ☐ |
| Emergency runbook reviewed by all parties | All | ☐ |
| Legal review of token sale terms | Legal | ☐ |

### T-3 Days

| Task | Owner | Status |
|------|-------|--------|
| Mainnet mint keypair generated (offline) | Dev | ☐ |
| LP wallet multisig configured | Ops | ☐ |
| Pool creation transaction pre-built | Dev | ☐ |
| Announcements drafted (Twitter, Discord, TG) | Marketing | ☐ |
| Block explorer metadata verified on devnet | Dev | ☐ |
| Monitoring dashboards set up (Dune, custom) | Dev | ☐ |
| Backup RPC endpoints configured | Dev | ☐ |
| Rate limits checked on all APIs | Dev | ☐ |

### T-1 Day (Day Before Launch)

| Task | Owner | Status |
|------|-------|--------|
| Final rehearsal: dry-run full launch sequence | Dev | ☐ |
| All wallets funded and verified | Ops | ☐ |
| Jito tip accounts verified | Dev | ☐ |
| Social media posts scheduled | Marketing | ☐ |
| Community mods briefed on launch timeline | Community | ☐ |
| Whale/early supporter wallets whitelisted (if needed) | Ops | ☐ |
| Health check on all RPC endpoints | Dev | ☐ |
| Confirm no Solana network congestion/issues | Dev | ☐ |

### T-0 (Launch Hour)

| Step | Time | Action |
|------|------|--------|
| 1 | T+0m | Create mint account on mainnet |
| 2 | T+1m | Create token metadata |
| 3 | T+2m | Mint initial supply to distribution wallets |
| 4 | T+3m | Create DEX pool (Raydium/Meteora) |
| 5 | T+4m | Seed initial liquidity via Jito bundle |
| 6 | T+5m | Verify pool on Solscan/Jupiter |
| 7 | T+6m | Announce on Twitter + Telegram + Discord |
| 8 | T+7m | Enable trading (remove any gate if applicable) |
| 9 | T+8m | Confirm first trades executing correctly |
| 10 | T+15m | Post 15-minute metrics update to community |

---

## Liquidity Seeding Strategy

### Initial Liquidity Decision Matrix

| Project Stage | SOL Liquidity | Token % | Pool Type |
|---------------|--------------|---------|-----------|
| Meme coin (speculative) | 50-200 SOL | 80-90% supply | Raydium AMM / pump.fun |
| Utility token (small) | 200-500 SOL | 40-60% supply | Raydium CLMM |
| Utility token (medium) | 500-2000 SOL | 30-50% supply | Meteora DLMM |
| DeFi protocol token | 2000-10000 SOL | 20-40% supply | Multi-DEX |

### Seeding Timing

**Never seed liquidity before announcing.** The sequence matters:

1. Create pool with minimal liquidity (prevents snipers from setting price)
2. Add full liquidity in the same Jito bundle as the announcement
3. This ensures the first public trades happen at your intended price

### Single-Sided vs Double-Sided Seeding

```
Double-sided (recommended for most launches):
  - Add SOL + tokens at a fixed ratio
  - Initial price = SOL_amount / token_amount
  - Creates immediate two-sided market

Single-sided (advanced):
  - Add only tokens, set starting price via oracle
  - Users buy with SOL, creating natural price discovery
  - Risk: if no buyers, price goes to zero instantly
```

---

## Jito Bundle Protection

### Why Bundles Matter

Without Jito bundles, your liquidity seeding transaction enters the public mempool. MEV bots will:
1. Front-run your LP addition (buy before you, sell after)
2. Sandwich your transactions
3. Extract 5-15% of your initial liquidity value

### Bundle Construction (TypeScript)

```typescript
import { Keypair, Transaction, SystemProgram, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { Bundle } from "jito-ts/dist/sdk/block-engine/bundle";
import { searcherClient } from "jito-ts/dist/sdk/block-engine/searcher";

const JITO_BLOCK_ENGINE = "https://mainnet.block-engine.jito.wtf/api/v1/bundles";

async function sendProtectedBundle(
  transactions: Transaction[],
  payer: Keypair,
  tipLamports: number = 100_000 // 0.0001 SOL tip
): Promise<string> {
  const client = searcherClient(JITO_BLOCK_ENGINE, undefined);

  // Add tip transaction to last position
  const tipTx = new Transaction().add(
    SystemProgram.transfer({
      fromPubkey: payer.publicKey,
      toPubkey: new Keypair().publicKey, // Jito tip account
      lamports: tipLamports,
    })
  );

  const allTxs = [...transactions, tipTx];
  const bundle = new Bundle(allTxs, 5);

  const result = await client.sendBundle(bundle);
  if (result.value) {
    console.log(`Bundle sent: ${result.value}`);
    return result.value;
  }
  throw new Error("Bundle submission failed");
}
```

### Jito Tip Strategy

| Network Congestion | Recommended Tip | Rationale |
|-------------------|-----------------|-----------|
| Low (< 2k TPS) | 0.0001 SOL | Minimal competition |
| Medium (2-4k TPS) | 0.001 SOL | Standard priority |
| High (> 4k TPS) | 0.01 SOL | Guarantee inclusion |
| Launch day (any) | 0.01-0.05 SOL | Don't risk it |

---

## Launch Sequence: Detailed Steps

### Step 1: Create Mint

```typescript
import { createMint, getOrCreateAssociatedTokenAccount, mintTo } from "@solana/spl-token";

const mint = await createMint(
  connection,
  payer,          // Fee payer
  mintAuthority,  // Can mint new tokens
  freezeAuthority, // Can freeze accounts (set to null for trustless)
  9,              // Decimals (9 = standard, 6 = USDC-style)
  mintKeypair,    // Deterministic keypair
  { commitment: "confirmed" }
);
```

### Step 2: Seed LP (Atomic with Pool Creation)

```typescript
// All in one Jito bundle:
// 1. Create Raydium AMM pool
// 2. Add initial liquidity
// 3. (Optional) Revoke freeze authority

const createPoolIx = await buildCreatePoolInstruction({
  baseMint: mint,
  quoteMint: NATIVE_MINT, // SOL
  baseAmount: tokenAmount,
  quoteAmount: solAmount,
  startTime: Math.floor(Date.now() / 1000),
});

const addLiquidityIx = await buildAddLiquidityInstruction({
  poolId: createPoolIx.poolId,
  baseAmount: tokenAmount,
  quoteAmount: solAmount,
});
```

### Step 3: Announce

Pre-draft all announcements. Post simultaneously across all channels:

```
🚀 $TOKEN is LIVE on Solana!

📊 Pool: [Solscan link]
📈 Trade: [Jupiter link] | [Raydium link]
📋 Contract: [mint address]

Liquidity locked for 1 year 🔒
Mint authority revoked ✅
Freeze authority revoked ✅

DYOR — [link to docs/tokenomics]
```

### Step 4: Enable Trading

If using a gated launch (whitelist phase):
- Remove gate after announcement is live
- Monitor first 100 trades for anomalies
- Have a kill switch ready (circuit breaker pattern)

---

## Fee Account Management

| Account | Purpose | Access |
|---------|---------|--------|
| Fee payer | Pays transaction fees | Hot wallet, minimal SOL |
| LP wallet | Holds LP tokens | Multisig (3-of-5) |
| Treasury | Protocol fees | Multisig + timelock |
| Marketing | Ongoing costs | Single-sig, budget-capped |
| Emergency | Circuit breaker ops | Multisig, 2-of-3 |

Fund fee payer with 5-10 SOL on launch day. Keep treasury separate.

---

## Initial Price Discovery

### AMM Price Formula (Constant Product)

```
price = quote_reserve / base_reserve

Example:
  Pool: 1,000,000 tokens + 100 SOL
  Initial price: 100 / 1,000,000 = 0.0001 SOL per token
```

### Setting Initial Price

Your initial liquidity ratio determines the starting price:

| Desired Price | Tokens (9 dec) | SOL Needed |
|---------------|----------------|------------|
| $0.001 | 10,000,000 | ~15 SOL ($0.001 * 10M / $150) |
| $0.01 | 1,000,000 | ~67 SOL |
| $0.10 | 100,000,000 | ~6,667 SOL |

**Rule of thumb**: Start lower than you think. It's easier to 10x from a low base than recover from a dump after an overpriced launch.

---

## Marketing Timing vs Trading Enablement

```
❌ WRONG: Announce first, then create pool
  → Snipers front-run you, community buys at inflated price

❌ WRONG: Create pool, wait, then announce
  → Snipers find pool on-chain before community

✅ RIGHT: Bundle pool creation + liquidity + announcement atomically
  → First trades happen at intended price
  → Community and insiders see it at the same time
```

---

## Monitoring: First 24 Hours

### Key Metrics Dashboard

| Metric | Target (Hour 1) | Target (Hour 24) | Alert Threshold |
|--------|-----------------|-------------------|-----------------|
| Unique holders | 50+ | 500+ | < 20 holders at hour 1 |
| Trading volume | 2x initial liquidity | 10x | 0 volume for 30 min |
| Liquidity depth (±5%) | 80%+ of initial | 90%+ | < 50% of initial |
| Price impact (1 SOL) | < 2% | < 1% | > 5% |
| Top 10 holder % | < 40% | < 30% | > 60% |
| Organic buys/sells ratio | > 1.5 | > 1.2 | < 0.8 (sell pressure) |

### Monitoring Scripts

```typescript
// Track holder count every 5 minutes
async function monitorHolders(mint: PublicKey) {
  const accounts = await connection.getProgramAccounts(TOKEN_PROGRAM_ID, {
    filters: [
      { dataSize: 165 },
      { memcmp: { offset: 0, bytes: mint.toBase58() } },
    ],
  });
  const holders = accounts.filter(
    (a) => (a.account.data as Buffer).readBigUInt64LE(64) > 0n
  );
  return holders.length;
}
```

### Bot Integration (Telegram)

```typescript
import { Telegraf } from "telegraf";

const bot = new Telegraf(process.env.TG_BOT_TOKEN!);

// Post metrics every 15 minutes
setInterval(async () => {
  const metrics = await getTokenMetrics(mintAddress);
  bot.telegram.sendMessage(
    CHANNEL_ID,
    `📊 15-Min Update\n` +
    `Holders: ${metrics.holders}\n` +
    `Volume: ${metrics.volume24h} SOL\n` +
    `Price: ${metrics.price} SOL\n` +
    `Liquidity: ${metrics.liquidity} SOL`
  );
}, 15 * 60 * 1000);
```

---

## Emergency Procedures

### Scenario: Pool Creation Fails

1. Do NOT retry blindly — check if partial state was created
2. Verify mint was created successfully
3. Re-run pool creation with fresh transaction
4. Delay announcement by 10 minutes, post update to community

### Scenario: Sniper Bot Dominance (>50% supply bought in first minute)

1. Do NOT panic sell or rug
2. Post transparency update
3. Consider adding more liquidity to reduce price impact
4. Implement gradual buyback if price crashes

### Scenario: RPC Failure During Launch

```typescript
const RPC_ENDPOINTS = [
  "https://api.mainnet-beta.solana.com",
  "https://solana-mainnet.g.alchemy.com/v2/YOUR_KEY",
  "https://rpc.helius.xyz/?api-key=YOUR_KEY",
];

// Failover connection
function getConnection(): Connection {
  for (const rpc of RPC_ENDPOINTS) {
    try {
      return new Connection(rpc, "confirmed");
    } catch (e) {
      continue;
    }
  }
  throw new Error("All RPC endpoints failed");
}
```

### Scenario: Smart Contract Bug Discovered Post-Launch

1. If freeze authority retained: freeze affected accounts
2. If upgrade authority retained: patch and redeploy
3. If authorities revoked: communicate transparently, coordinate migration
4. Have a pre-written incident response template ready

---

## Post-Launch Stabilization (First 48h)

### Buyback Strategy

```
Allocate 5-10% of raised SOL for stabilization:
- Buy back if price drops > 30% from initial
- Execute via limit orders on Jupiter (not market buys)
- Spread buys over 6-12 hours
- Report all buybacks on-chain transparently
```

### LP Adjustments

| Condition | Action |
|-----------|--------|
| Price up 5x+ | Add single-sided SOL liquidity (deepen pool) |
| Price down 50%+ | Buy back with treasury, add as liquidity |
| Volume spike | Increase fee tier if using CLMM |
| Volume dead | Activate marketing, consider LP incentives |

---

## DEX Launch Strategy Comparison

### Raydium IDO

- **Best for**: High-visibility launches, established communities
- **Pool types**: AMM (constant product), CLMM (concentrated)
- **Pros**: Deepest liquidity on Solana, Jupiter integrated
- **Cons**: Higher SOL cost for pool creation (~0.5-2 SOL)
- **Launch path**: Create pool → Seed LP → Jupiter auto-discovers

### Meteora Dynamic Pool / DLMM

- **Best for**: Active liquidity management, dynamic fees
- **Pool types**: Dynamic AMM, DLMM (bin-based)
- **Pros**: Better capital efficiency, dynamic fees, MEV protection
- **Cons**: Less name recognition, smaller initial volume
- **Launch path**: Create DLMM pool → Add bin liquidity → Jupiter routes through it

### pump.fun Graduation

- **Best for**: Meme coins, low-capital launches, zero upfront liquidity
- **Mechanism**: Bonding curve → automatic Raydium pool at $69k market cap
- **Pros**: Zero upfront liquidity cost, viral mechanics
- **Cons**: 1% fee, slower price discovery, less control
- **Launch path**: Create on pump.fun → Social traction → Auto-graduate

### Decision Tree

```
Do you have > 500 SOL for initial liquidity?
├── Yes → Is your token utility/governance?
│   ├── Yes → Meteora DLMM or Raydium CLMM
│   └── No → Raydium AMM
└── No → Do you have community traction?
    ├── Yes → Raydium AMM with minimal liquidity
    └── No → pump.fun graduation path
```

---

## Multi-DEX Launch Strategy

For larger launches ($1M+ market cap target):

1. **Primary pool**: Raydium CLMM or Meteora DLMM (60% of liquidity)
2. **Secondary pool**: Other DEX (30% of liquidity)
3. **Reserve**: 10% for opportunistic additions

Jupiter aggregates all DEXes, so splitting liquidity can improve routing but increases management overhead. For most launches, a single well-funded pool is superior.
