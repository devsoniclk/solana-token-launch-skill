# Vesting Schedules & Lockups

## Vesting Types

### Cliff Vesting

No tokens unlock until the cliff date. Then 100% unlocks at once.

```
Timeline: |------ cliff ------| tokens unlock
Example:  |----- 12 months ----|→ 100% available
```

**Use case:** Short-term contributor rewards, grant milestones.

### Linear Vesting

Tokens unlock continuously over time after the cliff.

```
Unlocked(t) = total * (t - cliff) / (duration - cliff)  for t >= cliff
Unlocked(t) = 0                                           for t < cliff
```

```
Timeline: |cliff|===================================|
              0%  | 1% → 2% → 3% → ... → 100%
```

**Use case:** Team, investors, long-term allocations.

### Graded (Stepped) Vesting

Tokens unlock in discrete chunks at fixed intervals.

```
Timeline: |-- 6mo --|-- 6mo --|-- 6mo --|-- 6mo --|
          0%        25%       50%       75%       100%
```

**Use case:** Quarterly unlocks for investors, milestone-based ecosystem funding.

---

## Common Vesting Schedules by Allocation

| Allocation    | Cliff     | Vesting Duration | TGE Unlock | Rationale                    |
|---------------|-----------|-----------------|------------|------------------------------|
| Team          | 12 months | 48 months total | 0%         | Long-term alignment          |
| Seed investors| 12 months | 36 months total | 0-5%       | Earliest risk, longest lock  |
| Private sale  | 6 months  | 24 months total | 10-15%     | Medium risk, medium lock     |
| Strategic     | 3 months  | 18 months total | 15-20%     | Partners, short lock         |
| Public sale   | None      | 0-6 months      | 50-100%    | Price discovery, fairness    |
| Community     | None      | 48 months       | 10-20%     | Gradual distribution         |
| Ecosystem     | None      | Milestone-based | 0-10%      | Pay for results              |
| Treasury      | N/A       | Governance-controlled | 0%    | DAO decides                  |

### Example: 1B Token Supply

```
Team (15% = 150M):
  TGE: 0 tokens
  Cliff: 12 months
  Vesting: 36 months linear after cliff
  Monthly unlock after cliff: 150M / 36 = 4.17M/month

Investors (10% = 100M):
  TGE: 10M (10%)
  Cliff: 6 months
  Vesting: 18 months linear after cliff
  Monthly unlock after cliff: 90M / 18 = 5M/month

Community (5% = 50M):
  TGE: 5M (10%)
  Cliff: 0
  Vesting: 48 months linear
  Monthly unlock: 45M / 48 = 937,500/month
```

---

## On-Chain Vesting Solutions

### Streamflow (Recommended)

The most popular vesting/streaming protocol on Solana.

```typescript
import { StreamClient } from "@streamflow/stream";

const streamClient = new StreamClient(
  "https://api.mainnet-beta.solana.com"
);

// Create vesting stream
const vesting = await streamClient.create({
  sender: wallet,
  recipient: teamMemberWallet,
  mint: tokenMintAddress,
  start: Math.floor(Date.now() / 1000) + 30 * 24 * 3600, // 30 days from now
  amount: new BN("150000000000000"), // 150M tokens (with 6 decimals)
  period: 1,                    // 1 second resolution
  cliff: cliffTimestamp,        // 12 months
  cliffAmount: new BN("0"),     // No cliff amount
  amountPerPeriod: new BN("11574074074"), // ~4.17M tokens per 30-day period
  name: "Team Vesting - Alice",
  canTopup: false,
  cancelableBySender: true,     // Revocable
  transferableBySender: false,
  automaticWithdrawal: true,    // Auto-claim
  withdrawFrequency: 86400,     // Daily auto-withdraw
});
```

**Streamflow features:**
- Revocable or non-revocable streams
- Automatic withdrawals
- Public dashboard for transparency
- Multi-sig support
- Token-2022 compatible

### Custom Anchor Vesting Contract

