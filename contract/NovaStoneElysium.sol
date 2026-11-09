// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title Nova Elysium Stone (NOVA) — NFT for the Nova Elysium Stone collection.
/// @notice ELYSIUM VERSION: identical rules to the BNB original, redeployed on
/// Kinetiq Elysium Mainnet (chain ID 99901). Fees are in HYPE (the native gas
/// token); `ether` units in this file therefore mean HYPE on Elysium.
/// The BNB contract 0x889b917A7E4103095457e0eE6C15c65DC630E0aD stays live on BNB
/// with its 328 mints — this is a fresh collection on Elysium starting at 0.
/// @notice Rules (decided by the owner, immutable in this contract except where noted):
/// - MAX_SUPPLY 3,999. No per-wallet limit (the site states none).
/// - NO FREE MINTS (removed 2026-11-09 at owner request): every mint costs
///   0.003 HYPE, HELD in the contract (not forwarded). The owner collects
///   accumulated fees with withdraw(). Network gas is separate and variable,
///   paid to validators.
/// - Personal wallets only (msg.sender == tx.origin, contract callers rejected).
/// - No Agent ID gate: any personal wallet may mint (the site does not state
///   an on-chain Agent ID requirement; the agent wallet is the mint method,
///   not a gate). Add a gate only by redeploying a changed contract.
/// - No mining token: Nova Points / mining power live in the metadata
///   ("Mining Power (pts/day)") and are an off-chain plan, not an on-chain
///   token. mintedByWallet lets any reader check a wallet's minted count
///   (leaderboard input) without an indexer for single wallets.
/// - tokenURI = baseURI + tokenId + ".json" (meta files are N.json).
/// - mintOpen defaults FALSE: the owner opens mint only after baseURI is set.
/// - withdraw() (onlyOwner): sends the whole contract balance to the owner.
///   No receive/fallback: plain HYPE sends revert, so the balance only grows
///   from mint fees.
contract NovaStone is ERC721, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 3999;
    uint256 public constant FEE = 0.003 ether; // every mint pays this; no free mints

    string public baseURI;
    bool public mintOpen;
    uint256 public totalMinted;
    mapping(address => uint256) public mintedByWallet;

    event BaseURISet(string baseURI);

    constructor(string memory _baseURI) ERC721("Nova Elysium Stone", "NOVA") {
        baseURI = _baseURI;
    }

    function feeFor(uint256 /* tokenId */) public pure returns (uint256) {
        return FEE;
    }

    function currentFee() public view returns (uint256) {
        return feeFor(totalMinted + 1);
    }

    function feeForNext(address /* wallet */) public view returns (uint256) {
        return FEE;
    }

    function quoteFor(address /* wallet */, uint256 qty) public view returns (uint256) {
        return qty * FEE;
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
        emit BaseURISet(_baseURI);
    }

    function setMintOpen(bool _open) external onlyOwner {
        mintOpen = _open;
    }

    function withdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "empty");
        (bool ok, ) = owner().call{value: bal}("");
        require(ok, "withdraw failed");
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "nonexistent");
        return string(abi.encodePacked(_baseURI(), tokenId.toString(), ".json"));
    }

    function mint(uint256 qty) external payable {
        require(mintOpen, "mint closed");
        require(msg.sender == tx.origin, "no contracts");
        require(qty > 0, "qty zero");
        require(totalMinted + qty <= MAX_SUPPLY, "supply");
        uint256 fee = quoteFor(msg.sender, qty);
        require(msg.value == fee, "wrong fee");
        for (uint256 i = 0; i < qty; i++) {
            totalMinted += 1;
            mintedByWallet[msg.sender] += 1;
            _safeMint(msg.sender, totalMinted);
        }
        // Fee stays in the contract; the owner collects it with withdraw().
    }
}
