# DEX Liquidity Configuration

## DEX Comparison (2026 Solana Ecosystem)

| DEX         | Type              | Fee Tiers      | Best For                    |
|-------------|-------------------|----------------|-----------------------------|
| Raydium AMM v4 | Constant product | 0.25% fixed  | Standard pairs, new tokens  |
| Raydium CLMM | Concentrated     | 0.01-1%       | High-volume pairs, capital efficiency |
| Orca Whirlpools | Concentrated  | 0.01-1%       | DeFi integrations, clean UX |
| Meteora DLMM | Dynamic liquidity | Variable      | Active management, volatility |
| Meteora DAMM | Dynamic AMM       | Variable      | Pools with dynamic fees     |

---

## Raydium AMM v4 (Legacy)

Standard constant product AMM. The most common for new token launches.

### Pool Creation

Requires an OpenBook market ID first.

```bash
# Step 1: Create OpenBook market
# (Requires @openbook-dex/client or raydium-sdk)

# Step 2: Create Raydium AMM pool
# Use raydium-sdk or CLI tools
```

**TypeScript with Raydium SDK:**

```typescript
import { 
  Liquidity, 
  LiquidityPoolKeys,
  jsonInfo2PoolKeys,
  Percent,
  Token,
  TokenAmount,
  SPL_ACCOUNT_LAYOUT
} from "@raydium-io/raydium-sdk";

// Create pool
const poolKeys = await Liquidity.makeCreatePoolInstructionSimple({
  connection,
  baseToken: new Token(TOKEN_PROGRAM_ID, mintAddress, decimals, symbol, name),
  quoteToken: new Token(TOKEN_PROGRAM_ID, WSOL_MINT, 9, "WSOL", "Wrapped SOL"),
  baseAmount: new TokenAmount(baseToken, baseAmount),
  quoteAmount: new TokenAmount(quoteToken, quoteAmount),
  startTime: new BN(Math.floor(Date.now() / 1000)),
  owner: wallet.publicKey,
  feeDestinationId: FEE_DESTINATION_ID,
});
```

### Key Parameters

```
Initial price = quoteAmount / baseAmount
LP mint supply = sqrt(baseAmount * quoteAmount)
```

---

## Raydium CLMM (Concentrated Liquidity Market Maker)

LPs provide liquidity within specific price ranges (ticks). Higher capital efficiency.

### Tick Spacing

| Fee Tier | Tick Spacing | Use Case                    |
|----------|-------------|-----------------------------|
| 0.01%    | 1           | Stablecoin pairs            |
| 0.05%    | 8           | Major pairs (SOL/USDC)      |
| 0.25%    | 60          | Standard pairs              |
| 1%       | 120         | Exotic/volatile pairs       |

### Adding Liquidity (Concentrated)

```typescript
import { Clmm, TickUtils } from "@raydium-io/raydium-sdk";

// Define price range
const lowerPrice = new Decimal(0.001);  // Lower bound
const upperPrice = new Decimal(0.01);   // Upper bound

// Convert to tick indices
const lowerTick = TickUtils.getPriceTick(lowerPrice, tickSpacing);
const upperTick = TickUtils.getPriceTick(upperPrice, tickSpacing);

// Add liquidity
const { execute } = await Clmm.makeOpenPositionFromLiquidityInstruction({
  poolInfo,
  ownerInfo: { wallet: wallet.publicKey },
  tickLower: lowerTick,
  tickUpper: upperTick,
  liquidity: targetLiquidity,
  slippage: new Percent(1, 100), // 1%
});
```

### Capital Efficiency

Concentrated liquidity provides up to **4000x** the capital efficiency of constant product AMMs for the same price range.

```
Capital efficiency = 1 / (sqrt(upperPrice) - sqrt(lowerPrice))
```

Narrower range = higher efficiency = higher risk of going out of range.

---

## Orca Whirlpools

Concentrated liquidity on Solana. Clean SDK, used by Jupiter for routing.

### Pool Creation

```typescript
import { WhirlpoolContext, ORCA_WHIRLPOOL_PROGRAM_ID } from "@orca-so/whirlpools-sdk";

const ctx = WhirlpoolContext.from(
  connection,
  wallet,
  ORCA_WHIRLPOOL_PROGRAM_ID
);

// Create pool
const { poolKey, tx } = await ctx.whirlpoolClient.createPool(
  whirlpoolConfig,
  tokenMintA,
  tokenMintB,
  tickSpacing,
  initialTickIndex,
  wallet.publicKey
);
```

