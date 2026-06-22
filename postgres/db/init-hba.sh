#!/bin/bash
set -e

# Prepend scram-sha-256 local auth configuration to pg_hba.conf for production security
# pg_hba.conf evaluates rules from top to bottom and uses the first match.

echo "Customizing pg_hba.conf for production..."

TEMP_HBA=$(mktemp)

# Write secure scram-sha-256 rules for local connections
echo "local all all scram-sha-256" > "$TEMP_HBA"

# Append the rest of the existing rules (excluding default local rules)
grep -v "^local" "$PGDATA/pg_hba.conf" >> "$TEMP_HBA" || true

# Overwrite pg_hba.conf
cp "$TEMP_HBA" "$PGDATA/pg_hba.conf"
rm "$TEMP_HBA"

echo "pg_hba.conf successfully updated with scram-sha-256 rules!"
