# 07 — Risk Assessment & Red Flags

## Tokenomics Red Flags Checklist

| Red Flag | Severity | Description |
|----------|----------|-------------|
| Team allocation > 20% | 🔴 Critical | Excessive insider control |
| No vesting on team tokens | 🔴 Critical | Immediate dump risk |
| Single wallet holds > 10% | 🟠 High | Whale manipulation risk |
| No lock on liquidity | 🔴 Critical | Rug-pull vector |
| Unlimited mint authority | 🔴 Critical | Infinite supply dilution |
| Transaction tax > 5% | 🟠 High | Punishes trading, enables extraction |
| Anti-whale with team exemption | 🔴 Critical | Hypocritical centralization |
| Rebasing/elastic supply | 🟡 Medium | Complex, hard to value |
| No clear utility or value accrual | 🟡 Medium | Unsustainable tokenomics |
| Vague "burn" mechanics | 🟡 Medium | Often used to hide inflation |

### Scoring Tokenomics (0-20 points)

```
Team allocation:
  < 10% = 5 pts
  10-20% with vesting = 4 pts
  10-20% no vesting = 1 pt
  > 20% = 0 pts

Supply distribution:
  Top 10 wallets < 30% = 5 pts
  Top 10 wallets 30-50% = 3 pts
  Top 10 wallets > 50% = 0 pts

Vesting schedule:
  All allocations vested 12+ months = 5 pts
  Partial vesting = 3 pts
  No vesting = 0 pts

Value accrual mechanism:
  Clear buyback/burn or fee sharing = 5 pts
  Unclear mechanism = 2 pts
  No mechanism = 0 pts
```

---

## Smart Contract Risks

### Authority Risks (Solana-Specific)

| Authority | Risk if Retained | Recommendation |
|-----------|-----------------|----------------|
| Mint authority | Can create unlimited tokens | Revoke after initial mint |
| Freeze authority | Can freeze any token account | Revoke for trustless tokens |
| Update authority (metadata) | Can change token name/symbol/URI | Revoke or transfer to multisig |
| Upgrade authority (programs) | Can change program logic | Transfer to multisig with timelock |

### Checking Authorities (CLI)

```bash
# Check mint authorities
spl-token display <MINT_ADDRESS>

# Expected output for safe token:
# Mint authority: (not set)
# Freeze authority: (not set)

# Check metadata authority
metaplex show <MINT_ADDRESS>
# Look for: Update Authority
```

### Risk Scoring (0-20 points)

```
Mint authority revoked = 8 pts | retained = 0 pts
Freeze authority revoked = 6 pts | retained = 0 pts
Metadata authority revoked = 3 pts | multisig = 2 pts | single-sig = 0 pts
Upgrade authority (if applicable):
  Multisig + timelock = 3 pts | multisig = 2 pts | single-sig = 0 pts
```

---

## Liquidity Risks

### LP Lock Analysis

| LP Status | Risk Level | Description |
|-----------|-----------|-------------|
| LP burned (>99%) | 🟢 Low | Cannot be withdrawn |
| LP locked 12+ months | 🟡 Medium | Temporary protection |
| LP locked < 12 months | 🟠 High | Short lock = planned exit |
| LP unlocked | 🔴 Critical | Instant rug possible |
| Single-sided LP only | 🔴 Critical | No depth on one side |

### Liquidity Depth Metrics

```
Healthy liquidity:
  - 1 SOL trade has < 1% price impact
  - Pool has > 100 SOL total value
  - Liquidity distributed across ±20% price range

Dangerous liquidity:
  - 1 SOL trade has > 5% price impact
  - Pool has < 10 SOL total value
  - All liquidity at single price point
```

### Risk Scoring (0-20 points)

```
LP status:
  Burned = 8 pts
  Locked 12+ months = 6 pts
  Locked 3-12 months = 3 pts
  Unlocked = 0 pts

Liquidity depth:
  > 500 SOL = 6 pts
  100-500 SOL = 4 pts
  10-100 SOL = 2 pts
  < 10 SOL = 0 pts

Price impact (1 SOL trade):
  < 0.5% = 6 pts
  0.5-2% = 4 pts
  2-5% = 2 pts
  > 5% = 0 pts
```

---

## MEV / Sandwich Attack Vectors

### Attack Types on Solana

