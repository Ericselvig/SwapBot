// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {Test, console2} from "forge-std/Test.sol";
import {SwapBot} from "../src/SwapBot.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {TransferHelper} from "@uniswap/v3-core/contracts/libraries/TransferHelper.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";

contract SwapBotTest is Test, IUniswapV3MintCallback {
    ERC20Mock ARB;
    ERC20Mock USDC;
    MockPriceFeed priceFeed;
    address uniswapFactory;
    address swapRouter;
    IUniswapV3Pool pool;
    SwapBot swapBot;
    address bob;

    function setUp() external {
        bob = makeAddr("bob");
        ARB = new ERC20Mock();
        USDC = new ERC20Mock();

        if (address(ARB) > address(USDC)) {
            (ARB, USDC) = (USDC, ARB);
        }

        require(address(ARB) < address(USDC));
        // Chainlink price feed for ARB/USDC is 2
        priceFeed = new MockPriceFeed(2e8);

        uniswapFactory = deployCode(
            "../node_modules/@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol:UniswapV3Factory"
        );

        pool = IUniswapV3Pool(
            IUniswapV3Factory(uniswapFactory).createPool(
                address(ARB),
                address(USDC),
                500
            )
        );

        swapRouter = deployCode(
            "../node_modules/@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol:SwapRouter",
            abi.encode(uniswapFactory, address(0))
        );

        swapBot = new SwapBot(
            address(ARB),
            address(USDC),
            address(priceFeed),
            swapRouter,
            address(pool)
        );

        ARB.mint(address(swapBot), 10_000 * 1e18);
        USDC.mint(address(swapBot), 10_000 * 1e18);

        ARB.mint(bob, 10e18);
        USDC.mint(bob, 10e18);

        ARB.mint(address(this), 1e6 * 1e18);
        USDC.mint(address(this), 1e6 * 1e18);

        pool.initialize(970342857 * 1e20);

        pool.mint(address(this), 0, 25000, 100e18, bytes(""));
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external {
        if (amount0 > 0) {
            TransferHelper.safeTransfer(
                IUniswapV3Pool(msg.sender).token0(),
                msg.sender,
                amount0
            );
        }
        if (amount1 > 0) {
            TransferHelper.safeTransfer(
                IUniswapV3Pool(msg.sender).token1(),
                msg.sender,
                amount1
            );
        }
    }

    function test_swap() external {
        (,int256 price,,,) = priceFeed.latestRoundData();
        console2.log("ARB price via chainlink: ", price);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        console2.log("ARB Price via uniswap before swap: ", uint256(sqrtPriceX96) ** 2 * 1e8 >> 192);
        vm.startPrank(bob);
        ARB.approve(address(swapBot), 1e18);
        swapBot.swap(1e18);
        (sqrtPriceX96, , , , , , ) = pool.slot0();
        console2.log("ARB Price via uniswap after swap: ", uint256(sqrtPriceX96) ** 2 * 1e8 >> 192);
    }
}
