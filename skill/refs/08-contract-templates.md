# 08 — Reference Smart Contract Code

## SPL Token Creation (TypeScript)

```typescript
import {
  Connection,
  Keypair,
  PublicKey,
  LAMPORTS_PER_SOL,
} from "@solana/web3.js";
import {
  createMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
  setAuthority,
  AuthorityType,
} from "@solana/spl-token";
import bs58 from "bs58";

const connection = new Connection("https://api.mainnet-beta.solana.com", "confirmed");
const payer = Keypair.fromSecretKey(bs58.decode(process.env.PAYER_KEY!));

async function createToken() {
  // Create mint with 9 decimals
  const mint = await createMint(
    connection,
    payer,
    payer.publicKey,     // mint authority
    payer.publicKey,     // freeze authority
    9                    // decimals
  );
  console.log(`Mint created: ${mint.toBase58()}`);

  // Create token account for the payer
  const tokenAccount = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint,
    payer.publicKey
  );
  console.log(`Token account: ${tokenAccount.address.toBase58()}`);

  // Mint 1 billion tokens (1,000,000,000 * 10^9)
  const mintAmount = BigInt(1_000_000_000) * BigInt(10 ** 9);
  const sig = await mintTo(
    connection,
    payer,
    mint,
    tokenAccount.address,
    payer.publicKey,
    mintAmount
  );
  console.log(`Minted: ${sig}`);

  // Revoke mint authority (irreversible!)
  await setAuthority(
    connection,
    payer,
    mint,
    payer.publicKey,
    AuthorityType.MintTokens,
    null // null = revoke
  );
  console.log("Mint authority revoked");

  // Revoke freeze authority
  await setAuthority(
    connection,
    payer,
    mint,
    payer.publicKey,
    AuthorityType.FreezeAccount,
    null
  );
  console.log("Freeze authority revoked");

  return { mint, tokenAccount: tokenAccount.address };
}

createToken().catch(console.error);
```

---

## Token-2022 with Extensions

```typescript
import {
  Connection,
  Keypair,
  SystemProgram,
  Transaction,
  sendAndConfirmTransaction,
} from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID,
  createInitializeMintInstruction,
  createInitializeTransferFeeConfigInstruction,
  getMintLen,
  ExtensionType,
  getAssociatedTokenAddressSync,
  createAssociatedTokenAccountInstruction,
  createMintToCheckedInstruction,
  createSetAuthorityInstruction,
  AuthorityType,
} from "@solana/spl-token";

const connection = new Connection("https://api.mainnet-beta.solana.com", "confirmed");

async function createToken2022WithTransferFee(
  payer: Keypair,
  decimals: number = 9,
  feeBasisPoints: number = 50, // 0.5%
  maxFee: bigint = BigInt(5_000_000_000) // 5 tokens max fee
) {
  const mint = Keypair.generate();
  const extensions = [ExtensionType.TransferFeeConfig];
  const mintLen = getMintLen(extensions);
  const lamports = await connection.getMinimumBalanceForRentExemption(mintLen);

  const ix = [
    SystemProgram.createAccount({
      fromPubkey: payer.publicKey,
      newAccountPubkey: mint.publicKey,
      space: mintLen,
      lamports,
      programId: TOKEN_2022_PROGRAM_ID,
    }),
    createInitializeTransferFeeConfigInstruction(
      mint.publicKey,
      payer.publicKey, // transfer fee config authority
      payer.publicKey, // withdraw withheld authority
      feeBasisPoints,
      maxFee,
      TOKEN_2022_PROGRAM_ID
    ),
    createInitializeMintInstruction(
      mint.publicKey,
      decimals,
      payer.publicKey,
      payer.publicKey,
      TOKEN_2022_PROGRAM_ID
    ),
  ];

  const tx = new Transaction().add(...ix);
  const sig = await sendAndConfirmTransaction(connection, tx, [payer, mint]);
  console.log(`Token-2022 mint created: ${mint.publicKey.toBase58()}`);
  console.log(`Transaction: ${sig}`);

  // Mint tokens to associated token account
  const ata = getAssociatedTokenAddressSync(
    mint.publicKey,
    payer.publicKey,
    false,
    TOKEN_2022_PROGRAM_ID
  );

  const mintTx = new Transaction().add(
    createAssociatedTokenAccountInstruction(
      payer.publicKey,
      ata,
      payer.publicKey,
      mint.publicKey,
      TOKEN_2022_PROGRAM_ID
    ),
    createMintToCheckedInstruction(
      mint.publicKey,
      ata,
      payer.publicKey,
      BigInt(1_000_000_000) * BigInt(10 ** decimals),
      decimals,
      [],
      TOKEN_2022_PROGRAM_ID
    )
  );

  await sendAndConfirmTransaction(connection, mintTx, [payer]);
  console.log(`Minted to ATA: ${ata.toBase58()}`);

  return mint.publicKey;
}
```

