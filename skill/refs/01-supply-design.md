# Token Supply & Distribution Design

## Supply Models

### Fixed Supply

Most Solana tokens use fixed supply. The mint authority is revoked after creation — no new tokens can ever be minted.

```
Total supply: 1,000,000,000 (1B)
Mint authority: REVOKED
Freeze authority: REVOKED (or retained for compliance)
```

**When to use:** Governance tokens, meme tokens, utility tokens with predictable demand.

### Inflationary Supply

New tokens are minted on a schedule. Requires retaining mint authority (centralization risk).

```
Initial supply: 100,000,000
Annual inflation: 5% (compounding) or fixed amount
Inflation cap: Optional hard cap after N years
```

**When to use:** Staking rewards, protocol revenue sharing, dynamic ecosystems. SOL itself is inflationary (~5.2% initial, declining 15% annually toward 1.5% terminal rate).

### Deflationary Supply

Tokens are burned on transactions, reducing circulating supply over time.

```
Mechanism: X% of each transfer burned
Example: 2% burn on every transfer
Net effect: Supply decreases with usage velocity
```

**When to use:** Store-of-value narratives, fee-burning protocols (EIP-1559 model).

---

## Supply Sizing Heuristics

| Supply     | Reasoning                                                       | Example           |
|------------|-----------------------------------------------------------------|-------------------|
| 1,000 (1K) | NFTs, governance seats, limited membership tokens               | —                 |
| 1,000,000 (1M) | Small-cap utility, protocol tokens                        | Early DeFi tokens |
| 1,000,000,000 (1B) | **Standard** for most SPL tokens. Clean numbers, fits in u64 | BONK, WIF        |
| 10,000,000,000 (10B) | Meme tokens, high-velocity utility                   | —                 |
| 1,000,000,000,000 (1T) | Meme tokens (psychological: "cheap per token")    | SHIB, PEPE (ETH) |

**Why 1B is the default:** Fits comfortably in u64 (max 18.4 quintillion), allows 6 decimal places without overflow, feels "substantial" in unit terms, easy to reason about percentages.

**Supply × Price = Market Cap.** A 1B supply at $0.01 = $10M market cap. A 1T supply at $0.000001 = $1M market cap. Same FDV, different psychology.

---

## Decimal Places

| Token Program | Decimals | Smallest Unit           | Use Case           |
|---------------|----------|-------------------------|-------------------|
| SPL Token     | **6**    | 0.000001 (1 lamport)    | Standard Solana    |
| SPL Token     | 9        | 0.000000001             | ETH compatibility  |
| SPL Token     | 0        | 1 (whole tokens only)   | Governance seats   |
| Token-2022    | 0-9      | Varies                  | Any of the above   |

**Rule:** Use 6 decimals for Solana-native tokens. Use 9 only if cross-chain bridging to Ethereum is planned. Using 9 decimals on Solana adds unnecessary compute for no benefit in most cases.

```bash
# Create mint with 6 decimals
spl-token create-token --decimals 6

# Create mint with 9 decimals (ETH compat)
spl-token create-token --decimals 9
```

---

## Distribution Allocations

### Standard Allocation Table

| Allocation      | Typical % | Vesting                  | Notes                              |
|-----------------|-----------|--------------------------|------------------------------------|
| Public sale     | 20-40%    | None or short cliff      | Price discovery, wide distribution |
| Liquidity       | 10-20%    | Locked 1-2 years         | DEX pool seeding                   |
| Team            | 10-20%    | 12mo cliff + 36mo linear | Retention, credibility             |
| Investors/SAFT  | 10-20%    | 6mo cliff + 18mo linear  | Seed/private/strategic rounds      |
| Treasury/DAO    | 10-20%    | Governance-controlled    | Long-term protocol development     |
| Ecosystem/Growth| 5-15%     | Milestone-based          | Grants, incentives, partnerships   |
| Community/Airdrop| 5-10%    | Immediate or vesting     | Awareness, decentralization        |

### Example: 1B Token Supply

```
Public sale:      300,000,000 (30%)
Liquidity:        150,000,000 (15%) — locked 2 years
Team:             150,000,000 (15%) — 12mo cliff + 36mo linear
Investors:        100,000,000 (10%) — 6mo cliff + 18mo linear
Treasury:         150,000,000 (15%) — DAO-controlled
Ecosystem:        100,000,000 (10%) — milestone unlocks
Airdrop:           50,000,000 ( 5%) — immediate
```

---

## Emission Schedules

### Linear Emission

```
emitted(t) = total_allocation / vesting_duration * t
```

Tokens unlock at a constant rate. Simple, predictable.

### Halving Emission (Bitcoin-style)

```
emitted(block) = initial_reward / 2^(halving_count)
halving_count = floor(block / halving_interval)
```

Front-loads rewards, creates scarcity narrative.

### Exponential Decay

```
emitted(t) = initial_rate * e^(-λt)
```

Where λ = decay constant. Smooth curve, never truly reaches zero.

### Graded (Stepped) Emission