| Attack | Mechanism | Impact |
|--------|-----------|--------|
| Sandwich attack | Bot buys before + sells after your trade | 1-15% value extraction |
| Front-running | Bot copies your trade, pays higher priority | Worse fill price |
| Back-running | Bot trades after your trade to capture arbitrage | Minimal direct impact |
| JIT liquidity | Bot adds/removes liquidity around your trade | Reduced slippage efficiency |
| Time-bandit | Validator reorders blocks for profit | Rare on Solana but possible |

### Protection Strategies

```
1. Use Jito bundles for large trades (sandwich-proof)
2. Set tight slippage tolerance (0.5-1% for liquid pairs)
3. Split large trades across multiple transactions
4. Use Jupiter's split-route optimization
5. Trade during low-congestion periods
6. For launches: bundle all LP operations
```

### Risk Scoring (0-10 points)

```
Launch uses Jito bundles = 4 pts
Slippage protection configured = 2 pts
Trade splitting implemented = 2 pts
MEV-aware routing (Jupiter) = 2 pts
```

---

## Rug-Pull Patterns

### Common Rug Types on Solana

| Type | Mechanism | Red Flag Signs |
|------|-----------|----------------|
| Liquidity pull | Remove all LP tokens | LP not burned/locked |
| Mint rug | Mint billions of new tokens | Mint authority not revoked |
| Freeze rug | Freeze all accounts, demand payment | Freeze authority retained |
| Slow rug | Team sells gradually over weeks | Large team wallets, no vesting |
| Honeypot | Code prevents selling (Token-2022 hooks) | Unusual extensions on mint |
| Social rug | Abandon project after raising funds | Anonymous team, no roadmap updates |
| Migration rug | Fake "upgrade" drains user funds | Unverified migration contracts |

### Detection Checklist

```typescript
async function assessRugRisk(mintAddress: string): Promise<RugAssessment> {
  const mintInfo = await getMint(connection, new PublicKey(mintAddress));

  const flags: string[] = [];

  // Check mint authority
  if (mintInfo.mintAuthority) flags.push("MINT_AUTHORITY_ACTIVE");

  // Check freeze authority
  if (mintInfo.freezeAuthority) flags.push("FREEZE_AUTHORITY_ACTIVE");

  // Check supply concentration
  const largestHolders = await getLargestHolders(mintAddress, 10);
  const top10Percent = largestHolders.reduce((sum, h) => sum + h.percent, 0);
  if (top10Percent > 50) flags.push(`TOP10_HOLD_${top10Percent.toFixed(1)}%`);

  // Check LP lock status
  const lpInfo = await getLPInfo(mintAddress);
  if (!lpInfo.locked) flags.push("LP_UNLOCKED");

  return {
    score: calculateSafetyScore(flags),
    flags,
    recommendation: flags.length > 2 ? "HIGH_RISK" : flags.length > 0 ? "MEDIUM_RISK" : "LOW_RISK",
  };
}
```

---

## Regulatory Considerations

### SEC (United States)

| Factor | Security (Howey Test) | Not a Security |
|--------|----------------------|----------------|
| Investment of money | ✅ Token sale | ❌ Airdrop/utility |
| Common enterprise | ✅ Team-driven | ❌ Decentralized |
| Expectation of profit | ✅ Marketing profits | ❌ Pure utility |
| Efforts of others | ✅ Team delivers | ❌ Community-driven |

**Practical guidance**: If your token sale promises returns, has a central team driving value, and buyers expect profit — it likely qualifies as a security. Structure accordingly or limit to non-US participants.

### MiCA (European Union)

- Applies to all crypto-assets offered in the EU
- Requires a whitepaper filed with national authority
- Stablecoins (ARTs/EMTs) have stricter requirements
- Utility tokens with no profit mechanism have lighter requirements
- In force since June 2024, full enforcement from December 2024

### Risk Scoring (0-10 points)

```
No profit promises in marketing = 3 pts
KYC/AML for token sale participants = 2 pts
Legal opinion obtained = 2 pts
Jurisdiction analysis documented = 2 pts
Terms of service with disclaimers = 1 pt
```

---

## Game-Theoretic Attacks

### Vampire Attacks

**Mechanism**: Competitor forks your protocol, offers higher incentives to drain your liquidity.

**Defenses**:
- Strong brand and community moat
- Token lockup incentives (vote-escrowed models)
- Continuous innovation velocity
- Exclusive integrations

### Governance Capture

**Mechanism**: Attacker accumulates governance tokens to pass malicious proposals.

