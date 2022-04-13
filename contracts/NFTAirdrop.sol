// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface INFT {
    function safeMintMulti(
        address to,
        uint256 num,
        uint256[] memory attr
    ) external;
}

contract NFTAirdrop is Ownable {
    using Counters for Counters.Counter;

    address public admin;
    INFT public nft;

    mapping(address => bool) public isClaimed;

    Counters.Counter private _randomCounter;
    uint256 public oneStarRate;
    uint256 public twoStarRate;
    uint256 public threeStarRate;
    uint256 public fourStarRate;
    uint256 public fiveStarRate;

    event Claimed(address indexed _to, uint256 amount, uint256[] listAttr);

    constructor(address _admin, address _nft) {
        admin = _admin;
        nft = INFT(_nft);
    }

    // setter
    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function setNFT(address _nft) external onlyOwner {
        nft = INFT(_nft);
    }

    function setRate(
        uint256 _oneStarRate,
        uint256 _twoStarRate,
        uint256 _threeStarRate,
        uint256 _fourStarRate,
        uint256 _fiveStarRate
    ) external onlyOwner {
        oneStarRate = _oneStarRate;
        twoStarRate = _twoStarRate;
        threeStarRate = _threeStarRate;
        fourStarRate = _fourStarRate;
        fiveStarRate = _fiveStarRate;
    }

    function claim(uint256 _amount, bytes memory _adminSignature) external {
        address _to = msg.sender;

        require(!isClaimed[_to], "ALREADY_CLAIMED");

        require(verify(_to, _amount, _adminSignature), "NOT_PERMITTED");

        // mint
        uint256[] memory attrList = new uint256[](_amount);

        for (uint256 i = 0; i < _amount; i++) {
            _randomCounter.increment();
            uint256 randomStar = calcStar(random(i));
            attrList[i] = randomStar;
        }

        nft.safeMintMulti(_to, _amount, attrList);

        isClaimed[_to] = true;
        emit Claimed(_to, _amount, attrList);
    }

    function verify(
        address _to,
        uint256 _amount,
        bytes memory _adminSignature
    ) public view returns (bool) {
        bytes32 messageHash = getMessageHash(_to, _amount);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        // whether this permission is granted from admin
        // whether this user is the user admin permits to claim
        bool isPermittedByAdmin = recoverSigner(
            ethSignedMessageHash,
            _adminSignature
        ) == admin;

        return isPermittedByAdmin;
    }

    function getMessageHash(address _to, uint256 _amount)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_to, _amount));
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        /*
        Signature is produced by signing a keccak256 hash with the following format (EIP-191 compliant):
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function recoverSigner(bytes32 _messageHash, bytes memory _signature)
        public
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_messageHash, v, r, s);
    }

    function splitSignature(bytes memory _sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(_sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(_sig, 32))
            // second 32 bytes
            s := mload(add(_sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    function random(uint256 _num) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        _randomCounter.current(),
                        block.timestamp,
                        blockhash(block.number - 1),
                        _num,
                        tx.origin // Because may have many random in 1 block
                    )
                )
            ) % 100;
    }

    function calcStar(uint256 _randomNum) internal view returns (uint256) {
        if (_randomNum <= oneStarRate) {
            return 1;
        } else if (
            _randomNum > oneStarRate && _randomNum <= oneStarRate + twoStarRate
        ) {
            return 2;
        } else if (
            _randomNum > oneStarRate + twoStarRate &&
            _randomNum <= oneStarRate + twoStarRate + threeStarRate
        ) {
            return 3;
        } else if (
            _randomNum > oneStarRate + twoStarRate + threeStarRate &&
            _randomNum <=
            oneStarRate + twoStarRate + threeStarRate + fourStarRate
        ) {
            return 4;
        } else {
            return 5;
        }
    }
}
