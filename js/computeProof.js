const Web3 = require('web3');
const bip39 = require('bip39');
const MerkleTree = require('merkletreejs');
const keccak256 = require('keccak256')

const web3 = new Web3();

//buffer to hex util function
const buf2hex = x => '0x'+x.toString('hex')

// test values
const leaves = [ "0000unknown", "1104joy", "0200hold", "0300case", "0400reduce", "0500dust", "0600time", "0700smart", "0010wine", "1114spin", "0210collect", "0310random", "0410cigar", "1511merit", "0610balance", "0710sing", "0020now", "1124hand", "0220flavor", "0320lobster", "0420figure", "0520fold", "1621tuition", "0720eye", "0030mixed", "1134ski", "0230slide", "0330popular", "0430clarify", "0530airport", "0630hammer", "0730velvet", "0040whisper", "0140nerve", "0240wet", "1343knee", "1443return", "1543wire", "0640chair", "0740unlock", "0050diagram", "0150hand", "1252reduce", "0350clap", "0450sock", "0550surprise", "0650vehicle", "0750once", "0060scene", "0160fortune", "1262bonus", "0360forward", "0460mom", "0560exist", "1661have", "0760joke", "0070video", "0170word", "0270dog", "0370worry", "0470purity", "0570drip", "0670bacon", "0770gloom" ];
const hashedLeaves = []

// iterate through game data arrays, concat, and hash
for (let i = 0; i < leaves.length; i++) {
	// hash
	hashedLeaves.push(keccak256(leaves[i]))
}	

//sort binary buffers for simpler merkle proofs on chain
hashedLeaves.sort(Buffer.compare)

//compute tree and root
const tree = new MerkleTree(hashedLeaves, keccak256)
const root = buf2hex(tree.getRoot())
console.log('root: ' + root)

//generate proof; required to valididate on-chain
function getProof(str) {
	const proof = tree.getProof(keccak256(str)).map(x => buf2hex(x.data))
	console.log('proof: ', proof)
	return
}	

console.log(getProof('0000unknown'))
