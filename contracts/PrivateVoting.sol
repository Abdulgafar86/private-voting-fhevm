// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

contract PrivateVoting is GatewayCaller {
    // encrypted tallies
    euint64 public votesA;
    euint64 public votesB;

    // decrypted public totals (filled by Gateway callback)
    uint64 public revealedA;
    uint64 public revealedB;
    bool public revealed;

    constructor() {
        votesA = TFHE.asEuint64(0);
        votesB = TFHE.asEuint64(0);

        // allow contract to manipulate these ciphertexts
        TFHE.allow(votesA, address(this));
        TFHE.allow(votesB, address(this));
    }

    // vote: caller provides an encrypted "1" (e.g., ciphertext for integer 1)
    // encryptedOne must be a ciphertext suitable for euint64 (sent as bytes/encoded)
    function vote(bool isForA, bytes calldata encryptedOne) external {
        // create an euint64 from the submitted ciphertext
        euint64 one = TFHE.asEuint64(encryptedOne);

        // contract should be allowed to operate on that ciphertext
        TFHE.allow(one, address(this));

        if (isForA) {
            votesA = TFHE.add(votesA, one);
        } else {
            votesB = TFHE.add(votesB, one);
        }
    }

    // anyone can request reveal — contract requests async decryption of both tallies
    function requestReveal() external {
        uint256[] memory ctsA = Gateway.toUint256(votesA);
        uint256 requestA = Gateway.requestDecryption(ctsA, this.revealCallback.selector, 0, block.timestamp + 3600, false);
        addParamsUint256(requestA, 0); // mark this request as for A

        uint256[] memory ctsB = Gateway.toUint256(votesB);
        uint256 requestB = Gateway.requestDecryption(ctsB, this.revealCallback.selector, 0, block.timestamp + 3600, false);
        addParamsUint256(requestB, 1); // mark this request as for B
    }

    // callback invoked by Gateway relayer with decrypted integer
    // note: callback signature must match types (requestID, decryptedValue)
    function revealCallback(uint256 requestID, uint64 decrypted) public onlyGateway returns (uint64) {
        uint256[] memory params = getParamsUint256(requestID);
        require(params.length > 0, "no params");

        if (params[0] == 0) {
            revealedA = decrypted;
        } else {
            revealedB = decrypted;
        }

        // set revealed true if we have nonzero totals (simple logic)
        if (revealedA != 0 || revealedB != 0) {
            revealed = true;
        }

        return decrypted;
    }
}
