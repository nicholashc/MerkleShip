# MERKLESHIP

MerkleShip is an implementation of the classic board game [Battleship](https://en.wikipedia.org/wiki/Battleship_(game)) on Ethereum. Each player's initial board state is stored in a Merkle Tree, allowing the players to reveal only the squares guessed while maintaining the secrecy of the rest of their board. This document explains the rules, features, and design considerations that went into the game. This project was completed as part of the 2018/19 ConsenSys Developer Program.

### TABLE OF CONTENTS

1. Game Rules	
2. Design Considerations	
3. Gameplay
4. Security Considerations
5. Gas Considerations
6. Project Set Up

### 1) GAME RULES

Battleship is a two-player limited knowledge board game. Each player has a ruled coordinate grid on which they place a collection of ships of varying lengths. The location and orientation of these ships is hidden from the other player. The players take turns guessing the location of the other player's ships. If there is a ship in the coordinate guessed, it's a hit. If not, it's a miss. Ships sink when the opposing player has hit every square along a ship's length. The objective of the game is to be the first player to sink all of the other player's ships.

In MerkleShip, each player has two 8x8 square grids. One grid is secret and contains the player's ships. The other grid tracks shots taken (either hit or miss). Before the start of the game, each player arranges their ships secretly. The ships are placed either horizontally or vertically. Each player must place one 4-square ship, one 3-square ship, one 2-square ship, and three 1-square ships.

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_BoardLayout.png">
<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GuessLayout.png">

### 2) DESIGN CONSIDERATIONS

Why run this game on Ethereum? A smart contract protocol allows players who don't trust each other to play a game of battleship and be confident that the other player is following the rules. This trustless environment allows the two players to wager monetary value on the outcome of the game. There is also no need for a trusted third party who could manipulate the results of the game or remove service.

Storing the entire game state on-chain is impractical for several reasons. 1)Wwriting the full state to storage each turn creates a large gas cost for the users. 2) As a general principle, the blockchain should only be used for what it's good for: guaranteeing a trustless counter-party relationship, censorship resistance, immutable proof of a certain outcome. 3) Bloating the chain with unnecessary storage adds overhead to the cost and practicality of running clients in the future.

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GuessEncoding.png">

Merkle proofs allow for both users to prove they are conforming to the rules of the game, while only committing a single merkle root to state. Before the game, each player generates their game board off-chain. Each square of the board forms a leaf in the Merkle Tree. The leaf contains the following information concatenated into a single string: whether or not there is a ship in the square (bool), xy coordinates, ship length, and salt. The players can add a secret salt to each leaf to prevent the hashes of every game state being computed in advance (see more in Security Considerations). Each player computes their merkle tree and commits the merkle root to the blockchain before the game starts. Merkle trees in MerkleShip must be sorted and balanced.

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_MerkleProof.png">

Every turn, each player proposes a guess and in the same turn provides the merkle proof that reveals whether the other player's previous guess was a hit or a miss. The merkle proof guarantees that the players honestly reveal the outcome of each guess. At the end of the game, the winner may also have to provide a proof for their entire game state to verify that they had the correct number and length of ships on their board.

### 3) GAME PLAY

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GameState.png">

### 3A) SET UP

A player can propose a new game by committing a merkle root of their game state. This player is referred to as Player A. Player A has the option of wagering value on the outcome of this game. Any value wagered is held in escrow in the smart contract. Proposed games may be cancelled by the Player A in order to recover their full wager. As soon as a second player (Player B) accepts a proposed game, players cannot cancel without conceding. 

#### 3B) ACTIVE GAME

The active game state consists of each player taking turns guessing and providing a merkle proof to reveal and verify the previous player's guess. Player A always goes first and has nothing to reveal on their first turn. Successful hits are tracked and the game automatically moves to Victory Pending state if either player reaches 12 hits. If at any point one of the players takes longer than 48 hours to complete a turn, the other player can trigger an Abandoned game state and claim both player's wagers. At any point, either player can concede the game. By conceding the game, the player recovers 20% of their wager, incentivizing quick resolution rather than abandonment.

#### 3C) POST GAME

There are several possible outcomes from the Victory Pending game state. If the losing player suspects the potential victor of dishonest play they can challenge the victory, requiring the potential victor to provide a full proof of their initial game state. If the potential victor confirms the validity of their initial game state the victory is locked in and they can claim the full wagered amount. If the potential victor cannot provide a valid proof or abandons the game during this state, the victory is reversed and the initial losing player can claim the full wagered amount.

#### 3D) SMACK TALK

