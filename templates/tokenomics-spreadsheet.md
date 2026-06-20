# Tokenomics Allocation Template

Fill in this template to define your token's distribution. Once complete, feed it to the `tokenomics-reviewer` agent for scoring and feedback.

---

## Basic Information

| Field | Value |
|-------|-------|
| **Project Name** | |
| **Token Ticker** | |
| **Total Supply** | |
| **Token Standard** | SPL / Token-2022 |
| **Decimals** | 6 (standard) / 9 (human-readable) |
| **Supply Type** | Fixed / Inflationary / Deflationary |
| **Mint Authority** | Revoked / Multisig / Program |

---

## Distribution Allocation

> Fill in the `%` column. All rows must sum to 100%.

| # | Category | % | Tokens | Description / Purpose |
|---|----------|---|--------|----------------------|
| 1 | Community / Airdrop | ___% | | Early users, testnet participants, community rewards |
| 2 | Ecosystem / Growth | ___% | | Grants, developer incentives, integrations, partnerships |
| 3 | Staking Rewards | ___% | | Staking emissions for validators/stakers |
| 4 | Team | ___% | | Founders, core contributors, early employees |
| 5 | Investors / Advisors | ___% | | Seed, Series A, strategic angels |
| 6 | Treasury / DAO | ___% | | Governance-controlled reserves, insurance fund |
| 7 | Liquidity | ___% | | DEX pool seeding, market making |
| 8 | Marketing | ___% | | KOL campaigns, airdrops 2.0, community incentives |
| 9 | [Custom] | ___% | | |
| 10 | [Custom] | ___% | | |
| | **TOTAL** | **100%** | | |

### Typical Ranges (Reference)

| Category | Typical Range | Notes |
|----------|--------------|-------|
| Community / Airdrop | 20–50% | Higher = more decentralized; JUP did 40% |
| Ecosystem / Growth | 10–25% | Essential for long-term developer ecosystem |
| Staking Rewards | 5–20% | Depends on inflation model and emission schedule |
| Team | 5–20% | Should always be locked; 10–15% is common |
| Investors / Advisors | 5–20% | VC-backed projects tend toward 15–20% |
| Treasury / DAO | 5–15% | Insurance fund + future governance proposals |
| Liquidity | 3–15% | Minimum 5% for credibility; can go higher |
| Marketing | 0–10% | Vague allocation; better to fold into community |

---

## Vesting Schedule

> For each category, define when tokens unlock. Categories with 100% at TGE can skip this.

| # | Category | Total Tokens | TGE Unlock % | TGE Tokens | Cliff (months) | Vesting Duration (months) | Unlock Frequency | Revocable? |
|---|----------|-------------|-------------|-----------|----------------|--------------------------|-----------------|-----------|
| 1 | Community / Airdrop | | ___% | | | | Monthly / Quarterly / Linear | Yes / No |
| 2 | Ecosystem / Growth | | ___% | | | | Monthly / Quarterly / Linear | Yes / No |
| 3 | Staking Rewards | | ___% | | | | Continuous emissions | N/A |
| 4 | Team | | ___% | | | | Monthly / Quarterly / Linear | Yes / No |
| 5 | Investors / Advisors | | ___% | | | | Monthly / Quarterly / Linear | Yes / No |
| 6 | Treasury / DAO | | ___% | | | | Governance-voted | N/A |
| 7 | Liquidity | | ___% | | | | N/A (locked) | No |
| 8 | Marketing | | ___% | | | | Monthly / Quarterly / Linear | Yes / No |

### Vesting Best Practices

| Category | Recommended TGE | Recommended Cliff | Recommended Vest |
|----------|----------------|-------------------|-----------------|
| Team | 0% | 12 months | 36–48 months |
| Investors | 0–5% | 6–12 months | 24–36 months |
| Advisors | 0% | 6–12 months | 24–36 months |
| Community | 50–100% | None | 0–6 months |
| Ecosystem | 0–10% | 3–6 months | 24–48 months |
| Marketing | 0–25% | None | 3–6 months |

