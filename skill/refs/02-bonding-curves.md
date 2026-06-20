# Bonding Curves & Pricing Models

## Core Concepts

A bonding curve is a mathematical function that defines the relationship between a token's price and its supply. As tokens are bought, the price increases along the curve. As tokens are sold, the price decreases.

```
price = f(supply)
```

The area under the curve between two supply points represents the cost (in the reserve token) to move between those points.

---

## Constant Product (x * y = k)

The most widely used AMM formula. Pioneered by Uniswap, adopted by Raydium.

### Formula

```
x * y = k
```

Where:
- `x` = reserve of token A (e.g., SOL)
- `y` = reserve of token B (e.g., YOUR_TOKEN)
- `k` = constant (invariant)

### Price Derivation

```
price_A_in_B = y / x     (how many B per 1 A)
price_B_in_A = x / y     (how many A per 1 B)
```

### Trade Execution

Buying `Δx` of token A with token B:

```
(x + Δx) * (y - Δy) = k
Δy = y - k / (x + Δx)
Δy = y * Δx / (x + Δx)
```

### Price Impact

```
effective_price = Δy / Δx
spot_price = y / x
price_impact = 1 - (effective_price / spot_price)
```

For a trade of size `Δx`:

```
price_impact = Δx / (x + Δx)
```

**Example:** Pool has 100 SOL and 1,000,000 TOKEN.
- Buying 10 SOL worth: price_impact = 10 / (100 + 10) = 9.1%
- Buying 50 SOL worth: price_impact = 50 / (100 + 50) = 33.3%

### Python Simulation

```python
def constant_product_swap(x_reserve, y_reserve, dx):
    """Swap dx of token X for dy of token Y using x*y=k."""
    k = x_reserve * y_reserve
    new_x = x_reserve + dx
    new_y = k / new_x
    dy = y_reserve - new_y
    
    spot_price = y_reserve / x_reserve
    effective_price = dy / dx
    price_impact = 1 - (effective_price / spot_price)
    
    return {
        'dy': dy,
        'new_x': new_x,
        'new_y': new_y,
        'spot_price': spot_price,
        'effective_price': effective_price,
        'price_impact': price_impact,
        'fee': dx * 0.0025  # 0.25% fee typical
    }

# Example: 100 SOL / 1,000,000 TOKEN pool
result = constant_product_swap(100, 1_000_000, 10)
print(f"Tokens received: {result['dy']:.2f}")
print(f"Spot price: {result['spot_price']:.4f} TOKEN/SOL")
print(f"Effective price: {result['effective_price']:.4f} TOKEN/SOL")
print(f"Price impact: {result['price_impact']*100:.2f}%")
```

**Output:**
```
Tokens received: 90909.09
Spot price: 10000.0000 TOKEN/SOL
Effective price: 9090.9091 TOKEN/SOL
Price impact: 9.09%
```

---

## Constant Sum (x + y = k)

Linear pricing. No slippage, but can be fully drained.

### Formula

```
x + y = k
price = 1 (constant)
```

### Problem

One side of the pool can be completely drained. If SOL is worth more than the implied price, arbitrageurs will drain all the SOL.

### Use Case

Only useful when two tokens should trade 1:1 (stablecoin pairs). Not suitable for token launches.

---

## Logarithmic / Polynomial Curves

### Logarithmic

```
price(supply) = a * ln(supply) + b
```

Price increases slowly as supply grows. Early buyers get better prices, but the curve flattens — discouraging late speculation.

### Polynomial (Power Curve)

```
price(supply) = a * supply^b
```

Where `b > 1` gives an accelerating curve (convex), and `0 < b < 1` gives a decelerating curve (concave).

### Square Root Curve

```
price(supply) = a * sqrt(supply)
```

Used by some bonding curve launches. Moderate price increase, less extreme than linear.

---

## Bancor Formula

The original bonding curve formula from Bancor (2017).

```
price = supply / (CW * balance)
```

Where:
- `supply` = current token supply
- `balance` = reserve balance (in base token)
- `CW` = connector weight (0 to 1)

