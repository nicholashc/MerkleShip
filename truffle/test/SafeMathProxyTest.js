const truffleAssert = require('truffle-assertions');
const MerkleShip = artifacts.require('MerkleShip');
const SafeMath = artifacts.require('SafeMath');
const ProxySafeMath = artifacts.require('ProxySafeMath');

contract('contractProxySafeMath', (accounts) => {
  let contractProxySafeMath = null;
  let trace = false;
  let contractSafeMath = null;
  let contractMerkleShip = null;
  beforeEach(async () => {
    contractSafeMath = await SafeMath.new({from: accounts[0]});
    if (trace) console.log('SUCESSO: SafeMath.new({from: accounts[0]}');
    MerkleShip.link('SafeMath', contractSafeMath.address);
    contractMerkleShip = await MerkleShip.new({from: accounts[0]});
    if (trace) console.log('SUCESSO: MerkleShip.new({from:accounts[0]}');
    ProxySafeMath.link('SafeMath', contractSafeMath.address);
    contractProxySafeMath = await ProxySafeMath.new({from: accounts[0]});
  });

  it('Should fail testdiv(uint256,uint256) when NOT comply with: b > 0', async () => {
    let result = await truffleAssert.fails(
      contractProxySafeMath.testdiv(11, 0, {from: accounts[0]}),
      'revert',
    );
  });
  it('Should fail testsub(uint256,uint256) when NOT comply with: b <= a', async () => {
    let result = await truffleAssert.fails(
      contractProxySafeMath.testsub(101, 102, {from: accounts[0]}),
      'revert',
    );
  });
  it('Should fail testmod(uint256,uint256) when NOT comply with: b != 0', async () => {
    let result = await truffleAssert.fails(
      contractProxySafeMath.testmod(48, 0, {from: accounts[0]}),
      'revert',
    );
  });
});
