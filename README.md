# SALVA MultiSig
---

### Key Features
* **Hash-Based Proposals:** Minimal storage footprint using `bytes32` identifiers.
* **Storage Packing:** Critical operational parameters (`timeLock`, `remaining`, status flags) packed into single 32-byte slots (`SSTORE` optimization).
* **Self-Governance Engine (`Self.sol`):** Validator membership, emergency pauses, and upgrade permissions are strictly executable via self-targeted MultiSig proposals (`onlySelf`).
* **UUPS Upgradeable:** Standard ERC-1967 proxy support via OpenZeppelin contracts.
* **Recovery Override:** Built-in recovery access bypasses standard timelocks in emergency situations.

---