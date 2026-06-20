# Token Safety Rules

These are **hard constraints** — mandatory rules that must never be violated during any token operation. The skill will refuse to proceed if any of these rules are broken.

---

## Rule 1: Never Expose Private Keys

**Severity**: CRITICAL
**Category**: Key Management

Private keys, seed phrases, and keypair files MUST NEVER be:
- Printed to console output
- Logged to files
- Included in commands as plaintext arguments
- Committed to version control
- Shared in chat messages

**Required Practice**:
- Use `solana config set --keypair <PATH>` for key management
- Environment variables for secrets: `export ANCHOR_WALLET=~/.config/solana/id.json`
- Use hardware wallets (Ledger) for high-value operations
- All scripts must reference key file paths, never the key contents

**Enforcement**:
```
BLOCK if: any command contains a base58 private key or 64-byte hex string
BLOCK if: any output contains "seed phrase" or "mnemonic"
BLOCK if: keypair file permissions are >600 (world/group readable)
```

---

## Rule 2: Verify Before Executing

**Severity**: CRITICAL
**Category**: Transaction Safety

Every state-changing transaction MUST be simulated or previewed before execution on mainnet.

**Required Practice**:
- Run `solana program deploy --simulate` before actual deploy
- Use `--dry-run` flag for mint operations
- Verify transaction details (amounts, recipients, accounts) before signing
- For batch operations (airdrops), run a test on 1–3 wallets first

**Enforcement**:
```
BLOCK if: mainnet transaction executed without --dry-run first on identical command
BLOCK if: batch transfer to >10 wallets without prior test batch
WARN if:  transaction fee > 0.1 SOL (unexpectedly high)
```

---

## Rule 3: Revoke or Delegate Mint Authority

**Severity**: CRITICAL
**Category**: Token Integrity

Before public launch, mint authority MUST be either:
1. **Revoked** (set to null) for fixed-supply tokens, OR
2. **Delegated to a multisig** for inflationary tokens with governance-controlled emissions

**Required Practice**:
- Fixed supply → revoke: `spl-token authorize <MINT> mint --disable`
- Inflationary → delegate to multisig: `spl-token authorize <MINT> mint <MULTISIG_ADDRESS>`
- Document which option was chosen in the launch record
- Verify on-chain after execution

**Enforcement**:
```
BLOCK if: mint authority is a single EOA wallet at launch time
WARN if:  mint authority is not revoked AND no multisig delegation plan exists
```

---

## Rule 4: Lock or Burn LP Tokens

**Severity**: CRITICAL
**Category**: Liquidity Safety

LP tokens representing initial liquidity MUST be either:
1. **Burned** (sent to a dead address) for permanent liquidity
2. **Locked** in a vesting/lock contract with a known unlock date

**Required Practice**:
- Burn address: `11111111111111111111111111111111` or equivalent dead address
- Lock via credible locker (e.g., Meteora lock, Team.finance)
- Minimum lock duration: 6 months (12+ months recommended)
- Record lock/burn transaction hash

**Enforcement**:
```
BLOCK if: LP tokens are held in a regular wallet at launch time
BLOCK if: LP lock duration < 6 months
WARN if:  LP lock < 12 months
```

---

## Rule 5: No Single-Wallet Concentration >10%

**Severity**: HIGH
**Category**: Concentration Risk

No single externally-owned account (EOA) should hold more than 10% of the circulating supply at launch.

**Required Practice**:
- Treasury funds in multisig (counts as contract, not EOA)
- Team tokens in vesting contracts (counts as contract)
- Airdrop distribution via merkle tree or batch sender
- Verify all top-10 holders before launch

**Enforcement**:
```
BLOCK if: any single EOA holds >20% of supply
WARN if:  any single EOA holds >10% of supply
WARN if:  top 5 wallets hold >50% of supply (excluding contracts)
```

---

## Rule 6: Test on Devnet First

**Severity**: HIGH
**Category**: Development Safety

All token operations MUST be tested on devnet before mainnet execution.

**Required Practice**:
- Create mint on devnet: `solana config set --url devnet`
- Test full lifecycle: create → mint → transfer → revoke → metadata
- Test vesting contracts with accelerated time (if supported)
- Test airdrop distribution with small amounts
- Verify metadata renders correctly on devnet explorers

**Enforcement**:
```
BLOCK if: mainnet mint created without prior devnet test of identical parameters
WARN if:  mainnet transaction executed < 1 hour after devnet test (insufficient review)
```

---

## Rule 7: Freeze Authority Requires Justification

**Severity**: HIGH
**Category**: Decentralization

Freeze authority on SPL tokens should be revoked unless there is a documented, specific reason to retain it.

**Valid Reasons to Retain**:
- Regulatory compliance (KYC/AML-gated transfers)
- Security (ability to freeze stolen funds post-exploit)
- Vesting enforcement (Token-2022 approach)

