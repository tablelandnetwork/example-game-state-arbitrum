// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@tableland/evm/contracts/ITablelandTables.sol";
import "@tableland/evm/contracts/utils/TablelandDeployments.sol";
import "@tableland/evm/contracts/utils/URITemplate.sol";

// Holds core data for every game minted
struct Game {
    bool status;
    string[] known;
    uint256 unknown;
    uint256 remaining;
    mapping(bytes32 => uint256[]) letters; // proof => [positions]
}
// StoredData is all data stored by the contract
struct StoredData {
    uint256 _gameStoreId;
    string _gameStoreName;
    ITablelandTables _tableland;
    mapping(uint256 => Game) games;
}

contract GameLevels is
    ERC721EnumerableUpgradeable,
    ERC721HolderUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // An instance of the struct defined above.
    StoredData internal stored;
    string private _baseURIString;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    function initialize() public initializer {
        __ERC721_init("GameLevels", "GG_");
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Called when the smart contract is deployed. This function will create a table
     * on the Tableland network that will contain a new row for every new project minted
     * by a user of this smart contract.
     */
    function _initGameStore() external onlyOwner returns (uint256 tokenId) {
        stored._tableland = TablelandDeployments.get();
        // // The create statement sent to Tableland.
        stored._gameStoreId = stored._tableland.createTable(
            address(this),
            string.concat(
                "CREATE TABLE game_store_",
                StringsUpgradeable.toString(block.chainid),
                " (",
                " id INTEGER PRIMARY KEY,",
                " creator TEXT,",
                " word TEXT,",
                " winner TEXT,",
                " created INTEGER,",
                " letters INTEGER,",
                " remaining INTEGER",
                ");"
            )
        );

        // Store the table name locally for future reference.
        stored._gameStoreName = string.concat(
            "game_store_",
            StringsUpgradeable.toString(block.chainid),
            "_",
            StringsUpgradeable.toString(stored._gameStoreId)
        );

        return stored._gameStoreId;
    }

    /**
     * @dev Called whenever a user requests a new game
     */
    function _createGame(
        address creator,
        string memory word,
        uint256 tokenId
    ) internal {
        uint256 wl = bytes(word).length;
        string memory tokenIdString = StringsUpgradeable.toString(tokenId);
        string memory creatorString = StringsUpgradeable.toHexString(creator);
        string memory nowString = StringsUpgradeable.toString(block.timestamp);
        string memory letterCount = StringsUpgradeable.toString(wl);
        string memory hold = _concat(new string[](wl));

        /*
         * insert a single row for the game metadata
         */
        stored._tableland.runSQL(
            address(this),
            stored._gameStoreId,
            string.concat(
                "INSERT INTO ",
                stored._gameStoreName,
                "(id, creator, created, word, letters, remaining) VALUES (",
                tokenIdString,
                ",'",
                creatorString,
                "',",
                nowString,
                ",'",
                hold,
                "',",
                letterCount,
                ",6);"
            )
        );
    }

    /**
     * @dev Called whenever a user requests a new game. this is just obfuscating the answer
     * if you want real security, you should use some proof based tooling. 
     */
    function _storeProof(
        string memory word,
        uint256 tokenId
    ) internal {
        bytes memory w = bytes(word);
        stored.games[tokenId].status = true;
        stored.games[tokenId].known = new string[](w.length);
        stored.games[tokenId].unknown = w.length;
        stored.games[tokenId].remaining = 6;
        for (uint i; i < w.length; i++) {
            stored.games[tokenId].letters[keccak256(abi.encodePacked(tokenId, w[i]))].push(i);
        }
    }

    /**
     * @dev Called whenever a user requests a new game. this is just obfuscating the answer
     * if you want real security, you should use some proof based tooling. 
     */
    function _guess(
        uint256 tokenId,
        string memory letter
    ) internal view returns (bool, uint256[] memory) {
        bytes32 guess = keccak256(abi.encodePacked(tokenId, bytes(letter)));
        uint256[] memory positions = stored.games[tokenId].letters[guess];
        return (positions.length > 0, positions);
    }

    function getKnown(
        uint256 tokenId
    ) public view returns (string memory) {
        return _concat(stored.games[tokenId].known);
    }

    /**
    * @dev Joins a string array into a hangman style phrase.
    */
    function _concat(string[] memory letters) private pure returns(string memory s) {
        for (uint i; i < letters.length; i++) {
            bytes memory e = bytes(letters[i]);
            if (e.length == 0) {
                s = string.concat(s, "_");
            } else {
                s = string.concat(s, letters[i]);
            }
        }
        return s;
    }


    /**
    * @dev Called by players to make a guess.
    */
    function guessLetter(uint256 tokenId, string memory letter) public returns (string[] memory) {
        require(stored.games[tokenId].status == true, "Game over");

        string memory tokenIdString = StringsUpgradeable.toString(tokenId);
        string memory statement;
        bool won = false;
        (bool success, uint256[] memory positions) = _guess(tokenId, letter);
        if (success) {
            for (uint i; i < positions.length; i++) {
                // update our known array
                stored.games[tokenId].known[positions[i]] = letter;
            }
            string memory word = _concat(stored.games[tokenId].known);

            // check if it is a win
            stored.games[tokenId].unknown = stored.games[tokenId].unknown - positions.length;
            if (stored.games[tokenId].unknown == 0) {
                won = true;
                stored.games[tokenId].status = false; // game over

                string memory winner = StringsUpgradeable.toHexString(_msgSender());
                // update won game
                statement = string.concat(
                    "UPDATE ",
                    stored._gameStoreName,
                    " SET word='",word,"',winner='",winner,"' WHERE id=",tokenIdString,";"
                );
                // send the nft to the winner
                super._safeTransfer(ownerOf(tokenId), _msgSender(), tokenId, "");
            } else {
                // update active game
                statement = string.concat(
                    "UPDATE ",
                    stored._gameStoreName,
                    " SET word='",word,"' WHERE id=",tokenIdString,";"
                );
            }
        } else { // failed
            // remove a try
            stored.games[tokenId].remaining = stored.games[tokenId].remaining - 1;
            if (stored.games[tokenId].remaining < 1) {
                stored.games[tokenId].status = false; // game over

                // send the nft back to the contract
                super._safeTransfer(ownerOf(tokenId), address(this), tokenId, "");
            }
            string memory guesses = StringsUpgradeable.toString(stored.games[tokenId].remaining);
            // update active game
            statement = string.concat(
                "UPDATE ",
                stored._gameStoreName,
                " SET remaining=",guesses," WHERE id=",tokenIdString,";"
            );
        }

        // update our game state
        stored._tableland.runSQL(
            address(this),
            stored._gameStoreId,
            statement
        );

        return stored.games[tokenId].known;
    }

    /**
    * @dev Called by players to make a new game.
    */
    function safeMint(address to, string memory word) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _createGame(to, word, tokenId);
        _storeProof(word, tokenId);
        _safeMint(to, tokenId);
    }

    /**
    * @dev Generate a live SVG of the current game.
    */
    function generateSvg(string memory word, bool won, bool lost) public pure returns(string memory){
        string memory color = "white";
        string memory fill = "black";
        if (won) {
            color = "green";
            fill = "white";
        }
        if (lost) {
            color = "black";
            fill = "red";
        }
        string memory svg = string.concat(
            '<svg height="350" width="350" viewBox="0 0 350 350"  style="background-color:',color,'" xmlns="http://www.w3.org/2000/svg">',
            '<text x="50%" y="50%" text-anchor="middle" dominant-baseline="central" font-size="12" dy="7">',
            '<tspan wrap="soft" letter-spacing="5" fill="',fill,'">',
            word,
            '</tspan>',
            '</text>',
            '</svg>'
        );

        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64Upgradeable.encode(bytes(string(abi.encodePacked(
            svg
        ))))));
    }

    /**
    * @dev Dynamically generate the metadata payload for any game.
    */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireMinted(tokenId);
        // Card memory card = tokenToCard[tokenId];
        string memory word = _concat(stored.games[tokenId].known);
        bool won = stored.games[tokenId].unknown == 0;
        bool lost = stored.games[tokenId].remaining == 0;
        string memory status = "active";
        if (won) {
            status = "won";
        }
        if (lost) {
            status = "lost";
        }
        string memory strTokenId = StringsUpgradeable.toString(tokenId);
        
        string memory image = generateSvg(word, won, lost);

        string memory remaining = StringsUpgradeable.toString(stored.games[tokenId].remaining);

        return
            string.concat(
                'data:application/json,',
                string.concat(
                    '{"name":"',
                    word,
                    '","animation_url":"https://bafybeier2ldrq6gwsu4axdblw2ppwy7bgrt6zl6bgkvztvvt3uhh7qlchu.ipfs.w3s.link/?table=',stored._gameStoreName,'&token=',
                    strTokenId,
                    '","image":"',
                    image,
                    '","attributes":[{"trait_type":"status","value":"',
                    status,
                    '"},{"trait_type":"word","value":"',
                    word,
                    '"},{"trait_type":"guesses_remaining","value":"',
                    remaining,
                    '"}]}'
                )
            );
    }

    function collectionSvg() public view returns(string memory){
        string memory texts;

        for (uint i=0; i<20; i++) {
            if (!_exists(i)) { break; }
            if (stored.games[i].status == true) {
                texts = string.concat(
                    texts, 
                    '<tspan wrap="soft" letter-spacing="5" fill="black" x="50%" dy="1em">',
                    _concat(stored.games[i].known),
                    '</tspan>');
            } else if (stored.games[i].remaining == 0) {
                texts = string.concat(
                    texts, 
                    '<tspan wrap="soft" letter-spacing="5" fill="red" x="50%" dy="1em">',
                    _concat(stored.games[i].known),
                    '</tspan>');
            } else if (stored.games[i].known.length > 0) {
                texts = string.concat(
                    texts, 
                    '<tspan wrap="soft" letter-spacing="5" fill="gold" x="50%" dy="1em">',
                    _concat(stored.games[i].known),
                    '</tspan>');
            }

        }

        string memory svg = string.concat(
            '<svg height="350" width="350" viewBox="0 0 350 350"  style="background-color:white" xmlns="http://www.w3.org/2000/svg">',
            '<text x="50%" y="20%" text-anchor="middle" dominant-baseline="central" font-size="12" word-spacing="20">',
            texts,
            '</text>',
            '</svg>'
        );

        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64Upgradeable.encode(bytes(string(abi.encodePacked(
            svg
        ))))));
    }
    
    /**
    * @dev Dynamically generate the collection metadata. WARNING. OpenSea appears to only call this once.
    */
    function contractURI() public view returns (string memory) {

        return
            string(abi.encodePacked(
                'data:application/json;base64,',
                Base64Upgradeable.encode(bytes(
                    abi.encodePacked(
                        '{"name":"Tableland Game State Example",',
                        '"slug":"tableland-game-state",',
                        '"description":"A game of hangman where each letter is guessed on chain and the state is managed in Tableland. Use the guessLetter method to send a letter guess to any token with an active game. Use safeMint to start a new game with your own word. Use the external website link to call that function on Arbiscan.",',
                        '"banner_image_url":"https://nftstorage.link/ipfs/bafkreiaovbl245aoe6fk24ad5s2uryy4o256dc7zhpl2hs7inybgybhfaa",',
                        '"external_link":"https://goerli.arbiscan.com/address/0x58d9Cd52d81d06Ec0818015F8FD4A3aDc8FCF45b#writeProxyContract",',
                        '"image_data":"https://nftstorage.link/ipfs/bafkreibahfxzpiarlfaes37bljy5tycvubo4gdzbtptpvc36iitnekukwe",',
                        '"image":"', // i'm not sure how often OS refreshes this (or ever)
                        collectionSvg(),
                        '"}'
                    )
                ))
            ));

    }

    function totalSupply() override public view returns (uint256) {
      return _tokenIdCounter.current();
    }

    function tokenByIndex(uint256 index) override public pure returns (uint256) {
      return index;
    }
    
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
