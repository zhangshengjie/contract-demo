/*
 * @Description: calling demo
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-08-04 21:05:35
 * @LastEditors: cejay
 * @LastEditTime: 2022-09-09 17:02:44
 */

import { assert } from 'console';
import { ethers } from 'ethers';
import Web3 from 'web3';
import { Utils } from './utils';
import { ecsign, toRpcSig, keccak256 } from 'ethereumjs-util'
import { arrayify } from 'ethers/lib/utils';

async function main() {
    const web3 = new Web3('http://localhost:8545');


    {
        // 签名
        /*
        function dividend(
            uint256 amount_,
            uint256 nonce_,
            bytes memory signature_
        ) external pure returns (address) {
            address sender = 0xB5eF866Aa826E1428f38b0C9396F8348167e44fD;
            bytes32 message = keccak256(abi.encodePacked(nonce_, sender, amount_));
    
            return message.toEthSignedMessageHash().recover(signature_);
        }
         */
        //bytes32 message = keccak256(abi.encodePacked(nonce_, sender, amount_));
        const nonce = 1;
        const sender = '0xB5eF866Aa826E1428f38b0C9396F8348167e44fD';
        const amount = 100;
        //abi.encodePacked(nonce_, sender, amount_)
        let message = ethers.utils.solidityPack(['uint256', 'address', 'uint256'], [nonce, sender.toLowerCase(), amount]);
        // keccak256(message)
        message = ethers.utils.keccak256(message);
        let privateKey: string = '0x7f0ef6c943faa45cf9bc338bc051821e78201870c034464499bb9024f3f7e27e';
        const msg1 = Buffer.concat([
            Buffer.from('\x19Ethereum Signed Message:\n32', 'ascii'),
            Buffer.from(arrayify(message))
        ])
        const sig = ecsign(keccak256(msg1), Buffer.from(arrayify(privateKey)))
        const signedMessage = toRpcSig(sig.v, sig.r, sig.s);
        console.log('signedMessage', signedMessage);
    }


    await Utils.sleep(1000 * 1);
    const accounts = await web3.eth.getAccounts();
    // each accounts
    for (let i = 0; i < accounts.length; i++) {
        const account = accounts[i];
        console.log(`${i}\t${account}`);
    }
    assert(accounts.length > 5);

    // #region NFT
    let NFTContract: any;
    let NFTAddress: string;
    {
        const NFTObj = await Utils.compileContract(`${__dirname}/../build/ERC721A-NFT.sol`, 'NFT');

        const NFTObjArgs = [
            'NFTName',
            'NFTSymbol',
            'https://nft.com/',
            10, //uint32 maxSupply_,
            accounts[1],//address paymentReceiver_,
            accounts[2] //address controller_
        ];

        NFTAddress = await Utils.deployContract(web3, NFTObj.abi, '0x' + NFTObj.bytecode, NFTObjArgs, accounts[0], 1e9);
        console.log('NFT address:' + NFTAddress);
        NFTContract = new web3.eth.Contract(NFTObj.abi, NFTAddress);

        // defalut saleEnabled = false can not mint
        // function batchMint(uint32 amount_)
        try {
            await NFTContract.methods.batchMint(1).send(
                { from: accounts[3], }
            );
            throw new Error('batchMint test failed');
        } catch (error) {
            // ok
            if ((<any>error).message.includes('Sale not enabled')) {
                console.log('1. batchMint test passed');
            } else {
                throw error;
            }
        }
        // setSalePrice(uint256 price_)
        try {
            await NFTContract.methods.setSalePrice(web3.utils.toWei('1', 'ether')).send(
                { from: accounts[0], }
            );
            throw new Error('setSalePrice test failed');
        } catch (error) {
            // ok
            if ((<any>error).message.includes('missing role 0x4913d4da5605218c48834fed44bccb6bdddd90d4fdf48923cf059a07f6fe4a77')) {
                console.log('2. setSalePrice test passed');
            } else {
                throw error;
            }
        }

        try {
            await NFTContract.methods.setSalePrice(web3.utils.toWei('1', 'ether')).send(
                { from: accounts[2], }
            );
            console.log('3. setSalePrice test passed');
        } catch (error) {
            // ok 
            throw error;
        }

        try {
            await NFTContract.methods.batchMint(1).send(
                { from: accounts[3], }
            );
            throw new Error('batchMint test failed');
        } catch (error) {
            // ok
            if ((<any>error).message.includes('Sale not enabled')) {
                console.log('4. batchMint test passed');
            } else {
                throw error;
            }
        }
        // enableSale()
        try {
            await NFTContract.methods.toggleSaleEnable(true).send(
                { from: accounts[0], }
            );
            throw new Error('enableSale test failed');
        } catch (error) {
            if ((<any>error).message.includes('missing role 0x4913d4da5605218c48834fed44bccb6bdddd90d4fdf48923cf059a07f6fe4a77')) {
                console.log('5. setSalePrice test passed');
            } else {
                throw error;
            }
        }
        try {
            await NFTContract.methods.toggleSaleEnable(true).send(
                { from: accounts[2], }
            );
            console.log('6. enableSale test passed');
        } catch (error) {
            throw error;
        }

        // setDefaultSale
        try {
            await NFTContract.methods.setDefaultSale(true).send(
                {
                    from: accounts[2]
                }
            );
            console.log('7. setDefaultSale test passed');
        } catch (error) {
            throw error;
        }

        try {
            await NFTContract.methods.batchMint(1).send(
                {
                    from: accounts[3],
                    gas: 1e9,
                    value: web3.utils.toWei('0.9', 'ether')
                }
            );
            throw new Error('batchMint test failed');
        } catch (error) {
            // ok
            if ((<any>error).message.includes('Insufficent input amount')) {
                console.log('8. batchMint test passed');
            } else {
                throw error;
            }
        }
        try {
            await NFTContract.methods.batchMint(1).send(
                {
                    from: accounts[3],
                    gas: 1e9,
                    value: web3.utils.toWei('1', 'ether')
                }
            );
            console.log('9. batchMint test passed');
        } catch (error) {
            throw error;
        }
        try {
            await NFTContract.methods.batchMint(10).send(
                {
                    from: accounts[3],
                    gas: 1e9,
                    value: web3.utils.toWei('10', 'ether')
                }
            );
            throw new Error('batchMint test failed');
        } catch (error) {
            // ok
            if ((<any>error).message.includes('Insufficent supply')) {
                console.log('10. batchMint test passed');
            } else {
                throw error;
            }
        }
        try {
            await NFTContract.methods.batchMint(9).send(
                {
                    from: accounts[3],
                    gas: 1e9,
                    value: web3.utils.toWei('9', 'ether')
                }
            );
            console.log('11. batchMint test passed');
        } catch (error) {
            throw error;
        }

        //function withdraw()
        try {
            await NFTContract.methods.withdraw().send(
                {
                    from: accounts[2],
                }
            );
            console.log('12. withdraw test passed');
        } catch (error) {
            throw error;
        }

    }

    // #endregion

    // #region stake

    {
        const StakeObj = await Utils.compileContract(`${__dirname}/../build/Stake.sol`, 'Stake');

        const StakeObjArgs = [
            accounts[4]
        ];

        const StakeAddress = await Utils.deployContract(web3, StakeObj.abi, '0x' + StakeObj.bytecode, StakeObjArgs, accounts[0], 1e9);
        console.log('Stake address:' + StakeAddress);
        const StakeContract = new web3.eth.Contract(StakeObj.abi, StakeAddress);
        //  function setNFTMinimumStakeTime(uint24 newMinimumStakeTime)
        try {
            await StakeContract.methods.setNFTMinimumStakeTime(30).send(
                { from: accounts[0], }
            );
            throw new Error('setNFTMinimumStakeTime test failed');
        }
        catch (error) {
            if ((<any>error).message.includes('caller is not the owner')) {
                console.log('1. setNFTMinimumStakeTime test passed');
            } else {
                throw error;
            }
        }
        try {
            await StakeContract.methods.setNFTMinimumStakeTime(10).send(
                { from: accounts[4], }
            );
            console.log('2. setNFTMinimumStakeTime test passed');
        }
        catch (error) {
            throw error;
        }

        //function createNFTStake(address NFT, uint256[] calldata tokenIds)
        try {
            await StakeContract.methods.createNFTStake(NFTAddress, [0, 1, 2]).send(
                { from: accounts[3], }
            );
            throw new Error('createNFTStake test failed');
        }
        catch (error) {
            if ((<any>error).message.includes('Not approved for all')) {
                console.log('3. createNFTStake test passed');
            } else {
                throw error;
            }
        }
        // approve for all
        try {
            await NFTContract.methods.setApprovalForAll(StakeAddress, true).send(
                { from: accounts[3], }
            );
            console.log('4. setApprovalForAll test passed');
        } catch (error) {
            throw error;
        }
        try {
            await StakeContract.methods.createNFTStake(NFTAddress, [3, 1]).send(
                {
                    from: accounts[3],
                    gas: 1e9
                }
            );
            await StakeContract.methods.createNFTStake(NFTAddress, [2]).send(
                {
                    from: accounts[3],
                    gas: 1e9
                }
            );
            console.log('5. createNFTStake test passed');
        }
        catch (error) {
            throw error;
        }

        // function withdrawNFTStake(uint256 stakeId)
        try {
            await StakeContract.methods.withdrawNFTStake(0).send(
                {
                    from: accounts[3],
                    gas: 1e9
                }
            );
            throw new Error('withdrawNFTStake test failed');
        } catch (error) {
            if ((<any>error).message.includes('Not enough time has passed')) {
                console.log('6. withdrawNFTStake test passed');
            } else {
                throw error;
            }
        }
        await Utils.sleep(11 * 1000);
        try {
            await StakeContract.methods.withdrawNFTStake(0).send(
                {
                    from: accounts[3],
                    gas: 1e9
                }
            );
            console.log('7. withdrawNFTStake test passed');
        } catch (error) {
            throw error;
        }



    }

    // #endregion




}

main();