### Tick Spacing Options

| Tick Spacing | Fee Equivalent | Common Use     |
|-------------|---------------|----------------|
| 8           | ~0.01%        | Stable pairs   |
| 16          | ~0.05%        | Major pairs    |
| 64          | ~0.3%         | Standard       |
| 128         | ~1%           | Volatile pairs |

---

## Meteora DLMM (Dynamic Liquidity Market Maker)

Bin-based liquidity. LPs allocate to discrete price bins. Dynamic fees based on volatility.

### Key Differences

- **Bin structure:** Liquidity is in discrete bins, not continuous ticks
- **Dynamic fees:** Fee rate increases during high volatility
- **One-sided liquidity:** Can provide single-token liquidity
- **Auto-rebalance:** Built-in strategies for passive LPs

### Pool Creation

```typescript
import { DLMM } from "@meteora-ag/dlmm";

const dlmmPool = await DLMM.create(connection, poolPublicKey);

// Add liquidity
const addLiquidityTx = await dlmmPool.addLiquidityByStrategy({
  userPublicKey: wallet.publicKey,
  amountX: tokenAmountX,
  amountY: tokenAmountY,
  strategy: {
    maxBinId: upperBin,
    minBinId: lowerBin,
    strategyType: StrategyType.SpotImbalanced,
  },
});
```

---

## Jupiter Routing & Aggregation

Jupiter doesn't have its own pools — it routes across all Solana DEXes for best price.

### Swap via Jupiter API

```bash
# Get quote
curl "https://quote-api.jup.ag/v6/quote?inputMint=So11111111111111111111111111111111&outputMint=EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v&amount=1000000000&slippageBps=50"

# Get swap transaction
curl -X POST "https://quote-api.jup.ag/v6/swap" \
  -H "Content-Type: application/json" \
  -d '{
    "quoteResponse": <quote>,
    "userPublicKey": "<wallet>",
    "wrapUnwrapSOL": true,
    "dynamicComputeUnitLimit": true,
    "prioritizationFeeLamports": "auto"
  }'
```

### Jupiter for New Token Launches

After creating a DEX pool, Jupiter will discover and route to it automatically. No registration needed — Jupiter indexes all Solana AMM pools.

---

## Initial Liquidity Provisioning

### How Much SOL to Seed

| Market Cap Target | Suggested Initial SOL | Implied Price        |
|-------------------|----------------------|----------------------|
| $100K             | 5-10 SOL             | $7K-$14K per SOL est |
| $1M               | 50-100 SOL           | —                    |
| $10M              | 500-1000 SOL         | —                    |

**Rule of thumb:** Initial liquidity should support a $10K trade with <5% price impact.

```
For <5% price impact on a $10K trade:
reserve_sol >= $10K / (5% * SOL_price)
At $150/SOL: reserve >= 1,333 SOL
```

This is why most launches are illiquid initially.

### Seeding Strategy

```bash
# 1. Create token
spl-token create-token --decimals 6

# 2. Create token account
spl-token create-account <MINT>

# 3. Mint initial supply
spl-token mint <MINT> 1000000000

# 4. Transfer tokens for liquidity (150M = 15%)
spl-token transfer <MINT> 150000000 <LP_WALLET>

# 5. Create DEX pool with tokens + SOL
# (Use Raydium SDK, Orca SDK, or Meteora SDK)
```

---

## LP Token Management

### What LP Tokens Represent

LP tokens are your share of the pool. Holding them means you can redeem underlying assets proportionally.

```
your_share = your_lp_tokens / total_lp_supply
your_sol = pool_sol * your_share
your_token = pool_token * your_share
```

### Why Lock LP Tokens

Locked LP tokens prove the team cannot remove liquidity (rug pull). This is the single most important trust signal for new token launches.

### How to Lock

**Option 1: Burn LP tokens**

```bash
spl-token burn <LP_TOKEN_ACCOUNT> <AMOUNT>
```

**Option 2: Time-lock contract (Streamflow, Team.Finance)**