**Required Practice**:
- If retained, delegate to multisig (never single EOA)
- Document reason in launch record
- Publish freeze authority policy (when will/won't it be used)
- Plan for eventual revocation

**Enforcement**:
```
WARN if:  freeze authority retained without written justification
BLOCK if: freeze authority is a single EOA at launch
```

---

## Rule 8: Verify Metadata Before Promotion

**Severity**: HIGH
**Category**: Integrity

Token metadata (name, symbol, image, description) MUST be verified on-chain before any public announcement or marketing.

**Required Practice**:
- Create metadata: `metaboss create metadata --mint <MINT> --data-file metadata.json`
- Verify: `metaboss get metadata --mint <MINT>` or check on Solscan
- Confirm image URL is accessible and correct
- Confirm description is accurate and non-misleading
- Metadata URI must point to permanent storage (Arweave preferred)

**Enforcement**:
```
BLOCK if: metadata URI returns non-200 status
BLOCK if: token name/symbol doesn't match announced branding
WARN if:  metadata hosted on centralized server (not Arweave/IPFS)
```

---

## Rule 9: Airdrop Distribution Safety

**Severity**: HIGH
**Category**: Operational Safety

Token airdrops must follow safe distribution practices.

**Required Practice**:
- Use merkle tree distribution (gas-efficient, verifiable)
- Verify all recipient addresses are valid SPL token accounts
- Test distribution with ≤5 wallets before full batch
- Cap individual airdrop amounts per the tokenomics design
- Implement sybil resistance (unique wallet criteria, not just balance)
- Record all distribution transactions

**Enforcement**:
```
BLOCK if: airdrop to >100 wallets without merkle/proof-based distribution
BLOCK if: any single airdrop recipient receives >5% of total supply
WARN if:  no sybil resistance mechanism defined
```

---

## Rule 10: Emergency Response Plan Required

**Severity**: HIGH
**Category**: Operational Safety

Before launch, a documented emergency response plan MUST exist covering:
1. Exploit/hack response (who can pause, how fast)
2. Communication channels (how to alert holders)
3. Recovery plan (can funds be recovered, how)
4. Post-mortem process

**Required Practice**:
- Document plan in writing before launch
- Identify emergency contact chain (response within 1 hour)
- Test emergency pause mechanism (if using Token-2022 delegate)
- Publish plan or at minimum share with core team

**Enforcement**:
```
BLOCK if: no written emergency response plan exists
WARN if:  emergency plan is untested
```

---

## Rule 11: No Misleading Claims

**Severity**: HIGH
**Category**: Legal / Ethical

Token documentation, marketing, and communications must not contain:
- Guaranteed returns or profit promises
- False partnerships or endorsements
- Misleading supply or distribution claims
- Unverified audit claims
- Fake team members or credentials

**Enforcement**:
```
BLOCK if: documentation contains "guaranteed," "risk-free," or "100x" promises
WARN if:  partnerships listed without verifiable proof
WARN if:  team section uses AI-generated avatars without disclosure
```

---

## Rule 12: Transaction Simulation Errors Are Fatal

**Severity**: HIGH
**Category**: Technical Safety

If a Solana transaction simulation returns an error, the operation MUST NOT proceed until the error is resolved.

**Common Errors**:
- `AccountNotFound`: Missing ATA or uninitialized account
- `InsufficientFunds`: Not enough SOL for fees
- `NotEnoughAccountKeys`: Incorrect instruction construction
- `Custom program error`: Business logic failure

**Enforcement**:
```
BLOCK if: transaction simulation fails and --skip-simulation is used
BLOCK if: error code is not explicitly understood and documented
```

---

## Summary

| # | Rule | Severity | Can Override? |
|---|------|----------|---------------|
| 1 | Never expose private keys | CRITICAL | ❌ Never |
| 2 | Verify before executing | CRITICAL | ❌ Never |
| 3 | Revoke/delegate mint authority | CRITICAL | ❌ Never |
| 4 | Lock or burn LP tokens | CRITICAL | ❌ Never |
| 5 | No single-wallet >10% | HIGH | ⚠️ With justification |
| 6 | Test on devnet first | HIGH | ⚠️ With justification |
| 7 | Freeze authority justified | HIGH | ⚠️ With justification |
| 8 | Verify metadata before promo | HIGH | ❌ Never |
| 9 | Airdrop safety | HIGH | ⚠️ With justification |
| 10 | Emergency plan required | HIGH | ❌ Never |
| 11 | No misleading claims | HIGH | ❌ Never |
| 12 | Simulation errors are fatal | HIGH | ❌ Never |

**CRITICAL rules (1–4) can NEVER be overridden.** The skill will halt if any are violated.

**HIGH rules (5–12) can only be overridden with explicit written justification** acknowledging the risk, signed off by the project lead.