---

## Anchor Vesting Contract

### Program (lib.rs)

```rust
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

declare_id!("Vest1111111111111111111111111111111111111111");

#[program]
pub mod vesting_contract {
    use super::*;

    pub fn create_vesting(
        ctx: Context<CreateVesting>,
        total_amount: u64,
        start_ts: i64,
        cliff_duration: i64,
        vesting_duration: i64,
    ) -> Result<()> {
        let vesting = &mut ctx.accounts.vesting;
        vesting.beneficiary = ctx.accounts.beneficiary.key();
        vesting.mint = ctx.accounts.mint.key();
        vesting.total_amount = total_amount;
        vesting.claimed_amount = 0;
        vesting.start_ts = start_ts;
        vesting.cliff_duration = cliff_duration;
        vesting.vesting_duration = vesting_duration;
        vesting.authority = ctx.accounts.authority.key();

        // Transfer tokens to vesting vault
        let cpi_accounts = Transfer {
            from: ctx.accounts.source.to_account_info(),
            to: ctx.accounts.vault.to_account_info(),
            authority: ctx.accounts.authority.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
        token::transfer(cpi_ctx, total_amount)?;

        Ok(())
    }

    pub fn claim(ctx: Context<Claim>) -> Result<()> {
        let vesting = &mut ctx.accounts.vesting;
        let clock = Clock::get()?;
        let now = clock.unix_timestamp;

        require!(now >= vesting.start_ts + vesting.cliff_duration, VestingError::CliffNotReached);

        let vested = if now >= vesting.start_ts + vesting.vesting_duration {
            vesting.total_amount
        } else {
            let elapsed = now - vesting.start_ts;
            (vesting.total_amount as u128 * elapsed as u128 / vesting.vesting_duration as u128) as u64
        };

        let claimable = vested - vesting.claimed_amount;
        require!(claimable > 0, VestingError::NothingToClaim);

        vesting.claimed_amount += claimable;

        let seeds = &[b"vesting".as_ref(), vesting.beneficiary.as_ref(), &[ctx.bumps.vault]];
        let signer_seeds = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.vault.to_account_info(),
            to: ctx.accounts.beneficiary_token.to_account_info(),
            authority: ctx.accounts.vault.to_account_info(),
        };
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer_seeds,
        );
        token::transfer(cpi_ctx, claimable)?;

        Ok(())
    }
}

#[derive(Accounts)]
pub struct CreateVesting<'info> {
    #[account(init, payer = authority, space = 8 + Vesting::INIT_SPACE)]
    pub vesting: Account<'info, Vesting>,
    #[account(mut)]
    pub authority: Signer<'info>,
    /// CHECK: validated in instruction
    pub beneficiary: UncheckedAccount<'info>,
    pub mint: Account<'info, anchor_spl::token::Mint>,
    #[account(mut)]
    pub source: Account<'info, TokenAccount>,
    #[account(
        init,
        payer = authority,
        token::mint = mint,
        token::authority = vault,
        seeds = [b"vesting", beneficiary.key().as_ref()],
        bump,
    )]
    pub vault: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Claim<'info> {
    #[account(mut, has_one = beneficiary)]
    pub vesting: Account<'info, Vesting>,
    pub beneficiary: Signer<'info>,
    #[account(mut, seeds = [b"vesting", beneficiary.key().as_ref()], bump)]
    pub vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub beneficiary_token: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

#[account]
#[derive(InitSpace)]
pub struct Vesting {
    pub beneficiary: Pubkey,
    pub mint: Pubkey,
    pub total_amount: u64,
    pub claimed_amount: u64,
    pub start_ts: i64,
    pub cliff_duration: i64,
    pub vesting_duration: i64,
    pub authority: Pubkey,
}

#[error_code]
pub enum VestingError {
    CliffNotReached,
    NothingToClaim,
}
```