CW = 0.5 gives constant product behavior.
CW = 1 gives constant price (constant sum).
CW < 0.5 gives steeper price curves.

### Bancor Continuous Token Model

```
tokens_to_mint = supply * ((1 + reserve_paid / balance) ^ CW - 1)
```

---

## Bonding Curves on Solana

### pump.fun Model

pump.fun uses a virtual bonding curve that transitions to Raydium AMM.

**How it works:**

1. Token created on pump.fun with a virtual AMM (no real liquidity yet)
2. Virtual reserves: `virtual_SOL = 30 SOL`, `virtual_TOKEN = total_supply * 0.8`
3. Price follows constant product: `price = virtual_SOL / virtual_TOKEN`
4. When real SOL deposited reaches ~85 SOL → token "graduates"
5. Real liquidity is deposited to Raydium AMM
6. Virtual reserves concept: trades happen against virtual + real reserves

**Virtual vs Real Reserves:**

```
effective_reserve_sol = virtual_sol + real_sol_deposited
effective_reserve_token = virtual_token - tokens_sold

price = effective_reserve_sol / effective_reserve_token
```

The virtual reserves create an initial price floor and ensure the curve is liquid from the first trade.

### Raydium AMM

Standard constant product AMM. Pool creation requires both tokens:

```
Initial price = SOL_amount / TOKEN_amount
k = SOL_amount * TOKEN_amount
```

### Raydium CLMM

Concentrated liquidity. LPs provide liquidity within specific price ranges (ticks).

```
L = sqrt(x * y)  (liquidity within a tick)
price = y / x
```

---

## Price Impact Calculations

### Exact Formula (Constant Product)

For a buy of `dx` base tokens:

```
dy = y * dx / (x + dx)

price_impact = dx / (x + dx)
```

For a sell of `dy` quote tokens:

```
dx = x * dy / (y + dy)

price_impact = dy / (y + dy)
```

### With Fees

```
dx_after_fee = dx * (1 - fee_rate)
dy = y * dx_after_fee / (x + dx_after_fee)
```

### Slippage Tolerance

```
min_dy = dy * (1 - slippage_tolerance)

// If actual dy < min_dy, revert transaction
```

**Anchor instruction example:**

```rust
#[derive(Accounts)]
pub struct Swap<'info> {
    #[account(mut)]
    pub pool: Account<'info, Pool>,
    
    #[account(mut)]
    pub user_base: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub user_quote: Account<'info, TokenAccount>,
    
    pub user: Signer<'info>,
}

pub fn swap(ctx: Context<Swap>, amount_in: u64, minimum_out: u64) -> Result<()> {
    let pool = &ctx.accounts.pool;
    
    let reserve_in = pool.base_reserve;
    let reserve_out = pool.quote_reserve;
    
    let amount_in_after_fee = amount_in * 9975 / 10000; // 0.25% fee
    let amount_out = (reserve_out as u128)
        .checked_mul(amount_in_after_fee as u128).unwrap()
        .checked_div(
            (reserve_in as u128)
                .checked_add(amount_in_after_fee as u128).unwrap()
        ).unwrap() as u64;
    
    require!(amount_out >= minimum_out, SwapError::SlippageExceeded);
    
    // Execute transfers...
    Ok(())
}
```

---

## Graduation Mechanics

Bonding curves often "graduate" to a full DEX once sufficient liquidity is accumulated.

### pump.fun Graduation

```
Threshold: ~85 SOL in bonding curve
Action: Automatically creates Raydium AMM pool
Result: Tokens tradeable on Raydium, Jupiter, etc.
LP tokens: Burned (locked forever)
```

### Custom Graduation Logic

```rust
pub fn try_graduate(ctx: Context<Graduate>) -> Result<()> {
    let pool = &ctx.accounts.bonding_curve;
    
    require!(
        pool.real_sol_deposited >= pool.graduation_threshold,
        ErrorCode::NotEnoughLiquidity
    );
    
    // 1. Create Raydium/OpenBook market
    // 2. Create AMM pool with accumulated liquidity
    // 3. Deposit all SOL + remaining tokens
    // 4. Burn LP tokens
    // 5. Mark bonding curve as graduated
    
    pool.graduated = true;
    Ok(())
}
```

