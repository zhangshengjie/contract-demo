/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-08-04 21:05:35
 * @LastEditors: cejay
 * @LastEditTime: 2022-09-01 17:01:33
 */

import { assert } from 'console';
import Web3 from 'web3';
import { Utils } from './utils';

async function main() {
    const web3 = new Web3('http://localhost:8545');
    await Utils.sleep(1000 * 1);
    const accounts = await web3.eth.getAccounts();
    console.log(accounts);
    assert(accounts.length > 5);

    // #region NFT
    if (true) {
        const NFTObj = await Utils.compileContract(`${__dirname}/../build/ERC721A-NFT.sol`, 'NFT');

        const NFTObjArgs = [
            'NFTName',
            'NFTSymbol',
            'https://nft.com/',
            10, //uint32 maxSupply_,
            accounts[1],//address paymentReceiver_,
            accounts[2] //address controller_
        ];

        const NFTAddress = await Utils.deployContract(web3, NFTObj.abi, '0x' + NFTObj.bytecode, NFTObjArgs, accounts[0], 1e9);
        console.log('NFT address:' + NFTAddress);
        const NFTContract = new web3.eth.Contract(NFTObj.abi, NFTAddress);

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
            await NFTContract.methods.batchMint(2).send(
                {
                    from: accounts[3],
                    gas: 1e9,
                    value: web3.utils.toWei('3', 'ether')
                }
            );
            console.log('10. batchMint test passed');
        } catch (error) {
            throw error;
        }









    }


    // #endregion




}

main();