```
Year 1: 25% of allocation
Year 2: 25% of allocation
Year 3: 25% of allocation
Year 4: 25% of allocation
```

Simple quarterly or annual unlocks.

---

## Buyback-and-Burn Mechanics

**How it works:** Protocol uses revenue to buy tokens on open market → sends to burn address → reduces circulating supply.

```
Burn address: 11111111111111111111111111111111 (system program)
or: use spl-token burn instruction
```

```bash
# Burn tokens from your account
spl-token burn <TOKEN_ACCOUNT> <AMOUNT>
```

**Implementation options:**
1. **Manual burn:** Team buys and burns quarterly (centralized, verifiable)
2. **Auto-burn on transactions:** Token-2022 transfer fee → fee recipient → auto-burn
3. **Smart contract burn:** Program burns % of each interaction

**Key metric:** Burn rate vs issuance rate. Net deflationary when burns > emissions.

---

## Anti-Whale Mechanisms

| Mechanism          | Token-2022 Extension    | Effect                                |
|--------------------|-------------------------|---------------------------------------|
| Max wallet holding | Custom (transfer hook)  | No wallet can hold > X% of supply     |
| Max transaction    | Custom (transfer hook)  | No single transfer > X tokens         |
| Cooldown period    | Custom (transfer hook)  | Minimum time between buys             |
| Graduated tax      | Transfer fee + hook     | Higher tax on larger transactions     |

**Implementation with Token-2022 Transfer Hook:**

```rust
// Anchor program: enforce max wallet
fn transfer_hook(ctx: Context<Transfer>, amount: u64) -> Result<()> {
    let dest_balance = ctx.accounts.destination.amount;
    let max_wallet = 10_000_000 * 10u64.pow(6); // 1% of 1B supply
    
    require!(
        dest_balance + amount <= max_wallet,
        TransferHookError::ExceedsMaxWallet
    );
    Ok(())
}
```

**Gotcha:** Max wallet can be bypassed via multiple wallets. It deters casual whales but not determined ones.

---

## Token Utility Design Patterns

| Pattern         | Mechanism                        | Example                |
|-----------------|----------------------------------|------------------------|
| Governance      | Vote on proposals, weighted by holdings | JUP, Marinade     |
| Staking         | Lock tokens → earn yield/fees    | mSOL, JTO              |
| Fee discount    | Hold token → reduced protocol fees | —                     |
| Access/Paywall  | Hold N tokens → unlock features  | Premium tiers          |
| Revenue share   | Stakers receive protocol revenue | veTOKEN models         |
| Collateral      | Use as backing in DeFi protocols | LP positions           |
| Burn-to-access  | Burn tokens to mint NFT/access   | Deflationary + utility |

**ve-Token model (vote-escrowed):**
- Lock tokens for 1-4 years
- Longer lock = more voting power + higher yield
- Inspired by Curve's veCRV, adapted on Solana via governance programs

---

## Common Mistakes

1. **Too much supply unlocked at TGE (>30%).** Leads to immediate sell pressure.
2. **No liquidity allocation.** Token can't be traded.
3. **Team tokens with no vesting.** Red flag for every serious investor.
4. **Over-complicated emission schedule.** If you can't explain it in one sentence, simplify.
5. **Deflationary + inflationary simultaneously.** Conflicting narratives.
6. **Using 0 decimals for a tradeable token.** Breaks DeFi composability.
7. **Retaining mint authority indefinitely.** Centralization risk.
8. **No treasury allocation.** No runway for development.
9. **Airdropping to non-users.** Mercenary capital dumps immediately.
10. **Ignoring Token-2022 extensions.** You're leaving functionality on the table.

---

## Decision Framework

### Step 1: Choose Supply Model

| Question                                | Fixed | Inflationary | Deflationary |
|-----------------------------------------|-------|--------------|--------------|
| Do you need ongoing emissions?          | No    | **Yes**      | No           |
| Is the token primarily a store of value?| **Yes** | No        | **Yes**      |
| Does the protocol earn revenue?         | —     | —            | **Yes** (burn)|
| Default choice for new projects         | **✓** |              |              |

### Step 2: Choose Supply Size

| Market Cap Target | Suggested Supply | Price Point     |
|-------------------|------------------|-----------------|
| $1M - $10M        | 100M - 1B        | $0.01 - $0.10   |
| $10M - $100M      | 1B               | $0.01 - $0.10   |
| $100M+            | 1B - 10B         | $0.01 - $0.10   |
| Meme token        | 1T               | $0.000001 range  |

### Step 3: Choose Decimals

| Condition                          | Decimals |
|------------------------------------|----------|
| Solana-native, no cross-chain plan | 6        |
| Cross-chain to Ethereum planned    | 9        |
| Whole-unit governance/membership   | 0        |

### Step 4: Allocate Distribution

| Priority                      | Allocate To         |
|-------------------------------|---------------------|
| Need deep liquidity           | 20%+ to LP          |
| Building community first      | 25%+ to airdrop     |
| Fundraising needed            | 15-20% to investors |
| Long-term development         | 20%+ to treasury    |
| Team retention critical       | 15-20% to team      |
