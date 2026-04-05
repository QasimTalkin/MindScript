#!/usr/bin/env bash
set -euo pipefail

echo "==> MindScript setup"

# 1. Verify Swift Toolchain
if xcode-select -p &>/dev/null; then
    echo "  Swift toolchain: $(xcode-select -p)"
    echo "  Swift version:   $(swift --version | head -1)"
else
    echo "ERROR: Swift toolchain not found."
    echo "       Please run: xcode-select --install"
    exit 1
fi

# 2. Install Homebrew dependencies
if ! command -v brew &>/dev/null; then
    echo "ERROR: Homebrew not found. Install from https://brew.sh"
    exit 1
fi

brew install supabase/tap/supabase  # Supabase CLI for local dev
brew install stripe/stripe-cli/stripe  # Stripe CLI for webhook testing

echo "  Supabase CLI: $(supabase --version)"
echo "  Stripe CLI: $(stripe --version)"

# 3. Create .env file if it doesn't exist
ENV_FILE="$(dirname "$0")/../.env"
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" << 'EOF'
# Supabase — from https://supabase.com/dashboard/project/<your-project>/settings/api
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=YOUR_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY

# Stripe — from https://dashboard.stripe.com/apikeys
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRO_MONTHLY_PRICE_ID=price_...
EOF
    echo "  Created .env — fill in your credentials before building"
fi

echo ""
echo "==> Setup complete."
echo "    1. Fill in .env with your Supabase and Stripe credentials"
echo "    2. Update Constants.swift with your Supabase URL and anon key"
echo "    3. Run: cd MindScript && swift build"
