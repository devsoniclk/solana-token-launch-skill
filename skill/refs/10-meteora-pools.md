# 10 — Meteora Dynamic Pools & DLMM

## Meteora DLMM Explained

DLMM (Dynamic Liquidity Market Maker) is Meteora's concentrated liquidity solution that uses discrete price bins instead of a continuous curve. Each bin represents a single price point, and liquidity providers deposit into specific bins.

### Key Concepts

- **Bins**: Discrete price ranges. Each bin has exactly one price.
- **Bin step**: The price difference between adjacent bins (e.g., 0.25%, 1%).
- **Active bin**: The current trading price bin.
- **Bin array**: A group of contiguous bins for efficient on-chain storage.
- **Position**: A range of bins where a liquidity provider has deposited.

### DLMM vs Traditional AMM vs Concentrated Liquidity

| Feature | Traditional AMM | CLMM (Raydium) | DLMM (Meteora) |
|---------|----------------|-----------------|-----------------|
| Price curve | Continuous (x*y=k) | Continuous (tick-based) | Discrete bins |
| Capital efficiency | 1x baseline | 4-100x | 10-200x |
| Fee structure | Fixed % | Variable per tick | Dynamic per bin |
| Rebalancing | Automatic | Manual tick management | Bin-level management |
| IL protection | None | Partial (range) | Partial (bin range) |
| Complexity for LPs | Low | Medium | Medium-High |
| Best for | High-volatility pairs | Large-cap pairs | Any pair, active management |

### When to Use DLMM

**Use DLMM when:**
- You want maximum capital efficiency
- You'll actively manage liquidity positions
- You want dynamic fees that adjust to volatility
- You're launching a new token and want precise price control

**Use Dynamic Pools when:**
- You want a simple AMM with better fees than Raydium
- You don't want to actively manage positions
- The pair has unpredictable volume patterns

---

## Bin Structure and Price Ranges

### How Bins Work

```
Price:  0.975   1.000   1.025   1.050   1.075
         │       │       │       │       │
Bin ID: -2      -1       0      +1      +2
         │       │       │       │       │
Liquidity:  LOW   MED    HIGH   MED     LOW

When someone buys, price moves right (up).
When someone sells, price moves left (down).
Liquidity in each bin is consumed sequentially.
```

### Bin Step Selection

| Bin Step | Price Increment | Best For | Tradeoff |
|----------|----------------|----------|----------|
| 1 | 0.01% | Stable pairs (USDC/USDT) | Max efficiency, high rebalance frequency |
| 5 | 0.05% | Low-vol pairs | Good efficiency, moderate management |
| 10 | 0.10% | Medium-vol pairs | Balanced |
| 25 | 0.25% | Most token pairs | Default recommendation |
| 50 | 0.50% | Higher volatility | Wider bins, less management |
| 100 | 1.00% | Meme coins, high vol | Wide bins, minimal management |
| 200 | 2.00% | Very high volatility | Least efficient, easiest management |

### Price Formula

```
bin_price = (1 + bin_step / 10000) ^ bin_id

Example with bin_step = 25 (0.25%):
  bin 0    = 1.0000
  bin 1    = 1.0025
  bin 10   = 1.0253
  bin 100  = 1.2834
  bin -10  = 0.9753
```

---

## Creating a DLMM Pool

### TypeScript SDK

