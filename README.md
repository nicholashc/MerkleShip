# MERKLESHIP

MerkleShip is an implementation of the classic boardgame [Battleship](https://en.wikipedia.org/wiki/Battleship_(game)) on Ethereum. Each player's board initial board state is stored in a Merkle Tree, allowing the players to reveal only the squares guessed while maintaining the secrecy of the rest of their board. This document explains the rules, features, and design considerations that went into the game. This project was completed as part of the 2018/19 ConsenSys Developer Program.

### TABLE OF CONTENTS

1. Game Rules	
2. Design Considerations	
3. Gameplay
4. Security Considerations
5. Set Up

### 1) GAME RULES

Battleship is a two-player limited knowledge board game. Each player has a ruled coordinate grid on which they place a collection of ships of varying lengths. The location and orientation of these ships is hidden from the other player. The players take turns guessing the location of the other player's ships. If there is a ship in the coordinate guessed, it's a hit. If not, it's a miss. Ships sink when the opposing player has hit every square along a ship's length. The objective of game is to be the first player to sink all of the other player's ships.

In MerkleShip, each player has two 8x8 square grids. One grid is secret and contains the player's ships. The other grid tracks shots taken (either hit or miss). Before the start of the game, each player arranges their ships secretly. The ships are placed either horizontally or vertically. Each player must place one 4-square ship, one 3-square ship, one 2-square ship, and three 1-square ships.

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_BoardLayout.png">
<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GuessLayout.png">

### 2) DESIGN CONSIDERATIONS

Why run this game on Ethereum? A smart contract protocol allows players who don't trust each other to play a game of battleship and be confident that the other player is following the rules. This trustless environment allows the two players to confidently wager monetary value on the outcome of the game. There is also no need for a trusted third party who could manipulate the results of the game or remove service.

Storing the entire game state on-chain is impractical for several reasons. 1) writing the full state to storage each turn creates a large gas cost for the users. 2) as a general principle, the blockchain should only be used for what it's good for: guaranteeing a trustless counterparty relationship, censorship resistence, immutible proof of a certain outcome. 3) bloating the chain with unnessary storage adds overhead to the cost and practicality of running clients in the future. Thus, it's only necessary to commit a merkle root of their game board to the blockchain and provide proofs as necessary. 

Merkle proofs allow for both users to prove they are conforming to the rules of the game, while only commiting a single merkle root to state. This design pattern is similar to a stateless client model. Before the game, each player generates their game board offchain. Each square of the board forms a leaf in the Merkle Tree. The leaf contains the following information concatenated into a single string: whether or not there is a ship in the square (bool), xy coordinates, ship length, and salt. The players can add a secret salt to each leaf to prevent the hashes of every game state being computed in advance (see more in security considerations). Each player computes their merkle tree and commits the merkle root to the blockchain before the game starts. 

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GuessEncoding.png">
<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_MerkleProof.png">

Every turn, each player proposes a guess and in the same turn provides the merkle proof that reveals whether the other player's previous guess was a hit or a miss. The merkle proof guarantees that the players honestly reveal the outcome of each guess. At the end of the game, the winner may also have to provide a proof for their entire game state to verify that they had the correct number and length of ships on their board.

### 3) GAME PLAY

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GameState.png">

### 3A) SET UP

During the initial phase of the game, a player can propose a new game by commiting a merkle root of their game state. This player is refered to as Player A. Player A has the option of wagering value on the outcome of this game. Any value wagered is held in escrow in the smart contract. Proposed games may be cancelled by the proposer in order to recover their full wager. As soon as a second player (Player B) accepts a proposed game, neither player can cancel without conceding. 

### 3B) ACTIVE GAME

The active game state consists of each player taking turns guessing and providing a merkle proof to reveal and verify the previous player's guess. Player A always goes first and has nothing to reveal on their first turn. Successful hits are tracked and the game automatically moves to Victory Pending state if either player reaches 12 hits. If at any point one of the players takes longer than 48 hours to complete a turn, the other player can trigger an Abandoned game state and claim both player's wagers. At any point, either player can concede the game. By conceding the game, the player recovers 20% of their wager, incentivizing quick resolution rather than abandonment.

### 3C) POST GAME

There are several possible outcomes from the Victory Pending game state. If the losing player suspects the potential victor of dishonest play they can challenge the victory, requiring the potential victor to provide a full proof of their initial game state. If the potential victor confirms the validity of their intial game state the vicotry is locked in and they can claim the full wagered amount. If the potential victor cannot provide a valid proof or abandons the game during this state, the vicotry is reversed and the initial losing player can claim the full wagered amount.

### 3D) SMACK TALK

With every turn, players have the opportunity to submit a short message that is broadcast as an event. This allows the players to communicate as the games progress. This feature has a length limit and restricts valid characters to lower case letters and spaces.

### 3E) EMERGENCY STOP

The only admin-level feature in the contract is the ability to trigger an emergency state. This function can only be called once and cannot be reversed. When this state is activated, players cannot continue active games, propose new games, or accept proposals. Players can trigger an emergency resolve of any of their games, which credits them with their original wagers. The only other function players may call in this state is the withdraw function. The admin address does not have the ability to influence the outcome of games or remove ether from the contract.

### 4) SECURITY CONSIDERATIONS
### 4A) SAFE WITHDRAW PATTERNS
### 4B) GAME THEORY - GRIEFING
### 4C) GAME THEORY - DISHONEST INITIAL STATE
### 5) SET UP