With every turn, players have the opportunity to submit a short message that is broadcast as an event. This allows the players to communicate as the games progress. This feature has a length limit and restricts valid characters to lower case letters and spaces.

#### 3E) EMERGENCY STOP

The only admin-level feature in the contract is the ability to trigger an emergency state. This function can only be called once and cannot be reversed. When this state is activated, players cannot continue active games, propose new games, or accept proposals. Players can trigger an emergency resolve of any of their games, which credits them with their original wagers. The only other function players may call in this state is the withdraw function. The admin address does not have the ability to influence the outcome of games or remove ether from the contract.

### 4) SECURITY CONSIDERATIONS
#### 4A) SAFE WITHDRAW PATTERNS

Ether only leaves the contract via a single function: `withdraw()`. Prizes or refunds are credited to a user balance rather than pushed directly. This prevents a potential denial of service vector where a smart contract refuses to accept funds send via `transfer`, preventing a game from resolving. Users then have to pull funds by sending a withdraw transaction. The user balance storage is set to zero before funds are transferred. While the `transfer` method gas stipend does not currently provide enough gas for state changes that could potentially trigger a reentrancy attack, changing the balance to zero before sending funds protects against future protocol level changes that alter this invariant (looking at you Constantinople).

#### 4B) GAME THEORY - GRIEFING

In order to prevent one player from griefing the other by taking exceedingly long on each turn, there is a 48h time limit which resets with each new turn. If either player ever exceeds this limit, they risk losing their wagered funds.

#### 4C) GAME THEORY - DISHONEST INITIAL STATE

While the merkle proofs provided each turn prove the validity of what is revealed, they do not provide any information about the honesty of the initial game state that went into the committed merkle root. For example, a dishonest player might provide a merkle proof for a game where they only have ships on six squares rather than the required twelve. The aforementioned challenge victory feature mediates this issue by potentially requiring any victor to prove the honesty of their initial game state before they can claim their prize. The player must provide the full unhashed array of each square's initial state. This data is verified against the ship amount and length requirements and then a merkle tree is recomputed on-chain and compared to the stored merkle root.

#### 4D) RAINBOW TABLE ATTACKS

The board encoding diagramed above recommends that a unique salt phrase is added to each square's data. Without this additional entropy, motivated users could precompute a rainbow table of the merkle roots of all possible game states and use this information to easily win. The recommended pattern is for a user to generate salt phrases from a single passphrase or seed, similar to how hierarchical deterministic wallets function. This feature is not implemented in the proof of concept front end, but is demonstrated in the node.js sketches in /js.

#### 4E) UNDER/OVERFLOW

Arithmatic operations that could potentially trigger an unexpected integer underflow or overflow are mitigated with the use of Open Zeppelin's SafeMath libary. 

### 5) GAS CONSIDERATIONS

There are several design decisions in this contract that attempt to minimize the gas costs of playing. 1) Merkle proofs reduce the amount of storage written to the chain. 2) Tightly packed structs store most of the game data in a reduced number of 256-bit words. 3) Non-critical information like smack talk is pushed into events rather than written in storage. 4) The most gas intensive feature is validating the full game state in the event of a challenge. To reduce this cost, as much storage is zeroed out as possible to take advantage of the gas refunds given when non-zero storage values are changed to zero.

### 6) PROJECT SET UP

To run the truffle tests:

```
git clone https://github.com/nicholashc/MerkleShip/
cd MerkleShip/truffle
ganache-cli -l 10000000
truffle test
```

Get Kovan ETH at [github.com/kovan-testnet/faucet](https://github.com/kovan-testnet/faucet). Interact with contract directly on the Kovan network at [0x902d5c4d8869720d44dd4246c539b039cdeb803c](https://kovan.etherscan.io/address/0x902d5c4d8869720d44dd4246c539b039cdeb803c#code). Or interact with the same contract via a limited proof of concept front end at [merkleship.surge.sh](https://merkleship.surge.sh). This website reads some information about active games. It allows you to generate a merkle tree based on board data and submit it to the blockchain. It allows you to manually track guesses. Unfortunately, it does not yet calculate proofs automatically, track new guesses from the chain, or allow you to load in-progress games. I am not providing a development environment to test the front end but you are welcome to run the /site directory locally. It's just vanilla javascript, html, and css.

In order to make calculating the merkle proofs easier, I've provided a node.js script in js/computeProof.js. To calculate a proof, replace the array called `leaves` with your data console logged from the website (or generate your own). Run the script with: 
```
npm install
node computeProof.js
```
