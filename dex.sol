// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract DEX {
    IERC20 public token;
    uint256 public ethReserve;
    uint256 public tokenReserve;

    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event TokensSwapped(address indexed trader, uint256 inputAmount, uint256 outputAmount, string tradeType);

    constructor(IERC20 _token) {
        token = _token;
    }

    function addLiquidity(uint256 tokenAmount) public payable {
        require(msg.value > 0 && tokenAmount > 0);
        if (ethReserve == 0 && tokenReserve == 0) {
            require(token.transferFrom(msg.sender, address(this), tokenAmount));
            ethReserve += msg.value;
            tokenReserve += tokenAmount;
        } else {
            uint256 ethRatio = (msg.value * tokenReserve) / ethReserve;
            require(tokenAmount >= ethRatio);
            require(token.transferFrom(msg.sender, address(this), ethRatio));
            ethReserve += msg.value;
            tokenReserve += ethRatio;
        }
        emit LiquidityAdded(msg.sender, msg.value, tokenAmount);
    }

    function removeLiquidity(uint256 liquidity) public {
        require(liquidity > 0 && liquidity <= ethReserve);
        uint256 tokenAmount = (liquidity * tokenReserve) / ethReserve;
        ethReserve -= liquidity;
        tokenReserve -= tokenAmount;
        payable(msg.sender).transfer(liquidity);
        require(token.transfer(msg.sender, tokenAmount));
        emit LiquidityRemoved(msg.sender, liquidity, tokenAmount);
    }

    function swapETHForTokens() public payable {
        require(msg.value > 0);
        uint256 tokensOut = getOutputAmount(msg.value, ethReserve, tokenReserve);
        ethReserve += msg.value;
        tokenReserve -= tokensOut;
        require(token.transfer(msg.sender, tokensOut));
        emit TokensSwapped(msg.sender, msg.value, tokensOut, "ETH to Token");
    }

    function swapTokensForETH(uint256 tokenAmount) public {
        require(tokenAmount > 0);
        uint256 ethOut = getOutputAmount(tokenAmount, tokenReserve, ethReserve);
        tokenReserve += tokenAmount;
        ethReserve -= ethOut;
        require(token.transferFrom(msg.sender, address(this), tokenAmount));
        payable(msg.sender).transfer(ethOut);
        emit TokensSwapped(msg.sender, tokenAmount, ethOut, "Token to ETH");
    }

    function getOutputAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0);
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }

    function getReserves() public view returns (uint256, uint256) {
        return (ethReserve, tokenReserve);
    }
}
