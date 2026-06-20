# Simulate Launch Command

**Command**: `simulate-launch`
**Purpose**: Run Monte Carlo simulations of token launch scenarios to stress-test tokenomics, estimate price trajectories, and identify failure modes before going live.

---

## Usage

```
claude simulate-launch --tokenomics <path> [options]
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--tokenomics` | (required) | Path to tokenomics JSON or markdown |
| `--scenarios` | `1000` | Number of Monte Carlo simulation runs |
| `--horizon` | `365` | Simulation horizon in days |
| `--initial-mc` | auto | Initial market cap in USD |
| `--initial-fdv` | auto | Fully diluted valuation in USD |
| `--tge-unlock-pct` | auto | % of supply circulating at TGE |
| `--market-condition` | `mixed` | `bull`, `bear`, `mixed`, or `sideways` |
| `--dex-liquidity` | auto | Initial DEX liquidity in USD |
| `--volatility` | `high` | `low`, `medium`, `high`, `extreme` |
| `--output` | `simulation-report.md` | Output file path |
| `--format` | `markdown` | `markdown`, `json`, or `csv` |

---

## Simulation Model

### Price Dynamics

The simulation uses a modified geometric Brownian motion (GBM) model adapted for crypto token launches:

```
dS/S = μ(t)·dt + σ(t)·dW + J·dN
```

Where:
- `S` = token price
- `μ(t)` = time-varying drift (base: adoption curve, negative: post-hype decay)
- `σ(t)` = time-varying volatility (higher at launch, decaying over time)
- `dW` = Wiener process (random walk)
- `J` = jump size (represents large events: listings, partnerships, dumps)
- `dN` = Poisson process for jump events

### Supply-Side Pressure Model

```
Circulating(t) = TGE_tokens + Σ(unlock_schedule(t))
Sell_Pressure(t) = Circulating(t) × sell_rate(t) × (1 - staking_lock_rate)
```

Where `sell_rate` depends on:
- Time since unlock (decreasing over time)
- Holder type (team < investors < airdrop recipients)
- Market conditions (bear market increases sell rate)
- Staking rewards (higher rewards → lower sell rate)

### Liquidity Model

```
Price_Impact(trade_size) = trade_size / (2 × DEX_liquidity)
Effective_Price = Spot_Price × (1 - Price_Impact - Slippage_Fee)
```

Liquidity depth modeled as:
- Initial: seeded by launch allocation
- Growth: proportional to volume and market cap
- Decay: LP withdrawals, market makers reducing exposure

---

## Scenarios Modeled

### Scenario 1: Bull Market Launch
- Market-wide crypto rally (BTC +50% over horizon)
- High social media attention
- CEX listing within 30 days
- Probability weight: 20%

### Scenario 2: Sideways / Neutral
- Range-bound market
- Organic growth, modest community expansion
- No major catalysts
- Probability weight: 40%

### Scenario 3: Bear Market Launch
- Market-wide downturn (BTC -30% over horizon)
- Reduced liquidity across ecosystem
- Delayed listings
- Probability weight: 25%

### Scenario 4: Black Swan Event
- Protocol exploit, regulatory action, or major market crash
- Extreme drawdown (>50%)
- Probability weight: 15%

### Custom Scenarios

Users can define custom scenarios:

```json
{
  "name": "Viral Memecoin",
  "probability": 0.05,
  "initial_conditions": {
    "market_cap": 500000,
    "social_score": 95,
    "whale_concentration": 0.4
  },
  "events": [
    {"day": 3, "type": "listing", "impact": 3.0},
    {"day": 7, "type": "viral_tweet", "impact": 5.0},
    {"day": 14, "type": "whale_dump", "impact": 0.3}
  ]
}
```

---

## Output Report