```typescript
import {
  Connection,
  Keypair,
  PublicKey,
  sendAndConfirmTransaction,
} from "@solana/web3.js";
import DLMM from "@meteora-ag/dlmm";
import { BN } from "@coral-xyz/anchor";

const connection = new Connection("https://api.mainnet-beta.solana.com", "confirmed");

async function createDLMMPool(
  payer: Keypair,
  tokenX: PublicKey,    // e.g., USDC
  tokenY: PublicKey,    // e.g., your token
  binStep: number,      // e.g., 25 for 0.25%
  baseFactor: number,   // base fee in bps (e.g., 10000 = 1%)
  initialPrice: number  // price of tokenY in terms of tokenX
) {
  // Convert price to active ID
  const activeId = DLMM.getPriceToBinId(initialPrice, binStep);
  console.log(`Initial active bin ID: ${activeId}`);

  // Build pool creation transaction
  const { createPoolTx, poolAddress } = await DLMM.createLiquidityPool(
    connection,
    payer,
    tokenX,
    tokenY,
    binStep,
    activeId,
    new BN(baseFactor)
  );

  const sig = await sendAndConfirmTransaction(connection, createPoolTx, [payer]);
  console.log(`DLMM Pool created: ${poolAddress.toBase58()}`);
  console.log(`Transaction: ${sig}`);

  return poolAddress;
}

// Example usage:
// createDLMMPool(
//   payer,
//   new PublicKey("EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"), // USDC
//   new PublicKey("YOUR_TOKEN_MINT"),
//   25,      // 0.25% bin step
//   10000,   // 1% base fee
//   0.001    // initial price
// );
```

### Pool Creation Parameters Guide

| Parameter | Recommended Value | Notes |
|-----------|------------------|-------|
| binStep | 25 (default) | Increase for high-volatility pairs |
| baseFactor | 10000 (1%) | Base fee percentage in bps |
| activeId | Price-derived | Use `DLMM.getPriceToBinId()` |

---

## Adding Liquidity to DLMM

### Strategy Types

| Strategy | Description | Best For |
|----------|-------------|----------|
| **Spot** | Equal token distribution across bins | Balanced exposure, general purpose |
| **Curve** | More liquidity near active bin | Capturing most trades, lower IL |
| **Bid-Ask** | Liquidity at edges, empty middle | Range-bound markets, market making |

### Spot Strategy

```typescript
async function addSpotLiquidity(
  connection: Connection,
  payer: Keypair,
  poolAddress: PublicKey,
  amountX: bigint,  // amount of token X
  amountY: bigint,  // amount of token Y
  range: number = 10 // bins on each side of active bin
) {
  const dlmmPool = await DLMM.create(connection, poolAddress, {
    cluster: "mainnet-beta",
  });

  const activeBin = await dlmmPool.getActiveBin();

  const tx = await dlmmPool.addLiquidityByStrategy({
    userPublicKey: payer.publicKey,
    amountX: new BN(amountX.toString()),
    amountY: new BN(amountY.toString()),
    strategy: {
      minBinId: activeBin.binId - range,
      maxBinId: activeBin.binId + range,
      strategyType: 0, // 0 = spot
    },
    slippage: 0.5,
  });

  const sig = await sendAndConfirmTransaction(connection, tx as any, [payer]);
  console.log(`Spot liquidity added: ${sig}`);
}
```

### Curve Strategy

```typescript
async function addCurveLiquidity(
  connection: Connection,
  payer: Keypair,
  poolAddress: PublicKey,
  amountX: bigint,
  amountY: bigint,
  range: number = 20
) {
  const dlmmPool = await DLMM.create(connection, poolAddress, {
    cluster: "mainnet-beta",
  });

  const activeBin = await dlmmPool.getActiveBin();

  // Curve: concentrate more liquidity near the active bin
  const tx = await dlmmPool.addLiquidityByStrategy({
    userPublicKey: payer.publicKey,
    amountX: new BN(amountX.toString()),
    amountY: new BN(amountY.toString()),
    strategy: {
      minBinId: activeBin.binId - range,
      maxBinId: activeBin.binId + range,
      strategyType: 1, // 1 = curve
    },
    slippage: 0.5,
  });

  const sig = await sendAndConfirmTransaction(connection, tx as any, [payer]);
  console.log(`Curve liquidity added: ${sig}`);
}
```

### Bid-Ask Strategy

