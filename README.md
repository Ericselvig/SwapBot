# SwapBot
## The Problem
When exchanging tokens via a Uniswap v3 pool, discrepancies between price feeds provided by Chainlink and the pool can result in users receiving a different amount of tokens than expected. This mismatch can lead to a loss in value for the user.

## The Solution
SwapBot is a bot designed to align the Uniswap v3 pool price with the Chainlink price feed.

## How it Works
1. The user initiates a swap from token A to token B.
2. SwapBot compares the price from the Chainlink price feed with the price in the Uniswap v3 pool.
3. If the Chainlink price feed indicates a higher price for token A than the Uniswap v3 pool:
    - SwapBot makes a swap in the pool, supplying token B to increase the price of token A until it matches the Chainlink price feed.
    - Mathematical Model:
        - Let `L` be the liquidity of the pool in a certain tick range, where the price belogs.
        - Let `P` be the price of token A in terms of token B in the pool.
        - Let `ΔY` be the amount of token B to be supplied to the pool.<p>
        Then, `L = ΔY / Δ√P` [[6.7](https://uniswap.org/whitepaper-v3.pdf)], which gives, <br>
        `ΔY = L * Δ√P`<p>
        Similarly, `ΔX = Δ(1/√P) * L`
4. The user's swap is then executed at the adjusted price.

## Additional Ideas
To avoid using its own funds, SwapBot can utilize flash loans to temporarily acquire the necessary tokens for manipulating the pool.

## Notes
- There will be a slight difference in price feeds due to uniswap pool's fee, as well as the actual swap.
- This bot hasn't been tested for cross-tick swaps.

## Running tests
```bash
git clone https://github.com/ericselvig/swapbot.git
cd swapbot
npm i
forge test
```