```
 _____       ______        _____
/  ___|     |___  /       /  ___|
\ `--.  ___    / /__ _ __ \ `--.  ___  __ _ ___
 `--. \/ _ \  / / _ \ '_ \ `--. \/ _ \/ _` / __|
/\__/ /  __/./ /  __/ | | /\__/ /  __/ (_| \__ \
\____/ \___|\_/ \___|_| |_\____/ \___|\__,_|___/

```

# Boring Vault Arctic Architecture

Boring Vaults are flexible vault contracts that allow for intricate strategies, secured by both onchain and offchain mechanisms.

The BoringVault architecture is made up of:

- **BoringVault**: A barebones vault contract that outsources complex functionality to external contracts.
- **Manager**: Limits the possible strategies BoringVaults can use, without large gas overheads, or unnecessary risk.
- **Teller**: Facilitates user deposits and withdraws in/out of the BoringVault.
- **Accountant**: Provides a safe share price for Teller interacts via offchain oracles.

The arctic architecture implements:

- **ManagerWithMerkleVerification**: Utilizes Merkle Proofs to limit BoringVault strategies.
- **TellerWithMultiAssetSupport**: Allows user deposits and withdraws using multiple related assets.
- **AccountantWithRateProviders**: Leverages offchain pricing, and onchain rate providers to calculate a safe share price.

## Documentation

GO TO GITBOOK
