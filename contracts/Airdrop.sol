// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "hardhat/console.sol";

contract Airdrop {
    address public admin;

    constructor(address _admin) {
        admin = _admin;
    }

    function verify(
        address _to,
        uint256 _amount,
        bytes memory adminSignature,
        bytes memory userSignature
    ) public view returns (bool) {
        bytes32 messageHash = getMessageHash(_to, _amount);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        bool isFromAdmin = recoverSigner(
            ethSignedMessageHash,
            adminSignature
        ) == admin;
        bool isFromUser = recoverSigner(ethSignedMessageHash, userSignature) ==
            msg.sender;

        console.log("Airdrop - verify() - admin: ", admin);
        console.log("Airdrop - verify() - isFromAdmin: ", isFromAdmin);
        console.log("Airdrop - verify() - user: ", msg.sender);
        console.log("Airdrop - verify() - isFromUser: ", isFromUser);

        return isFromAdmin && isFromUser;
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
        Signature is produced by signing a keccak256 hash with the following format:
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

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}
