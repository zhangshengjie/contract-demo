const solc = require('solc');
import fs from 'fs';
import Web3 from 'web3';

export class Utils {


    /**
     * sleep ms
     * @param {number} time ms
     */
    static sleep(time = 0) {
        return new Promise((resolve, reject) => {
            setTimeout(() => {
                resolve(true);
            }, time);
        })
    }




    /**
     * compile *.sol file
     * @param solPath *.sol file path
     * @param contractClassName contract class name
     * @returns 
     */
    static async compileContract(solPath: string, contractClassName: string) {
        const input = {
            language: 'Solidity',
            sources: {
                'contract.sol': {
                    content: fs.readFileSync(solPath, 'utf8')
                }
            },
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                },
                evmVersion: 'london',
                outputSelection: {
                    '*': {
                        '*': ['*']
                    }
                }
            }
        };
        console.log(`solc version:${solc.version()}`);

        // enable optimizer 200  
        const output = JSON.parse(solc.compile(JSON.stringify(input)));
        const abi = output.contracts['contract.sol'][contractClassName].abi;
        const bytecode: string = output.contracts['contract.sol'][contractClassName].evm.bytecode.object;

        return {
            abi, bytecode
        }
    }


    /**
     * sign transaction and send transaction
     * @param web3 web3 instance
     * @param privateKey private key of from account
     * @param to to address
     * @param value value
     * @param data data
     * @returns null or transaction hash
     */
    static async signAndSendTransaction(web3: Web3,
        privateKey: string,
        to: string | undefined,
        value: string,
        maxPriorityFeePerGas: string,
        maxFeePerGas: string,
        data: string | undefined, callback?: (txhash: string) => void) {
        const account = web3.eth.accounts.privateKeyToAccount(privateKey);
        const rawTx = {
            from: account.address,
            to: to,
            value: value,
            data: data,
            gas: web3.utils.toWei('1', 'ether'),
            maxPriorityFeePerGas,
            maxFeePerGas
        };

        let gas = (await web3.eth.estimateGas(rawTx)) * 10;
        rawTx.gas = web3.utils.toHex(web3.utils.toBN(gas)); // gas limit
        let signedTransactionData = await account.signTransaction(rawTx);
        if (signedTransactionData.rawTransaction && signedTransactionData.transactionHash) {
            callback && callback(signedTransactionData.transactionHash);
            await web3.eth.sendSignedTransaction(signedTransactionData.rawTransaction, (err: any, hash: string) => {
                if (err) {
                    console.log(err);
                } else {
                    console.log(`tx:${hash} has been sent, please wait few secs to confirm`);

                }
            });
            while (true) {
                await Utils.sleep(1000 * 1);
                const receipt = await web3.eth.getTransactionReceipt(signedTransactionData.transactionHash);
                if (receipt) {
                    if (receipt.status === true) {
                        if (to) {
                            return signedTransactionData.transactionHash;
                        } else {
                            return receipt.logs[0].address;
                        }

                    } else {
                        throw new Error('transaction failed');
                    }
                }
            }
        }
        return null;
    }

    static async deployContract(web3: Web3, abi: any, data: string, args: any[], from: string, gas: number): Promise<string> {
        const contract = new web3.eth.Contract(abi);
        const re = await contract.deploy({
            data,
            arguments: args
        }).send({
            from,
            gas
        });
        return re.options.address;

    }

}
