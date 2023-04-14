# Game state management - a game of hangman

This is a game of hangman. A user can mint a new game using `safeMint` just like any NFT. Other players can play the NFT using `guessLetter` by submitting a target tokenID and their letter guess. 

All game state and updates are shipped off to a table on Tableland. 

The NFT is built on IFPS and reads that state to render the live game. 

You could also easily build a dapp for viewing leaderboards, open games, etc. 

## Gameplay

A user calls `safeMint(addr, "secret"). That user (addr) now owns an NFT for the game, awaiting people to guess "secret".

A player can now call `guessLetter(tokenId, "x"). Because "x" is not in "secret" one fail will be recorded. If 6 fails are recorded, the game ends and the NFT transfers back to the smart contract. If all the letters of the word of guessed before the game is over, the person submitting the final letter will get the winning NFT.

The state at each level is pushed to Tableland for rendering, query, search, etc. 

## Example deployment (how to play)

https://goerli.arbiscan.com/address/0x58d9Cd52d81d06Ec0818015F8FD4A3aDc8FCF45b#writeProxyContract

Use `safeMint` and `guessLetter` above to play.

## Example game state table on Tableland (how to view state)

https://testnets.opensea.io/assets/mumbai/0x4b48841d4b32c4650e4abc117a03fe8b51f38f68/4448

You can view the full state of the example deployments below running in the above table. 

You can query that state here,

https://testnet.tableland.network/query?s=select%20*%20from%20game_store_80001_4448%20limit%201

## Example NFT (how to visually see the game and game nfts)

https://testnets.opensea.io/collection/tableland-game-state-example-v2

You can see multiple examples of open and completed games. Chose any open ones (white background) to make your own guesses. 

View the React app in the /nft folder.

## Develop

You must have a `.env` file with the following information

```
PRIVATE_KEY={your wallet key with a balance of matic}
ARBISCAN_API_KEY={your polyscan api key for pushing the abi}
ARBITRUM_GOERLI_API_KEY={your alchemy api key for mumbai}
REPORT_GAS=true
```

### Install

`npm install`

### Start Tableland locally

`npm run tableland`

### Deploy to local hardhat

`npm run local` or upgrade `npm run localup`

### Deploy to Mumbai

`npm run deploy`

### Update

`npm run update`

## Develop the NFT

`cd nft`

`npm install`

`npm run dev`

`npm run build`

# Warning

This example is not maintained.