```rust
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

#[program]
pub mod vesting_contract {
    use super::*;

    pub fn create_vesting(
        ctx: Context<CreateVesting>,
        beneficiary: Pubkey,
        total_amount: u64,
        cliff_time: i64,
        start_time: i64,
        end_time: i64,
        revocable: bool,
    ) -> Result<()> {
        let vesting = &mut ctx.accounts.vesting_account;
        vesting.beneficiary = beneficiary;
        vesting.mint = ctx.accounts.token_mint.key();
        vesting.total_amount = total_amount;
        vesting.claimed_amount = 0;
        vesting.cliff_time = cliff_time;
        vesting.start_time = start_time;
        vesting.end_time = end_time;
        vesting.revocable = revocable;
        vesting.authority = ctx.accounts.authority.key();
        vesting.is_revoked = false;

        // Transfer tokens to vesting PDA
        let cpi_accounts = Transfer {
            from: ctx.accounts.source_account.to_account_info(),
            to: ctx.accounts.vesting_token_account.to_account_info(),
            authority: ctx.accounts.authority.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
        );
        token::transfer(cpi_ctx, total_amount)?;

        Ok(())
    }

    pub fn claim(ctx: Context<Claim>) -> Result<()> {
        let vesting = &mut ctx.accounts.vesting_account;
        let clock = Clock::get()?;

        require!(!vesting.is_revoked, VestingError::Revoked);
        require!(
            clock.unix_timestamp >= vesting.cliff_time,
            VestingError::CliffNotReached
        );

        let vested_amount = calculate_vested(
            vesting.total_amount,
            vesting.start_time,
            vesting.end_time,
            clock.unix_timestamp,
        );

        let claimable = vested_amount
            .checked_sub(vesting.claimed_amount)
            .ok_or(VestingError::NothingToClaim)?;

        require!(claimable > 0, VestingError::NothingToClaim);

        vesting.claimed_amount = vesting
            .claimed_amount
            .checked_add(claimable)
            .unwrap();

        // Transfer from vesting PDA to beneficiary
        let seeds = &[b"vesting", vesting.key().as_ref(), &[ctx.bumps.vesting_token_account]];
        let signer_seeds = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.vesting_token_account.to_account_info(),
            to: ctx.accounts.beneficiary_token_account.to_account_info(),
            authority: ctx.accounts.vesting_token_account.to_account_info(),
        };
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer_seeds,
        );
        token::transfer(cpi_ctx, claimable)?;

        Ok(())
    }

    pub fn revoke(ctx: Context<Revoke>) -> Result<()> {
        let vesting = &mut ctx.accounts.vesting_account;

        require!(vesting.revocable, VestingError::NotRevocable);
        require!(!vesting.is_revoked, VestingError::AlreadyRevoked);
        require!(
            ctx.accounts.authority.key() == vesting.authority,
            VestingError::Unauthorized
        );

        vesting.is_revoked = true;

        // Return unvested tokens to authority
        let vested = calculate_vested(
            vesting.total_amount,
            vesting.start_time,
            vesting.end_time,
            Clock::get()?.unix_timestamp,
        );
        let unvested = vesting
            .total_amount
            .checked_sub(vested)
            .unwrap();

        // Transfer unvested back to authority
        // ... (CPI transfer)

        Ok(())
    }
}

fn calculate_vested(total: u64, start: i64, end: i64, now: i64) -> u64 {
    if now < start {
        return 0;
    }
    if now >= end {
        return total;
    }
    let elapsed = (now - start) as u128;
    let duration = (end - start) as u128;
    ((total as u128) * elapsed / duration) as u64
}

#[derive(Accounts)]
#[instruction(beneficiary: Pubkey)]
pub struct CreateVesting<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + VestingAccount::INIT_SPACE,
        seeds = [b"vesting", beneficiary.as_ref(), mint.key().as_ref()],
        bump,
    )]
    pub vesting_account: Account<'info, VestingAccount>,

    #[account(
        init,
        payer = authority,
        token::mint = token_mint,
        token::authority = vesting_token_account,
        seeds = [b"vesting_token", vesting_account.key().as_ref()],
        bump,
    )]
    pub vesting_token_account: Account<'info, TokenAccount>,

    pub token_mint: Account<'info, Mint>,

    #[account(mut)]
    pub source_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[account]
#[derive(InitSpace)]
pub struct VestingAccount {
    pub beneficiary: Pubkey,
    pub mint: Pubkey,
    pub total_amount: u64,
    pub claimed_amount: u64,
    pub cliff_time: i64,
    pub start_time: i64,
    pub end_time: i64,
    pub revocable: bool,
    pub authority: Pubkey,
    pub is_revoked: bool,
}

#[error_code]
pub enum VestingError {
    #[msg("Cliff period has not been reached")]
    CliffNotReached,
    #[msg("Nothing to claim")]
    NothingToClaim,
    #[msg("Vesting has been revoked")]
    Revoked,
    #[msg("Vesting is not revocable")]
    NotRevocable,
    #[msg("Already revoked")]
    AlreadyRevoked,
    #[msg("Unauthorized")]
    Unauthorized,
}
```

---

## Token-2022 Transfer Hooks for Vesting

