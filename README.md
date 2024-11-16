By implementing BOLD new CDP model, if the developer has a license and changes some parts of the code, it is possible to get 'leverage' for any token.
However the standard BOLD protocol in LiquityV2 only supports ETH derivations, only Ethereum is used in this project.

Now UniswapV4 hooks come into play!

By using UniswapV4 hooks, more specifically Before/After Swap Hooks, before a swap the token will first be borrowed against BOLD protocol, then receive the stablecoin BOLD, and then swap it back to Ethereum, all this inside the hook.

This iteration will achieve a leveraged long spot swap, that can be liquidated by BOLD protocol.

The iteration can be re-iterated to achieve more leverage, but also creating a tighter liquidations price!

With this done, a bot is created to increase leverage when the token moves upwards, borrowing more BOLD stablecoin from LiquidtyV2 and swaping for more Ethereum.

Now this is where Luni-chan gets interesting! The opposite will be done for when price moves down. The bot will repay debt when price moves downards, creating a case where the user is not liquidated but rather gets its PnL reduced.

With this Luni-chan allows for spot leveraged trading with this, using BOLD on top of UniswapV4.

LiquityV2 benefits as more interest in BOLD is generated as users have an easier way to access leverage for Eth tokens.
UniswapV4 liquidity providers would be able to get more capital efficiency on their LP as they could get interest fees if the LiquityV2 governance choose to do so, as it generates lots of revenue for the both protocols.
Liquidity providers on both protocols get access to make yield, as their pools are used for lending purposes within Luni-chan
