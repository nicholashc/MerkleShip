# MERKLESHIP

*in progress*

MerkleShip is an implementation of the classic boardgame Battleship on Ethereum. Each player's board is stored in Merkle Tree, allowing them to trustlessly reveal only the squares guessed while maintaining the secrecy of the rest of their board. This document explains the rules, features, and design considerations that went into the game. This project was completed as part of the 2018/19 ConsenSys Developer Program.

## TABLE OF CONTENTS

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

## GAME RULES

Battleship (link wikipedia) is a two-player limited knowledge board game. Each player has a ruled coordinate grid on which they place a collection of ships of varying legnths. The location and orientation of these ships is hidden from the other player. The players take turns guessing the location of the other player's ships. If there is a ship in the coordinate guessed, it's a hit. If not, it's a miss. Ships sink when the oppossing player has hit every square along a ship's length. The objective of game is to be the first player to sink all of the other player's ships.

In MerkleShip, each player has two 8x8 square grids. One grid is secret and contains the players ships. The other grid tracks shots taken (either hit or miss). Before the start of the game, each player arranges their ships secretly. The ships are placed either horizontally or vertically. Each player must place one 4-square ship, one 3-square ship, one 2-square ship, and three 1-square ships.

<img src="https://github.com/nicholashc/MerkleShip/blob/master/diagrams/Diagram_BoardLayout.png">
