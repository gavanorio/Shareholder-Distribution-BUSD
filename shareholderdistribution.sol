// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; 
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

}

contract DistributionContract is Context, Ownable {
    IERC20 public token;
    address payable public tokenHolder;

    mapping (address => uint) distributionPercentages;
    mapping (address => uint) arrayPosition;
    mapping(address => bool) exists;
    address[] distributionAddresses;
    uint[] percentages;
    uint masterSum;

    event Validate(uint sum, bool result);
    event Sent(address from, address to, uint amount );

    constructor() {
        tokenHolder = payable(0x000000000000000000000000000000000000dEaD); //CAMBIAR A WALLET TOKENHOLDER
        token = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); //BUSD

        //LISTA DE SOCIOS Y PORCENTAJES SE INICIALIZA VACIO
        //USAR LA FUNCION addAddressToDistribution O addAddressesFromArray PARA AGREGAR SOCIOS A LA LISTA

    }
    
    function changeTokenHolder(address payable _newTokenHolder) external onlyOwner(){
        tokenHolder = _newTokenHolder;
    }

    function addAddressToDistribution(address _address, uint _percentAmount) external onlyOwner(){
        require(exists[_address] == false, "the address already exists on the list. Please delete it or replace its value using the appropiate functions");
        distributionAddresses.push(_address);
        distributionPercentages[_address]=_percentAmount;
        exists[_address] = true;
        updatePercentages();
    }

    function removeAddressFromDistribution(address _address) external onlyOwner(){
        require(exists[_address] == true, "the address does not exist");
        delete distributionAddresses[arrayPosition[_address]];
        distributionPercentages[_address]=0;
        exists[_address] = false;
        updatePercentages();
    }

    function editAddressFromDistribution(address _address, uint _newPercentAmount) external onlyOwner(){
        require(exists[_address] == true, "the address does not exist");
        distributionPercentages[_address]=_newPercentAmount;
        updatePercentages();
    }

    function cleanDistributionArray() external onlyOwner(){
        uint i = 0;

        while (i<distributionAddresses.length) {
            exists[distributionAddresses[i]] = false;
            arrayPosition[distributionAddresses[i]] = 0;
            distributionPercentages[distributionAddresses[i]] = 0;
            i++;
        }
        delete distributionAddresses;
        delete percentages;
    }


    function addAddressesFromArray(address[] memory _addresses, uint[] memory _percentAmounts) external onlyOwner(){
        require(_addresses.length == _percentAmounts.length, "Array lenghts do not match");

        uint i = 0;

        while (i<_addresses.length) {
            addAddressToDistributionNoUpdate(_addresses[i], _percentAmounts[i]);
            i++;
        }
        updatePercentages();
    }

    function addAddressToDistributionNoUpdate(address _address, uint _percentAmount) internal{
        require(exists[_address] == false, "the address already exists on the list. Please delete it or replace its value using the appropiate functions");
        distributionAddresses.push(_address);
        distributionPercentages[_address]=_percentAmount;
        exists[_address] = true;
    }


    function updatePercentages() internal{
        delete percentages;
        uint i = 0;

        while (i<distributionAddresses.length) {
            percentages.push(distributionPercentages[distributionAddresses[i]]);
            i++;
        }

        uint j = 0;

        while (j<distributionAddresses.length) {
            arrayPosition[distributionAddresses[j]] = j;
            j++;
        }

    }

    function getListOfAddresses() public view returns (address[] memory){
        return distributionAddresses;
    }

    function getListOfAddressesAndPercentages() public view returns (address[] memory, uint[] memory){
        return (distributionAddresses,percentages);
    }

    function validate() internal view returns (bool){
        uint i = 0;
        uint sum = 0;

        while (i<percentages.length) {
            sum = sum + percentages[i];
            i++;
        }

        if (sum == 100){
            return true;
        }
        else{
            return false;
        }

    }

    function getBalanceFromHolder() public view returns(uint) {
        uint balance_ = token.balanceOf(tokenHolder);
        return balance_;
    }
        
    function transact(uint amount, address recipient) internal {
        token.transferFrom(msg.sender, recipient, amount);
    }

    function calculateAmountToDistribute(uint amount, uint percent) internal returns(uint){
        uint amountToDistribute = amount*percent/100;
        return amountToDistribute;
    }

    function distributeTokens(uint amount) external onlyOwner(){
        require(amount <= token.balanceOf(tokenHolder), "you don't have enough balance.");
        bool validated = validate();
        require(validated == true, "Sum of percentages not equal to 100, can't execute transaction");

        uint i = 0;
        address payable transferAddress;
        uint amountToDistribute;


        while (i<distributionAddresses.length) {
            transferAddress = payable(distributionAddresses[i]);
            amountToDistribute = calculateAmountToDistribute(amount, percentages[i]);
            transact(amountToDistribute,transferAddress);
            i++;
        }

    }

    function changeDistributionToken (IERC20 _tokenAddress) external onlyOwner(){
        token = _tokenAddress;
    }

    function getDistributionToken() public view returns(IERC20){
        return token;
    }
    
}
