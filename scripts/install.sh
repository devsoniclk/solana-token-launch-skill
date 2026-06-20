#!/usr/bin/env bash
#
# install.sh — Installer for solana-token-launch-skill
#
# Checks for required tools and installs dependencies.
# Safe to run multiple times (idempotent).
#
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# ─── Tool Checks ─────────────────────────────────────────────────────────────

check_command() {
    local cmd="$1"
    local name="$2"
    local install_hint="$3"
    local min_version="${4:-}"

    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>&1 | head -1 || echo "unknown")
        success "$name found: $version"
        return 0
    else
        error "$name not found. $install_hint"
        return 1
    fi
}

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Solana Token Launch Skill — Installer"
echo "═══════════════════════════════════════════════════════════"
echo ""

MISSING=0

# ─── Required: Solana CLI ────────────────────────────────────────────────────
info "Checking for Solana CLI..."
if ! check_command solana "Solana CLI" \
    "Install: sh -c \"\$(curl -sSfL https://release.anza.xyz/stable/install)\""; then
    MISSING=$((MISSING + 1))
fi

# ─── Required: Anchor ────────────────────────────────────────────────────────
info "Checking for Anchor..."
if ! check_command anchor "Anchor Framework" \
    "Install: cargo install --git https://github.com/coral-xyz/anchor avm --locked && avm install latest && avm use latest"; then
    MISSING=$((MISSING + 1))
fi

# ─── Required: Node.js ───────────────────────────────────────────────────────
info "Checking for Node.js..."
if ! check_command node "Node.js" \
    "Install: https://nodejs.org/ (v18+ required)" "18"; then
    MISSING=$((MISSING + 1))
else
    NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_MAJOR" -lt 18 ]; then
        error "Node.js v18+ required, found v${NODE_MAJOR}. Please upgrade."
        MISSING=$((MISSING + 1))
    fi
fi

# ─── Required: npm ───────────────────────────────────────────────────────────
info "Checking for npm..."
if ! check_command npm "npm" "Comes with Node.js: https://nodejs.org/"; then
    MISSING=$((MISSING + 1))
fi

# ─── Required: Rust / Cargo (for Anchor programs) ────────────────────────────
info "Checking for Rust..."
if ! check_command cargo "Rust/Cargo" \
    "Install: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"; then
    MISSING=$((MISSING + 1))
fi

# ─── Optional: metaboss (metadata tool) ─────────────────────────────────────
info "Checking for metaboss (optional)..."
if command -v metaboss &>/dev/null; then
    success "metaboss found: $(metaboss --version 2>&1 | head -1)"
else
    warn "metaboss not found (optional). Install: cargo install metaboss"
fi

# ─── Optional: solana-test-validator ─────────────────────────────────────────
info "Checking for solana-test-validator (optional)..."
if command -v solana-test-validator &>/dev/null; then
    success "solana-test-validator found"
else
    warn "solana-test-validator not found (comes with Solana CLI tools)"
fi

# ─── Check for missing critical tools ────────────────────────────────────────
if [ "$MISSING" -gt 0 ]; then
    echo ""
    error "$MISSING required tool(s) missing. Please install them and re-run."
    echo ""
    echo "Quick install commands:"
    echo ""
    echo "  # Solana CLI"
    echo "  sh -c \"\$(curl -sSfL https://release.anza.xyz/stable/install)\""
    echo ""
    echo "  # Anchor"
    echo "  cargo install --git https://github.com/coral-xyz/anchor avm --locked"
    echo "  avm install latest && avm use latest"
    echo ""
    echo "  # Node.js (use nvm for version management)"
    echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
    echo "  nvm install 20 && nvm use 20"
    echo ""
    echo "  # Rust"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo ""
    exit 1
fi

# ─── Install npm dependencies ────────────────────────────────────────────────
echo ""
info "Installing npm dependencies..."

cd "$SKILL_DIR"

if [ -f "package.json" ]; then
    npm install --silent
    success "npm dependencies installed"
else
    warn "No package.json found in $SKILL_DIR — skipping npm install"
    info "Creating minimal package.json..."

    cat > package.json << 'PACKAGE_EOF'
{
  "name": "solana-token-launch-skill",
  "version": "1.0.0",
  "description": "Solana AI Kit skill for launching SPL tokens with best-practice tokenomics",
  "private": true,
  "scripts": {
    "simulate": "node scripts/simulate.js",
    "review": "node scripts/review.js",
    "lint:tokenomics": "node scripts/validate-tokenomics.js"
  },
  "dependencies": {
    "@solana/web3.js": "^1.95.0",
    "@solana/spl-token": "^0.4.0",
    "@metaplex-foundation/mpl-token-metadata": "^3.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "license": "MIT"
}
PACKAGE_EOF

    npm install --silent
    success "Created package.json and installed dependencies"
fi

# ─── Verify Solana config ────────────────────────────────────────────────────
echo ""
info "Checking Solana configuration..."

CLUSTER=$(solana config get 2>/dev/null | grep "RPC URL" | awk '{print $NF}' || echo "unknown")
KEYPAIR=$(solana config get 2>/dev/null | grep "Keypair Path" | awk '{print $NF}' || echo "unknown")

info "  Cluster: $CLUSTER"
info "  Keypair: $KEYPAIR"

if [ "$CLUSTER" = "unknown" ] || [ "$KEYPAIR" = "unknown" ]; then
    warn "Solana CLI not fully configured. Run: solana config set --url mainnet-beta"
fi

# ─── Create keypair if none exists ────────────────────────────────────────────
if [ ! -f "${KEYPAIR:-/dev/null}" ] 2>/dev/null; then
    warn "No keypair found. Generating a new devnet keypair..."
    solana-keygen new --no-bip39-passphrase --outfile ~/.config/solana/id.json 2>/dev/null || true
    solana config set --keypair ~/.config/solana/id.json 2>/dev/null || true
    success "New keypair generated at ~/.config/solana/id.json"
    warn "Fund this wallet: solana airdrop 2 --url devnet"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
success "Installation complete!"
echo ""
echo "  Next steps:"
echo "    1. Design tokenomics:   claude design-token"
echo "    2. Review tokenomics:   claude tokenomics-reviewer"
echo "    3. Simulate launch:     claude simulate-launch"
echo "    4. Check readiness:     claude launch-readiness"
echo ""
echo "  Documentation: $SKILL_DIR/README.md"
echo "  Examples:      $SKILL_DIR/examples/"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
