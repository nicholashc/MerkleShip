/*
@dev
TO ADD:
- checks for potential winners submitting valid game state
  - winners must provide merkle proofs for hitThreshold squares with a ship
  - if they do not, the other player can claim the prize
- checks for valid ship position
- helper function to reconstruct game board from guesses
*/

pragma solidity ^0.4.25;

contract MerkleShip {

  ///////////////////
  //STATE VARIABLES//
  ///////////////////

  //global count 
  uint32 public gameCount;
  //max turn length before a game is considered abandoned 
  uint32 public abandonThreshold = 48 hours;
  //board width
  uint8 public rows = 8;
  //board height
  uint8 public columns = 8;
  //sucessful hits required for victory
  uint8 public hitThreshold = 12;
  //storage of game state by index
  mapping (uint32 => Game) public games;
  //ETH available for user withdrawal
  mapping (address => uint) public userBalance;

  enum GameState { Ready, Cancelled, Active, Abandoned, Complete }
  enum Turn { Inactive, PlayerA, PlayerB }
  enum GuessState { Unknown, Pending, Hit, Miss }

  struct Game {
    //global gameCount; will overflow at 4294967295
    uint32 id; 
    //turn start time; reset at start of each term; will overflow February 7, 2106
    uint32 turnStartTime; 
    //wager from one player (total prize is wager * 2)
    //cannot overflow as max uint96 is larger than total ETH supply
    uint96 wager; 
    //player that proposed the game
    address playerA;
    //player that accepted the game
    address playerB;
    //winner only set on game resolution
    address winner;
    //tracks number of hits on player A's board
    uint8 playerAhitCount;
    //tracks number of hits on player B's board
    uint8 playerBhitCount;
    //game state; takes 8 bits of storage
    GameState state; 
    //turn state; takes 8 bits of storage
    Turn turn; //4 bits needed
    
    //note: the above packs tightly into three 256-bit words
    //merkle root of playerA secret game board
    bytes32 playerAMerkleRoot;
    //merkle root of playerB secret game board
    bytes32 playerBMerkleRoot;
    //index of player A guess states
    mapping (uint8 => GuessState) playerAhits;  
    //index of player B guess states
    mapping (uint8 => GuessState) playerBhits;  
    //tracks square index of player A guesses; length property used to retreive most recent guess
    uint8[] playerAguesses; 
    //tracks square index of player B guesses; length property used to retreive most recent guess 
    uint8[] playerBguesses; 
  }

  ///////////////
  //CONSTRUCTOR//
  ///////////////

  constructor() public {
    //contstructor stuff 
  }

  /////////////
  //MODIFIERS//
  /////////////

  /*
  * controls whether it is the correct turn of the player attempting to call a game function
  * blocks players who are not part of the game
  */
  modifier turnControl(uint32 _id) { 
    if (games[_id].turn == Turn.PlayerA) {
      require (msg.sender == games[_id].playerA, "it must be your turn");
    } else if (games[_id].turn == Turn.PlayerB) {
      require (msg.sender == games[_id].playerB, "it must be your turn");
    } 
    _; 
  }

  /*
  * limits enagement to active games
  */
  modifier isActive(uint32 _id) { 
    require (games[_id].state == GameState.Active, "the game must be active");
    _;
  }
  
  /*
  * limits enagement to games that have been proposed but are not yet active
  */
  modifier isReady(uint32 _id) { 
    require (games[_id].state == GameState.Ready, "the game must be waiting for a player");
    _;
  }

  /*
  * blocks players who are not part of the game
  * turn agnostic
  */
  modifier isPlayer(uint32 _id) { 
    require (msg.sender == games[_id].playerA || msg.sender == games[_id].playerB, "you must be a valid player");
    _;
  }

  //////////
  //EVENTS//
  //////////

  event LogProposedGame(
    uint256 indexed gameID,
    address indexed playerA,
    uint256 wager
  );

  event LogGameAccepted(
    uint256 indexed gameID,
    address indexed playerB,
    uint256 wager
  );

  event LogGameCancelled(
    uint256 indexed gameID,
    address indexed playerB
  );

  event LogSmackTalk(
    uint256 indexed gameID,
    address indexed sender,
    string smackTalk
  );

  event LogUserWithdraw(
    address indexed user,
    uint256 amount
  );
  
  event LogGuess(
    uint256 indexed gameID,
    address indexed user,
    uint256 square,
    bool guess
  ); 

  event LogReveal(
    uint256 indexed gameID,
    address indexed user,
    bool verfied
  );

  event LogWinner(
    uint256 indexed gameID,
    address indexed winner,
    string message
  );

  /////////////////////////
  //GAME SET UP FUNCTIONS//
  /////////////////////////

  /*
  * propose a new game
  * user must provide the merkle root of their secret game board
  * merkle root computed offchain but validated on chain
  * winners must provide proofs of a valid game board before they can claim their prize
  * can submit a wager on the outcome of the game, which must be matched by the second player 
  * 0 ETH is a valid wager
  */
  function proposeGame(
    uint32 _wager, 
    bytes32 _playerAMerkleRoot
  ) 
  external 
  payable 
  {
    require (msg.value == _wager, "you must send the right amount");

    gameCount++;

    Game storage g = games[gameCount];

    g.id = gameCount;
    g.wager = _wager;
    g.playerA = msg.sender;
    g.state = GameState.Ready;
    g.playerAMerkleRoot = _playerAMerkleRoot;

    emit LogProposedGame(gameCount, msg.sender, msg.value);
  }

  /*
  * accept a propsed new game 
  * must match playerA's wager
  * starts the timer of playerA's fisrt turn
  */
  function acceptGame(
    uint32 _id, 
    bytes32 _playerBMerkleRoot
  ) 
  external 
  payable 
  isReady(_id) 
  {
    require (msg.value == games[_id].wager, "you must match the wager");

    Game storage g = games[_id];

    g.turnStartTime = uint32(now);
    g.playerB = msg.sender;
    g.state = GameState.Active;
    g.turn = Turn.PlayerA;
    g.playerBMerkleRoot = _playerBMerkleRoot;

    emit LogGameAccepted(_id, msg.sender, msg.value);
  }

  /*
  * can be called by playerA is their proposed game has not yet been accepted 
  */
  function cancelProposedGame(
    uint32 _id
    ) 
  external 
  isReady(_id) 
  {
    require (msg.sender == games[_id].playerA, "you must have proposed this game");

    uint256 balanceToReturn = games[_id].wager;

    Game storage g = games[_id];

    g.state = GameState.Cancelled;
    g.wager = 0;

    userBalance[msg.sender] += balanceToReturn;

    emit LogGameCancelled(_id, msg.sender);
  }

  /////////////////////////
  //GAME SET UP FUNCTIONS//
  /////////////////////////

  /*
  * user submits their guess
  * user also provides a merkle proof that reveals whether or not the previous player's guess was a hit
  * proof not provided on first turn
  */
  function guessAndReveal(
    uint32 _id, 
    uint8[2] _square, 
    bool _guess,
    bytes32[] _proof, 
    string _leafData,
    string _smackTalk
    ) 
  external 
  turnControl(_id) 
  isActive(_id) 
  {
    require (_checkIfCoordinateIsValid(_square[0], _square[1]) == true, "the coordinates must be valid");

    uint8 square = _coordinateToIndex(_square[0], _square[1]);

    Game storage g = games[_id];

    if (msg.sender == games[_id].playerA) {
      if (g.playerBguesses.length > 0) {
        //don't reveal on the first turn 
        _reveal(_id, _proof, _leafData);
      }
      g.playerAguesses.push(square);
      g.playerAhits[uint8(g.playerBguesses.length)] = GuessState.Pending;
      g.turnStartTime = uint32(now);
      g.turn = Turn.PlayerB;
    } else if (msg.sender == games[_id].playerB) {
      _reveal(_id, _proof, _leafData);
      g.playerBguesses.push(square);
      g.playerAhits[uint8(g.playerAguesses.length)] = GuessState.Pending;
      g.turnStartTime = uint32(now);
      g.turn = Turn.PlayerA;
    }

    emit LogGuess(_id, msg.sender, square, _guess);
    emit LogSmackTalk(_id, msg.sender, _smackTalk);
  } 

  /*
  * reveal component
  * can only be called as part of guess (no case of reveal without guess)
  */
  function _reveal(
    uint32 _id, 
    bytes32[] _proof,
    string _leafData
    ) 
  internal 
  {
    Game storage g = games[_id];
    //get merkle root from game storage
    bytes32 _root;
    if (msg.sender == games[_id].playerA) {
      _root = g.playerAMerkleRoot;
    } else if (msg.sender == games[_id].playerB) {
      _root = g.playerBMerkleRoot;
    }

    //process reveal
    require (_verifyMerkleProof(_proof, _root, _leafData) == true, "you must provide a valid Merkle Proof");

    uint8 guessToReveal;

    if (msg.sender == games[_id].playerA) {
      guessToReveal = uint8(g.playerBguesses.length - 1);
    } else if (msg.sender == games[_id].playerB) {
      guessToReveal = uint8(g.playerAguesses.length - 1);
    }

    bytes memory isHit = _substring(_leafData,0,1);

    //check if hit 
    if (keccak256(isHit) == keccak256("1")) {
      if (msg.sender == games[_id].playerA) {
        g.playerBhits[guessToReveal] = GuessState.Hit;
        g.playerBhitCount++;
      } else if (msg.sender == games[_id].playerB) {
        g.playerAhits[guessToReveal] = GuessState.Hit;
        g.playerAhitCount++;
      }
    } else if (keccak256(isHit) == keccak256("0")) {
      if (msg.sender == games[_id].playerA) {
        g.playerBhits[guessToReveal] = GuessState.Miss;
      } else if (msg.sender == games[_id].playerB) {
        g.playerAhits[guessToReveal] = GuessState.Miss;
      }
    }

    //check for winner
    if (g.playerAhitCount == hitThreshold) {
      g.state = GameState.Complete;
      g.winner = games[_id].playerB;
    } else if (g.playerBhitCount == hitThreshold) {
      g.state = GameState.Complete;
      g.winner = games[_id].playerA;
    } 

    //process winner
    if (g.state == GameState.Complete) {
      uint prize = games[_id].wager * 2;
      userBalance[g.winner] += prize;
      emit LogWinner(_id, g.winner, "victory by hit count");
    }

    emit LogReveal(_id, msg.sender, true);
  }

  /*
  * can be called in case an game is abandonend
  * a game is abandoned if any turn lasts longer than the abandonThreshold
  * the player who did not abandon the game wins the full prize
  */
  function resolveAbandonedGame(
    uint32 _id
    ) 
  external 
  isActive(_id) 
  {
    require (now >= games[_id].turnStartTime + abandonThreshold, "the game must be stale for at least 48 hours"); 

    if (msg.sender == games[_id].playerA) {
      require (games[_id].turn == Turn.PlayerB, "it must be the other player's turn");
    } else if (msg.sender == games[_id].playerB) {
      require (games[_id].turn == Turn.PlayerA, "it must be the other player's turn");
    }

    Game storage g = games[_id];

    g.state = GameState.Abandoned;
    g.winner = msg.sender;

    uint prize = games[_id].wager * 2;
    userBalance[msg.sender] += prize;

    emit LogWinner(_id, g.winner, "victory by abandonment");
  }

  /*
  * can be called by either player
  * the loser recovers 20% of their wager 
  * this incentivizes quick game resolution when the outcome seems certain
  */
  function concedeGame(
    uint32 _id
  ) 
  external 
  isActive(_id) 
  isPlayer(_id) 
  {

    address winner;

    if (msg.sender == games[_id].playerA) {
      winner = games[_id].playerB;
    } else if (msg.sender == games[_id].playerB) {
      winner = games[_id].playerA;
    }

    Game storage g = games[_id];

    g.state = GameState.Complete;
    g.winner = winner;
    address loser;
    if (winner == games[_id].playerA) {
      loser = games[_id].playerB;
    } else if (winner == games[_id].playerB) {
      loser = games[_id].playerA;
    }

    uint256 prize = (games[_id].wager * 180) / 100;
    //@dev check this for potential underflow
    uint256 concession = games[_id].wager * 2 - prize;
    userBalance[winner] += prize;
    userBalance[loser] += concession;

    emit LogWinner(_id, g.winner, "victory by consession");
  }

  /*
  * this is the only function that transfers ETH out of the contract 
  * requires safer pull pattern
  */
  function withdraw() external {
    require (userBalance[msg.sender] > 0, "user must have a balance to withdraw");

    uint256 balance = userBalance[msg.sender];
    userBalance[msg.sender] = 0;
    msg.sender.transfer(balance);

    emit LogUserWithdraw(msg.sender, balance);
  }


  //////////////////
  //VIEW FUNCTIONS//
  //////////////////

  //@dev add helper functions to rebuild visible game board from guesses 


  /////////////
  //UTILITIES//
  /////////////
  
  /*
  * verifies provided merkle proof against logged merkle roots
  * requires hashed leaves to be sorted
  * requires leafList.length % 2 == 0 (eg 64 leaves)
  * leaf data provided a single concatenated string of (isShip bool value, x coordinate, y coordinate, salt)
  */
  function _verifyMerkleProof(
    bytes32[] _proof, 
    bytes32 _root, 
    string _leafData
  ) 
  internal 
  pure 
  returns(bool) 
  {
    bytes32 computedHash = keccak256(abi.encodePacked(_leafData));

    for (uint256 i = 0; i < _proof.length; i++) {
      bytes32 proofElement = _proof[i];
        computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
    }

    return computedHash == _root;
  }

  /*
  * utility function to check if coordinates are within a valid game board
  */
  function _checkIfCoordinateIsValid(
    uint _x, 
    uint _y
  ) 
  internal 
  view 
  returns(bool) 
  {
    if (_x <= columns - 1 && _y <= rows - 1) {
      return true;
    } else {
      return false;
    }
  }

  /*
  * utility function to convert coordinate to index
  * eg, on an 8x8 board (0,0) == 0; (2,3) == 19;
  */  
  function _coordinateToIndex(
    uint _x, 
    uint _y
  ) 
  internal 
  view 
  returns(uint8) 
  {
    require (_checkIfCoordinateIsValid(_x, _y) == true, "coordinate must be valid");

    uint xShifted = _x + 1;
    uint yShifted = _y + 1;

    if (yShifted > 1) {
      return uint8(yShifted * columns + xShifted - 1);
    } else {
      return uint8(xShifted - 1);
    }
  }

  /*
  * utility function to convert index to coordinate
  * note: @dev currently unused
  */  
  function _indexToCoordinate(
    uint _index
  ) 
  internal 
  view 
  returns(uint8[2]) 
  {
    require (_index <= rows * columns - 1, "the index must be valid");

    uint x = _index % columns;
    uint y; 
    
    if (_index >= columns) {
        uint temp = _index - x;
        y = temp / rows;
    }

    return [uint8(x), uint8(y)];
  }

  /*
  * helper function to return a substring
  */
  function _substring(
    string str, 
    uint startIndex, 
    uint endIndex
  ) 
  internal 
  pure 
  returns(bytes) 
  {
    bytes memory strBytes = bytes(str);
    bytes memory result = new bytes(endIndex-startIndex);
    for(uint i = startIndex; i < endIndex; i++) {
        result[i-startIndex] = strBytes[i];
    }

    return result;
  }

}