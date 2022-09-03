// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";

contract AccessControl {
    mapping(uint8 => address) private _roles;

    uint8 public constant ADMIN_ROLE = 0;

    /**
     * @dev Modifier that checks that an account is specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role [0,254]/
     *
     */
    modifier onlyRole(uint8 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev Returns `true` if `account` is `role`.
     */
    function isRole(uint8 role, address account) public view returns (bool) {
        return _roles[role] == account;
    }

    /**
     * @dev Revert with a standard message if `msg.sender` is not `role`.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     */
    function _checkRole(uint8 role) internal view {
        _checkRole(role, msg.sender);
    }

    /**
     * @dev Revert with a standard message if `account` is not `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role [0,254]/
     */
    function _checkRole(uint8 role, address account) internal view {
        if (!isRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is not role ",
                        Strings.toString(uint256(role))
                    )
                )
            );
        }
    }

    /**
     * @dev set `role` to `account`.
     *
     * Requirements:
     *
     * - the caller must be `ADMIN_ROLE`.
     */
    function setRole(uint8 role, address account) public onlyRole(ADMIN_ROLE) {
        _setRole(role, account);
    }

    function _setRole(uint8 role, address account) internal virtual {
        _roles[role] = account;
    }
}
