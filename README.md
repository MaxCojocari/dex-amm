# DEX/AMM

This project represents an implementation of Decentralized Exchange (DEX) contracts using a classical (constant product) **Automated Market Maker** (AMM) principle for ERC20 tokens.

## Solution architecture

The core architectural idea resides in pooling: liquidity providers can stake their liquidity in a contract; that staked liquidity allows anyone else to trade in a decentralized way, paying a small fee (0.3%), which gets accumulated in a contract and then gets shared by all liquidity providers.

The core files of this project are in the directory `dex-amm/contracts` which contains two folders: `Interfaces`, `Libraries` and the actual contracts.

![image](https://user-images.githubusercontent.com/92053176/186387585-8866ea47-7539-45bc-b3e4-7597df2e1367.png)

The core contracts are `AMMPair.sol`, `AMMPairETH.sol`. Their main purpose is to accept tokens from users and use accumulated reserves of tokens to perform swaps, either in token - token pools (both ERC20), or ETH - token ones. Each of them can pool only one pair of tokens (or ETH - token pairs) and allows to perform swaps only between them. 

The factory contracts `AMMFactory` and `AMMFactoryETH` are registries of all deployed pair contracts. Their importance resides in simplifying pair contracts deployment: instead of deploying the pair contract manually, one can simply call a method in the factory contract.

The `AMMRouter.sol` contract is a high-level contract that serves as the entrypoint for most user applications. This contract makes it easier to create pairs, add and remove liquidity, calculate prices for all possible swap variations and perform actual swaps. Router works with all pairs deployed via the `AMMFactory.sol`, `AMMFactoryETH.sol` contracts.

## Liquidity mining

The `AMMStaking.sol` deals with liquidity mining. It is nothing else than a simple staking pool: newly minted LP tokens can be deposited in vaults and for this you can be awarded with exclusive TitaniumSweet tokens (TSW). The more you deposit, the longer staking time you apply, the more tokens you can earn. It sounds really sweet, doesn't it?:money_mouth_face:

The algorithm is based on the following formula.

![image](https://user-images.githubusercontent.com/92053176/186395419-e5c16535-7d00-479d-aecf-66bd763b10c9.png)


The `nrTokensPerBlock` is set by the owner of `AMMStaking.sol` contract. The number of stakers in pool should greater than a specified number (here 3, can be reseted respectively). The idea is inspired a little bit from SushiSwap paradigma. So there is a lot of space for improvement in my implementation.

## QA & Testing coverage
All contracts, except for openzeppelin ERC20 and `Token.sol` contracts, were fully checked and tested. For full test report, clone this repistory and run the command:

```shell
npx hardhat coverage
```
![image](https://user-images.githubusercontent.com/92053176/186395676-a646aade-a018-4dee-b540-d86b82601803.png)




