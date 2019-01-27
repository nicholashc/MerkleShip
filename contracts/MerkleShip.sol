pragma solidity ^0.5.0;
/** ABIEncoderV2 required for arguments with string arrays */
/** ignore compiler warnings about this feature (yolo) */
pragma experimental ABIEncoderV2; 

import "../contracts/SafeMath.sol";

/** @title MerkleShip: Trustless Battleship on Ethereum */
contract MerkleShip {

  using SafeMath for *;

  ///////////////////
  //STATE VARIABLES//
  ///////////////////

  /** toggle for emergency circuit */
  bool public isStopped = false;
  /** admin address; cannot receive any ether */
  address public admin;
  /** global game id count */
  uint32 public gameCount;
  /** max turn length before a game is considered abandoned */ 
  uint32  public abandonThreshold = 48 hours;
  /** board width */
  uint8 public rows = 8;
  /** board height */
  uint8 public columns = 8;
  /** successful hits required for victory */
  uint8 public hitThreshold = 12;
  /** storage of game state by id */
  mapping (uint32 => Game) public games;
  /** ETH available for user withdrawal */
  mapping (address => uint256) public userBalance;
  /** separate timer to track VictoryPending claim time */
  mapping (uint32 => uint256) public claimTimer;

  /** eight possible game states */
  enum GameState { Ready, Cancelled, Active, Abandoned, VictoryPending, VictoryChallenged, Complete, Zeroed }
  /** three possible turn states */
  enum Turn { Inactive, PlayerA, PlayerB }
  /** four possible guess states */
  enum GuessState { Unknown, Pending, Hit, Miss }

  /** @dev primary storage of game state
   * @dev the variables up to playerAMerkleRoot maximize storage by packing tightly into three 256-bit words 
   */
  struct Game {
    /** global gameCount; will overflow if there are more than 4,294,967,295 games  */
    uint32 id; 
    /** turn start time; reset at start of each turn; will overflow February 7, 2106 */
    uint32 turnStartTime; 
    /** wager from one player (total prize is wager * 2) */
    /** cannot overflow as max uint96 is larger than total ETH supply unless vitalik goes wild */
    uint96 wager; 
    /** player who proposed the game */
    address payable playerA;
    /** player who accepted the game */
    address payable playerB;
    /** winner only set on game resolution */
    address payable winner;
    /** tracks number of hits on player A's board */
    uint8 playerAhitCount;
    /** tracks number of hits on player B's board */
    uint8 playerBhitCount;
    /** game state; takes 8 bits of storage */
    GameState state; 
    /** turn state; takes 8 bits of storage */
    Turn turn; 
    /** merkle root of playerA secret game board */
    bytes32 playerAMerkleRoot;
    /** merkle root of playerB secret game board */
    bytes32 playerBMerkleRoot;
    /** index of player A guess states */
    mapping (uint8 => GuessState) playerAguesses;  
    /** index of player B guess states */
    mapping (uint8 => GuessState) playerBguesses;  
    /** tracks square index of player A guesses; length property used to retrieve most recent guess */
    uint8[] playerAsquaresGuessed; 
    /** tracks square index of player B guesses; length property used to retrieve most recent guess */
    uint8[] playerBsquaresGuessed; 
  }

  /////////////
  //MODIFIERS//
  /////////////

  /** @dev controls whether it is the correct turn of the player attempting to call a game function
   * @dev blocks players who are not part of the game
   * @param _id Game ID
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

  /** @dev limits engagement to active games
   * @param _id Game ID
   */
  modifier isActive(uint32 _id) { 
    require (
      games[_id].state == GameState.Active,
      "the game must be active");
    _;
  }
  
  /** @dev limits engagement to games that have been proposed but are not yet active
   * @param _id Game ID
   */
  modifier isReady(uint32 _id) { 
    require (
      games[_id].state == GameState.Ready,
      "the game must be waiting for a player");
    _;
  }

  /** @dev blocks players who are not part of the game
   * @dev turn agnostic
   * @param _id Game ID
   */
  modifier isPlayer(uint32 _id) { 
    require (
      msg.sender == games[_id].playerA || msg.sender == games[_id].playerB,
      "you must be a valid player");
    _;
  }

  /** @dev circuit-breaker that blocks most functionality during an emergency
   */
  modifier notEmergency() { 
    require (isStopped == false,
    "you can only use this function in a non-emergency"); 
    _; 
  }

  /** @dev restricts functions that can only be used in an emergency
   */
  modifier onlyEmergency() { 
    require (isStopped == true,
    "you can only use this function in an emergency"); 
    _; 
  }
  
  /** @dev restricts functions that can accessed by the admin
   */
  modifier onlyAdmin() { 
    require (msg.sender == admin,
    "you must be the admin"); 
    _; 
  }

  ///////////////
  //CONSTRUCTOR//
  ///////////////

  constructor() public {
    admin = msg.sender;
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
    uint256 square
  ); 

  event LogReveal(
    uint256 indexed gameID,
    address indexed user,
    bool verfied,
    uint256 square,
    bool isHit
  );

  event LogVictoryPending(
    uint256 indexed gameID,
    address indexed winner
  );

  event LogVictoryChallenged(
    uint256 indexed gameID,
    address indexed challenger
  );

  event LogWinner(
    uint256 indexed gameID,
    address indexed winner,
    string message
  );

  event LogEmergency(
    string message
  );

  //////////////////
  //ADMIN FUNCTION//
  //////////////////

  /** @dev emergency stop function to bring all games to safe halt 
   * @dev can only be called once and cannot be reversed
   * @param _message optional message to explain stoppage
   */
  function emergencyStop(string calldata _message) 
    external
    onlyAdmin()
    notEmergency()
  {
    isStopped = true;
    emit LogEmergency(_message);
  }

  //////////////////////
  //PRE-GAME FUNCTIONS//
  //////////////////////

  /**
   * @dev propose a new game
   * @param _wager amount in wei (0 is a valid amount)
   * @param  _playerAMerkleRoot merkle root of initial game state
   */
  function proposeGame(uint32 _wager, bytes32 _playerAMerkleRoot) 
    external 
    payable 
    notEmergency()
  {
    require (msg.value == _wager, "you must send the right amount");
    /** increment gameCount; the first game is 1, not 0 */
    gameCount++;
    /** initialize struct in storage */
    Game storage g = games[gameCount];
    /** save initial game state */
    g.id = gameCount;
    g.wager = _wager;
    g.playerA = msg.sender;
    g.state = GameState.Ready;
    g.playerAMerkleRoot = _playerAMerkleRoot;

    emit LogProposedGame(gameCount, msg.sender, msg.value);
  }

  /**
   * @dev accept a proposed game
   * @param _id game id
   * @param  _playerBMerkleRoot merkle root of initial game state
   */
  function acceptGame(uint32 _id, bytes32 _playerBMerkleRoot) 
    external 
    payable 
    isReady(_id) 
    notEmergency()
  {
    require (msg.value == games[_id].wager, "you must match the wager");
    /** initialize struct from storage */
    Game storage g = games[_id];
    /** update game state */
    g.turnStartTime = uint32(now);
    g.playerB = msg.sender;
    g.state = GameState.Active;
    g.turn = Turn.PlayerA;
    g.playerBMerkleRoot = _playerBMerkleRoot;

    emit LogGameAccepted(_id, msg.sender, msg.value);
  }

  /**
   * @dev cancel a proposed game
   * @param _id game id
   */
  function cancelProposedGame(uint32 _id) 
    external 
    isReady(_id) 
    notEmergency()
  {
    require (msg.sender == games[_id].playerA, "you must have proposed this game");
    /** local variable of balance to return */
    uint256 balanceToReturn = games[_id].wager;
    /** initialize struct from storage */
    Game storage g = games[_id];
    /** update state and set wager amount to 0 */
    g.state = GameState.Cancelled;
    g.wager = 0;
    /** update user balance */
    userBalance[msg.sender] += balanceToReturn;

    emit LogGameCancelled(_id, msg.sender);
  }

  /////////////////////
  //IN-GAME FUNCTIONS//
  /////////////////////

  /** @dev submit a guess and reveal result of other player's previous guess
   * @param _id game id
   * @param _square x,y coordinates of guess
   * @param _proof merkle proof which consists of six hashes 
   * @param _leafData unhashed leaf being revealed (concatenated string in specified format)
   * @param _smackTalk optional message to other player
   */
  function guessAndReveal(
    uint32 _id, 
    uint8[2] memory _square, 
    bytes32[6] memory _proof, 
    string memory _leafData,
    string memory _smackTalk
    ) 
    public 
    turnControl(_id) 
    isActive(_id) 
    notEmergency()
  {
    require (_isStringValid(_smackTalk) || bytes(_smackTalk).length == 0, "smack talk must be a valid string");
    /** convert coordinates to index */
    /** this function also checks that the coordinate are inbounds */
    uint8 square = _coordinateToIndex(_square[0], _square[1]);
    /** initialize struct from storage */
    Game storage g = games[_id];
    /** process reveal and update state with playerA guess */
    if (msg.sender == games[_id].playerA) {
      /** nothing to reveal on playerA's first turn */
      if (g.playerBsquaresGuessed.length > 0) {
        /** reveal square from playerB's previous guess */
        _reveal(_id, _proof, _leafData);
      }
      /** guess coordinates stored in sequential array */
      g.playerAsquaresGuessed.push(square);
      /** guess state pending until revealed */
      g.playerAguesses[uint8(g.playerBsquaresGuessed.length)] = GuessState.Pending;
      /** reset turn start time */
      g.turnStartTime = uint32(now);
      /** update turn state  */
      g.turn = Turn.PlayerB;
    } 
    /** process reveal and update state with playerB guess */
    else if (msg.sender == games[_id].playerB) {
      _reveal(_id, _proof, _leafData);
      g.playerBsquaresGuessed.push(square);
      g.playerAguesses[uint8(g.playerAsquaresGuessed.length)] = GuessState.Pending;
      g.turnStartTime = uint32(now);
      g.turn = Turn.PlayerA;
    }

    emit LogGuess(_id, msg.sender, square);
    emit LogSmackTalk(_id, msg.sender, _smackTalk);
  } 

  /** @dev validate and reveal the previous guess
   * @param _id game id
   * @param _proof merkle proof with six hashes 
   * @param _leafData unhashed leaf being revealed (concatenated string in specified format)
   */
  function _reveal(
    uint32 _id, 
    bytes32[6] memory _proof, 
    string memory _leafData
  ) 
    internal 
  {    
    /** initialize game from storage */
    Game storage g = games[_id];
    /** retreive appropriate merkle root from game state  */
    bytes32 root;
    if (msg.sender == games[_id].playerA) {
      root = g.playerAMerkleRoot;
    } 
    else if (msg.sender == games[_id].playerB) {
      root = g.playerBMerkleRoot;
    }
    /** reveal and verify merkle proof from the other player's last guess */
    /** if the player calling this function can't provide the verification they will not be able to advance their turn */
    require (
      _verifyMerkleProof(_proof, root, _leafData) == true, 
      "you must provide a valid Merkle Proof"
    );
    /** retrieve index of square about to be revealed */
    uint8 guessToReveal;
    if (msg.sender == games[_id].playerA) {
      guessToReveal = uint8(g.playerBsquaresGuessed[g.playerBsquaresGuessed.length.sub(1)]);
    } 
    else if (msg.sender == games[_id].playerB) {
      guessToReveal = uint8(g.playerAsquaresGuessed[g.playerAsquaresGuessed.length.sub(1)]);
    }
    /** check the first byte of the revealed data to confirm if there was a ship in that square */
    bytes1 isHit = _subString(_leafData, 0);
    require (isHit == 0x31 || isHit == 0x30, "leaf data must be in correct format");
    /** update state if there was a hit */
    bool hit;
    /** 0x31 is the character "1" in bytes1 */
    if (isHit == 0x31) {
      hit = true;
      if (msg.sender == games[_id].playerA) {
        g.playerBguesses[guessToReveal] = GuessState.Hit;
        g.playerBhitCount++;
      } 
      else if (msg.sender == games[_id].playerB) {
        g.playerAguesses[guessToReveal] = GuessState.Hit;
        g.playerAhitCount++;
      }
    } 
    /** update state if there was a miss */
    /** 0x30 is the character "0" in bytes1 */
    else if (isHit == 0x30) {
      hit = false;
      if (msg.sender == games[_id].playerA) {
        g.playerBguesses[guessToReveal] = GuessState.Miss;
      } 
      else if (msg.sender == games[_id].playerB) {
        g.playerAguesses[guessToReveal] = GuessState.Miss;
      }
    } 

    _checkForVictoryByHit(_id);

    emit LogReveal(_id, msg.sender, true, guessToReveal, hit);
  }

  /** @dev check if a victory by hit was achieved
   * @param _id game id
   */
  function _checkForVictoryByHit(uint32 _id) 
    internal
  {
    /** initialize game from storage */
    Game storage g = games[_id];
    /** check for winner */
    if (g.playerAhitCount == hitThreshold) {
      g.state = GameState.VictoryPending;
      g.winner = games[_id].playerB;
    } 
    else if (g.playerBhitCount == hitThreshold) {
      g.state = GameState.VictoryPending;
      g.winner = games[_id].playerA;
    } 
    /** process winner */
    if (g.state == GameState.VictoryPending) {
      claimTimer[_id] = now;
      
      emit LogVictoryPending(_id, msg.sender);
    }
  }

  /** @dev can be called to resolve a game abandoned by the other player
   * @param _id game id
   */
  function resolveAbandonedGame(uint32 _id) 
    external 
    isActive(_id)
    isPlayer(_id) 
    notEmergency()
  {
    require (
      now >= games[_id].turnStartTime + abandonThreshold,
      "the game must be stale for at least 48 hours"
    ); 

    /** can only be called if it is NOT your turn */
    if (msg.sender == games[_id].playerA) {
      require (games[_id].turn == Turn.PlayerB, "it must be the other player's turn");
    } 
    else if (msg.sender == games[_id].playerB) {
      require (games[_id].turn == Turn.PlayerA, "it must be the other player's turn");
    }
    /** initialize struct from storage */
    Game storage g = games[_id];
    /** update game state */
    g.state = GameState.Abandoned;
    g.winner = msg.sender;
    /** calcuate prize */
    uint prize = g.wager * 2;
    /** zero out wager just in case */
    g.wager = 0;
    /** update winner balance */
    userBalance[msg.sender] += prize;

    emit LogWinner(_id, g.winner, "victory by abandonment");
  }

  /** @dev either player can call this function to concede
   * @dev the loser recovers 20% of their wager, incentivizing quick resolution of games
   * @param _id game id
   */
  function concedeGame(uint32 _id) 
    external 
    isActive(_id) 
    isPlayer(_id) 
    notEmergency()
  { 
    /** assign loser status to player conceding */
    address payable loser = msg.sender;
    /** assign winner status to other player */
    address payable winner;
    if (msg.sender == games[_id].playerA) {
      winner = games[_id].playerB;
    } 
    else if (msg.sender == games[_id].playerB) {
      winner = games[_id].playerA;
    }
    /** initialize struct in storage */
    Game storage g = games[_id];
    /** update game state */
    g.state = GameState.Complete;
    g.winner = winner;
    /** calculate winner prize (90% of pot) */
    uint256 prize = (g.wager.mul(180)).div(100);
    /** calculate loser prize (10% of pot) */
    uint256 concession = g.wager.mul(2).sub(prize);
    /** zero out wager */
    g.wager = 0;
    /** update user balances */
    userBalance[winner] += prize;
    userBalance[loser] += concession;

    emit LogWinner(_id, g.winner, "victory by concession");
  }

  /** @dev players can challenge pending victories, requiring full validation of starting game state
   * @dev on-chain reconstruction and validation of the full proof is expensive and makes up ~30% of the code in this contract
   * @dev this is all to handle to the single edge case of a player who computes a merkle root based on a dishonest initial game state
   * @param _id game id
   */
  function challengeVictory(uint32 _id)
    external
    isPlayer(_id)
    notEmergency()
  {
    Game storage g = games[_id];

    require (g.state == GameState.VictoryPending, "this game must be pending proof of honest play");
    require (msg.sender != g.winner);

    claimTimer[_id] = now;
    
    g.state = GameState.VictoryChallenged;

    emit LogVictoryChallenged(_id, msg.sender);
  }

  /** @dev if challenge, the proposed victor must provide and validate a full proof of their starting game state
   * @dev on-chain reconstruction and validation of the full proof is expensive and makes up ~30% of the code in this contract
   * @dev this is all to handle to the single edge case of a player who computes a merkle root based on a dishonest initial game state
   * @param _id game id
   * @param _leafData full unhashed array of starting game state for on-chain validation
   */
  function answerChallenge(uint32 _id, string[64] memory _leafData) 
    public
    isPlayer(_id) 
    notEmergency()
  {
    /** initialize struct from storage */
    Game storage g = games[_id];

    require (
      g.state == GameState.VictoryChallenged, 
      "this game must be in the VictoryChallenged state"
    );
    require (
      _checkShipCount(_leafData) == true, 
      "you must have set the correct number of ship squares"
    );
    require (
      _checkShipLength(_leafData) == true, 
      "you must have set the correct ship lengths "
    );

    bytes32 root;

    if (msg.sender == games[_id].playerA) {
      root = g.playerAMerkleRoot;
    } 
    else if (msg.sender == games[_id].playerB) {
      root = g.playerBMerkleRoot;
    }

    require (
      _computeMerkleTree(
        _sortArray(
          _hashEach(
            _leafData
          )
        )
      ) == root, 
      "the merkle root must match"
    );

    /** calculate prize */
    uint256 prize = g.wager * 2;
    /** zero out wager */
    g.wager = 0;
    /** update winner balance */
    userBalance[g.winner] += prize;

    /** offset gas cost of this process by zeroing out as much storage as possible */
    /** this takes advantage of gas refunds gained from setting non-zero storage values to zero */
    /** only valid winners can use this to offset gas costs */
    _zeroOutStorage(_id);

    emit LogWinner(_id, g.winner, "verified victory by hit count");
  }

  /** @dev helper function to reduce gas costs of full validation by earning storage refunds
   * @param _id game id
   */
  function _zeroOutStorage(uint32 _id)
    internal
  {
    /** initialize struct from storage */
    Game storage g = games[_id]; 

    /** g.id maintained for history */
    delete g.turnStartTime;
    delete g.wager;
    delete g.playerA;
    delete g.playerB;
    /** g.winner maintained for history */
    delete g.playerAhitCount;
    delete g.playerBhitCount;
    g.state = GameState.Zeroed;
    delete g.turn; 
    delete g.playerAMerkleRoot;
    delete g.playerBMerkleRoot;
    for (uint8 i = 0; i < g.playerAsquaresGuessed.length; i++) {
      /** loop required to delete individual mapping keys */
      delete g.playerAguesses[i]; 
    }
    for (uint8 i = 0; i < g.playerBsquaresGuessed.length; i++) {
      /** loop required to delete individual mapping keys */
      delete g.playerBguesses[i]; 
    } 
    delete g.playerAsquaresGuessed; 
    delete g.playerBsquaresGuessed; 
  }

  /** @dev function to claim abandoned game in VictoryPending state
   * @param _id game id
   */
  function resolveUnclaimedVictory(uint32 _id) 
    external
    isPlayer(_id) 
    notEmergency()
  { 
    Game storage g = games[_id];

    require (
      now >= claimTimer[_id] + abandonThreshold, 
      "the potential victor has 48h to validate their claim"
    );
    require (
      g.state == GameState.VictoryPending, 
      "this game must be pending proof of honest play"
    );
    
    /** change game state */
    g.state = GameState.Complete;
    /** calculate prize */
    uint256 prize = g.wager * 2;
    /** zero out wager */
    g.wager = 0;
    /** update winner balance */
    userBalance[g.winner] += prize;

    emit LogWinner(_id, g.winner, "victory by unchallenged hit count");
  }

  /** @dev function to claim unproven challenge in VictoryChallenged state
   * @param _id game id
   */
  function resolveUnansweredChallenge(uint32 _id) 
    external
    isPlayer(_id) 
    notEmergency()
  { 
    Game storage g = games[_id];

    require (
      now >= claimTimer[_id] + abandonThreshold, 
      "the potential victor has 48h to validate their claim"
    );
    require (
      g.state == GameState.VictoryChallenged,
      "this game must be in VictoryChallenged state"
    );

    /** change victor */
    if (g.winner == games[_id].playerA) {
      g.winner = games[_id].playerB;
    } 
    else if (g.winner == games[_id].playerB) {
      g.winner = games[_id].playerA;
    } 

    /** change game state */
    g.state = GameState.Complete;
    /** calculate prize */
    uint256 prize = g.wager * 2;
    /** zero out wager */
    g.wager = 0;
    /** update winner balance */
    userBalance[g.winner] += prize;

    emit LogWinner(_id, g.winner, "victory by unanswered challenge");
  }
  
  /** @dev this function is only way ETH can leave the contract
   */
  function withdraw() 
    external 
  {
    require (userBalance[msg.sender] > 0, "user must have a balance to withdraw");
    /** set balance as local variable */
    uint256 balance = userBalance[msg.sender];
    /** change state balance to 0 */
    userBalance[msg.sender] = 0;
    /** safely transfer without potential for reentrancy */
    /** for smart contracts trying to change state in their fallback function or reverting transfers...don't ¯\_(ツ)_/¯ */
    msg.sender.transfer(balance);

    emit LogUserWithdraw(msg.sender, balance);
  }

  /** @dev emergencyResolve credits wagers in any game state so users can withdraw
   * @param _id game id
   */
  function emergencyResolve(uint32 _id)
    external
    onlyEmergency()
    isPlayer(_id) 
  {
    Game storage g = games[_id];
    
    if (g.state == GameState.Ready) {
      /** return staked funds */
      g.state = GameState.Complete;
      uint256 refund = g.wager;
      g.wager = 0;
      userBalance[g.playerA] += refund;
    } else if (
      g.state == GameState.Active || 
      g.state == GameState.VictoryPending ||
      g.state == GameState.VictoryChallenged
    ) {
      /** split funds */
      g.state = GameState.Complete;
      uint256 refund = g.wager;
      g.wager = 0;
      userBalance[g.playerA] += refund;
      userBalance[g.playerB] += refund;
    }

    emit LogWinner(_id, address(0), "game resolved in an emergency");  
  }

  //////////////////////////////
  //VALIDATE VICTORY FUNCTIONS//
  //////////////////////////////

  /** @dev the functions in this section exist exclusively to valid the full game state in the rare event a victory is challenged */

  /** @dev confirms whether the winner set the correct number of ships if their victory is challenged
   * @param _data array of initial state
   * @return true if condition met; false if not
   */
  function _checkShipCount(string[64] memory _data) 
    internal
    view
    returns(bool)
  {
    uint256 shipCount;

    for (uint256 i = 0; i < 64; i++) {
      if (_subString(_data[i], 0) == 0x31) {
        shipCount++;
        if (shipCount == hitThreshold) {
          return true;
        }
      }
    }
  }

  /** @dev confirms whether the winner set the correct lengths of ships if their victory is challenged
   * @param _data array of initial state
   * @return true if condition met; false if not
   */
  function _checkShipLength(string[64] memory _data) 
    internal
    view
    returns(bool)
  {
    uint256 longShipsVerfied;

    for (uint256 i = 0; i < 64; i++) {
      bytes1 shipLength = _subString(_data[i], 3);
      bool fourFound;
      bool threeFound;
      bool twoFound;

      if (shipLength == 0x34 && fourFound == false) {
        require (
          _subString(_data[i + 1], 3) == 0x34 &&
          _subString(_data[i + 2], 3) == 0x34 &&
          _subString(_data[i + 3], 3) == 0x34 ||
          _subString(_data[i + rows], 3) == 0x34 &&
          _subString(_data[i + 2 * rows], 3) == 0x34 &&
          _subString(_data[i + 3 * rows], 3) == 0x34,
          "you must have one ship that is four squares long" 
        );
        longShipsVerfied++;
        fourFound = true;
      }

      if (shipLength == 0x33 && threeFound == false) {
        require (
          _subString(_data[i + 1], 3) == 0x33 &&
          _subString(_data[i + 2], 3) == 0x33 ||
          _subString(_data[i + rows], 3) == 0x33 &&
          _subString(_data[i + 2 * rows], 3) == 0x33,
          "you must have one ship that is three squares long" 
        );
        longShipsVerfied++;
        threeFound = true;
      }

      if (shipLength == 0x32 && twoFound == false) {
        require (
          _subString(_data[i + 1], 3) == 0x32 ||
          _subString(_data[i + rows], 3) == 0x32,
          "you must have one ship that is two squares long" 
        );
        longShipsVerfied++;
        twoFound = true;
      }

      if (longShipsVerfied == 3) {
        return true;
      }
    }
  }

  /** @dev helper function for recomputing merkle tree
   * @param _data unhashed leaves from initial game state
   * @return array of hashed leaves
   */
  function _hashEach(string[64] memory _data) 
    internal 
    pure 
    returns(bytes32[] memory)
  {
    bytes32[] memory arr = new bytes32[](64);
       for (uint i = 0; i < _data.length; i++) {
           arr[i] = keccak256(abi.encodePacked(_data[i]));
       }

    return arr;
  } 

  /** @dev helper function for sorting merkle tree leaves
   * @param _data hashed leaves
   * @return array of sorted leaves
   */
  function _sortArray(bytes32[] memory _data) 
    internal 
    pure 
    returns(bytes32[] memory) 
  {
    _quickSort(_data, int(0), int(_data.length.sub(1)));
    return _data;
  }
  
  /** @dev helper function for sorting merkle tree leaves
   * @dev based on https://gist.github.com/subhodi/b3b86cc13ad2636420963e692a4d896f
   * @param _arr hashed leaves
   * @param _left initial left-most array index
   * @param _right initial right-most array index
   * @return array of sorted leaves
   */
  function _quickSort(bytes32[] memory _arr, int _left, int _right) 
    internal 
    pure 
  {
    int i = _left;
    int j = _right;
    if(i==j) return;
    bytes32 pivot = _arr[uint(_left + (_right - _left) / 2)];
    while (i <= j) {
      while (_arr[uint(i)] < pivot) i++;
      while (pivot < _arr[uint(j)]) j--;
      if (i <= j) {
        (_arr[uint(i)], _arr[uint(j)]) = (_arr[uint(j)], _arr[uint(i)]);
        i++;
        j--;
      }
    }
    if (_left < j)
      _quickSort(_arr, _left, j);
    if (i < _right)
      _quickSort(_arr, i, _right);
  }

  /** @dev recompute merkle tree
   * @param _data sorted hashed leaves
   * @return merkle root
   */
  function _computeMerkleTree(bytes32[] memory _data) 
    internal 
    pure 
    returns(bytes32) 
  {
    require (_data.length.mod(2) == 0, "even sets only");

    if (_data.length >= 2) {
      bytes32[] memory newData = new bytes32[](_data.length / 2);
      uint256 j = 0;
      for (uint256 i = 0; i < _data.length; i+=2) {
        newData[j] = keccak256(abi.encodePacked(_data[i], _data[i+1]));
        j++;
      }
      if (newData.length > 2) {
        return _computeMerkleTree(newData);
      }
      else if (newData.length == 2) {
        return keccak256(abi.encodePacked(newData[0], newData[1]));
      }
    } 
    else if (_data.length == 2) {
      return keccak256(abi.encodePacked(_data[0], _data[1]));
    }
  }

  /////////////
  //UTILITIES//
  /////////////

  /** @dev verifies merkle proof against stored root
   * @dev requires the merkle tree be a sorted, balanced array of hashed leaves
   * @dev adapted from https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/cryptography/MerkleProof.sol
   * @param _proof six hash merkle proof
   * @param _root merkle root saved in game storage
   * @param _leafData unhashed leaf data being revealed
   * @return true if proof is validated; false if not
   */
  function _verifyMerkleProof(
    bytes32[6] memory _proof, 
    bytes32 _root, 
    string memory _leafData
  ) 
    internal 
    pure 
    returns(bool) 
  {
    /** hash leaf data */
    bytes32 computedHash = keccak256(abi.encodePacked(_leafData));
    /** loop through proof to compute merkle root */
    for (uint256 i = 0; i < _proof.length; i++) {
      bytes32 proofElement = _proof[i];
      computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
    }
    /** return true if proof matches stored merkle roof */
    return computedHash == _root;
  }

  /** @dev utility function to check if coordinates are within a valid game board
   * @param _x x coordinate
   * @param _y y coordinate
   * @return true if coordinates are valid; false if not
   */
  function _isCoordinateValid(uint8 _x, uint8 _y) 
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

  /** @dev utility function to convert coordinate to array index
   * @param _x x coordinate
   * @param _y y coordinate
   * @return index from 0-63
   */
  function _coordinateToIndex(uint8 _x, uint8 _y) 
    internal 
    view 
    returns(uint8) 
  {
    require (_isCoordinateValid(_x, _y), "coordinate must be valid");
    /** move starting index from 0 to 1 so multiplication works properly */
    uint8 xShifted = _x + 1;
    uint8 yShifted = _y + 1;

    if (yShifted > 1) {
      /** if not in first row, multiply by row height and add reshifted x value */
      return uint8(yShifted * columns + xShifted - 1);
    } 
    else {
      /** if in first row, return reshifted x value */
      return uint8(xShifted - 1);
    }
  }

 /** @dev utility function to return a substring
   * @param _inputStr input string
   * @param _index index of desired substring character
   * @return one byte substring
   */
  function _subString(string memory _inputStr, uint256 _index) 
    internal 
    pure 
    returns(bytes1) 
  { 
    /** convert to bytes to access substring index */
    bytes memory _str = bytes(_inputStr);
    /** return first character */
    return _str[_index];
  }

  /** @dev utility function to make sure no one xss attacks the front end with invalid strings
   * @param _inputStr input string
   * @return true if string is valid; false if not
   */
  function _isStringValid(string memory _inputStr)
    internal 
    pure
    returns(bool)
  { 
    /** convert to bytes to access length property */
    bytes memory _str = bytes(_inputStr);
    uint256 _length = _str.length;
    
    require (_length <= 40,"string cannot be longer than 40 characters");
    /** check each character */
    for (uint256 i = 0; i < _length; i++) {
      require ( 
        /** allowed: a-z lowercase && " " (a normal space character) */
        (_str[i] > 0x60 && _str[i] < 0x7b) || _str[i] == 0x20,
        "string contains invalid characters"
      );
    }
    
    return true;
  }
}