```typescript
async function addBidAskLiquidity(
  connection: Connection,
  payer: Keypair,
  poolAddress: PublicKey,
  amountX: bigint,
  amountY: bigint,
  range: number = 30
) {
  const dlmmPool = await DLMM.create(connection, poolAddress, {
    cluster: "mainnet-beta",
  });

  const activeBin = await dlmmPool.getActiveBin();

  // Bid-Ask: place liquidity at the edges
  const tx = await dlmmPool.addLiquidityByStrategy({
    userPublicKey: payer.publicKey,
    amountX: new BN(amountX.toString()),
    amountY: new BN(amountY.toString()),
    strategy: {
      minBinId: activeBin.binId - range,
      maxBinId: activeBin.binId + range,
      strategyType: 2, // 2 = bid-ask
    },
    slippage: 0.5,
  });

  const sig = await sendAndConfirmTransaction(connection, tx as any, [payer]);
  console.log(`Bid-Ask liquidity added: ${sig}`);
}
```

### Strategy Comparison Visual

```
Spot (equal distribution):
  Bin:   -3  -2  -1   0  +1  +2  +3
  Liq:   ██  ██  ██  ██  ██  ██  ██

Curve (concentrated center):
  Bin:   -3  -2  -1   0  +1  +2  +3
  Liq:   ░░  ▒▒  ▓▓  ██  ▓▓  ▒▒  ░░

Bid-Ask (edges heavy):
  Bin:   -3  -2  -1   0  +1  +2  +3
  Liq:   ██  ▓▓  ░░  ░░  ░░  ▓▓  ██
```

---

## Dynamic Fee Mechanics

DLMM fees adjust based on market volatility and bin utilization.

### Fee Components

```
Total Fee = Base Fee + Variable Fee

Base Fee = baseFactor × binStep / 10000
Variable Fee = dynamically adjusted based on:
  - Price movement speed
  - Number of bins crossed per swap
  - Time since last swap
```

### Fee Examples

| Scenario | Base Fee | Variable Fee | Total Fee |
|----------|----------|-------------|-----------|
| Small swap, stable market | 0.25% | 0.00% | 0.25% |
| Medium swap, normal volatility | 0.25% | 0.05% | 0.30% |
| Large swap, high volatility | 0.25% | 0.50% | 0.75% |
| Massive swap, extreme vol | 0.25% | 2.00%+ | 2.25%+ |

### Fee Optimization for LPs

```typescript
// Higher baseFactor = higher base fee = more fee income but fewer trades
// Lower baseFactor = lower base fee = more trades but less per trade

// For new token launches (high vol):
const launchConfig = { binStep: 25, baseFactor: 15000 }; // 1.5% base fee

// For established pairs:
const stableConfig = { binStep: 10, baseFactor: 5000 }; // 0.5% base fee

// For stablecoins:
const stablecoinConfig = { binStep: 1, baseFactor: 1000 }; // 0.01% base fee
```

---

## Meteora Dynamic Pools (Standard AMM)

Dynamic Pools are Meteora's standard AMM with dynamic fees. Simpler than DLMM but better than traditional constant-product AMMs.

### Creating a Dynamic Pool

```typescript
import { DynamicPool } from "@meteora-ag/dynamic-pools";
import { Connection, Keypair, PublicKey, sendAndConfirmTransaction } from "@solana/web3.js";

async function createDynamicPool(
  connection: Connection,
  payer: Keypair,
  tokenAMint: PublicKey,
  tokenBMint: PublicKey,
  tokenAAmount: bigint,
  tokenBAmount: bigint
) {
  const pool = await DynamicPool.create(connection, {
    cluster: "mainnet-beta",
  });

  const createTx = await pool.createPool({
    tokenAMint,
    tokenBMint,
    payer: payer.publicKey,
    tokenAAmount: new BN(tokenAAmount.toString()),
    tokenBAmount: new BN(tokenBAmount.toString()),
    activationType: 0, // 0 = slot-based, 1 = timestamp-based
  });

  const sig = await sendAndConfirmTransaction(connection, createTx, [payer]);
  console.log(`Dynamic Pool created: ${sig}`);
  return sig;
}
```

### Dynamic vs DLMM Decision

