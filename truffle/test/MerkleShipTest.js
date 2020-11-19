const truffleAssert = require('truffle-assertions');
const MerkleShip = artifacts.require('MerkleShip');
const SafeMath = artifacts.require('SafeMath');
const ProxySafeMath = artifacts.require('ProxySafeMath');

contract('MerkleShip', (accounts) => {
  let trace = false;
  let contractSafeMath = null;
  let contractMerkleShip = null;
  beforeEach(async () => {
    contractSafeMath = await SafeMath.new({from: accounts[0]});
    if (trace) console.log('SUCESSO: SafeMath.new({from: accounts[0]}');
    MerkleShip.link('SafeMath', contractSafeMath.address);
    contractMerkleShip = await MerkleShip.new({from: accounts[0]});
    if (trace) console.log('SUCESSO: MerkleShip.new({from:accounts[0]}');
  });

  it('Should fail emergencyStop(string) when NOT comply with: msg.sender == admin', async () => {
    let result = await truffleAssert.fails(
      contractMerkleShip.emergencyStop('verified victory by hit count', {
        from: accounts[9],
      }),
      'revert',
    );
  });
  it('Should fail proposeGame(uint96,bytes32) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('verified victory by hit count', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.proposeGame(
        3,
        [
          96,
          251,
          98,
          44,
          211,
          120,
          101,
          117,
          167,
          1,
          145,
          29,
          84,
          5,
          190,
          231,
          59,
          65,
          190,
          85,
          215,
          217,
          37,
          195,
          89,
          154,
          51,
          60,
          189,
          121,
          106,
          5,
        ],
        {from: accounts[0], value: 3},
      ),
      'revert',
    );
  });
  it('Should fail proposeGame(uint96,bytes32) when NOT comply with: msg.value == _wager', async () => {
    let result = await truffleAssert.fails(
      contractMerkleShip.proposeGame(
        4,
        [
          96,
          251,
          98,
          44,
          211,
          120,
          101,
          117,
          167,
          1,
          145,
          29,
          84,
          5,
          190,
          231,
          59,
          65,
          190,
          85,
          215,
          217,
          37,
          195,
          89,
          154,
          51,
          60,
          189,
          121,
          106,
          5,
        ],
        {from: accounts[0], value: 3},
      ),
      'revert',
    );
  });
  it('Should fail acceptGame(uint32,bytes32) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('victory by unanswered challenge', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.acceptGame(
        49,
        [
          66,
          187,
          18,
          217,
          232,
          105,
          226,
          26,
          177,
          44,
          120,
          174,
          121,
          177,
          222,
          38,
          184,
          228,
          192,
          73,
          129,
          96,
          242,
          174,
          83,
          217,
          148,
          248,
          80,
          67,
          4,
          252,
        ],
        {from: accounts[0]},
      ),
      'revert',
    );
  });
  it('Should fail cancelProposedGame(uint32) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('victory by abandonment', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.cancelProposedGame(9, {from: accounts[0]}),
      'revert',
    );
  });
  it('Should fail guessAndReveal(uint32,uint8[2],bytes32[6],string,string) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('victory by abandonment', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.guessAndReveal(
        3,
        [8, 181],
        [
          [
            254,
            134,
            12,
            109,
            81,
            17,
            83,
            148,
            154,
            221,
            219,
            7,
            135,
            120,
            22,
            233,
            179,
            52,
            60,
            144,
            28,
            17,
            57,
            150,
            60,
            98,
            16,
            63,
            26,
            148,
            255,
            247,
          ],
          [
            49,
            16,
            199,
            160,
            33,
            76,
            178,
            22,
            73,
            156,
            241,
            190,
            161,
            20,
            244,
            45,
            2,
            110,
            86,
            173,
            169,
            253,
            105,
            244,
            117,
            7,
            115,
            74,
            213,
            251,
            217,
            232,
          ],
          [
            155,
            156,
            164,
            79,
            230,
            133,
            45,
            207,
            185,
            10,
            228,
            19,
            210,
            203,
            115,
            89,
            26,
            139,
            180,
            177,
            241,
            40,
            228,
            85,
            45,
            35,
            129,
            89,
            85,
            127,
            34,
            227,
          ],
          [
            133,
            205,
            228,
            67,
            72,
            52,
            1,
            15,
            208,
            236,
            253,
            69,
            164,
            199,
            203,
            188,
            128,
            238,
            109,
            228,
            214,
            112,
            201,
            162,
            100,
            57,
            208,
            55,
            144,
            108,
            31,
            130,
          ],
          [
            85,
            217,
            28,
            206,
            254,
            62,
            138,
            79,
            242,
            231,
            111,
            202,
            18,
            233,
            145,
            130,
            10,
            136,
            218,
            37,
            231,
            64,
            112,
            155,
            92,
            33,
            73,
            89,
            171,
            81,
            3,
            109,
          ],
          [
            15,
            180,
            73,
            109,
            170,
            247,
            204,
            159,
            24,
            49,
            24,
            110,
            197,
            246,
            191,
            63,
            227,
            245,
            243,
            223,
            38,
            153,
            116,
            59,
            146,
            83,
            152,
            26,
            219,
            154,
            59,
            251,
          ],
        ],
        'victory by unanswered challenge',
        'victory by unanswered challenge',
        {from: accounts[0]},
      ),
      'revert',
    );
  });
  it('Should fail resolveAbandonedGame(uint32) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('game resolved in an emergency', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.resolveAbandonedGame(48, {from: accounts[0]}),
      'revert',
    );
  });
  it('Should fail concedeGame(uint32) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('victory by abandonment', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.concedeGame(180, {from: accounts[0]}),
      'revert',
    );
  });
  it('Should fail challengeVictory(uint32) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('victory by concession', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.challengeVictory(181, {from: accounts[0]}),
      'revert',
    );
  });
  it('Should fail answerChallenge(uint32,string[64]) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('kgrwbq', {from: accounts[0]});
    let result = await truffleAssert.fails(
      contractMerkleShip.answerChallenge(
        7,
        [
          'verified victory by hit count',
          'verified victory by hit count',
          'verified victory by hit count',
          'game resolved in an emergency',
          'b4d56u',
          'victory by abandonment',
          'victory by abandonment',
          'sys3tf',
          'b4d56u',
          'victory by unchallenged hit count',
          'verified victory by hit count',
          'victory by concession',
          'victory by concession',
          'sys3tf',
          'verified victory by hit count',
          'sys3tf',
          'victory by concession',
          'victory by unanswered challenge',
          'sys3tf',
          'victory by abandonment',
          'victory by abandonment',
          'game resolved in an emergency',
          'victory by unanswered challenge',
          'verified victory by hit count',
          'victory by abandonment',
          'sys3tf',
          'b4d56u',
          'game resolved in an emergency',
          'victory by unanswered challenge',
          'victory by abandonment',
          'victory by concession',
          'sys3tf',
          'verified victory by hit count',
          'hlxngq',
          'verified victory by hit count',
          'kgrwbq',
          'kgrwbq',
          'hlxngq',
          'victory by abandonment',
          'verified victory by hit count',
          'victory by unanswered challenge',
          'hlxngq',
          'sys3tf',
          'game resolved in an emergency',
          'victory by unchallenged hit count',
          'ou8jvi',
          'sys3tf',
          'victory by unchallenged hit count',
          'victory by concession',
          'victory by abandonment',
          'sys3tf',
          'b4d56u',
          'irikqq',
          'b4d56u',
          'hlxngq',
          '3ylshw',
          '1ubo7l',
          'b4d56u',
          'victory by unchallenged hit count',
          'irikqq',
          'game resolved in an emergency',
          'victory by abandonment',
          'sys3tf',
          'victory by abandonment',
        ],
        {from: accounts[0]},
      ),
      'revert',
    );
  });
  it('Should fail resolveUnclaimedVictory(uint32) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('verified victory by hit count', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.resolveUnclaimedVictory(100, {from: accounts[0]}),
      'revert',
    );
  });
  it('Should fail resolveUnansweredChallenge(uint32) when NOT comply with: isStopped == false', async () => {
    await contractMerkleShip.emergencyStop('victory by abandonment', {
      from: accounts[0],
    });
    let result = await truffleAssert.fails(
      contractMerkleShip.resolveUnansweredChallenge(12, {from: accounts[0]}),
      'revert',
    );
  });
  it('Should fail emergencyResolve(uint32) when NOT comply with: isStopped == true', async () => {
    let result = await truffleAssert.fails(
      contractMerkleShip.emergencyResolve(7, {from: accounts[0]}),
      'revert',
    );
  });
});
