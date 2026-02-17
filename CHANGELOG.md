# Changelog

## 0.0.2 - 2026-02-17

### Added
- Transaction dependency validation with `depends_on` field support
- `VeChain.Transaction.get_depends_on/1` function to retrieve dependency configuration
- `VeChain.Transaction.apply_depends_on/2` function to validate transaction dependencies

### Changed
- Allow Elixir version 1.17 and above

### Removed
- Removed `ex_abi` direct dependency from project

## 0.0.1 - 2026-02-XX

First release