```
Use Dynamic Pool when:
  - You want passive liquidity management
  - The pair has moderate, predictable volume
  - You want simpler integration
  - Capital efficiency is less critical

Use DLMM when:
  - You want maximum capital efficiency
  - You'll actively manage positions
  - The pair has high volume relative to liquidity
  - You want to implement custom market-making strategies
```

---

## Jupiter Integration

All Meteora pools are automatically integrated with Jupiter for best-route aggregation. No additional work needed.

### Verifying Jupiter Discovery

```typescript
// Check if your pool is being routed through Jupiter
const JUPITER_PRICE_API = "https://price.jup.ag/v6";

async function checkJupiterRouting(tokenMint: string) {
  const res = await fetch(`${JUPITER_PRICE_API}/price?ids=${tokenMint}`);
  const data = await res.json();

  if (data.data[tokenMint]) {
    console.log(`Price: ${data.data[tokenMint].price}`);
    console.log(`Token is discoverable on Jupiter`);
  } else {
    console.log(`Token not found — ensure pool has liquidity`);
  }
}
```

### Forced Routing Through Meteora

For large trades, you can force Jupiter to route through Meteora:

```typescript
const JUPITER_QUOTE_API = "https://quote-api.jup.ag/v6";

async function getQuoteWithDex(
  inputMint: string,
  outputMint: string,
  amount: number,
  dex: string = "Meteora DLMM"
) {
  const res = await fetch(
    `${JUPITER_QUOTE_API}/quote?inputMint=${inputMint}&outputMint=${outputMint}` +
    `&amount=${amount}&dexes=${encodeURIComponent(dex)}`
  );
  return res.json();
}
```

---

## CLI Usage

### Meteora CLI (via npx)

```bash
# Install
npm install -g @meteora-ag/cli

# Create a DLMM pool
meteora dlmm create-pool \
  --token-x EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v \
  --token-y YOUR_MINT \
  --bin-step 25 \
  --base-factor 10000 \
  --initial-price 0.001

# Add liquidity
meteora dlmm add-liquidity \
  --pool POOL_ADDRESS \
  --amount-x 1000000000 \
  --amount-y 0 \
  --strategy spot \
  --range 10

# Remove liquidity
meteora dlmm remove-liquidity \
  --pool POOL_ADDRESS \
  --position POSITION_ADDRESS \
  --bins-from -10 \
  --bins-to 10

# Claim fees
meteora dlmm claim-fees \
  --pool POOL_ADDRESS \
  --position POSITION_ADDRESS
```

---

## Pool Creation Parameters Deep Dive

### DLMM Pool Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| tokenX | PublicKey | Base token (usually stablecoin) | Required |
| tokenY | PublicKey | Quote token (your token) | Required |
| binStep | number | Price increment per bin (bps) | 25 |
| baseFactor | number | Base fee multiplier (bps) | 10000 |
| activeId | number | Starting bin ID | Price-derived |

### Recommended Configurations

| Token Type | binStep | baseFactor | Strategy | Range |
|------------|---------|------------|----------|-------|
| Stablecoin pair | 1-5 | 1000-2000 | Spot | 5-10 |
| Blue chip / SOL | 10-25 | 5000-8000 | Curve | 15-20 |
| Mid-cap token | 25 | 10000 | Spot/Curve | 10-20 |
| Meme coin | 50-100 | 10000-20000 | Spot | 5-15 |
| New launch | 25-50 | 10000-15000 | Curve | 10-15 |

---

## Liquidity Management Strategies

### Strategy 1: Set-and-Forget (Passive)

```
- Use wide range (±30 bins)
- Use spot strategy
- Claim fees weekly
- Rebalance monthly if price drifts out of range
- Risk: price moves out of range, earn nothing
```

### Strategy 2: Active Market Making

```
- Use tight range (±5-10 bins)
- Use curve strategy concentrated on active bin
- Rebalance every 4-8 hours
- Set alerts for price movement > 5%
- Risk: high gas costs, IL if rebalance poorly timed
```

