var MerkleShip = artifacts.require("./MerkleShip.sol");

module.exports = function(deployer) {
  deployer.deploy(MerkleShip);
};