```typescript
// Streamflow vesting/lock
import { StreamClient } from "@streamflow/stream";

const streamClient = new StreamClient(rpcUrl);

await streamClient.create({
  sender: wallet,
  mint: lpTokenMint,
  recipient: burnAddress, // or lock contract
  start: Math.floor(Date.now() / 1000),
  amount: lpTokenAmount,
  period: 1, // unlock period
  cliff: unlockTimestamp,
  cliffAmount: new BN(0),
  amountPerPeriod: new BN(0), // 0 until cliff, then all at once
  name: "LP Lock",
});
```

---

## Fee Tier Selection

| Fee Tier | Best For                     | Typical APR  |
|----------|------------------------------|-------------|
| 0.01%    | Stablecoin pairs (USDC/USDT) | 2-5%        |
| 0.05%    | High-volume majors (SOL/USDC)| 10-30%      |
| 0.25%    | Standard alt pairs           | 20-100%     |
| 1%       | New/volatile tokens          | 50-500%+    |

**For new token launches:** Use **0.25%** or **1%**. Higher fees compensate LPs for higher impermanent loss risk on volatile tokens.

---

## Impermanent Loss Math

### Formula

```
IL = 2 * sqrt(price_ratio) / (1 + price_ratio) - 1
```

Where `price_ratio = new_price / initial_price`.

### Quick Reference Table

| Price Change (x) | Impermanent Loss |
|-------------------|-----------------|
| 1.25x (25% up)   | -0.6%           |
| 1.5x (50% up)    | -2.0%           |
| 2x (100% up)     | -5.7%           |
| 3x (200% up)     | -13.4%          |
| 5x (400% up)     | -25.5%          |
| 0.5x (50% down)  | -5.7%           |
| 0.25x (75% down) | -13.4%          |

### Python Calculator

```python
import math

def impermanent_loss(price_ratio):
    """Calculate IL for a given price change ratio."""
    il = 2 * math.sqrt(price_ratio) / (1 + price_ratio) - 1
    return il

# Examples
for ratio in [1.25, 1.5, 2, 3, 5, 0.5, 0.25]:
    il = impermanent_loss(ratio)
    print(f"Price {ratio}x: IL = {il*100:.2f}%")
```

---

## MEV Protection for Initial Liquidity

### The Problem

When you create a pool and add liquidity, MEV bots can:
1. Front-run your liquidity addition
2. Buy tokens at the initial low price
3. Sell after your liquidity drives the price up

### Solution: Jito Bundles

Jito bundles let you submit transactions atomically — all-or-nothing.

```typescript
import { search } from "jito-ts";

// Create bundle: market creation + pool creation + liquidity add
const bundle = new Bundle(
  [
    marketCreationIx,
    poolCreationIx,
    addLiquidityIx,
  ],
  10_000 // max tip
);

// Submit bundle — all transactions execute atomically or none do
const result = await searcherClient.sendBundle(bundle);
```

### Key MEV Protection Steps

1. **Create pool + add liquidity in single transaction** (or bundle)
2. **Set high compute unit limit** (transactions are larger)
3. **Add Jito tip** (0.01-0.1 SOL) to incentivize inclusion
4. **Use `createPool` with initial liquidity** in same instruction when possible
5. **Avoid pre-announcing** pool creation time

---

## Pool Migration Strategies

### Raydium AMM v4 → CLMM

When your token grows, you may want to migrate from basic AMM to concentrated liquidity.

**Steps:**
1. Create new CLMM pool with same token pair
2. Seed initial liquidity in CLMM pool
3. Gradually remove liquidity from AMM v4 pool
4. Jupiter will automatically route to the deeper pool
5. Leave AMM pool open (don't close) for backward compatibility

### Bonding Curve → AMM (Graduation)

```
1. Accumulate SOL in bonding curve
2. At threshold: create OpenBook market
3. Create Raydium AMM pool
4. Deposit bonding curve SOL + remaining tokens
5. Burn LP tokens
6. Mark bonding curve as graduated
```

---

## CLI Commands Reference

```bash
# List all pools for a token
spl-token accounts --verbose

# Check pool reserves (via Raydium API)
curl "https://api-v3.raydium.io/pools/info/mint?mint1=<MINT>&mint2=So11111111111111111111111111111111"

# Transfer tokens to LP wallet
spl-token transfer <MINT> <AMOUNT> <LP_WALLET> --fund-recipient

# Burn LP tokens
spl-token burn <LP_ACCOUNT> <AMOUNT>

# Close empty token account (reclaim rent)
spl-token close <ACCOUNT>
```
