// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import { ScarabRouter } from "./ScarabRouter.sol";

interface IBlast {
    function configureClaimableGas() external;
    function configureGovernor(address governor) external;
}

interface IBlastPoints {
    function configurePointsOperator(address operator) external;
    function configurePointsOperatorOnBehalf(address contractAddress, address operator) external;
}

contract ScarabRouterBlast is ScarabRouter {
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    IBlastPoints public constant BLAST_POINTS = IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800);

    constructor(address feeWallet_, address pointsOperator_) ScarabRouter(feeWallet_, address(0)) {
        BLAST.configureClaimableGas();
        // This sets the contract's governor. This call must come last because after
        // the governor is set, this contract will lose the ability to configure itself.
        BLAST.configureGovernor(feeWallet_);

        BLAST_POINTS.configurePointsOperator(pointsOperator_);
    }
}
