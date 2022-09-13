# Better-multicall

This repo is an experiment to improve existing multicall in Starknet.

## Why is multicall great?
It allows to combine multiple transactions in a single one. This saves you time and fees.

## What's the problem with existing multicall?
You can pass an ordered list of multiple calls, but you need to know all the call inputs before. That is perfect if you just want to set an allowance and then do a transfer, but this is bad when you want to use a value returned by a previous call.
For example, if you mint an NFT, the contract could return you the id of this nft (which you can't know in advance because it might not be the same if someone tries to mint at the same time than you). If you want to use this returned id in another call,
for example in a call to set your NFT name, you need to wait for the transaction to be accepted in order to send another one. That sucks.

## How can we fix it?
Instead of just passing an array of calls that contain fixed values, you could provide references to the outputs of previous calls.