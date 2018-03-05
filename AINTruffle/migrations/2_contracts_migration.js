var Token = artifacts.require("./AinToken.sol");
var Crowdsale = artifacts.require("./Crowdsale.sol");

module.exports = function(deployer) {
  deployer.deploy(Token).then(function(){
  	return deployer.deploy(Crowdsale,Token.address);
  });
}
