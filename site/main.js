	//set up private board
		for (let i=0; i< 64; i++){
    		let newDiv = document.createElement("div");
    		newDiv.id = "main" + i;
    		newDiv.className = "square";
    		newDiv.setAttribute("data-ship", 0)
    		newDiv.setAttribute("data-index", i)
    		document.getElementById("mainBoard")
    			.appendChild(newDiv)
    			.addEventListener("click", changeColor);
		}

		//set up guess board
		for (let i=0; i< 64; i++){
			let newDiv = document.createElement("div");
    		newDiv.id = "alt" + i;
    		newDiv.className = "square";
    		document.getElementById("altBoard")
    			.appendChild(newDiv)
    			.addEventListener("click", guess);
		}

		//board set up functions
		let count = 12;

		function changeColor() {
			if (this.style.backgroundColor != "orange") {
		    	if (count > 0) {
		    		this.style.backgroundColor = "orange";
		    		this.setAttribute("data-ship", 1)
		    		count--;
		    		document.getElementById("count")	
		    		.innerHTML = count;
		    	}
		    } else {
	    		count++
	    		document.getElementById("count")	
	    		.innerHTML = count;
		    	this.style.backgroundColor = "white";
		    	this.setAttribute("data-ship", 0)
		    }
		    return false;
		}

		function guess() {
			if (this.innerHTML != "x") {
		    	this.innerHTML = "x";
		    } else {
		    	this.innerHTML = "";
		    }
		    return false;
		}

		//compute state
		let leaves = []
		let hashedLeaves = []
		let level1 = []
		let level2 = []
		let level3 = []
		let level4 = []
		let level5 = []
		let merkleRoot = ""

		function clearData() {
			console.log(1)
			leaves = [];
			hashedLeaves = [];
			level1 = [];
			level2 = [];
			level3 = [];
			level4 = [];
			level5 = [];
			merkleRoot = "";
			console.log(2)
			concat()
		}

		function concat() {
			for (let i=0; i< 64; i++){
				let elm = document.getElementById("main" + i)
				let data = elm.dataset.ship
				let leaf = data + indexToX(i) + indexToY(i) + data //length not handled properly here
				leaves.push(leaf)
				console.log(leaf)
			}
			hash()
		}

		function hash()  {
			for (let i = 0; i < leaves.length; i++) {
				hashedLeaves.push(web3.sha3(leaves[i]))
			}	
			hashedLeaves.sort()
			console.log(hashedLeaves)
			merkleTree()
		}

		function merkleTree() {
			for (let i = 0; i < hashedLeaves.length; i+=2) {
				level1.push(web3.sha3(hashedLeaves[i] + hashedLeaves[i+1]))
			}
			console.log(level1)
			for (i = 0; i < level1.length; i+=2) {
				level2.push(web3.sha3(level1[i] + level1[i+1]))
			}
			console.log(level2)
			for (i = 0; i < level2.length; i+=2) {
				level3.push(web3.sha3(level2[i] + level2[i+1]))
			}
			console.log(level3)
			for (i = 0; i < level3.length; i+=2) {
				level4.push(web3.sha3(level3[i] + level3[i+1]))
			}
			console.log(level3)
			for (i = 0; i < level4.length; i+=2) {
				level5.push(web3.sha3(level4[i] + level4[i+1]))
			}
			console.log(level5)
			merkleRoot = web3.sha3(level5[0] + level5[1])
			console.log(merkleRoot)
			document.getElementById("root")	
	    		.innerHTML = merkleRoot;
		}

		function indexToX(_index) {
			if (_index < 8) {
				return _index
			} else {
				return _index % 8
			}
		}

		function indexToY(_index) {
			if (_index < 8) {
				return 0
			} else {
				return (_index - (_index % 8)) / 8
			}
		}

		//web3
		let account;
		window.addEventListener('load', async () => {
			if (window.ethereum) {
		    	window.web3 = new Web3(ethereum);
		    	try {
		    		await ethereum.enable();
		    		account = web3.eth.accounts[0];
		    		document.getElementById("account").innerHTML = account;
		    	} catch (error) {
		    		console.log(error);
		    	}
		  	} else if (window.web3) {
		    	window.web3 = new Web3(web3.currentProvider);
		    	account = web3.eth.accounts[0];
		    	document.getElementById("account").innerHTML = account;
		  	} else {
		    	console.log('no web3!');
		  	}
		});


		//contract initialization
		const contractAbi = [{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"userBalance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"},{"name":"_square","type":"uint8[2]"},{"name":"_proof","type":"bytes32[6]"},{"name":"_leafData","type":"string"},{"name":"_smackTalk","type":"string"}],"name":"guessAndReveal","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_wager","type":"uint96"},{"name":"_playerAMerkleRoot","type":"bytes32"}],"name":"proposeGame","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"getBalance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"}],"name":"resolveUnansweredChallenge","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"}],"name":"emergencyResolve","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"isStopped","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"rows","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"gameCount","outputs":[{"name":"","type":"uint32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"hitThreshold","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"}],"name":"concedeGame","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"}],"name":"cancelProposedGame","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"abandonThreshold","outputs":[{"name":"","type":"uint32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"},{"name":"_playerBMerkleRoot","type":"bytes32"}],"name":"acceptGame","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"},{"name":"_leafData","type":"string[64]"}],"name":"answerChallenge","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint32"}],"name":"claimTimer","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"columns","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"}],"name":"resolveAbandonedGame","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_message","type":"string"}],"name":"emergencyStop","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"}],"name":"resolveUnclaimedVictory","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint32"}],"name":"games","outputs":[{"name":"id","type":"uint32"},{"name":"turnStartTime","type":"uint32"},{"name":"wager","type":"uint96"},{"name":"playerA","type":"address"},{"name":"playerB","type":"address"},{"name":"winner","type":"address"},{"name":"playerAhitCount","type":"uint8"},{"name":"playerBhitCount","type":"uint8"},{"name":"state","type":"uint8"},{"name":"turn","type":"uint8"},{"name":"playerAMerkleRoot","type":"bytes32"},{"name":"playerBMerkleRoot","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_id","type":"uint32"}],"name":"challengeVictory","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"admin","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"playerA","type":"address"},{"indexed":false,"name":"wager","type":"uint256"}],"name":"LogProposedGame","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"playerB","type":"address"},{"indexed":false,"name":"wager","type":"uint256"}],"name":"LogGameAccepted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"playerB","type":"address"}],"name":"LogGameCancelled","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"sender","type":"address"},{"indexed":false,"name":"smackTalk","type":"string"}],"name":"LogSmackTalk","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"user","type":"address"},{"indexed":false,"name":"amount","type":"uint256"}],"name":"LogUserWithdraw","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"user","type":"address"},{"indexed":false,"name":"square","type":"uint256"}],"name":"LogGuess","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"user","type":"address"},{"indexed":false,"name":"verfied","type":"bool"},{"indexed":false,"name":"square","type":"uint256"},{"indexed":false,"name":"isHit","type":"bool"}],"name":"LogReveal","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"winner","type":"address"}],"name":"LogVictoryPending","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"challenger","type":"address"}],"name":"LogVictoryChallenged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"gameID","type":"uint256"},{"indexed":true,"name":"winner","type":"address"},{"indexed":false,"name":"message","type":"string"}],"name":"LogWinner","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"message","type":"string"}],"name":"LogEmergency","type":"event"}];

		const contractAddress = "0x902d5c4d8869720d44dd4246c539b039cdeb803c";
		const contractInstance = web3.eth.contract(contractAbi).at(contractAddress);

		//read data from contract
  		contractInstance.gameCount(function(err, res) {
	    	if (err) {
	        	console.log(err);
	        	return;   
	    	} else {
	    		document.getElementById("game").innerHTML = res;
	  		}
	  	});

  		//send data to contract
		function proposeGame() {
		  console.log("proposed")
		  var val = document.getElementById("proposeValue").value; 
		  val = web3.toWei(val, "ether");
		  contractInstance.proposeGame(val, merkleRoot, {from: web3.eth.accounts[0], value: val}, function(err, txHash) {
		    if (err) {
		      console.log(err);
		      return;
		    } else {
			  console.log(txHash);
			}
		  });
		}
