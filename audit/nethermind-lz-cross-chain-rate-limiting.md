# [NM-0217] Veda vault’s cross-chain x PairwiseRateLimiter

**File(s)**: [LayerZeroTeller.sol](https://github.com/Se7en-Seas/boring-vault/blob/730929c7410b75a40547a8cc71104b1748c7e578/src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol), [PairwiseRateLimiter.sol](https://github.com/Se7en-Seas/boring-vault/blob/730929c7410b75a40547a8cc71104b1748c7e578/src/base/Roles/CrossChain/PairwiseRateLimiter.sol)

### Summary

The purpose of this PR is to add the rate limiting feature to the Veda vault’s cross-chain bridge. It uses the `PairwiseRateLimiter` contract that was audited previously during the "OFT Security Upgrades" audit item.

---

### Findings

After reviewing the updated code, we don't see any clear risk on the changes that were implemented. The code seems to work as expected.

---
