/*
@dev
TO ADD:
- checks for potential winners submitting valid game state
  - winners must provide merkle proofs for hitThreshold squares with a ship
  - if they do not, the other player can claim the prize
- checks for valid ship position
- helper function to reconstruct game board from guesses
- Q? do i have to keep initializing structs in sequential functions?
- add another value in the leaf string that detmines ship type
- update to 0.5.0

12 ship squares
one 4-long
one 3-long
one 2-long
three 1-long
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
  //separte timer to track PendingVictory claim time
  mapping (uint32 => uint256) public claimTimer;

  enum GameState { Ready, Cancelled, Active, Abandoned, PendingVictory, Complete }
  enum Turn { Inactive, PlayerA, PlayerB }
  enum GuessState { Unknown, Pending, Hit, Miss }

  struct Game {
    //global gameCount; will overflow if there are more than 4,294,967,295 games 
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
    Turn turn; 
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


  /////////////
  //MODIFIERS//
  /////////////

  /*
  * controls whether it is the correct turn of the player attempting to call a game function
  * blocks players who are not part of the game
  */
  modifier turnControl(uint32 _id) { 
    if (games[_id].turn == Turn.PlayerA) {
      require (
        msg.sender == games[_id].playerA,
        "it must be your turn");
    } 
    else if (games[_id].turn == Turn.PlayerB) {
      require (
        msg.sender == games[_id].playerB,
        "it must be your turn");
    } 
    _; 
  }

  /*
  * limits enagement to active games
  */
  modifier isActive(uint32 _id) { 
    require (
      games[_id].state == GameState.Active,
      "the game must be active");
    _;
  }
  
  /*
  * limits enagement to games that have been proposed but are not yet active
  */
  modifier isReady(uint32 _id) { 
    require (
      games[_id].state == GameState.Ready,
      "the game must be waiting for a player");
    _;
  }

  /*
  * blocks players who are not part of the game
  * turn agnostic
  */
  modifier isPlayer(uint32 _id) { 
    require (
      msg.sender == games[_id].playerA || msg.sender == games[_id].playerB,
      "you must be a valid player");
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

  event LogPendingVictory(
    uint256 indexed gameID,
    address indexed winner
  );

  event LogWinner(
    uint256 indexed gameID,
    address indexed winner,
    string message
  );


  //////////////////////
  //PRE-GAME FUNCTIONS//
  //////////////////////

  /*
  * propose a new game
  * user must provide the merkle root of their secret game board
  * merkle root computed offchain but validated on chain
  * winners must provide proofs of a valid game board before they can claim their prize
  * can submit a wager on the outcome of the game, which must be matched by the second player 
  * 0 ETH is a valid wager
  */
  function proposeGame(uint32 _wager, bytes32 _playerAMerkleRoot) 
    external 
    payable 
  {
    require (msg.value == _wager, "you must send the right amount");
    //increment gameCount; the first game is 1, not 0
    gameCount++;
    //initialize struct in storage
    Game storage g = games[gameCount];
    //save initial game state
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
  function acceptGame(uint32 _id, bytes32 _playerBMerkleRoot) 
    external 
    payable 
    isReady(_id) 
  {
    require (msg.value == games[_id].wager, "you must match the wager");
    //initialize struct in storage
    Game storage g = games[_id];
    //update game state
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
  function cancelProposedGame(uint32 _id) 
    external 
    isReady(_id) 
  {
    require (msg.sender == games[_id].playerA, "you must have proposed this game");
    //local variable of balance to return
    uint256 balanceToReturn = games[_id].wager;
    //initialize struct from storage
    Game storage g = games[_id];
    //update state and set wager amount to 0
    g.state = GameState.Cancelled;
    g.wager = 0;
    //update user balance
    userBalance[msg.sender] += balanceToReturn;

    emit LogGameCancelled(_id, msg.sender);
  }


  /////////////////////
  //IN-GAME FUNCTIONS//
  /////////////////////

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
    require (_proof.length == 6, "the merkle proof must be the correct length");
    //@dev add length check for _leafData here?
    require (_isValidString(_smackTalk), "smack talk must be a valid string");
    //convert coordinates to index 
    //this function checks that the coordinate is inbounds 
    uint8 square = _coordinateToIndex(_square[0], _square[1]);
    //initialize struct in storage
    Game storage g = games[_id];
    //process reveal and update state with playerA guess
    if (msg.sender == games[_id].playerA) {
      //nothing to reveal on playerA's first turn 
      if (g.playerBguesses.length > 0) {
        //reveal square from playerB's previous guess
        _reveal(_id, _proof, _leafData);
      }
      //guess coordinates stored in sequential array 
      g.playerAguesses.push(square);
      //guess state pending until revealed 
      g.playerAhits[uint8(g.playerBguesses.length)] = GuessState.Pending;
      //reset turn start time
      g.turnStartTime = uint32(now);
      //update turn state 
      g.turn = Turn.PlayerB;
    } 
    //process reveal and update state with playerB guess
    else if (msg.sender == games[_id].playerB) {
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
  * @dev: this function is too long. break up into modular code
  */
  function _reveal(uint32 _id, bytes32[] _proof, string _leafData) 
    internal 
  {    
    //initialize game in storage
    Game storage g = games[_id];
    //retreive appropriate merkle root from game state 
    bytes32 root;
    if (msg.sender == games[_id].playerA) {
      root = g.playerAMerkleRoot;
    } 
    else if (msg.sender == games[_id].playerB) {
      root = g.playerBMerkleRoot;
    }
    //reveal and verify merkle proof from the other player's last guess
    //if the player calling this function can't provide the verification they will not be able to advance their turn
    require (
      _verifyMerkleProof(_proof, root, _leafData) == true, 
      "you must provide a valid Merkle Proof"
    );
    //retreive index of square about to be revealed 
    uint8 guessToReveal;
    if (msg.sender == games[_id].playerA) {
      guessToReveal = uint8(g.playerBguesses[g.playerBguesses.length - 1]);
    } 
    else if (msg.sender == games[_id].playerB) {
      guessToReveal = uint8(g.playerAguesses[g.playerAguesses.length - 1]);
    }
    //check the first byte of the revealed data to confirm if there was a ship in that square
    bytes1 isHit = _subString(_leafData, 0);
    require (isHit == 0x31 || isHit == 0x30, "leaf data must be in correct format")
    //update state if there was a hit
    //0x31 is 1 in bytes1
    if (isHit == 0x31) {
      if (msg.sender == games[_id].playerA) {
        g.playerBhits[guessToReveal] = GuessState.Hit;
        g.playerBhitCount++;
      } 
      else if (msg.sender == games[_id].playerB) {
        g.playerAhits[guessToReveal] = GuessState.Hit;
        g.playerAhitCount++;
      }
    } 
    //update state if there was a miss 
    //0x30 is 0 in bytes1
    else if (isHit == 0x30) {
      if (msg.sender == games[_id].playerA) {
        g.playerBhits[guessToReveal] = GuessState.Miss;
      } 
      else if (msg.sender == games[_id].playerB) {
        g.playerAhits[guessToReveal] = GuessState.Miss;
      }
    } 

    _checkForVictoryByHit(uint32 _id);

    emit LogReveal(_id, msg.sender, true);
  }

  /*
  * check if victory by hit has been achieved
  * if yes, process victory
  */
  function _checkForVictoryByHit(uint32 _id) 
    internal
  {
    //initialize game in storage
    Game storage g = games[_id];
    //check for winner
    if (g.playerAhitCount == hitThreshold) {
      g.state = GameState.PendingVictory;
      g.winner = games[_id].playerB;
    } 
    else if (g.playerBhitCount == hitThreshold) {
      g.state = GameState.PendingVictory;
      g.winner = games[_id].playerA;
    } 
    //process winner
    if (g.state == GameState.PendingVictory) {
      claimTimer[_id] = now;
      
      emit LogPendingVictory(_id, msg.sender);
    }
  }

  /*
  * can be called in case an game is abandonend
  * a game is abandoned if any turn lasts longer than the abandonThreshold
  * the player who did not abandon the game wins the full prize
  */
  function resolveAbandonedGame(uint32 _id) 
    external 
    isActive(_id)
    isPlayer(_id) 
  {
    require (
      now >= games[_id].turnStartTime + abandonThreshold,
      "the game must be stale for at least 48 hours"
    ); 

    //can only be called if it is NOT your turn
    if (msg.sender == games[_id].playerA) {
      require (games[_id].turn == Turn.PlayerB, "it must be the other player's turn");
    } 
    else if (msg.sender == games[_id].playerB) {
      require (games[_id].turn == Turn.PlayerA, "it must be the other player's turn");
    }
    //initialize struct in storage
    Game storage g = games[_id];
    //update game state
    g.state = GameState.Abandoned;
    g.winner = msg.sender;
    //calcuate prize
    uint prize = games[_id].wager * 2;
    //update winner balance
    userBalance[msg.sender] += prize;

    emit LogWinner(_id, g.winner, "victory by abandonment");
  }

  /*
  * can be called by either player
  * the loser recovers 20% of their wager 
  * this incentivizes quick game resolution when the outcome seems certain
  */
  function concedeGame(uint32 _id) 
    external 
    isActive(_id) 
    isPlayer(_id) 
  { 
    //assign loser status to player conceding
    address loser = msg.sender;
    //assign winner status to other player
    address winner;
    if (msg.sender == games[_id].playerA) {
      winner = games[_id].playerB;
    } 
    else if (msg.sender == games[_id].playerB) {
      winner = games[_id].playerA;
    }
    //initialize struct in storage
    Game storage g = games[_id];
    //update game state 
    g.state = GameState.Complete;
    g.winner = winner;
    //calcuate winner prize (90% of pot)
    uint256 prize = (games[_id].wager * 180) / 100;
    //calcuate loser prize (10% of pot)
    uint256 concession = games[_id].wager * 2 - prize;
    //update user balances 
    userBalance[winner] += prize;
    userBalance[loser] += concession;

    emit LogWinner(_id, g.winner, "victory by consession");
  }

  /*
  * in the case of a victory by hit, the winner must provide provide that had an honest game board
  * without this proof the winner could have submitted a board with no ships, for example
  * if the winner cannot prove their honest play, the other wins the prize
  * @dev: the gas costs of this function are going to be crazy, research a better way to handle this case
  */
  function claimPrize(uint32 _id, string[64] _leaves) 
    external
    isPlayer(_id) 
  {
    //initialize struct in storage 
    Game storage g = games[_id];

    require (g.state = GameState.PendingVictory, "this game must be pending proof of honest play");

    //check that hitThreshold number of squares start with 1
    uint256 shipCount;
    for (uint256 i = 0; i < 64; i++) {
      if (_subString(_leaves[i], 0) == 0x31) {
        shipCount++;
        if (shipCount == hitThreshold) {
          break;
        }
      }
    }

    require (shipCount == hitThreshold, "you must have set the correct number of ship squares");

    //confirm that each ship more than one square long has the correct adjacencies
    uint256 longShipsVerfied;
    for (i = 0; i < 64; i++) {
      if (_subString[_leaves[i], 3] == 0x34) {
        require (
          _subString[_leaves[i + 1] == 0x34 &&
          _subString[_leaves[i + 2] == 0x34 &&
          _subString[_leaves[i + 3] == 0x34 ||
          _subString[_leaves[i + rows] == 0x34 &&
          _subString[_leaves[i + 2 * rows] == 0x34 &&
          _subString[_leaves[i + 3 * rows] == 0x34,
          "you must have one ship that is four squares long" 
        )
        longShipsVerfied++;
      }
      if (_subString[_leaves[i], 3] == 0x33) {
        require (
          _subString[_leaves[i + 1] == 0x34 &&
          _subString[_leaves[i + 2] == 0x34 ||
          _subString[_leaves[i + rows] == 0x34 &&
          _subString[_leaves[i + 2 * rows] == 0x34,
          "you must have one ship that is three squares long" 
        )
        longShipsVerfied++;
      }
      if (_subString[_leaves[i], 3] == 0x32) {
        require (
          _subString[_leaves[i + 1] == 0x34 ||
          _subString[_leaves[i + rows] == 0x34,
          "you must have one ship that is two squares long" 
        )
        longShipsVerfied++;
      }
      if (longShipsVerfied == 3) {
        break;
      }
    }

    //compute the merkle root and check that it matches in state
      //hash 
      //sort (possible options: //https://github.com/pipermerriam/ethereum-grove/tree/master/contracts, https://github.com/alice-si/array-booster/tree/master/contracts)
      //tree 

    //update game state 

    //calculate prize
    uint256 prize = games[_id].wager * 2;
    //update winner balance
    userBalance[g.winner] += prize;

    emit LogWinner(_id, g.winner, "victory by hit count");
  }

  /*
  *function to claim abandoned game in PendingVictory state 
  */

  function resolveUnclaimedVictory(uint32 _id) 
    external
    isPlayer(_id) 
  {
    require (now >= claimTimer[_id] + abandonThreshold, "the potential victor has 48h to validate their claim")
    Game storage g = games[_id];

    require (g.state = GameState.PendingVictory, "this game must be pending proof of honest play");
    
    //change winner
    //calculate prize
    uint256 prize = games[_id].wager * 2;
    //update winner balance
    userBalance[g.winner] += prize;
  }
  

  /*
  * this is the only function that transfers ETH out of the contract 
  * requires safer pull pattern
  */
  function withdraw() 
    external 
  {
    require (userBalance[msg.sender] > 0, "user must have a balance to withdraw");
    //set balance as local variable
    uint256 balance = userBalance[msg.sender];
    //change state balance to 0
    userBalance[msg.sender] = 0;
    //safely transfer without potential for reentrancy 
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
  function _verifyMerkleProof(bytes32[] _proof, bytes32 _root, string _leafData) 
    internal 
    pure 
    returns(bool) 
  {
    //hash leaf data
    bytes32 computedHash = keccak256(abi.encodePacked(_leafData));
    //loop through proof to compute merkle root
    for (uint256 i = 0; i < _proof.length; i++) {
      bytes32 proofElement = _proof[i];
      computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
    }
    //return true if proof matches stored merkle roof
    return computedHash == _root;
  }

  /*
  * utility function to check if coordinates are within a valid game board
  */
  function _checkIfCoordinateIsValid(uint8 _x, uint8 _y) 
    internal 
    view 
    returns(bool) 
  { 
    if (_x <= columns - 1 && _y <= rows - 1) {
      return true;
    } 
    else {
      return false;
    }
  }

  /*
  * utility function to convert coordinate to index
  * eg, on an 8x8 board (0,0) == 0; (2,3) == 19;
  */  
  function _coordinateToIndex(uint8 _x, uint8 _y) 
    internal 
    view 
    returns(uint8) 
  {
    require (_checkIfCoordinateIsValid(_x, _y), "coordinate must be valid");
    //move starting index from 0 to 1 so multiplication works properly
    uint8 xShifted = _x + 1;
    uint8 yShifted = _y + 1;

    if (yShifted > 1) {
      //if not in first row, multiply by row height and add reshifted x value 
      return uint8(yShifted * columns + xShifted - 1);
    } 
    else {
      //if in first row, return reshifted x value
      return uint8(xShifted - 1);
    }
  }

  /*
  * helper function to return a substring
  */
  function _subString(string _str, uint256 _index) 
    internal 
    pure 
    returns(bytes1) 
  { 
    //convert to bytes to access substring index 
    bytes memory str = bytes(_str);
    //return first character
    return str[_index];
  }

  /*
  * helper function to make sure no one xss attacks the front end
  */
  function _isValidString(string _str)
    public 
    pure
    returns(bool)
  { 
    //convert to bytes to access length property 
    bytes memory str = bytes(_str);
    uint256 _length = str.length;
    
    require (_length <= 40,"string cannot be longer than 40 characters");
    //check each character
    for (uint256 i = 0; i < _length; i++) {
      require ( 
        // a-z lowercase && " "
        (str[i] > 0x60 && str[i] < 0x7b) || str[i] == 0x20,
        "string contains invalid characters"
      );
    }
    
    return true;
  }
}