### Vesting Timeline (24-Month View)

Mark when major unlocks happen:

| Month | Event | Tokens Unlocking | Cumulative Circulating |
|-------|-------|-----------------|----------------------|
| 0 | TGE (Token Generation Event) | | |
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 6 | | | |
| 9 | | | |
| 12 | | | |
| 18 | | | |
| 24 | | | |

---

## Utility & Value Accrual

> Check all that apply and describe how the token is used.

### Token Utility

| Utility | Yes/No | Description |
|---------|--------|-------------|
| Governance voting | | Vote on protocol parameters, treasury spending, upgrades |
| Staking (yield) | | Stake tokens to earn protocol revenue or emissions |
| Fee payment | | Pay platform fees in token (with/without discount) |
| Access rights | | Premium features, gated content, tiered access |
| Collateral | | Use as collateral in lending/borrowing |
| Revenue sharing | | Direct fee distribution to holders/stakers |
| Burn mechanism | | Token burns reducing supply over time |
| Memetic / cultural | | Community value, memes, social signaling |
| [Custom] | | |

### Demand Sinks

> What mechanisms create buying pressure or reduce selling pressure?

| Sink Type | Description | Estimated Impact |
|-----------|-------------|-----------------|
| Protocol fees | Fees paid in token or buyback from revenue | $___/month projected |
| Staking lock | Tokens locked reducing circulating supply | ___% of supply locked |
| Buyback and burn | Protocol buys and burns tokens | $___/month projected |
| Required for operation | Token needed to use protocol features | ___ users projected |
| [Custom] | | |

---

## Launch Mechanics

| Field | Value |
|-------|-------|
| **Launch Method** | Airdrop / IDO / LBP / Fair Launch / CEX Listing / Combination |
| **Target Initial Market Cap** | $___ |
| **Target Initial FDV** | $___ |
| **Target DEX** | Raydium / Meteora / Orca / Jupiter / Other |
| **Initial Liquidity (USD)** | $___ |
| **LP Lock Duration** | ___ months / Burned |
| **Airdrop Eligibility** | Describe criteria |
| **Airdrop Sybil Resistance** | Describe mechanism |

---

## Inflation / Emissions Schedule (if applicable)

> Only fill this if your token is inflationary.

| Year | Emission Rate | New Tokens | Cumulative Supply | Inflation % |
|------|--------------|------------|-------------------|-------------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5+ | | | | |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Concentration (whale dump) | Low / Med / High | Low / Med / High | |
| Smart contract exploit | Low / Med / High | Low / Med / High | |
| Regulatory classification | Low / Med / High | Low / Med / High | |
| Oracle manipulation | Low / Med / High | Low / Med / High | |
| MEV / sandwich attacks | Low / Med / High | Low / Med / High | |
| Community exodus | Low / Med / High | Low / Med / High | |
| Liquidity crisis | Low / Med / High | Low / Med / High | |

---

## Summary Statistics

> Calculate after filling in the template.

| Metric | Value |
|--------|-------|
| Total Supply | |
| TGE Circulating Supply | |
| TGE Circulating % | |
| Insider Allocation (Team + Investors + Advisors) | |
| Community Allocation | |
| FDV at Target Price | |
| Initial Market Cap | |
| First Major Unlock (date + amount) | |
| Months to Full Circulation | |

---

## Notes

_Add any additional context, design rationale, or open questions here:_

---

## Checklist Before Review

- [ ] All allocation percentages sum to 100%
- [ ] TGE circulating supply is calculated
- [ ] Vesting schedules are defined for all locked categories
- [ ] Utility is clearly described (not just "governance")
- [ ] Demand sinks exist to offset inflation/unlocks
- [ ] Launch method is chosen and feasible
- [ ] Risk assessment is completed
- [ ] Run through `tokenomics-reviewer` agent
