# 09 — SPL Token Deployment Guide

## Quick Deploy: Token in 5 Commands

```bash
# 1. Install CLI tools
solana-keygen new --outfile ~/.config/solana/my-token.json
solana config set --keypair ~/.config/solana/my-token.json

# 2. Airdrop SOL (devnet only) or fund mainnet wallet
solana airdrop 2 --url devnet

# 3. Create token mint
spl-token create-token --decimals 9 --url devnet

# 4. Create token account and mint supply
spl-token create-account <MINT_ADDRESS>
spl-token mint <MINT_ADDRESS> 1000000000

# 5. Revoke authorities (for trustless token)
spl-token authorize <MINT_ADDRESS> mint --disable
spl-token authorize <MINT_ADDRESS> freeze --disable
```

That's it. You now have a deployed SPL token with 1 billion supply, no mint authority, no freeze authority.

---

## Full Deploy: Step-by-Step

### 1. Environment Setup

```bash
# Install Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/v1.18.4/install)"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Install SPL Token CLI
cargo install spl-token-cli

# Verify installations
solana --version   # solana-cli 1.18.4
spl-token --version # spl-token-cli 4.0.0

# Configure for devnet (testing) or mainnet
solana config set --url devnet
solana config set --url https://api.mainnet-beta.solana.com
```

### 2. Wallet Setup

```bash
# Generate a new keypair (or use existing)
solana-keygen new --outfile ~/my-token-authority.json --no-bip39-passphrase

# Set as default
solana config set --keypair ~/my-token-authority.json

# Check balance
solana balance
```

### 3. Create Token Mint

```bash
# Basic: create with defaults (9 decimals)
spl-token create-token

# Advanced: specify decimals
spl-token create-token --decimals 6

# Advanced: create with specific keypair (deterministic address)
spl-token create-token --decimals 9 ~/my-mint-keypair.json
```

**Output:**
```
Creating token AQoKY6k2MgMaDqYyV3s5vXRhKLfzm7K9EPj8xJSMVfPf
Signature: 5K7Rq...
```

### 4. Create Associated Token Account

```bash
# Create ATA for your wallet
spl-token create-account <MINT_ADDRESS>

# Create ATA for another wallet
spl-token create-account <MINT_ADDRESS> --owner <WALLET_ADDRESS>
```

### 5. Mint Initial Supply

```bash
# Mint 1 billion tokens (assuming 9 decimals)
spl-token mint <MINT_ADDRESS> 1000000000

# Mint to specific account
spl-token mint <MINT_ADDRESS> 1000000000 --recipient <TOKEN_ACCOUNT>
```

### 6. Revoke Mint Authority

```bash
# After minting, revoke to prevent future minting
spl-token authorize <MINT_ADDRESS> mint --disable
```

**Why revoke?**
- Prevents infinite supply inflation
- Required for DEX listing trust
- Community expects it for non-stablecoin tokens
- **Irreversible** — make sure you've minted everything you need first

### 7. Revoke Freeze Authority

```bash
spl-token authorize <MINT_ADDRESS> freeze --disable
```

**Why revoke?**
- Prevents the authority from freezing user accounts
- Builds trust (no honeypot risk)
- Required for some DEX listings
- **Irreversible**

---

## TypeScript SDK Deploy

### Full Deployment Script

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
  getMint,
} from "@solana/spl-token";
import {
  createCreateMetadataAccountV3Instruction,
  DataV2,
} from "@metaplex-foundation/mpl-token-metadata";
import bs58 from "bs58";

const TOKEN_METADATA_PROGRAM = new PublicKey(
  "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
);

interface TokenDeployConfig {
  name: string;
  symbol: string;
  uri: string; // Arweave/IPFS URI
  decimals: number;
  initialSupply: number;
  revokeMintAuthority: boolean;
  revokeFreezeAuthority: boolean;
  network: "devnet" | "mainnet";
}

