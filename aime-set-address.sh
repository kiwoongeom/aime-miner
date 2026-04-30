#!/bin/bash
# aime-set-address.sh — Manage saved Aime wallet address for auto-loading
#
# Usage:
#   ./aime-set-address.sh                       Interactive prompt
#   ./aime-set-address.sh AQWWPy...             Save address directly
#   ./aime-set-address.sh show                  Show currently saved address
#   ./aime-set-address.sh clear                 Remove saved address
#
# The address is saved to ~/.aime/last-wallet-address.txt and is
# automatically loaded by aime-mine.sh when no address arg is given.

set -uo pipefail

ADDRESS_FILE="$HOME/.aime/last-wallet-address.txt"

show_current() {
    if [ -f "$ADDRESS_FILE" ]; then
        local current=$(head -1 "$ADDRESS_FILE" | tr -d '[:space:]')
        if [ -n "$current" ]; then
            echo "Current saved address:"
            echo "  $current"
            echo ""
            echo "  File: $ADDRESS_FILE"
            return 0
        fi
    fi
    echo "No address currently saved."
    echo "  Expected file: $ADDRESS_FILE (does not exist or empty)"
    return 1
}

clear_address() {
    if [ -f "$ADDRESS_FILE" ]; then
        rm -f "$ADDRESS_FILE"
        echo "✓ Saved address cleared."
        echo "  Removed: $ADDRESS_FILE"
    else
        echo "Nothing to clear (no saved address)."
    fi
}

save_address() {
    local addr="$1"
    # Validate format: 95 chars, starts with A
    if [[ ! "$addr" =~ ^A[a-zA-Z0-9]{94}$ ]]; then
        echo "✗ Invalid address format" >&2
        echo "  Expected: 95 chars total, starts with 'A'" >&2
        echo "  Got:      ${#addr} chars: $addr" >&2
        return 1
    fi

    mkdir -p "$(dirname "$ADDRESS_FILE")"

    # Show old if exists
    if [ -f "$ADDRESS_FILE" ]; then
        local old=$(head -1 "$ADDRESS_FILE" | tr -d '[:space:]')
        echo "Replacing previous address:"
        echo "  OLD: $old"
    fi

    echo "$addr" > "$ADDRESS_FILE"
    echo "  NEW: $addr"
    echo ""
    echo "✓ Address saved to $ADDRESS_FILE"
    echo "  Run: ./aime-mine.sh    (no args needed)"
}

interactive_prompt() {
    echo "Aime Address Setup"
    echo "=================="
    show_current 2>/dev/null
    echo ""
    read -p "Paste your AIME address (or 'q' to cancel): " new_addr

    if [ "$new_addr" = "q" ] || [ "$new_addr" = "Q" ] || [ -z "$new_addr" ]; then
        echo "Cancelled."
        exit 0
    fi

    save_address "$new_addr"
}

# ===== MAIN =====
case "${1:-}" in
    "")
        interactive_prompt
        ;;
    show|status|current)
        show_current
        ;;
    clear|remove|delete|unset)
        clear_address
        ;;
    -h|--help|help)
        sed -n '2,16p' "$0" | sed 's/^#//; s/^ //'
        ;;
    *)
        save_address "$1"
        ;;
esac
