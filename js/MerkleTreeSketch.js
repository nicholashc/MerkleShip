/*
* node sketch to test client side merkle proof generation
*/

const Web3 = require('web3');
const bip39 = require('bip39');
const MerkleTree = require('merkletreejs');
const keccak256 = require('keccak256')

const web3 = new Web3();

/*
* utility for generating salt added to the leaf of each game square
* this functions like a brainwallet by deterministically generating a fixed number words from user-provided seed
* this is necessary to prevent a rain-bow table attack on all possible game states
* note: @dev much higher entropy is required as all possible states with bip39 words can still be rainbow tabled in short order
* @dev change salt to 128-bit+ hex keys 
*/
let mnemonicArray = [];

function generateMnemonic(pass) {
	let phrase = web3.utils.soliditySha3(pass)
	let mnemonic = bip39.entropyToMnemonic(phrase.slice(-32));
	for (let i = 0; i < 4; i++) {
		mnemonic = (mnemonic + ' ' + bip39.entropyToMnemonic(web3.utils.soliditySha3(mnemonic).slice(-32))); 
	}
	mnemonicArray = mnemonic.split(' ').slice(0, 63);
}

generateMnemonic('test')
console.log(mnemonicArray);

/*
* functions to compute a merkle tree off chain
* the merkle root of the secret game board is logged in the game state
* users provide a proof that reveals one guess per turn
* validated on chain
*/

// test values
const x = [0, 1, 2, 3, 0, 1, 2, 3]
const y = [0, 0, 0, 0, 1, 1, 1, 1]
const b = [false, true, false, false, false, true, false, false]
const c = ['unknown', 'joy', 'hold', 'case', 'reduce', 'dust', 'time', 'smart'];
const bufHash = []

// iterate through game data arrays, concat, and hash
for (let i = 0; i < x.length; i++) {
	//concat and hash
	bufHash.push(keccak256(String(x[i]) + String(y[i]) + String(b[i]) + c[i]))
}	
//sort binary buffers for simpler merkle proofs on chain
bufHash.sort(Buffer.compare)

//compute tree and root
const tree = new MerkleTree(bufHash, keccak256)
const root = buf2hex(tree.getRoot())
console.log('root: ' + root)

//generate proof; required to valididate on-chain
function getProof(str, num) {
	const proof = tree.getProof(keccak256(str, num)).map(x => buf2hex(x.data))
	console.log(proof)
	return
}	

//buffer to hex util function
const buf2hex = x => '0x'+x.toString('hex')


/*
computed test tree

1 10truejoy 0x1bb09f637d541974867da4692e64780008d3a4e247828ea941e5598cf4105ca0
6 21falsetime 0x247430200ba9e5e197e52b466539a6accae162ed55f898a5cb749b4c9587ef86

0 00falseunknown 0x272391685b201fbf8ea147b5d2a718d06e473c7095e79817e75eee1c22132e99
2 20falsehold 0x2df5b40dc17e3026aba28a01408e3e81a3769520beadf67ddb64b55c21bd31aa

4 01falsereduce 0x5e65f724b5c655fc2be5ddabdac892b1a86d609af369bddb0f86f72effb81cea
3 30falsecase 0x8439be356b2dd7425ec6f668051a46875e6c381906b5e220453648acf27ce893

5 11truedust 0x901787b94644892e2020bd193b49c612d863989924f14792d2fe2f138a2a4636
7 31falsesmart 0xd1acf4a0ff01ef263b9433bc1eab68ce63b5fca7759490188f53e56ed51dd7ac

16 0xb65d8da05eb3a58a2f7def5839a774748ad4a272df12bcbb1736188c720f0e36

02 0xdace09567e71d9315f9fcd3cf0b70a77a4d548815943ab866068447fe3bea277

43 0xadbd4d6e18ed117cffc286b3ced3f3856a86878f6d0c69d553c5312d1c451e16

57 0x8df035791041fdc92179a9a4b76d34e08cccfee5e82d66c9f2333e005339cc36

1602 0x6fe6d136bf96f307f77a31251e12efbbeba4926c7cd667643778fcadcd0985eb

4357 0x8753ae172c78290a069585e486cd3c842a0310d2a4450cf738d67453d5409595

root 0xdfaa33348516183f4cc09722e86d32fe813c71028ea33509b3e4f185934e8b2c

*/
