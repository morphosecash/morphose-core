pragma solidity ^0.8.0;
import "./MerkleTree.sol";
import "./MembershipVerifier.sol";
import "./SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


uint256 constant BN128_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

contract MorphoseERC20  {

    using MerkleTree for MerkleTree.Data;

    struct WithdrawProof {
        address payable recipent;
        bytes32 merkleRoot;
        bytes32 unitNullifier;
        bytes32[8] proof;
    }

    MembershipVerifier internal verifier;
    MerkleTree.Data internal merkleTree;
    mapping(bytes32 => bool) public withdrawn;
    uint256 public immutable denomination;
    address public token;
    uint256 public currentUnits;
    uint256 public anonymitySet;
    address public commAddr;

    event Deposit(bytes32 note, uint256 index, uint256 units);
    event Withdrawal(bytes32 unitNullifier);
 
    constructor(
        address morphAddr,
        address verifierAddr,
        uint256 denomination_,
        address token_,
        address commAddr_
    ) {
        verifier = MembershipVerifier(verifierAddr);
        merkleTree.hasher = Morph(morphAddr);
        require(denomination_ != 0, "Value cannot be zero");
        require(address(token_) != address(0), "Invalid Token Address"); 
        denomination = denomination_;
        token = token_;
        commAddr = commAddr_;
    }

    function deposit( bytes32 note, uint256 amount) public payable {
        require(uint256(note) < BN128_SCALAR_FIELD, "Invalid note");
        require(amount >= denomination, "Not enough funds sent");
        require(
            amount % denomination == 0,
            "Value needs to be exact multiple of denomination"
        );
        uint256 units = amount / denomination;
        require(units < BN128_SCALAR_FIELD);
        bytes32 leaf = merkleTree.hasher.poseidon([note, bytes32(units)]);
        uint256 index = merkleTree.insert(leaf);
        currentUnits += units;
        anonymitySet++;
        ERC20(token).transferFrom(msg.sender, address(this), amount ); 
        emit Deposit(note, index, units);     
    }

    function approve(address spender, uint256 amount)  public returns (bool success) {
        ERC20(token).approve(address(this), amount); 
        return true;
    }

    function withdraw(  WithdrawProof calldata args) public {
        require(merkleTree.roots[args.merkleRoot], "Invalid merkle tree root");
        require(
            !withdrawn[args.unitNullifier],
            "Deposit has been already withdrawn"
        );

        require(
            verifyMembershipProof(
                args.proof,
                args.merkleRoot,
                args.unitNullifier,
                getContextHash(args.recipent, msg.sender)
            ),
            "Invalid deposit proof"
        );

        withdrawn[args.unitNullifier] = true;
        
        if (currentUnits-- == 0) {
            anonymitySet = 0;
        }

        uint256 commission = SafeMath.div(denomination, 100);
        ERC20(token).transfer(args.recipent, (denomination - commission));
        ERC20(token).transfer(commAddr, commission);
    }

    function getMerklePath(uint256 index)
        public
        view
        returns (bytes32[MERKLE_DEPTH] memory)
    {
        return merkleTree.getPath(index);
    }

    function getContextHash(
        address recipent,
        address relayer
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(recipent, relayer)) >> 3;
    }

    function maxSlots() public pure returns (uint256) {
        return MERKLE_LEAVES;
    }

    function usedSlots() public view returns (uint256) {
        return merkleTree.numLeaves;
    }

    function verifyMembershipProof(
        bytes32[8] memory proof,
        bytes32 merkleRoot,
        bytes32 unitNullifier,
        bytes32 context
    ) internal view returns (bool) {
        require(proof.length == 8, "Invalid proof"); 
        require(uint256(merkleRoot) < BN128_SCALAR_FIELD, "Invalid merkleRoot");
        require(uint256(unitNullifier) < BN128_SCALAR_FIELD, "Invalid unitNullifier");
        require(uint256(context) < BN128_SCALAR_FIELD, "Invalid context");

        uint256[2] memory a = [uint256(proof[0]), uint256(proof[1])];
        uint256[2][2] memory b =
            [
                [uint256(proof[2]), uint256(proof[3])],
                [uint256(proof[4]), uint256(proof[5])]
            ];
        uint256[2] memory c = [uint256(proof[6]), uint256(proof[7])];
        uint256[3] memory input =
            [uint256(merkleRoot), uint256(unitNullifier), uint256(context)];
        return verifier.verifyProof(a, b, c, input);
    }
}