```markdown
# Launch Simulation Report: [TOKEN_NAME] ($TICKER)

## Parameters
- **Simulations Run**: 1,000
- **Horizon**: 365 days
- **Initial Market Cap**: $X
- **Initial FDV**: $X
- **TGE Circulating**: X%
- **DEX Liquidity**: $X
- **Volatility Assumption**: High

## Summary Statistics

| Metric | Mean | Median | P5 (Bear) | P25 | P75 | P95 (Bull) |
|--------|------|--------|-----------|-----|-----|------------|
| Price at Day 30 | $X | $X | $X | $X | $X | $X |
| Price at Day 90 | $X | $X | $X | $X | $X | $X |
| Price at Day 180 | $X | $X | $X | $X | $X | $X |
| Price at Day 365 | $X | $X | $X | $X | $X | $X |
| Market Cap at Day 365 | $X | $X | $X | $X | $X | $X |
| Max Drawdown | X% | X% | X% | X% | X% | X% |
| Days to ATH | X | X | X | X | X | X |

## Price Trajectory Visualization

```
Price ($)
  |
  |    *  *                              P95
  |   * ** *   *  *
  |  *      * * ** *  *           *
  | *        *     * ** * *  *  **    P75
  |*                   *  ** *    * *
  |                          *     *  Median
  |                                   P25
  |*                                  P5
  |_________________________________________ Days
  0   30   60   90  120  150  180 ...  365
```

## Circulating Supply vs Price

[Show how unlock schedule impacts price in median scenario]

## Sell Pressure Analysis

| Time Period | Unlock Volume | Avg Daily Sell Pressure | Impact on Price |
|-------------|--------------|------------------------|-----------------|
| Days 1–30 | X tokens | $X/day | X% drag |
| Days 31–90 | X tokens | $X/day | X% drag |
| Days 91–180 | X tokens | $X/day | X% drag |
| Days 181–365 | X tokens | $X/day | X% drag |

## Failure Modes

| Failure Mode | Probability | Trigger | Consequence |
|-------------|------------|---------|-------------|
| Death spiral (<90% drawdown) | X% | Large unlock + bear market | Token goes to near-zero; no recovery |
| Liquidity crisis | X% | LP withdrawal + sell pressure | Unable to exit positions; price disconnect |
| Whale dump | X% | Single holder >5% sells | X% instant drawdown; recovery time: X days |
| Stagnation | X% | No catalyst, low utility | Price flatlines, community dies |

## Vesting Impact Analysis

| Unlock Event | Day | Tokens | % Supply | Avg Price Impact |
|-------------|-----|--------|----------|-----------------|
| TGE | 0 | X | X% | — |
| Investor cliff end | 365 | X | X% | -X% avg |
| Team cliff end | 365 | X | X% | -X% avg |
| [Next unlock] | X | X | X% | -X% avg |

## Recommendations

Based on simulation results:

1. [Specific recommendation with data backing]
2. [Specific recommendation with data backing]
3. ...

## Risk Metrics

| Metric | Value | Benchmark | Status |
|--------|-------|-----------|--------|
| Value at Risk (95%, 1yr) | -$X | — | — |
| Sharpe Ratio (projected) | X | >1.0 | ✅/❌ |
| Max Drawdown (median) | X% | <70% | ✅/❌ |
| Recovery Time (median) | X days | <90 days | ✅/❌ |
```

---

## Methodology Notes

### Assumptions
- All simulations assume rational market with some behavioral noise
- Sell pressure coefficients calibrated against historical Solana token launches (JTO, JUP, PYTH, W, BONK, WEN)
- Correlation with SOL price: 0.6 (tokens tend to follow SOL direction)
- Gas fees are negligible (Solana)
- No MEV rebalancing modeled (conservative assumption)

### Limitations
- Cannot predict black swan events (only model their probability)
- Social virality is stochastic and not predictable
- Regulatory changes not modeled
- Assumes DEX liquidity remains functional
- Historical calibration may not predict future behavior

### Calibration Data
Modeled against observed patterns from:
- JTO launch (Dec 2023): 117% first-day rally, -45% correction, recovery in 60 days
- JUP launch (Jan 2024): 300%+ first-week rally, significant volatility
- W launch (Apr 2024): Moderate initial performance, gradual decline
- PYTH launch (Nov 2023): Steady growth with governance catalysts
