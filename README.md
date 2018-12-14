# MERKLESHIP

*in progress*

MerkleShip is an implementation of the classic boardgame Battleship on Ethereum. Each player's board is stored in Merkle Tree, allowing them to trustlessly reveal only the squares guessed while maintaining the secrecy of the rest of their board. This document explains the rules, features, and design considerations that went into the game. This project was completed as part of the 2018/19 ConsenSys Developer Program.

### TABLE OF CONTENTS

1) Game Rules	
2) Design Considerations	
3) Gameplay
	3A) set up
	3B) active-game
	3C) post-game
4) Features
	4A) wagering
	4B) time
	4C) smack talk
5) Security Considerations
6) Gas Considerations
7) User Interface
8) User Stories

### GAME RULES

Battleship (link wikipedia) is a two-player limited knowledge board game. Each player has a ruled coordinate grid on which they place a collection of ships of varying legnths. The location and orientation of these ships is hidden from the other player. The players take turns guessing the location of the other player's ships. If there is a ship in the coordinate guessed, it's a hit. If not, it's a miss. Ships sink when the oppossing player has hit every square along a ship's length. The objective of game is to be the first player to sink all of the other player's ships.

In MerkleShip, each player has two 8x8 square grids. One grid is secret and contains the players ships. The other grid tracks shots taken (either hit or miss). Before the start of the game, each player arranges their ships secretly. The ships are placed either horizontally or vertically. Each player must place one 4-square ship, one 3-square ship, one 2-square ship, and three 1-square ships.

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_BoardLayout.png">
<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GuessLayout.png">

### 2) DESIGN CONSIDERATIONS

Why run this game on Ethereum? A smart contract protocol allows players who don't trust each other to play a game of battleship and be confident that the other player is following the rules. This turstless environment allows the two players to confidently wager monetary value on the outcome of the game. There is also no need for a trusted thrid party who could manipulate the results of the game or remove service.

Storing the entire game state on-chain is impractical for several reasons. 1) writing the full state to storage each turn creates a large gas cost for the users. 2)  as a general principle, the blockchain should only be used for what it's good for: guarenteeing a trustless counterparty relationship, censorship resistence, immutible proof of a certain outcome. Thus, it's only necessary to commit a Merkle Root of their game board to the blockchain and provide proofs as necessary. 

Merkle Proofs allow for the both users to prove they are conforming to the rules of the game, while only commiting a single merkle root to state. This design pattern is similar to the stateless client model. Before the game, each player generates their game board offchain. Each square of the board forms a leaf in the Merkle Tree. The leaf contains the following information concatenated into a single string: whether or not there is a ship in the square (bool), xy coordinates, ship length, and salt. The players add a secret salt to each leaf to prevent the hashes of every game state being computed in advance (see more in security considerations). Each player computes their merkle tree and commits the merkle root to the blockchain before the game starts. 

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GuessEncoding.png">
<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_MerkleProof.png">

Every turn, each player proposes a guess and in the same turn provides the merkle proof that reveals whether the other player's previous guess was a hit or a miss. The merkle proof guarentees that the players honestly reveal the outcome of each guess. At the end of the game, the winner may also have to provide a proof for their entire game state to verify that they had the correct number and length of ships of their board.

### 3) GAME PLAY

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_GameState.png">

### 3A) SET UP
### 3B) ACTIVE GAME
### 3C) POST GAME
### 4) FEATURES
### 4A) WAGERING
### 4B) TIME
### 4C) SMACK TALK
### 5) SECURITY CONSIDERATIONS
### 6) GAS CONSIDERATIONS
### 7) USER INTERFACE
### 8) USER STORIES
