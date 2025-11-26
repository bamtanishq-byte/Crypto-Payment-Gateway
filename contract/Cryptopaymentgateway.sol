// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CryptoPaymentGateway
 * @dev A decentralized payment gateway for processing crypto payments
 */
contract CryptoPaymentGateway {
    
    // Merchant structure
    struct Merchant {
        address payable walletAddress;
        string businessName;
        bool isActive;
        uint256 totalTransactions;
        uint256 totalAmountReceived;
    }
    
    // Payment structure
    struct Payment {
        address payer;
        address merchant;
        uint256 amount;
        uint256 timestamp;
        string orderId;
        bool isCompleted;
    }
    
    // State variables
    mapping(address => Merchant) public merchants;
    mapping(string => Payment) public payments;
    mapping(address => string[]) public merchantPayments;
    
    address public owner;
    uint256 public platformFeePercentage; // Fee in basis points (e.g., 250 = 2.5%)
    uint256 public totalPlatformFees;
    
    // Events
    event MerchantRegistered(address indexed merchantAddress, string businessName);
    event PaymentProcessed(address indexed payer, address indexed merchant, uint256 amount, string orderId);
    event PaymentCompleted(string orderId, uint256 amount);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyActiveMerchant() {
        require(merchants[msg.sender].isActive, "Merchant is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        platformFeePercentage = 250; // Default 2.5% fee
    }
    
    /**
     * @dev Register a new merchant
     * @param _businessName Name of the merchant's business
     */
    function registerMerchant(string memory _businessName) public {
        require(!merchants[msg.sender].isActive, "Merchant already registered");
        require(bytes(_businessName).length > 0, "Business name cannot be empty");
        
        merchants[msg.sender] = Merchant({
            walletAddress: payable(msg.sender),
            businessName: _businessName,
            isActive: true,
            totalTransactions: 0,
            totalAmountReceived: 0
        });
        
        emit MerchantRegistered(msg.sender, _businessName);
    }
    
    /**
     * @dev Process a payment to a merchant
     * @param _merchantAddress Address of the merchant
     * @param _orderId Unique order identifier
     */
    function processPayment(address _merchantAddress, string memory _orderId) public payable {
        require(msg.value > 0, "Payment amount must be greater than 0");
        require(merchants[_merchantAddress].isActive, "Merchant is not active");
        require(payments[_orderId].amount == 0, "Order ID already exists");
        
        // Calculate platform fee
        uint256 platformFee = (msg.value * platformFeePercentage) / 10000;
        uint256 merchantAmount = msg.value - platformFee;
        
        // Store payment details
        payments[_orderId] = Payment({
            payer: msg.sender,
            merchant: _merchantAddress,
            amount: msg.value,
            timestamp: block.timestamp,
            orderId: _orderId,
            isCompleted: false
        });
        
        // Update merchant statistics
        merchants[_merchantAddress].totalTransactions++;
        merchants[_merchantAddress].totalAmountReceived += merchantAmount;
        merchantPayments[_merchantAddress].push(_orderId);
        
        // Transfer funds
        totalPlatformFees += platformFee;
        merchants[_merchantAddress].walletAddress.transfer(merchantAmount);
        
        // Mark payment as completed
        payments[_orderId].isCompleted = true;
        
        emit PaymentProcessed(msg.sender, _merchantAddress, msg.value, _orderId);
        emit PaymentCompleted(_orderId, msg.value);
    }
    
    /**
     * @dev Get merchant details
     * @param _merchantAddress Address of the merchant
     */
    function getMerchantDetails(address _merchantAddress) public view returns (
        string memory businessName,
        bool isActive,
        uint256 totalTransactions,
        uint256 totalAmountReceived
    ) {
        Merchant memory merchant = merchants[_merchantAddress];
        return (
            merchant.businessName,
            merchant.isActive,
            merchant.totalTransactions,
            merchant.totalAmountReceived
        );
    }
    
    /**
     * @dev Get payment details by order ID
     * @param _orderId Order identifier
     */
    function getPaymentDetails(string memory _orderId) public view returns (
        address payer,
        address merchant,
        uint256 amount,
        uint256 timestamp,
        bool isCompleted
    ) {
        Payment memory payment = payments[_orderId];
        return (
            payment.payer,
            payment.merchant,
            payment.amount,
            payment.timestamp,
            payment.isCompleted
        );
    }
    
    /**
     * @dev Withdraw accumulated platform fees (only owner)
     */
    function withdrawPlatformFees() public onlyOwner {
        uint256 amount = totalPlatformFees;
        require(amount > 0, "No fees to withdraw");
        
        totalPlatformFees = 0;
        payable(owner).transfer(amount);
        
        emit FeesWithdrawn(owner, amount);
    }
    
    /**
     * @dev Update platform fee percentage (only owner)
     * @param _newFeePercentage New fee percentage in basis points
     */
    function updatePlatformFee(uint256 _newFeePercentage) public onlyOwner {
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }
    
    /**
     * @dev Deactivate a merchant (only owner)
     * @param _merchantAddress Address of the merchant to deactivate
     */
    function deactivateMerchant(address _merchantAddress) public onlyOwner {
        require(merchants[_merchantAddress].isActive, "Merchant is not active");
        merchants[_merchantAddress].isActive = false;
    }
    
    /**
     * @dev Get all payment IDs for a merchant
     * @param _merchantAddress Address of the merchant
     */
    function getMerchantPayments(address _merchantAddress) public view returns (string[] memory) {
        return merchantPayments[_merchantAddress];
    }
    
    // Fallback function
    receive() external payable {
        revert("Direct payments not accepted. Use processPayment function");
    }
}
