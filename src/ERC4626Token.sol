// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

error InvalidAddress();
error ZeroAmount();
error InsufficientShares();
error InsufficientAllowance();
error SlippageExceeded();
error TransferFailed();

contract ERC4626Token {
    IERC20 public immutable asset;
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        if (address(_asset) == address(0)) revert InvalidAddress();
        asset = _asset;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        if (totalSupply == 0) return assets;
        uint256 ta = totalAssets();
        if (ta == 0) return assets;
        return assets * totalSupply / ta;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalSupply == 0) return shares;
        return shares * totalAssets() / totalSupply;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        if (totalSupply == 0) return assets;
        uint256 ta = totalAssets();
        if (ta == 0) return assets;
        return (assets * totalSupply + ta - 1) / ta; // rounding up
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidAddress();
        if (assets == 0) revert ZeroAmount();

        shares = previewDeposit(assets);

        _safeTransferFrom(asset, msg.sender, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares) {
        if (receiver == address(0) || owner == address(0)) revert InvalidAddress();
        if (assets == 0) revert ZeroAmount();

        shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burn(owner, shares);
        _safeTransfer(asset, receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets) {
        if (receiver == address(0) || owner == address(0)) revert InvalidAddress();
        if (shares == 0) revert ZeroAmount();

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        assets = previewRedeem(shares);

        _burn(owner, shares);
        _safeTransfer(asset, receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert InvalidAddress();

        uint256 bal = balances[from];
        if (bal < value) revert InsufficientShares();

        unchecked {
            balances[from] = bal - value;
            balances[to] += value;
        }

        emit Transfer(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        if (owner == address(0) || spender == address(0)) revert InvalidAddress();

        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 current = allowances[owner][spender];
        if (current < value) revert InsufficientAllowance();

        if (current != type(uint256).max) {
            unchecked {
                allowances[owner][spender] = current - value;
            }
            emit Approval(owner, spender, allowances[owner][spender]);
        }
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert InvalidAddress();

        totalSupply += value;
        balances[to] += value;

        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        uint256 bal = balances[from];
        if (bal < value) revert InsufficientShares();

        unchecked {
            balances[from] = bal - value;
            totalSupply -= value;
        }

        emit Transfer(from, address(0), value);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(token.transfer.selector, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
