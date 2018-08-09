var Bookkeeper = artifacts.require("Bookkeeper");
module.exports = function(deployer) {
  deployer.deploy(Bookkeeper);
};