async function deployToken(config: TokenDeployConfig) {
  const rpcUrl =
    config.network === "devnet"
      ? "https://api.devnet.solana.com"
      : "https://api.mainnet-beta.solana.com";

  const connection = new Connection(rpcUrl, "confirmed");
  const payer = Keypair.fromSecretKey(
    bs58.decode(process.env.PAYER_SECRET_KEY!)
  );

  // Check balance
  const balance = await connection.getBalance(payer.publicKey);
  if (balance < 0.05 * LAMPORTS_PER_SOL) {
    throw new Error(
      `Insufficient SOL balance: ${balance / LAMPORTS_PER_SOL}. Need at least 0.05 SOL.`
    );
  }

  console.log(`Deploying ${config.name} (${config.symbol}) on ${config.network}`);
  console.log(`Payer: ${payer.publicKey.toBase58()}`);

  // Step 1: Create mint
  console.log("\n[1/5] Creating mint...");
  const mint = await createMint(
    connection,
    payer,
    payer.publicKey,     // mint authority
    payer.publicKey,     // freeze authority (temporarily)
    config.decimals
  );
  console.log(`Mint: ${mint.toBase58()}`);

  // Step 2: Create token account
  console.log("\n[2/5] Creating token account...");
  const tokenAccount = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint,
    payer.publicKey
  );
  console.log(`Token Account: ${tokenAccount.address.toBase58()}`);

  // Step 3: Mint initial supply
  console.log("\n[3/5] Minting supply...");
  const mintAmount = BigInt(config.initialSupply) * BigInt(10 ** config.decimals);
  const mintSig = await mintTo(
    connection,
    payer,
    mint,
    tokenAccount.address,
    payer.publicKey,
    mintAmount
  );
  console.log(`Minted ${config.initialSupply} tokens: ${mintSig}`);

  // Step 4: Create metadata
  console.log("\n[4/5] Creating metadata...");
  const metadataPDA = PublicKey.findProgramAddressSync(
    [
      Buffer.from("metadata"),
      TOKEN_METADATA_PROGRAM.toBuffer(),
      mint.toBuffer(),
    ],
    TOKEN_METADATA_PROGRAM
  )[0];

  const metadata: DataV2 = {
    name: config.name,
    symbol: config.symbol,
    uri: config.uri,
    sellerFeeBasisPoints: 0,
    creators: [{ address: payer.publicKey, verified: true, share: 100 }],
    collection: null,
    uses: null,
  };

  const metadataIx = createCreateMetadataAccountV3Instruction(
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
        isMutable: true,
        collectionDetails: null,
      },
    }
  );

  const { Transaction } = await import("@solana/web3.js");
  const metadataTx = new Transaction().add(metadataIx);
  const metadataSig = await connection.sendTransaction(metadataTx, [payer], {
    skipPreflight: false,
  });
  await connection.confirmTransaction(metadataSig, "confirmed");
  console.log(`Metadata: ${metadataSig}`);

  // Step 5: Revoke authorities
  if (config.revokeMintAuthority) {
    console.log("\n[5/5] Revoking mint authority...");
    await setAuthority(
      connection,
      payer,
      mint,
      payer.publicKey,
      AuthorityType.MintTokens,
      null
    );
    console.log("Mint authority revoked");
  }

  if (config.revokeFreezeAuthority) {
    await setAuthority(
      connection,
      payer,
      mint,
      payer.publicKey,
      AuthorityType.FreezeAccount,
      null
    );
    console.log("Freeze authority revoked");
  }

  // Summary
  console.log("\n=== Deployment Complete ===");
  console.log(`Mint: ${mint.toBase58()}`);
  console.log(`Name: ${config.name}`);
  console.log(`Symbol: ${config.symbol}`);
  console.log(`Decimals: ${config.decimals}`);
  console.log(`Supply: ${config.initialSupply}`);
  console.log(`Mint Authority: ${config.revokeMintAuthority ? "REVOKED" : "ACTIVE"}`);
  console.log(`Freeze Authority: ${config.revokeFreezeAuthority ? "REVOKED" : "ACTIVE"}`);

  return {
    mint: mint.toBase58(),
    tokenAccount: tokenAccount.address.toBase58(),
  };
}

// Usage
deployToken({
  name: "My Protocol Token",
  symbol: "MPT",
  uri: "https://arweave.net/YOUR_METADATA_TX_ID",
  decimals: 9,
  initialSupply: 1_000_000_000,
  revokeMintAuthority: true,
  revokeFreezeAuthority: true,
  network: "devnet",
}).catch(console.error);
```

---

## Adding Metadata with Metaplex

### Metadata JSON Format (upload to Arweave/IPFS)

```json
{
  "name": "My Protocol Token",
  "symbol": "MPT",
  "description": "The governance and utility token of MyProtocol.",
  "image": "https://arweave.net/IMAGE_TX_ID",
  "external_url": "https://myprotocol.io",
  "attributes": [
    { "trait_type": "Type", "value": "Utility" },
    { "trait_type": "Chain", "value": "Solana" }
  ],
  "properties": {
    "files": [
      { "uri": "https://arweave.net/IMAGE_TX_ID", "type": "image/png" }
    ],
    "category": "image"
  }
}
```

### Upload to Arweave

```bash
# Using Bundlr/Irys CLI
npx @irys/sdk upload ./metadata.json --wallet ~/my-wallet.json --network mainnet

