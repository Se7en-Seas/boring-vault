pragma solidity 0.8.21;

import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract GenericRateProvider is IRateProvider {
    using Address for address;

    address public immutable target;
    bytes4 public immutable selector;
    uint256 public immutable staticArgument0;
    uint256 public immutable staticArgument1;
    uint256 public immutable staticArgument2;
    uint256 public immutable staticArgument3;

    constructor(address _target, bytes4 _selctor, uint256 _staticArgument0, uint256 _staticArgument1, uint256 _staticArgument2, uint256 _staticArgument3) {
        target = _target;
        selector = _selctor;
        staticArgument0 = _staticArgument0;
        staticArgument1 = _staticArgument1;
        staticArgument2 = _staticArgument2;
        staticArgument3 = _staticArgument3;

        // Make sure getRate succeeds.
        getRate();
    }

    /**
     * @notice Get the rate of some generic asset.
     * @dev This function only supports selectors that only contain static arguments, dynamic arguments will not be encoded correctly,
     *      and calls will likely fail.
     * @dev If staticArgumentN is not used, it can be left as 0.
     */
    function getRate() public view returns (uint256) {
        bytes memory callData = abi.encodeWithSelector(selector, staticArgument0, staticArgument1, staticArgument2, staticArgument3);
        bytes memory result = target.functionStaticCall(callData);

        return abi.decode(result, (uint256));
    }

}