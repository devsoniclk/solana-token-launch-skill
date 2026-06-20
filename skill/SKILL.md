# Token Launch Skill — Solana Tokenomics Design & Launch Strategy

> Production-grade skill for designing, simulating, and launching tokens on Solana. Covers tokenomics modeling, bonding curves, DEX liquidity, vesting, Token-2022 features, launch execution, and risk assessment.

## When to Load This Skill

- Designing token supply, distribution, or emission schedules
- Configuring bonding curves or pricing models
- Setting up Raydium CLMM / Orca Whirlpools / Meteora DLMM liquidity
- Modeling vesting schedules for teams, investors, or community
- Planning a token launch (memecoin, utility token, governance token)
- Evaluating Token-2022 extensions (transfer fees, confidential transfers, etc.)
- Assessing launch risks (MEV, sniping, rug-pull optics, regulatory)
- Auditing an existing tokenomics design for flaws

## Routing

Load the module(s) relevant to your task. Do not load everything at once.

| Task | Load |
|------|------|
| Token supply & distribution design | `refs/01-supply-design.md` |
| Bonding curve math & modeling | `refs/02-bonding-curves.md` |
| DEX liquidity configuration | `refs/03-liquidity-setup.md` |
| Vesting schedules & lockups | `refs/04-vesting.md` |
| Token-2022 extensions | `refs/05-token2022.md` |
| Launch day execution plan | `refs/06-launch-strategy.md` |
| Risk assessment & red flags | `refs/07-risk-assessment.md` |
| Reference smart contract code | `refs/08-contract-templates.md` |
| SPL Token deployment | `refs/09-spl-deployment.md` |
| Meteora dynamic pools | `refs/10-meteora-pools.md` |

## Quick Start

For a full token launch from scratch, load in this order:
1. `refs/01-supply-design.md` — decide supply and distribution
2. `refs/02-bonding-curves.md` — model pricing mechanics
3. `refs/03-liquidity-setup.md` — configure DEX pools
4. `refs/04-vesting.md` — design team/investor lockups
5. `refs/06-launch-strategy.md` — plan launch day execution
6. `refs/07-risk-assessment.md` — audit the full design

For a quick memecoin launch:
1. `refs/01-supply-design.md` — pick supply model
2. `refs/09-spl-deployment.md` — deploy the token
3. `refs/03-liquidity-setup.md` — seed a Raydium/Meteora pool

## Agents

- `agents/tokenomics-reviewer.md` — Reviews a tokenomics design for flaws, game-theoretic attacks, and common mistakes
- `agents/launch-readiness.md` — Pre-flight checklist: is this token launch actually ready?

## Commands

- `commands/design-token.md` — Interactive tokenomics design workflow
- `commands/simulate-launch.md` — Monte Carlo simulation of launch scenarios

## Key Principles

1. **No supply inflation without explicit governance** — emission schedules must be defensible
2. **Liquidity before hype** — always seed DEX pools before any marketing
3. **Vesting is non-negotiable** — team/investor tokens must be locked on-chain
4. **MEV protection matters** — sandwich attacks kill launches on day 1
5. **Token-2022 is the default** — use legacy SPL Token only for backward compatibility
6. **Test on devnet first** — never deploy untested tokenomics to mainnet

## Ecosystem References

- Solana SPL Token: https://spl.solana.com/token
- Token-2022: https://spl.solana.com/token-2022
- Raydium CLMM: https://docs.raydium.io
- Orca Whirlpools: https://orca-so.gitbook.io
- Meteora DLMM: https://docs.meteora.ag
- Jupiter: https://docs.jup.ag
- Metaplex Token Metadata: https://developers.metaplex.com
