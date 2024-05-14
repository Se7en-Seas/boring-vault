pragma solidity 0.8.21;

import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract GenericRateProvider is IRateProvider {
    using Address for address;

    //============================== IMMUTABLES ===============================

    /**
     * @notice The address to make rate calls to.
     */
    address public immutable target;

    /**
     * @notice The selector to call on the target.
     */
    bytes4 public immutable selector;

    /**
     * @notice Static arguments to pass to the target.
     */
    bytes32 public immutable staticArgument0;
    bytes32 public immutable staticArgument1;
    bytes32 public immutable staticArgument2;
    bytes32 public immutable staticArgument3;
    bytes32 public immutable staticArgument4;
    bytes32 public immutable staticArgument5;
    bytes32 public immutable staticArgument6;
    bytes32 public immutable staticArgument7;

    constructor(
        address _target,
        bytes4 _selctor,
        bytes32 _staticArgument0,
        bytes32 _staticArgument1,
        bytes32 _staticArgument2,
        bytes32 _staticArgument3,
        bytes32 _staticArgument4,
        bytes32 _staticArgument5,
        bytes32 _staticArgument6,
        bytes32 _staticArgument7
    ) {
        target = _target;
        selector = _selctor;
        staticArgument0 = _staticArgument0;
        staticArgument1 = _staticArgument1;
        staticArgument2 = _staticArgument2;
        staticArgument3 = _staticArgument3;
        staticArgument4 = _staticArgument4;
        staticArgument5 = _staticArgument5;
        staticArgument6 = _staticArgument6;
        staticArgument7 = _staticArgument7;

        // Make sure getRate succeeds.
        getRate();
    }

    // ========================================= RATE FUNCTION =========================================

    /**
     * @notice Get the rate of some generic asset.
     * @dev This function only supports selectors that only contain static arguments, dynamic arguments will not be encoded correctly,
     *      and calls will likely fail.
     * @dev If staticArgumentN is not used, it can be left as 0.
     */
    function getRate() public view returns (uint256) {
        bytes memory callData = abi.encodeWithSelector(
            selector,
            staticArgument0,
            staticArgument1,
            staticArgument2,
            staticArgument3,
            staticArgument4,
            staticArgument5,
            staticArgument6,
            staticArgument7
        );
        bytes memory result = target.functionStaticCall(callData);

        return abi.decode(result, (uint256));
    }
}
