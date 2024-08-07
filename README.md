```
              _____       ______        _____                       _.====.._
             /  ___|     |___  /       /  ___|                    ,:._       ~-_
             \ `--.  ___    / /__ _ __ \ `--.  ___  __ _ ___          `\        ~-_
              `--. \/ _ \  / / _ \ '_ \ `--. \/ _ \/ _` / __|           |          `.
             /\__/ /  __/./ /  __/ | | /\__/ /  __/ (_| \__ \         ,/             ~-_
.,_,.='``'-.,\____/ \___|\_/ \___|_| |_\____/ \___|\__,_|___/-..__..-''                 ~~--
```

# Boring Vault Architecture

Boring Vaults are flexible vault contracts that allow for intricate strategies, secured by both onchain and offchain mechanisms.

The BoringVault architecture is made up of:

- **BoringVault**: A barebones vault contract that outsources complex functionality to external contracts.
- **Manager**: Limits the possible strategies BoringVaults can use, without large gas overheads, or unnecessary risk.
- **Teller**: Facilitates user deposits and withdraws in/out of the BoringVault.
- **Accountant**: Provides a safe share price for Teller interactions via offchain oracles.

## Arctic Architecture

The Arctic Architecture implements a unique Manger, Teller, and Accountant.

### ManagerWithMerkleVerification

This Manager restricts the strategies that BoringVaults can employ by storing all possible actions in a [merkle tree](https://en.wikipedia.org/wiki/Merkle_tree). Each leaf of the merkle tree contains:

- `DecoderAndSanitizer` address, a contract used to extract sensitive function arguments from the calldata to `Target`
- `Target` address, the address the call is made to
- `ValueNonZero`, a bool indicating whether or not the BoringVault can transfer native ETH to the `Target`
- `Selector`, the bytes4 function selector on the `Target`
- `PackedAddressArguments`, a bytes value containing all sensitive function arguments found by the `DecoderAndSanitizer`

Each leaf allows the BoringVault to make an explicit action. Using this setup the merkle tree can be used to restrict:

1. What contracts the BoringVault can interact with.
2. What functions on those contracts the BoringVault can call.
3. What sensitive arguments can be passed into those functions.
4. Whether or not the BoringVault can transfer ETH with those function calls.

This Manager also supports a unique merkle tree per strategist, which offers a ton of flexibility and improvements in the future. For instance the main strategist can have access to a large merkle tree, but a strategist account intended to only exit certain positions based off market conditions would have a much smaller merkle tree that only allowed them to perform their job.

### TellerWithMultiAssetSupport

This Teller allows users to enter/exit the BoringVault with a broader set of assets, additionally it only supports permissioned withdraws, and it allows permissioned accounts to refund deposits within a certain time period. These features allow users to only interact with the asset they choose, but also offer a ton of protection for the BoringVault.

When DeFi products allow users to deposit and withdraw multiple different assets, it is a double edged sword, on the one hand users can choose exactly what they want in and out in order to reduce transactions and simplify their account management, but on the other hand it opens up a lot of MEV opportunities that only harm the users in the product because MEV bots will treat the product as a swapping pool, and arbitrage it. This Teller allows users this freedom of choice but substantially mitigates the MEV opportunities using the following:

1. After deposits all of the depositors shares are locked to their account for the `shareLockPeriod`, which makes flashloan arbitrages impossible.
2. During this period permissioned accounts have the ability to refund the deposit, which will completely reverse any state changes.
3. Withdraws are permissioned using an `AtomicQueue` which is convenient for users as they submit one transaction, then their money automatically shows up in their account in the next few days, however inconvenient for arbitragers as they can not control when their withdraw goes through.

This Teller was designed to take all the good things about multiple deposit assets, but remove the MEV opportunities so that users are not taken advantage of.

### AccountantWithRateProviders

This Accountant provides the exchange rate information needed by the Teller to accept multiple deposit assets, and is designed to be manipulation resitant using the following:

1. The share exchange rate is calculated offchain, because it is possible for attackers to manipulate onchain data sources.
2. Exchange rates written on chain are rate limited, and bound limited.
   1. _Rate Limiting_: Exchange rates can only be updated so often.
   2. _Bound Limiting_: Exchange rates must fall within a certain bound created using the previous exchange rate on chain.
   3. These two restrictions greatly limit how fast the exchange rate can change, and if either of them are violated, the Accountant enters a `paused` state which stops all BoringVault deposits and withdraws, and new exchange rate updates, until permissioned accounts unpause it.

## Audits

All audits are stored in the [audit](./audit/) folder.

## Documentation

For more detailed information, please refer to the [documentation](https://docs.veda.tech).

## Development

In order to run the tests make sure the following is done.

1. Foundry is [installed](https://book.getfoundry.sh/getting-started/installation)
2. Copy `sample.env`, rename the copy to `.env`, and update all RPCs.
3. Run `forge install`
4. Run `forge test`