### Client (TypeScript)

```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { VestingContract } from "../target/types/vesting_contract";
import { PublicKey, Keypair } from "@solana/web3.js";
import {
  getAssociatedTokenAddressSync,
  createAssociatedTokenAccountInstruction,
} from "@solana/spl-token";

async function createVestingSchedule(
  program: Program<VestingContract>,
  authority: Keypair,
  beneficiary: PublicKey,
  mint: PublicKey,
  totalAmount: bigint,
  cliffDays: number,
  vestingDays: number
) {
  const vesting = Keypair.generate();
  const vault = PublicKey.findProgramAddressSync(
    [Buffer.from("vesting"), beneficiary.toBuffer()],
    program.programId
  )[0];

  const sourceAta = getAssociatedTokenAddressSync(mint, authority.publicKey);

  await program.methods
    .createVesting(
      new anchor.BN(totalAmount.toString()),
      new anchor.BN(Math.floor(Date.now() / 1000)),
      new anchor.BN(cliffDays * 86400),
      new anchor.BN(vestingDays * 86400)
    )
    .accounts({
      vesting: vesting.publicKey,
      authority: authority.publicKey,
      beneficiary,
      mint,
      source: sourceAta,
      vault,
      tokenProgram: anchor.utils.token.TOKEN_PROGRAM_ID,
      systemProgram: anchor.web3.SystemProgram.programId,
    })
    .signers([vesting])
    .rpc();

  console.log(`Vesting created: ${vesting.publicKey.toBase58()}`);
  return vesting.publicKey;
}
```

---

## Raydium CLMM Pool Creation

```typescript
import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  sendAndConfirmTransaction,
} from "@solana/web3.js";
import {
  Clmm,
  ClmmConfigInfo,
  TokenAmount,
  TOKEN_PROGRAM_ID,
  TxVersion,
} from "@raydium-io/raydium-sdk";

const connection = new Connection("https://api.mainnet-beta.solana.com", "confirmed");

async function createRaydiumCLMMPool(
  payer: Keypair,
  baseMint: PublicKey,
  quoteMint: PublicKey,
  initialPrice: number, // price of base in terms of quote
  tickSpacing: number = 64
) {
  // Get CLMM program config
  const programId = new PublicKey("CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK");
  const configId = getConfigIdForTickSpacing(tickSpacing);

  // Build create pool instruction
  const { transaction, poolId } = await Clmm.makeCreatePoolInstruction({
    programId,
    owner: payer.publicKey,
    mintA: baseMint,
    mintB: quoteMint,
    ammConfig: configId,
    initialPrice: initialPrice,
    startTime: new anchor.BN(Math.floor(Date.now() / 1000)),
    txVersion: TxVersion.V0,
  });

  const tx = new Transaction();
  tx.add(...transaction.instructions);
  const sig = await sendAndConfirmTransaction(connection, tx, [payer]);

  console.log(`CLMM Pool created: ${poolId.toBase58()}`);
  console.log(`Transaction: ${sig}`);
  return poolId;
}

function getConfigIdForTickSpacing(tickSpacing: number): PublicKey {
  // Pre-deployed Raydium CLMM configs
  const configs: Record<number, string> = {
    1: "6Btb4dY4JLNxVJUh7qVxPSJ3L9VXG3jLiFgFCBbsVKP",
    8: "3RJQ5FhL5RSLG3Fp9sJQRVEDBvzf7VFBNKNMPQFikBBj",
    64: "21VGJibD3GLyCL5JY86KJP3EY6M7EC7F6DJFjMJDnViz",
    128: "5BHZ5hXbZQt5MqHHNhLMMGHgXcCJCkUXBbCcBE3jeu8",
  };
  return new PublicKey(configs[tickSpacing]);
}
```

---

## Meteora DLMM Pool Creation

