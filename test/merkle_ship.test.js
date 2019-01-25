var MerkleShip = artifacts.require('MerkleShip')

contract('MerkleShip', function(accounts) {

    const owner = accounts[0]
    const alice = accounts[1]
    const bob = accounts[2]

    //mostly useless test to check correct initialization
    it('should start with a game count of zero', async() => {
        let merkleShip = await MerkleShip.deployed()

        let count = await merkleShip.gameCount()

        assert.equal(count, 0, 'the contract start with a game state of zero')
    })

    //propose, no value
    it('should successfully propose a game with no value', async() => {
        let merkleShip = await MerkleShip.deployed()

        let mRoot = '0xdfaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c'
        let propose = await merkleShip.proposeGame(0, mRoot)
        let count = await merkleShip.gameCount()
        let state = await merkleShip.games.call(1)

        assert.equal(count, 1, 'the game count should correctly increment')
        assert.equal(state[3], accounts[0], 'player A should equal accounts[0]')
    })

    //propose, value
    it('should successfully propose a game with value', async() => {
        let merkleShip = await MerkleShip.deployed()

        let mRoot = '0xefaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c'
        let propose = await merkleShip.proposeGame(1, mRoot, { value: 1 } )
        let count = await merkleShip.gameCount()

        assert.equal(count, 2, 'the game count should correctly increment')
    })

    //cancel
    it('should be able to cancel a proposed game', async() => {
        let merkleShip = await MerkleShip.deployed()

        let cancel = await merkleShip.cancelProposedGame(1)
        let state = await merkleShip.games.call(1)

        assert.equal(state[8], 1, 'the game should be canceled ')
    })

    //accept
    it('should be able to accept a proposed game', async() => {
        let merkleShip = await MerkleShip.deployed()

        let mRoot = '0xffaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c'
        let cancel = await merkleShip.acceptGame(2, mRoot, { value: 1, from: alice } )
        let state = await merkleShip.games.call(2)

        assert.equal(state[8], 2, 'the game state should be active')
        assert.equal(state[3], accounts[0], 'player A should equal accounts[0]')
        assert.equal(state[4], accounts[1], 'player B should equal accounts[1]')
    })

    //concede
    it('should be able to concede an active game', async() => {
        let merkleShip = await MerkleShip.deployed()

        let concede = await merkleShip.concedeGame(2)
        let state = await merkleShip.games.call(2)

        assert.equal(state[8], 6, 'the game state should be complete')
        assert.equal(state[5], accounts[1], 'player B should be the winner')
    })

});

//@dev do I need to forumlate the proofs for each move from both teams to write a test for the end of game state?