# Or upload via API
curl -X POST "https://arweave.net/tx" \
  -H "Content-Type: application/json" \
  -d @metadata.json
```

### Set Metadata (if update authority is mutable)

```bash
# Using Metaboss CLI
metaboss update data --account <MINT> --keypair ~/my-wallet.json \
  --name "My Token" --symbol "MTK" --uri "https://arweave.net/NEW_URI"
```

---

## Devnet Testing Workflow

```bash
# Step 1: Configure for devnet
solana config set --url devnet

# Step 2: Fund wallet
solana airdrop 2

# Step 3: Deploy token
spl-token create-token --decimals 9
# Note the mint address

# Step 4: Create account and mint
spl-token create-account <MINT>
spl-token mint <MINT> 1000000000

# Step 5: Test transfers
spl-token transfer <MINT> 100 <RECIPIENT_WALLET>

# Step 6: Test revocation (create a second test mint for this)
spl-token create-token --decimals 9
spl-token authorize <TEST_MINT> mint --disable

# Step 7: Verify on explorer
# https://explorer.solana.com/address/<MINT>?cluster=devnet

# Step 8: Test with DEX (devnet Raydium if available, or simulate)
```

---

## Mainnet Deployment Checklist

| Step | Action | Verified |
|------|--------|----------|
| 1 | Code/CLI tested on devnet | ☐ |
| 2 | Metadata JSON uploaded to Arweave/IPFS | ☐ |
| 3 | Token image uploaded (512x512 PNG recommended) | ☐ |
| 4 | Metadata URI returns valid JSON | ☐ |
| 5 | Wallet funded with sufficient SOL (≥ 0.1) | ☐ |
| 6 | Mint keypair generated and backed up securely | ☐ |
| 7 | Decimals confirmed (9 standard, 6 for stablecoin-style) | ☐ |
| 8 | Initial supply amount confirmed | ☐ |
| 9 | Post-mint authority decision made (revoke or retain) | ☐ |
| 10 | Deployment executed | ☐ |
| 11 | Metadata confirmed on explorer | ☐ |
| 12 | Supply and authorities verified | ☐ |
| 13 | Token registered on Jupiter (automatic if liquidity exists) | ☐ |
| 14 | Token registered on Solscan (submit PR if needed) | ☐ |

---

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `insufficient funds` | Not enough SOL for rent + fees | Fund wallet with ≥ 0.05 SOL |
| `0x0` (Account not found) | ATA doesn't exist | Run `create-account` first |
| `Transaction too large` | Too many instructions | Split into multiple transactions |
| `Account does not have authority` | Wrong signer | Use correct authority keypair |
| `Custom program error: 0x1` | Already initialized | Check if mint already exists |
| `Blockhash not found` | RPC timeout/stale | Retry with fresh connection |
| `Simulation failed` | Invalid instruction data | Check parameters, try `--no-simulate` |
| Metadata not showing | URI not accessible | Verify Arweave/IPFS link is live |
| Token not on Jupiter | No liquidity pool | Create a DEX pool first |
| `0x4` (Not enough SOL) | Rent exemption | Need ~0.004 SOL per account |

---

## Cost Estimation

| Operation | SOL Cost (approx) |
|-----------|-------------------|
| Create token mint | 0.0046 SOL |
| Create associated token account | 0.0020 SOL |
| Mint tokens (one transaction) | 0.00001 SOL |
| Create metadata account | 0.0065 SOL |
| Revoke authority | 0.00001 SOL |
| **Total (simple deploy)** | **~0.015 SOL** |

### Including DEX Costs

| Additional Operation | SOL Cost |
|---------------------|----------|
| Raydium AMM pool creation | 0.5-2 SOL |
| Raydium CLMM pool creation | 0.5-1 SOL |
| Meteora DLMM pool creation | 0.3-0.5 SOL |
| Initial liquidity (varies) | 50-10000+ SOL |

### Total Deployment Budget

```
Bare minimum (token only):       0.015 SOL (~$2-3)
With metadata:                    0.02  SOL (~$3-4)
With Raydium pool:               0.5-2 SOL + liquidity
With Meteora DLMM:               0.3-0.5 SOL + liquidity
Full launch (pool + 100 SOL LP): ~102 SOL
```

**Tip**: Always keep 0.1 SOL buffer in your deployment wallet for unexpected fees and retries.