```typescript
import { Connection, Keypair, PublicKey, sendAndConfirmTransaction } from "@solana/web3.js";
import {
  DLMM,
  createLiquidityBook,
  getBinArrays,
} from "@meteora-ag/dlmm";
import { BN } from "@coral-xyz/anchor";

const connection = new Connection("https://api.mainnet-beta.solana.com", "confirmed");

async function createMeteoraDLMMPool(
  payer: Keypair,
  baseMint: PublicKey,
  quoteMint: PublicKey,
  binStep: number = 25,      // 0.25% bin step
  baseFactor: number = 10000, // 1% base fee
  initialPrice: number
) {
  const dlmm = await DLMM.create(connection, {
    cluster: "mainnet-beta",
  });

  // Create the pool
  const createPoolTx = await dlmm.createLiquidityBook(
    baseMint,
    quoteMint,
    binStep,
    baseFactor,
    new BN(Math.floor(initialPrice * 1e9)), // price in BN
    payer.publicKey,
    payer.publicKey  // fee owner
  );

  const sig = await sendAndConfirmTransaction(connection, createPoolTx, [payer]);
  console.log(`DLMM Pool created: ${sig}`);

  return sig;
}

async function addLiquidityToDLMM(
  connection: Connection,
  payer: Keypair,
  poolAddress: PublicKey,
  amount: bigint,
  strategy: "spot" | "curve" | "bid-ask" = "spot"
) {
  const dlmmPool = await DLMM.create(connection, poolAddress);

  // Get active bin
  const activeBin = await dlmmPool.getActiveBin();
  console.log(`Active bin price: ${activeBin.price}`);

  // Add liquidity based on strategy
  const addLiquidityTx = await dlmmPool.addLiquidityByStrategy({
    userPublicKey: payer.publicKey,
    amountX: new BN(amount.toString()),
    amountY: new BN(0), // single-sided
    strategy: {
      maxBinId: activeBin.binId + 10,
      minBinId: activeBin.binId - 10,
      strategyType: strategy === "spot" ? 0 : strategy === "curve" ? 1 : 2,
    },
    slippage: 0.5, // 0.5%
  });

  const sig = await sendAndConfirmTransaction(
    connection,
    addLiquidityTx as any,
    [payer]
  );
  console.log(`Liquidity added: ${sig}`);
}
```

---

## Jupiter Swap Integration

```typescript
import { Connection, Keypair, VersionedTransaction } from "@solana/web3.js";

const JUPITER_API = "https://quote-api.jup.ag/v6";

async function jupiterSwap(
  connection: Connection,
  payer: Keypair,
  inputMint: string,
  outputMint: string,
  amount: number, // in lamports/smallest unit
  slippageBps: number = 50 // 0.5%
) {
  // Get quote
  const quoteRes = await fetch(
    `${JUPITER_API}/quote?inputMint=${inputMint}&outputMint=${outputMint}` +
    `&amount=${amount}&slippageBps=${slippageBps}`
  );
  const quote = await quoteRes.json();
  console.log(`Quote: ${amount} ${inputMint} → ${quote.outAmount} ${outputMint}`);

  // Get swap transaction
  const swapRes = await fetch(`${JUPITER_API}/swap`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      quoteResponse: quote,
      userPublicKey: payer.publicKey.toBase58(),
      wrapAndUnwrapSol: true,
      dynamicComputeUnitLimit: true,
      prioritizationFeeLamports: "auto",
    }),
  });
  const { swapTransaction } = await swapRes.json();

  // Deserialize, sign, and send
  const txBuf = Buffer.from(swapTransaction, "base64");
  const tx = VersionedTransaction.deserialize(txBuf);
  tx.sign([payer]);

  const sig = await connection.sendTransaction(tx, {
    skipPreflight: true,
    maxRetries: 3,
  });
  console.log(`Swap sent: ${sig}`);

  // Confirm
  const status = await connection.confirmTransaction(sig, "confirmed");
  console.log(`Swap confirmed: ${sig}`);
  return sig;
}

// Example: Buy token with SOL
// jupiterSwap(connection, payer, "So11111111111111111111111111111111", "YOUR_MINT", 0.1 * 1e9);
```

---

## Metaplex Token Metadata

