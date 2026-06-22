#!/bin/bash
set -e

# Prepend the requested local auth configurations to pg_hba.conf
# pg_hba.conf evaluates rules from top to bottom and uses the first match.

echo "Customizing pg_hba.conf..."

TEMP_HBA=$(mktemp)

# Write the user's specific rules
echo "local all all trust" > "$TEMP_HBA"
echo "local all all scram-sha-256" >> "$TEMP_HBA"

# Append the rest of the existing rules (excluding default local rules)
grep -v "^local" "$PGDATA/pg_hba.conf" >> "$TEMP_HBA" || true

# Overwrite pg_hba.conf
cp "$TEMP_HBA" "$PGDATA/pg_hba.conf"
rm "$TEMP_HBA"

echo "pg_hba.conf successfully updated!"