Use Token-2022's transfer hook to enforce vesting at the token level.

```rust
// Transfer hook program
fn transfer_hook(ctx: Context<Transfer>, amount: u64) -> Result<()> {
    let vesting_state = &ctx.accounts.vesting_state;
    let clock = Clock::get()?;
    
    let transferable = calculate_transferable(
        vesting_state.total_allocation,
        vesting_state.start_time,
        vesting_state.end_time,
        vesting_state.cliff_time,
        vesting_state.claimed,
        clock.unix_timestamp,
    )?;
    
    require!(
        amount <= transferable,
        VestingHookError::TransferExceedsVested
    );
    
    Ok(())
}
```

**Advantage:** Vesting enforcement happens at the token program level — no separate contract needed, can't be bypassed.

---

## Revocable vs Non-Revocable

| Aspect          | Revocable                      | Non-Revocable                  |
|-----------------|--------------------------------|--------------------------------|
| Control         | Authority can cancel           | Cannot be cancelled            |
| Trust required  | Lower (protections built in)   | Higher (must trust schedule)   |
| Use case        | Team vesting (employment risk) | Investor vesting               |
| Unvested tokens | Return to authority/DAO        | Stay locked until vest         |
| Beneficiary risk| Could lose unvested tokens     | Guaranteed (if contract works) |

**Best practice:** Team tokens = revocable. Investor tokens = non-revocable. Community = non-revocable.

---

## Emergency Unlock Mechanisms

### Governance Override

```rust
pub fn emergency_unlock(ctx: Context<EmergencyUnlock>) -> Result<()> {
    let governance = &ctx.accounts.governance;
    
    require!(
        governance.proposal_passed,
        ErrorCode::ProposalNotPassed
    );
    
    // Unlock all vested tokens immediately
    // Usually requires multi-sig or DAO vote
    Ok(())
}
```

### Time-Locked Emergency

```rust
pub fn initiate_emergency(ctx: Context<EmergencyInit>) -> Result<()> {
    let emergency = &mut ctx.accounts.emergency_state;
    emergency.initiated_at = Clock::get()?.unix_timestamp;
    emergency.delay = 7 * 24 * 3600; // 7-day delay
    Ok(())
}

pub fn execute_emergency(ctx: Context<ExecuteEmergency>) -> Result<()> {
    let emergency = &ctx.accounts.emergency_state;
    let clock = Clock::get()?;
    
    require!(
        clock.unix_timestamp >= emergency.initiated_at + emergency.delay,
        ErrorCode::EmergencyDelayNotPassed
    );
    
    // Execute emergency unlock
    Ok(())
}
```

---

## Vesting Transparency

### Public Dashboard Components

1. **Total vested by allocation** (pie chart)
2. **Unlock schedule** (line chart over time)
3. **Claimed vs unclaimed** (per recipient)
4. **Next unlock date and amount**
5. **Revocation status**

### Streamflow Dashboard

Streamflow provides a public dashboard at `app.streamflow.finance` where any vesting contract can be viewed by anyone. Link this in your token documentation.

### Custom Dashboard with On-Chain Data

```typescript
// Read all vesting accounts for a token
const vestingAccounts = await connection.getProgramAccounts(
  VESTING_PROGRAM_ID,
  {
    filters: [
      { dataSize: VestingAccount.size },
      { memcmp: { offset: 8, bytes: tokenMint.toBase58() } },
    ],
  }
);

const totalVested = vestingAccounts.reduce(
  (sum, acc) => sum + acc.account.data.totalAmount,
  0n
);
```

---

## Common Mistakes

| Mistake                          | Impact                          | Fix                                |
|----------------------------------|--------------------------------|------------------------------------|
| Too short vesting (< 12mo team)  | Team dumps early               | 48mo+ total duration               |
| > 30% unlocked at TGE            | Immediate sell pressure         | 5-15% TGE unlock max               |
| No cliff for investors           | Day-1 dumping                  | 6-12mo cliff minimum               |
| No vesting at all                | Rug pull signal                | Always vest team/investor tokens   |
| Non-transparent vesting          | Community distrust             | Public dashboard, on-chain proof   |
| Revocable investor vesting       | Scam signal                    | Non-revocable for investors        |
| No emergency mechanism           | Locked if contract has bug     | Governance override with delay     |
| Off-chain vesting only           | No verifiability               | On-chain contracts or Streamflow   |
| Same schedule for all allocations| Doesn't fit different incentives| Custom per allocation type         |
| Ignoring Token-2022 hooks        | Extra complexity for enforcement| Use transfer hooks for new tokens  |
