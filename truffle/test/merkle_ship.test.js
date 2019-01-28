var MerkleShip = artifacts.require('MerkleShip')

contract('MerkleShip', function(accounts) {

    const owner = accounts[0]
    const alice = accounts[1]
    const bob = accounts[2]

    /** basic test to verify correct initialization */
    it('should start with a game count of zero', async() => {
        let merkleShip = await MerkleShip.deployed()

        let count = await merkleShip.gameCount()

        assert.equal(count, 0, 'the contract start with a game state of zero')
    })

    /** propose a game with no value and verify it's state */
    it('should successfully propose a game with no value', async() => {
        let merkleShip = await MerkleShip.deployed()

        let mRoot = '0xdfaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c'
        let propose = await merkleShip.proposeGame(0, mRoot, { from: bob })
        let count = await merkleShip.gameCount()
        let state = await merkleShip.games.call(1)

        assert.equal(count, 1, 'the game count should correctly increment')
        assert.equal(state[3], bob, 'player A should equal accounts[0]')
    })

    /** propose a game with value and verify it's state */
    it('should successfully propose a game with value', async() => {
        let merkleShip = await MerkleShip.deployed()

        let mRoot = '0xefaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c'
        let propose = await merkleShip.proposeGame(1, mRoot, { value: 1, from: bob } )
        let count = await merkleShip.gameCount()

        assert.equal(count, 2, 'the game count should correctly increment')
    })

    /** cancel a game and verify it's state*/
    it('should be able to cancel a proposed game', async() => {
        let merkleShip = await MerkleShip.deployed()

        let cancel = await merkleShip.cancelProposedGame(1, { from: bob } )
        let state = await merkleShip.games.call(1)

        assert.equal(state[8], 1, 'the game should be canceled ')
    })

    /** accept a game and verify it's state */
    it('should be able to accept a proposed game', async() => {
        let merkleShip = await MerkleShip.deployed()

        let mRoot = '0xffaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c'
        let accept = await merkleShip.acceptGame(2, mRoot, { value: 1, from: alice } )
        let state = await merkleShip.games.call(2)

        assert.equal(state[8], 2, 'the game state should be active')
        assert.equal(state[3], bob, 'player A should equal accounts[2]')
        assert.equal(state[4], alice, 'player B should equal accounts[1]')
    })

    /** concede a game and verify it's state */
    it('should be able to concede an active game', async() => {
        let merkleShip = await MerkleShip.deployed()

        let mRoot = '0xdfaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c'
        let propose = await merkleShip.proposeGame(0, mRoot, { from: bob })
        let mRoot2 = '0xffaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c'
        let accept = await merkleShip.acceptGame(3, mRoot2, { from: alice } )
        let concede = await merkleShip.concedeGame(3, { from: bob })
        let state = await merkleShip.games.call(3)

        assert.equal(state[8], 6, 'the game state should be complete')
        assert.equal(state[5], accounts[1], 'player B should be the winner')
    })

    /** trigger emergency mode */
    it('should be trigger emergency mode', async() => {
        let merkleShip = await MerkleShip.deployed()

        let stop = await merkleShip.emergencyStop('the game is being stopped!')
        let state = await merkleShip.isStopped.call()

        assert.equal(state, true, 'the game state should be stopped')
    })

    /** resolve a game in emergency mode */
    it('should be successfully resolve a game in emergency mode', async() => {
        let merkleShip = await MerkleShip.deployed()

        let resolve = await merkleShip.emergencyResolve(2, { from: bob })
        let state = await merkleShip.games.call(2)

        assert.equal(state[8], 6, 'the game state should be complete')
    })

    /** withdraw user funds */
    it('should successfully withdraw user funds', async() => {
        let merkleShip = await MerkleShip.deployed()

        let initialBalance = await merkleShip.getBalance.call()
        let withdrawA = await merkleShip.withdraw({ from: bob })
        let withdrawB = await merkleShip.withdraw({ from: alice })
        let finialBalance = await merkleShip.getBalance.call()

        assert.equal(initialBalance, 2, 'the intial balance should be 2 wei')
        assert.equal(finialBalance, 0, 'the final balance should be 0')
    })

    /** submit a guess and merkle proof that reveals the previous guess */

    /** should test vicotry conditions */

});
