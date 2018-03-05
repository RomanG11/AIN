pragma solidity ^0.4.19;

library SafeMath { //standart library for uint
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0){
        return 0;
    }
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function pow(uint256 a, uint256 b) internal pure returns (uint256){ //power function
    if (b == 0){
      return 1;
    }
    uint256 c = a**b;
    assert (c >= a);
    return c;
  }
}

//standart contract to identify owner
contract Ownable {

  address public owner;

  address public newOwner;

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function Ownable() public {
    owner = msg.sender;
  }

  function transferOwnership(address _newOwner) public onlyOwner {
    require(_newOwner != address(0));
    newOwner = _newOwner;
  }

  function acceptOwnership() public {
    if (msg.sender == newOwner) {
      owner = newOwner;
    }
  }
}

//Abstract Token contract
contract AinToken{
  function setCrowdsaleContract (address) public;
  function sendCrowdsaleTokens(address, uint256)  public;
  function burnTokens() public;
  function setIcoFinishedTrue () public;

}

//Crowdsale contract
contract Crowdsale is Ownable{

  using SafeMath for uint;

  uint decimals = 8;
  // Token contract address
  AinToken public token;

  // Constructor
  function Crowdsale(address _tokenAddress) public{
    token = AinToken(_tokenAddress);
    owner = msg.sender;

    token.setCrowdsaleContract(this);
  }
  
  address tokenDistribution1 = 0x1EECE4A2d1845319F5162221C6aaC885AF44bAA5;
  address tokenDistribution2 = 0x37041A0b698B802C3A44447b5532d1C6Da05C0dE;

  address teamAddress = 0x3E2017b68ec11e5c8733d38C4dFCb18a039D4C23;
  address foundationAddress = 0x3E2017b68ec11e5c8733d38C4dFCb18a039D4C23;


  struct AddressesStruct {
    address addr;
    uint percent;
  }

  AddressesStruct[] public bountyAddresses;
  // AddressesStruct[] public teamAddresses;
  
  function addBountryAddress(address _address, uint _percent) public onlyOwner {
    uint sum;
    for(uint i = 0; i<bountyAddresses.length; i++){
      require(bountyAddresses[i].addr != _address);
      sum = sum.add(bountyAddresses[i].percent);
    }
    require(sum.add(_percent) <= 100);
    AddressesStruct memory buffer;
    buffer.addr = _address;
    buffer.percent = _percent;

    bountyAddresses.push(buffer);
  }

  function changeBountryAddressPercent(address _address, uint _percent) public onlyOwner {
    uint sum;
    uint bufferIndex;
    for(uint i = 0; i<bountyAddresses.length; i++){
      if(bountyAddresses[i].addr == _address){
        bufferIndex = i;
      }
    }
    bountyAddresses[bufferIndex].percent = _percent;

    for(i = 0; i<bountyAddresses.length; i++){
      sum = sum.add(bountyAddresses[i].percent);
    }
    assert(sum.add(_percent) <= 100);
  }
  
  //Crowdsale variables
  uint public preIcoTokensSold = 0;
  uint public icoTokensSold = 0;
  uint public tokensSold = 0;
  uint public ethCollected = 0;

  // Buy constants
  // uint PreIcotokenPrice = 100000000000000/((uint)(10).pow(decimals));
  // uint icoTokenPrice = 150015000000000/((uint)(10).pow(decimals));

  // PreICO constants
  uint public preIcoStart = 0; //ASAP
  uint public preIcoFinish = 1523768400; // 04/15/2018 Midnight EST

  // Ico constants
  uint public icoStart = 1523768401; //04/15/2018 Midnight EST
  uint public icoFinish = 1529038800; //06/15/2018 Midnight EST

  // MaxCaps
  uint public preIcoMaxCap = (uint)(57500000).mul((uint)(10).pow(decimals)); //23%
  uint public icoMaxCap = (uint)(150000000).mul((uint)(10).pow(decimals));  //60%

  //check is now ICO
  function isPreIco(uint _time) public view returns (bool){
    if((preIcoStart <= _time) && (_time <= preIcoFinish)){
      return true;
    }
    return false;
  }

  //check is now ICO
  function isIco(uint _time) public view returns (bool){
    if((icoStart <= _time) && (_time <= icoFinish)){
      return true;
    }
    return false;
  }
  

  
  //fallback function (when investor send ether to contract)
  function() public payable{
    require(isPreIco(now) || isIco(now));
    
    if(msg.data.length > 0){
        buyTokensWithSalesFallback(msg.sender,bytesToUint(msg.data),msg.value);
    }
    else{
    require(buy(msg.sender,msg.value, now)); //redirect to func buy
    }
  }


  bool isIcoStarted = false;
  //function buy Tokens
  function buy(address _address, uint _value,uint _time) internal returns (bool){
    uint tokensForSend = etherToTokens(_value,_time);
    if (isPreIco(_time)){
      require(preIcoTokensSold.add(tokensForSend) <= preIcoMaxCap);
      preIcoTokensSold = preIcoTokensSold.add(tokensForSend);
    }else{
      if (!isIcoStarted){
        icoMaxCap = icoMaxCap.add(preIcoMaxCap.sub(preIcoTokensSold));
        isIcoStarted = true;
      }
      require(icoTokensSold.add(tokensForSend) <= icoMaxCap);
      icoTokensSold = icoTokensSold.add(tokensForSend);
    }
    
    tokensSold = tokensSold.add(tokensForSend);

    token.sendCrowdsaleTokens(_address,tokensForSend);

    tokenDistribution1.transfer(this.balance/2);
    tokenDistribution2.transfer(this.balance);

    return true;
  }

  //convert ether to tokens
  function etherToTokens(uint _value, uint _time) public view returns(uint res) {
    res = 0;
    if(isPreIco(_time)){
      res = _value/preIcoPriceAmount(_value);
    }
    if(isIco(_time)){
      res = _value/icoPriceAmount(_value);
    }
  }

  function endIco () public onlyOwner {
    require(now > icoFinish);
    
    uint percent7 = tokensSold.mul((uint)(7))/100;

    token.sendCrowdsaleTokens(foundationAddress,percent7);

    tokenDistrib();
    token.setIcoFinishedTrue();
    token.burnTokens();
  }

  function tokenDistrib () internal {
    uint percent3 = tokensSold.mul((uint)(3))/100;

    for (uint i = 0; i < bountyAddresses.length; i++){
      token.sendCrowdsaleTokens(bountyAddresses[i].addr, percent3.mul(bountyAddresses[i].percent)/100);
    }
  }

  function preIcoPriceAmount(uint _value) public view returns(uint) {
    if(_value < 10 ether){
      return 0.0001 ether/(uint)(10).pow(decimals);
    }
    if(_value < 25 ether){
      return 0.00009090909 ether/(uint)(10).pow(decimals);
    }    
    if(_value < 50 ether){
      return 0.00008333333 ether/(uint)(10).pow(decimals);
    }
    if(_value < 100 ether){
      return 0.00007692307 ether/(uint)(10).pow(decimals);
    }
    if(_value < 250 ether){
      return 0.00007142857 ether/(uint)(10).pow(decimals);
    }
    if(_value < 500 ether){
      return 0.00006666666 ether/(uint)(10).pow(decimals);
    }
    return 0.00005 ether/(uint)(10).pow(decimals);
  }

  function icoPriceAmount(uint _value) public view returns(uint) {
    if(_value < 10 ether){
      return 0.0002 ether/(uint)(10).pow(decimals);
    }
    if(_value < 25 ether){
      return 0.00018181818 ether/(uint)(10).pow(decimals);
    }    
    if(_value < 50 ether){
      return 0.00016666666 ether/(uint)(10).pow(decimals);
    }
    if(_value < 100 ether){
      return 0.00015384615 ether/(uint)(10).pow(decimals);
    }
    if(_value < 250 ether){
      return 0.00014285714 ether/(uint)(10).pow(decimals);
    }
    if(_value < 500 ether){
      return 0.00013333333 ether/(uint)(10).pow(decimals);
    }
    return 0.0001 ether/(uint)(10).pow(decimals);
  }

  //Sales functions
  function addSales(address _address, uint _commisson, uint _trackingNumber, uint _bonusToken) public onlyOwner{
    SalesStruct memory buffer;
    buffer.ethAddress = _address;
    buffer.commisson = _commisson;
    buffer.bonusToken = _bonusToken;
    buffer.trackingNumber = _trackingNumber;
    salesMap[_trackingNumber] = buffer;
    
    salesTrackingNumbers.push(_trackingNumber);
  }
  

  struct SalesStruct {
    address ethAddress;
    uint commisson;
    uint trackingNumber;
    uint bonusToken;
  }
  
  uint[] public salesTrackingNumbers;
  mapping (uint => SalesStruct) salesMap;
  

  function showSales(uint _trackingNumber) public view returns(address,uint,uint) {
    return (salesMap[_trackingNumber].ethAddress,salesMap[_trackingNumber].commisson,salesMap[_trackingNumber].bonusToken);
  }
  
  function buyTokensWithSales(uint _trackingNumber) public payable {
    require(salesMap[_trackingNumber].ethAddress != address(0));
    
    uint tokensForSend = etherToTokens(msg.value,now);
    tokensForSend = tokensForSend.add(tokensForSend.mul(salesMap[_trackingNumber].bonusToken)/100);
    token.sendCrowdsaleTokens(msg.sender,tokensForSend);
    salesMap[_trackingNumber].ethAddress.transfer(msg.value.mul(salesMap[_trackingNumber].commisson)/100);

    tokenDistribution1.transfer(this.balance/2);
    tokenDistribution2.transfer(this.balance);
  }

  function buyTokensWithSalesFallback(address _address,uint _trackingNumber, uint _value) internal {
     
    require(salesMap[_trackingNumber].ethAddress != address(0));
    
    uint tokensForSend = etherToTokens(_value,now);
    tokensForSend = tokensForSend.add(tokensForSend.mul(salesMap[_trackingNumber].bonusToken)/100);
    token.sendCrowdsaleTokens(_address,tokensForSend);
    salesMap[_trackingNumber].ethAddress.transfer(_value.mul(salesMap[_trackingNumber].commisson)/100);

    tokenDistribution1.transfer(this.balance/2);
    tokenDistribution2.transfer(this.balance);
  }


function bytesToUint(bytes _bytes) public pure returns(uint){
    uint result = 0;
    
    for (uint i = 0; i<_bytes.length; i++){
        uint buffer = (uint)(_bytes[_bytes.length-1-i]);

        result +=((buffer/16*10)+(buffer%16))*((uint)(10).pow(2*i));
    }
    return result;
}

}
