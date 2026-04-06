#!/bin/bash
# Generate version number based on year progress
# Formula: (YY - 25) . (seconds_elapsed / 31536000 as 6-digit)

# Get current UTC time components
YEAR=$(date -u +%Y)
YY=$(date -u +%y)
DAY_OF_YEAR=$(date -u +%j)
HOUR=$(date -u +%H)
MIN=$(date -u +%M)
SEC=$(date -u +%S)

# Calculate major version (YY - 25)
MAJOR=$((YY - 25))

# Calculate seconds elapsed since start of year
DAY_ZERO_INDEXED=$((DAY_OF_YEAR - 1))
SECONDS_ELAPSED=$((DAY_ZERO_INDEXED * 86400 + HOUR * 3600 + MIN * 60 + SEC))

# Seconds in a standard year (365 days)
SECONDS_IN_YEAR=31536000

# Calculate minor version as 6-digit integer
# Python is available on all GitHub Actions runners
MINOR=$(python3 -c "
seconds_elapsed = ${SECONDS_ELAPSED}
seconds_in_year = ${SECONDS_IN_YEAR}
pct = seconds_elapsed / seconds_in_year
minor = int(pct * 1000000)
print(f'{minor:06d}')
")

# Full version
VERSION="${MAJOR}.${MINOR}"

echo "Generated version: ${VERSION}"
echo "VERSION=${VERSION}" >> "${GITHUB_ENV}"
echo "version=${VERSION}" >> "${GITHUB_OUTPUT}"
