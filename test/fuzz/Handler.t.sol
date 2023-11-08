// Handler is going to narrow down the way we call functions

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    address weth;
    address wbtc;

    uint96 MAX_DEPOSIT_SIZE = type(uint96).max;

    uint256 public mintIsCalled;
    address[] public usersWithCollateral;

    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = collateralTokens[0];
        wbtc = collateralTokens[1];
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateral.length == 0) {
            return;
        }
        address sender = usersWithCollateral[addressSeed % usersWithCollateral.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDscToMint));
        if (amount == 0) {
            return;
        }
        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
        mintIsCalled++;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountOfCollateral) public {
        address tokenCollateral = _getCollateralFromSeed(collateralSeed);
        amountOfCollateral = bound(amountOfCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        ERC20Mock(tokenCollateral).mint(msg.sender, amountOfCollateral);
        ERC20Mock(tokenCollateral).approve(address(dsce), amountOfCollateral);
        dsce.depositCollateral(tokenCollateral, amountOfCollateral);
        vm.stopPrank();
        usersWithCollateral.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountOfCollateral) public {
        address tokenCollateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(msg.sender, tokenCollateral);
        amountOfCollateral = bound(amountOfCollateral, 0, maxCollateralToRedeem);
        if (amountOfCollateral == 0) {
            return;
        }
        dsce.redeemCollateral(tokenCollateral, amountOfCollateral);
    }

    //Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (address) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