```typescript
import { Connection, Keypair, PublicKey } from "@solana/web3.js";
import {
  createCreateMetadataAccountV3Instruction,
  createUpdateMetadataAccountV2Instruction,
  DataV2,
} from "@metaplex-foundation/mpl-token-metadata";
import { Transaction, sendAndConfirmTransaction } from "@solana/web3.js";

const TOKEN_METADATA_PROGRAM = new PublicKey("metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s");

async function createTokenMetadata(
  connection: Connection,
  payer: Keypair,
  mint: PublicKey,
  name: string,
  symbol: string,
  uri: string // Arweave/IPFS URI with JSON metadata
) {
  const metadataPDA = PublicKey.findProgramAddressSync(
    [
      Buffer.from("metadata"),
      TOKEN_METADATA_PROGRAM.toBuffer(),
      mint.toBuffer(),
    ],
    TOKEN_METADATA_PROGRAM
  )[0];

  const metadata: DataV2 = {
    name,
    symbol,
    uri,
    sellerFeeBasisPoints: 0,
    creators: [
      {
        address: payer.publicKey,
        verified: true,
        share: 100,
      },
    ],
    collection: null,
    uses: null,
  };

  const ix = createCreateMetadataAccountV3Instruction(
    {
      metadata: metadataPDA,
      mint,
      mintAuthority: payer.publicKey,
      payer: payer.publicKey,
      updateAuthority: payer.publicKey,
    },
    {
      createMetadataAccountArgsV3: {
        data: metadata,
        isMutable: false, // set false for immutable metadata
        collectionDetails: null,
      },
    }
  );

  const tx = new Transaction().add(ix);
  const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
  console.log(`Metadata created: ${sig}`);
  return metadataPDA;
}

// Metadata JSON format (upload to Arweave/IPFS):
const metadataJson = {
  name: "My Token",
  symbol: "MTK",
  description: "A utility token for the MyProtocol ecosystem.",
  image: "https://arweave.net/IMAGE_TX_ID",
  external_url: "https://myprotocol.io",
  attributes: [],
  properties: {
    files: [{ uri: "https://arweave.net/IMAGE_TX_ID", type: "image/png" }],
    category: "image",
  },
};
```

---

## Multisig Setup (Squads v4)

```typescript
import { Connection, Keypair, PublicKey } from "@solana/web3.js";
import Squads from "@sqds/sdk";
import { BN } from "@coral-xyz/anchor";

const connection = new Connection("https://api.mainnet-beta.solana.com", "confirmed");

async function createSquadMultisig(
  creator: Keypair,
  members: PublicKey[],
  threshold: number // e.g., 3 for 3-of-5
) {
  const squads = Squads.mainnet(connection, {
    multisigProgramId: new PublicKey("SQDS4ep65T869zMMBKyuUq6aD6EgTu8psMjkvj52pCf"),
  });

  // Create multisig
  const multisig = await squads.createMultisig(
    threshold,
    creator.publicKey,
    creator.publicKey, // config authority
    members
  );

  console.log(`Multisig created: ${multisig.publicKey.toBase58()}`);
  console.log(`Members: ${members.map((m) => m.toBase58()).join(", ")}`);
  console.log(`Threshold: ${threshold}/${members.length}`);

  return multisig.publicKey;
}

async function proposeTransaction(
  squads: Squads,
  multisig: PublicKey,
  proposer: Keypair,
  instructions: TransactionInstruction[]
) {
  // Create transaction proposal
  const tx = await squads.createTransaction(multisig, 0);
  console.log(`Transaction proposed: ${tx.publicKey.toBase58()}`);

  // Add instructions
  for (const ix of instructions) {
    await squads.addInstruction(tx.publicKey, ix);
  }

  // Activate proposal
  await squads.activateTransaction(tx.publicKey, proposer.publicKey);

  console.log("Transaction activated, awaiting approvals");
  return tx.publicKey;
}

async function approveAndExecute(
  squads: Squads,
  transactionPDA: PublicKey,
  approver: Keypair
) {
  // Approve
  await squads.approveTransaction(transactionPDA, approver.publicKey);
  console.log(`Approved by: ${approver.publicKey.toBase58()}`);

  // Execute (only works if threshold met)
  try {
    await squads.executeTransaction(transactionPDA, approver.publicKey);
    console.log("Transaction executed successfully");
  } catch (e) {
    console.log("Not enough approvals yet, waiting for other signers");
  }
}
```

---

## Package Dependencies

```json
{
  "dependencies": {
    "@solana/web3.js": "^1.95.0",
    "@solana/spl-token": "^0.4.0",
    "@coral-xyz/anchor": "^0.30.0",
    "@metaplex-foundation/mpl-token-metadata": "^3.0.0",
    "@raydium-io/raydium-sdk": "^1.3.0",
    "@meteora-ag/dlmm": "^1.0.0",
    "@sqds/sdk": "^2.0.0",
    "bs58": "^5.0.0"
  }
}
```
