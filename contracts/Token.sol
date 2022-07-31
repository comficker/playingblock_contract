//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FITNToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 constant startTime = 1632321000;
    uint256 constant endTime = startTime + 60;
    mapping(address => bool) public whitelist;

    constructor() ERC20("FITN", "FITN"){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, 25e7 ether);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     * - Allow whitelist only for 1 minute after listing PancakeSwap
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (block.timestamp >= startTime && block.timestamp <= endTime) {
            require(whitelist[recipient], 'FITN: not in whitelist');
        }

        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Add whitelist token addresses
     *
     */
    function setupWhitelist(address[] calldata whitelistAddresses) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            whitelist[whitelistAddresses[i]] = true;
        }
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