### Strategy 3: Launch-Optimized

```
- Start with spot strategy, ±15 bins
- First 24h: monitor and rebalance every 2 hours
- After 24h: widen range to ±25 bins
- After 1 week: transition to passive strategy
- Risk: high initial IL during volatile launch period
```

### Strategy 4: Hedge Position

```
- Use bid-ask strategy
- Place buys below current price (accumulate on dips)
- Place sells above current price (take profit)
- Effectively a grid trading bot
- Risk: price trends one direction, only one side fills
```

### Rebalancing Automation

```typescript
import { CronJob } from "cron";

async function rebalancePosition(
  connection: Connection,
  payer: Keypair,
  poolAddress: PublicKey,
  range: number
) {
  const dlmmPool = await DLMM.create(connection, poolAddress);
  const positions = await dlmmPool.getPositionsByUserAndLbPair(payer.publicKey);

  if (positions.userPositions.length === 0) {
    console.log("No positions found");
    return;
  }

  const position = positions.userPositions[0];
  const activeBin = await dlmmPool.getActiveBin();

  // Check if active bin is within position range
  const { minBinId, maxBinId } = position.positionData;

  if (activeBin.binId >= minBinId && activeBin.binId <= maxBinId) {
    console.log("Position in range, no rebalance needed");
    return;
  }

  // Price has moved out of range — rebalance
  console.log(`Rebalancing: active bin ${activeBin.binId}, position ${minBinId}-${maxBinId}`);

  // Remove all liquidity
  const removeTx = await dlmmPool.removeLiquidity({
    position: position.publicKey,
    userPublicKey: payer.publicKey,
    binIds: Array.from(
      { length: maxBinId - minBinId + 1 },
      (_, i) => minBinId + i
    ),
    slippage: 0.5,
  });
  await sendAndConfirmTransaction(connection, removeTx as any, [payer]);

  // Re-add with new range
  await addSpotLiquidity(connection, payer, poolAddress, 0n, 0n, range);
  console.log("Rebalance complete");
}

// Run every 4 hours
const job = new CronJob("0 */4 * * *", () => {
  rebalancePosition(connection, payer, POOL_ADDRESS, 15);
});
job.start();
```

---

## Fee Optimization

### Maximizing Fee Income

| Factor | Action | Impact |
|--------|--------|--------|
| Bin step | Lower = tighter spreads | More trades captured, more management |
| Range width | Narrower = more concentrated | Higher fee/token but more risk |
| Base factor | Higher = more fee per trade | Fewer trades but more per trade |
| Active management | Frequent rebalancing | Capture fees in all conditions |
| Strategy | Curve near active bin | Best for trending markets |

### Fee Claiming

```typescript
async function claimFees(
  connection: Connection,
  payer: Keypair,
  poolAddress: PublicKey
) {
  const dlmmPool = await DLMM.create(connection, poolAddress);
  const positions = await dlmmPool.getPositionsByUserAndLbPair(payer.publicKey);

  for (const position of positions.userPositions) {
    const claimTx = await dlmmPool.claimLmReward({
      position: position.publicKey,
      userPublicKey: payer.publicKey,
    });

    const sig = await sendAndConfirmTransaction(connection, claimTx as any, [payer]);
    console.log(`Claimed fees: ${sig}`);
  }
}
```

### Fee Comparison: DLMM vs Raydium vs Orca

| DEX | Fee Range | Dynamic? | Capital Efficiency |
|-----|-----------|----------|-------------------|
| Meteora DLMM | 0.01-4%+ | Yes | 10-200x |
| Meteora Dynamic | 0.1-1% | Yes | 3-10x |
| Raydium AMM | 0.25% fixed | No | 1x |
| Raydium CLMM | 0.01-1% | No (per tick) | 4-100x |
| Orca Whirlpools | 0.01-2% | No (per tick) | 4-100x |

**DLMM's dynamic fees give it an edge in volatile conditions** — fees increase automatically when volatility spikes, compensating LPs for increased impermanent loss risk.
