pragma solidity ^0.8.0;
import "./MorphoseERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MorphoseERC20Admin {
    struct Entry {
        uint256 index;
        address addr;
        address token;
    }

    address public owner = msg.sender;
    address public morph;
    address public verifier;

    uint256[] internal denominations;
    mapping(address => Entry) internal morphoses;

    event MorphoseDeployed(uint256 denomination, address addr);
    event MorphoseRemoved(uint256 denomination, address addr);

    constructor(address morph_, address verifier_) {
        morph = morph_;
        verifier = verifier_;
    }

    function transferOwner(address _owner) public restricted {
        owner = _owner;
    }

    modifier restricted() {
        require(
            msg.sender == owner,
            "This function is restricted to the contract's owner"
        );
        _;
    }

    function createMorphose(uint256 denomination, address token, address commmAdd) public restricted {
        MorphoseERC20 newMorphose = new MorphoseERC20(morph, verifier, denomination, token, commmAdd);
        emit MorphoseDeployed(denomination, address(newMorphose));
    }

    function getDenominations() public view returns (uint256[] memory) {
        return denominations;
    } 
}
