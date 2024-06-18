// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/src/interfaces/feeds/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title SwapBot
 * @author Yash Goyal
 * @notice A contract that swaps ARB for USDC, with similar price on chainlink and uniswap
 */
contract SwapBot {
    IERC20 private immutable token0;
    IERC20 private immutable token1;
    AggregatorV3Interface private immutable priceFeed;
    ISwapRouter private immutable router;
    IUniswapV3Pool private immutable pool;

    uint256 private constant PRECISION = 1e8;

    /**
     * @param _token0 ARB
     * @param _token1 USDC
     * @param _priceFeed ARB/USDC chainlink price feed
     * @param _router Uniswap v3 swap router
     */
    constructor(
        address _token0,
        address _token1,
        address _priceFeed,
        address _router,
        address _pool
    ) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        priceFeed = AggregatorV3Interface(_priceFeed);
        router = ISwapRouter(_router);
        pool = IUniswapV3Pool(_pool);
    }

    /**
     * @notice Swaps ARB for USDC
     * @param _amountToken0In Amount of ARB to swap
     */
    function swap(uint256 _amountToken0In) external {
        token0.transferFrom(msg.sender, address(this), _amountToken0In);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        _syncPriceFeeds();
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                fee: 500,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountToken0In,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        router.exactInputSingle(params);
    }

    /**
     * @notice syncs the price feeds of chainlink and uniswap by making a swap in the uniswap pool
     */
    function _syncPriceFeeds() internal {
        (, int answer, , , ) = priceFeed.latestRoundData();
        uint256 chainLinkPrice = uint256(answer);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 uniswapPrice = ((uint256(sqrtPriceX96) ** 2 * 1e8) >> 192);
        if (chainLinkPrice > uniswapPrice) {
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: address(token1),
                    tokenOut: address(token0),
                    fee: 500,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: ((Math.sqrt(chainLinkPrice) -
                        Math.sqrt(uniswapPrice)) * pool.liquidity()) /
                        PRECISION,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            router.exactInputSingle(params);
        } else {
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: address(token0),
                    tokenOut: address(token1),
                    fee: 500,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: ((1e16 /
                        Math.sqrt(uniswapPrice) -
                        1e16 /
                        Math.sqrt(chainLinkPrice)) * pool.liquidity()) /
                        PRECISION,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            router.exactInputSingle(params);
        }
    }
}
