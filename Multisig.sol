// "SPDX-License-Identifier: AGPL-3.0"
pragma solidity 0.7.5;
//pragma experimental ABIEncoderV2;

// 2of3 Multisig wallet.
// Receives from any address, requires 2 of 3 signatories send

// JS VM top 3 addresses for deployment use - 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db

contract MultiSig {
    struct Transaction {
        uint id;
        address multisig0;
        address multisig1;
        address recipient;
        uint amount;
        uint confs;
    }
    
    Transaction[] private transactions;
    
    uint private balance; // actual account balance
    uint private pendingBalance; // account balance after pending transactions
    
    address[3] private multisig;
    
    event newTransaction(uint id, address signatory, address to, uint amount);
    event newTransactionConf(uint id, address signatory);
    event paymentTransfer(uint id, address to, uint amount);
    
    constructor(address _multisig0, address _multisig1, address _multisig2) {
        // Sanity check, must be 3 different signatory addresses
        require(_multisig0 != _multisig1 && _multisig0 != _multisig2 && _multisig1 != _multisig2, "Must have 3 different signatory addresses.");
        
        multisig = [_multisig0, _multisig1, _multisig2]; // Set initial multisig addresses on creation
        balance = 0;
        pendingBalance = 0;
    }
    
    modifier onlyOwner() {
        require(msg.sender == multisig[0] || msg.sender == multisig[1] || msg.sender == multisig[2], "Function not initiated by contract owner.");
        _; // If true, continue execution
    }

    function setMultisig(uint _index, address _newMultisig) public onlyOwner {
        multisig[_index] = _newMultisig;
    }
    
    function getMultisig() public view returns(address[3] memory)
    {
        return multisig;
    }
    
    function getBalance() public view returns(uint) {
        return balance;
    }
    
    function getPendingBalance() public view returns(uint) {
        return pendingBalance;
    }
    
    function receiveFunds() public payable{
        balance += msg.value;
        pendingBalance += msg.value;
    }
    
    function createTransaction(address _recipient, uint _amount) public onlyOwner {
        // Create new transaction struct
        Transaction memory _newTransaction;
        
        require(msg.sender != _recipient, "Cannot send to signatories.");
        require(balance >= _amount && pendingBalance >= _amount, "Not enough funds to transact.");
        
        _newTransaction.id = transactions.length;
        _newTransaction.multisig0 = msg.sender;
        _newTransaction.multisig1 = address(0x0);
        _newTransaction.recipient = _recipient;
        _newTransaction.amount = _amount;
        _newTransaction.confs = 1;
        
        // Push the new Transaction struct to the transactions array
        transactions.push(_newTransaction);
        
        pendingBalance -= _amount;
        
        emit newTransaction(_newTransaction.id, msg.sender, _newTransaction.recipient, _newTransaction.amount);
    }
    
    function confirmTransaction(uint _id) public onlyOwner {
        // confirm transaction exists with only 1 signatory confimation
        require(transactions[_id].confs < 2, "Transaction already confirmed.");
        
        // <pedantic checking>
        // confirm multisig0 is not a 0 address
        require(transactions[_id].multisig0 != address(0x0), "!!Error: MultiSig0 is a 0 address!!");
        
        // confirm multisig1 is a 0 address
        require(transactions[_id].multisig1 == address(0x0), "!!Error: MultiSig1 is not a 0 address!!");
        // </pedantic checking>
        
        // confirm msg.sender has not already confirmed the transaction
        require(msg.sender != transactions[_id].multisig0, "Transaction already signed by this signatory.");
        
        transactions[_id].multisig1 = msg.sender;
        transactions[_id].confs = 2;
        
        emit newTransactionConf(_id, msg.sender);
        
        processTransaction(transactions[_id].id, transactions[_id].recipient, transactions[_id].amount);
    }
    
    function getTransaction(uint _id) public view returns(uint id, address multisig0, address multisig1, address recipient, uint amount, uint confs) {
        return(transactions[_id].id, transactions[_id].multisig0, transactions[_id].multisig1, transactions[_id].recipient, transactions[_id].amount, transactions[_id].confs);
    }
    
    function processTransaction(uint _id, address _recipient, uint _amount) public payable onlyOwner {
        address payable sendTransfer = address(uint160(_recipient));
        balance -= _amount;
        
        sendTransfer.transfer(_amount); // On error revert
        
        emit paymentTransfer(_id, _recipient, _amount);
    }
    
    function toWei(uint _ether) public pure returns(uint) {
        uint _wei = _ether * 1e18;
        
        return _wei;
    }
}