**Defenses**:
- Quorum requirements (> 30% participation)
- Timelock on execution (48-72 hours)
- Guardian multisig with veto power
- Quadratic voting

### Oracle Manipulation

**Mechanism**: Attacker manipulates price oracle to extract value from lending/derivatives.

**Defenses**:
- Use TWAP oracles, not spot prices
- Multiple oracle sources (Pyth + Switchboard)
- Circuit breakers on large price movements
- Maximum oracle deviation checks

---

## Scoring Rubric: Rate a Token Launch 1-100

| Category | Max Points | Assessment |
|----------|-----------|------------|
| Tokenomics design | 20 | Supply, distribution, vesting, utility |
| Smart contract safety | 20 | Authorities, audit, upgradeability |
| Liquidity security | 20 | LP lock, depth, multi-DEX |
| MEV protection | 10 | Bundles, slippage, routing |
| Regulatory posture | 10 | Legal compliance, disclaimers |
| Team transparency | 10 | Doxxed, track record, multisig |
| Community health | 10 | Organic growth, engagement quality |

### Rating Scale

| Score | Rating | Meaning |
|-------|--------|---------|
| 90-100 | 🟢 Excellent | Institutional-grade launch |
| 70-89 | 🟢 Good | Solid launch, minor improvements needed |
| 50-69 | 🟡 Fair | Several risks present, proceed with caution |
| 30-49 | 🟠 Poor | Significant red flags, high risk |
| 0-29 | 🔴 Dangerous | Multiple critical issues, likely scam |

---

## Common Launch Failure Modes

| Failure | Cause | Prevention |
|---------|-------|------------|
| Zero volume | No marketing, bad timing | Pre-build community, launch during active hours |
| Instant dump | Whale/sniper accumulation | Jito bundles, anti-sniper measures |
| Smart contract bug | Untested edge cases | Devnet testing, audit |
| RPC failure | Network congestion | Multiple RPC endpoints |
| Wrong price | Calculation error | Dry-run with real numbers |
| Metadata not showing | URI not uploaded | Upload metadata 24h+ before launch |
| Pool not found on Jupiter | Insufficient liquidity | Minimum 50 SOL liquidity |
| Community FUD | Poor communication | Pre-written responses, active mods |

---

## Post-Launch Risk Monitoring

### Automated Monitoring (run every 5 minutes)

```typescript
const ALERT_THRESHOLDS = {
  priceDrop1h: -20,      // Alert if price drops > 20% in 1 hour
  volumeDrop4h: -80,     // Alert if volume drops > 80% vs prior 4h
  holderGrowthRate: -10, // Alert if net holders decrease by 10
  topHolderPercent: 25,  // Alert if any single wallet > 25%
  liquidityDrain: -30,   // Alert if liquidity drops > 30%
};

async function monitorRisk(mint: string) {
  const [price, volume, holders, topHolder, liquidity] = await Promise.all([
    getPriceChange(mint, "1h"),
    getVolumeChange(mint, "4h"),
    getHolderChange(mint),
    getTopHolderPercent(mint),
    getLiquidityChange(mint),
  ]);

  const alerts: string[] = [];
  if (price < ALERT_THRESHOLDS.priceDrop1h)
    alerts.push(`🔴 Price dropped ${price}% in 1h`);
  if (volume < ALERT_THRESHOLDS.volumeDrop4h)
    alerts.push(`🟠 Volume dropped ${volume}% in 4h`);
  if (holders < ALERT_THRESHOLDS.holderGrowthRate)
    alerts.push(`🟡 Net ${holders} holders in last period`);
  if (topHolder > ALERT_THRESHOLDS.topHolderPercent)
    alerts.push(`🔴 Top holder owns ${topHolder}%`);
  if (liquidity < ALERT_THRESHOLDS.liquidityDrain)
    alerts.push(`🔴 Liquidity dropped ${liquidity}%`);

  if (alerts.length > 0) {
    await sendAlert(alerts);
  }
}
```

### Daily Risk Report Template

```
📊 Daily Risk Report — $TOKEN
Date: YYYY-MM-DD

Price: $X.XX (24h: +/-X%)
Volume: $XXX,XXX (24h)
Holders: X,XXX (24h: +/-XX)
Liquidity: $XXX,XXX

Risk Flags: [none / list active flags]
Score: XX/100 (previous: XX/100)

Action Items: [any required interventions]
```