### Graduation Decision Table

| Parameter             | Value         | Rationale                           |
|-----------------------|---------------|-------------------------------------|
| Graduation threshold  | 85-100 SOL    | Minimum viable DEX liquidity        |
| LP burn %             | 100%          | Prevents rug pull                   |
| DEX target            | Raydium AMM   | Highest volume on Solana            |
| Market ID             | OpenBook      | Required for Raydium AMM            |

---

## Simulation: Full Bonding Curve Lifecycle

```python
import math

class BondingCurve:
    def __init__(self, virtual_sol=30, total_supply=1_000_000_000, 
                 graduation_sol=85):
        self.virtual_sol = virtual_sol
        self.real_sol = 0
        self.virtual_token = total_supply * 0.8
        self.total_supply = total_supply
        self.graduation_sol = graduation_sol
        self.graduated = False
    
    @property
    def price(self):
        """Price in SOL per token."""
        return (self.virtual_sol + self.real_sol) / self.virtual_token
    
    def buy(self, sol_amount):
        """Buy tokens with SOL. Returns tokens received."""
        if self.graduated:
            raise Exception("Curve graduated, use DEX")
        
        sol_after_fee = sol_amount * 0.99  # 1% fee
        
        # Constant product swap
        effective_sol = self.virtual_sol + self.real_sol
        effective_token = self.virtual_token
        
        k = effective_sol * effective_token
        new_sol = effective_sol + sol_after_fee
        new_token = k / new_sol
        tokens_out = effective_token - new_token
        
        self.real_sol += sol_amount
        self.virtual_token = new_token
        
        if self.real_sol >= self.graduation_sol:
            self.graduated = True
            print(f"🎓 GRADUATED at {self.real_sol:.2f} SOL!")
        
        return tokens_out
    
    def simulate_lifecycle(self, trades):
        """Simulate a series of buys."""
        print(f"Initial price: {self.price:.10f} SOL/token")
        print(f"Virtual SOL: {self.virtual_sol}, Real SOL: {self.real_sol}")
        print("-" * 60)
        
        for i, sol_amount in enumerate(trades):
            tokens = self.buy(sol_amount)
            print(f"Trade {i+1}: {sol_amount} SOL → {tokens:,.0f} tokens")
            print(f"  Price: {self.price:.10f} SOL/token")
            print(f"  Real SOL in curve: {self.real_sol:.2f}")
            if self.graduated:
                break

# Simulate
curve = BondingCurve(virtual_sol=30, graduation_sol=85)
trades = [0.1, 0.5, 1, 2, 5, 10, 15, 20, 30]
curve.simulate_lifecycle(trades)
```

---

## When to Use Which Curve

| Curve Type       | Best For                        | Slippage | Drain Risk | Complexity |
|------------------|---------------------------------|----------|------------|------------|
| Constant Product | General AMM, established tokens | Medium   | Low        | Low        |
| Constant Sum     | Stablecoin pairs only           | None     | **High**   | Low        |
| Logarithmic      | Fair launches, slow price growth| Low-Med  | Low        | Medium     |
| Polynomial       | Custom token economics          | Variable | Low        | Medium     |
| Bancor           | Reserve-backed tokens           | Variable | Low        | High       |
| Virtual Reserve  | Bonding curve launches (pump.fun)| Medium  | Low        | High       |

### Decision Tree

```
Is this a stablecoin pair?
  YES → Constant Sum (with fallback to constant product)
  NO  ↓

Is this a new token launch?
  YES → Do you want automatic DEX graduation?
    YES → Virtual Reserve bonding curve (pump.fun model)
    NO  → Constant product AMM with manual liquidity
  NO  ↓

Is this an existing token with volume?
  YES → Constant product AMM (Raydium) or CLMM (concentrated)
  NO  → Bonding curve with low virtual reserves
```
