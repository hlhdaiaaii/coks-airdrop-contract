// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface ICOKSNFT {
    function safeMintMulti(
        address to,
        uint256 num,
        uint256[] memory attr
    ) external;
}

contract COKSWheel is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    uint256 public ticketPrice = 1 ether;

    address public admin;
    ICOKSNFT public nft;
    IERC20 public coksToken;
    IERC20 public stableCoin;

    // to => nonce => bool
    mapping(address => mapping(uint256 => bool)) public isClaimed;
    mapping(address => BuyTicketTransaction[]) public transactions;
    mapping(address => Counters.Counter) public transactionIds;

    // whitelist
    mapping(address => bool) public whitelist;

    Counters.Counter private _randomCounter;
    uint256 public oneStarRate;
    uint256 public twoStarRate;
    uint256 public threeStarRate;
    uint256 public fourStarRate;
    uint256 public fiveStarRate;

    struct BuyTicketTransaction {
        uint256 id;
        uint256 amount;
        uint256 price;
        uint256 timestamp;
    }

    event ClaimedToken(
        uint256 indexed _nonce,
        address indexed _to,
        uint256 _amount
    );
    event ClaimedStableCoin(
        uint256 indexed _nonce,
        address indexed _to,
        uint256 _amount
    );
    event ClaimedNFT(
        uint256 indexed _nonce,
        address indexed _to,
        uint256 _amount
    );
    event ClaimedWhitelist(uint256 indexed _nonce, address indexed _to);
    event BuyTicket(
        uint256 _id,
        address indexed _to,
        uint256 _amount,
        uint256 _price,
        uint256 _timestamp
    );

    // setter
    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function setTicketPrice(uint256 _ticketPrice) external onlyOwner {
        ticketPrice = _ticketPrice;
    }

    function config(
        address _admin,
        uint256 _ticketPrice,
        address _nft,
        address _coksToken,
        address _stableCoin
    ) external onlyOwner {
        admin = _admin;
        ticketPrice = _ticketPrice;
        nft = ICOKSNFT(_nft);
        coksToken = IERC20(_coksToken);
        stableCoin = IERC20(_stableCoin);
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

    function buyTicket(uint256 _amount) external payable {
        address _to = msg.sender;

        require(msg.value == _amount * ticketPrice, "NOT_ENOUGH_BALANCE");

        BuyTicketTransaction memory transaction = BuyTicketTransaction({
            id: transactionIds[_to].current(),
            amount: _amount,
            price: ticketPrice,
            timestamp: block.timestamp
        });
        transactions[_to].push(transaction);
        transactionIds[_to].increment();

        emit BuyTicket(
            transaction.id,
            _to,
            transaction.amount,
            transaction.price,
            transaction.timestamp
        );
    }

    function claimNFT(
        string memory _seperator,
        uint256 _nonce,
        uint256 _amount,
        bytes memory _adminSignature
    ) external {
        address _to = msg.sender;

        require(!isClaimed[_to][_nonce], "ALREADY_CLAIMED");

        bytes32 messageHash = keccak256(
            abi.encodePacked(_seperator, _nonce, _to, _amount)
        );

        require(verifySignature(messageHash, _adminSignature), "NOT_PERMITTED");

        // mint
        uint256[] memory attrList = new uint256[](_amount);

        for (uint256 i = 0; i < _amount; i++) {
            _randomCounter.increment();
            uint256 randomStar = calcStar(random(i));
            attrList[i] = randomStar;
        }

        nft.safeMintMulti(_to, _amount, attrList);

        isClaimed[_to][_nonce] = true;
        emit ClaimedNFT(_nonce, _to, _amount);
    }

    function claimToken(
        string memory _seperator,
        uint256 _nonce,
        uint256 _amount,
        bytes memory _adminSignature
    ) external nonReentrant {
        address _to = msg.sender;

        require(!isClaimed[_to][_nonce], "ALREADY_CLAIMED");

        bytes32 messageHash = keccak256(
            abi.encodePacked(_seperator, _nonce, _to, _amount)
        );

        require(verifySignature(messageHash, _adminSignature), "NOT_PERMITTED");

        coksToken.transfer(_to, _amount);
        isClaimed[_to][_nonce] = true;
        emit ClaimedToken(_nonce, _to, _amount);
    }

    function claimStableCoin(
        string memory _seperator,
        uint256 _nonce,
        uint256 _amount,
        bytes memory _adminSignature
    ) external nonReentrant {
        address _to = msg.sender;

        require(!isClaimed[_to][_nonce], "ALREADY_CLAIMED");

        bytes32 messageHash = keccak256(
            abi.encodePacked(_seperator, _nonce, _to, _amount)
        );

        require(verifySignature(messageHash, _adminSignature), "NOT_PERMITTED");

        stableCoin.transfer(_to, _amount);
        isClaimed[_to][_nonce] = true;
        emit ClaimedStableCoin(_nonce, _to, _amount);
    }

    function claimWhitelist(
        string memory _seperator,
        uint256 _nonce,
        bytes memory _adminSignature
    ) external {
        address _to = msg.sender;
        require(!isClaimed[_to][_nonce], "ALREADY_CLAIMED");

        bytes32 messageHash = keccak256(
            abi.encodePacked(_seperator, _nonce, _to)
        );

        require(verifySignature(messageHash, _adminSignature), "NOT_PERMITTED");

        whitelist[_to] = true;
        isClaimed[_to][_nonce] = true;
        emit ClaimedWhitelist(_nonce, _to);
    }

    function verifySignature(bytes32 _messageHash, bytes memory _adminSignature)
        public
        view
        returns (bool)
    {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(_messageHash);

        // whether this permission is granted from admin
        // whether this user is the user admin permits to claim
        bool isPermittedByAdmin = recoverSigner(
            ethSignedMessageHash,
            _adminSignature
        ) == admin;

        return isPermittedByAdmin;
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
