import { getFullnodeUrl, SuiClient } from "@mysten/sui.js/client";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { TransactionBlock } from '@mysten/sui.js/transactions';

import wallet from "./dev-wallet.json"

// Import our dev wallet keypair from the wallet file
const keypair = Ed25519Keypair.fromSecretKey(new Uint8Array(wallet));

// Define our WBA SUI Address
const to = "0x405f09a46025cf02dcb240d8361174a0a804cf887aeb2c49c58b94552f8558b7";

//Create a Sui devnet client
const client = new SuiClient({ url: getFullnodeUrl("devnet") });

// Now we're going to create a programable transaction block using '@mysten/sui.js/transactions' 
// to transfer 1000 Mist from our dev wallet to our WBA wallet address on the Sui devenet. 
// To complete this task we will need to split our SUI coin object.
(async () => {
  try {
      //create Transaction Block.
      const txb = new TransactionBlock();
      //Add a transferObject transaction
      txb.transferObjects([txb.gas], to);
      let txid = await client.signAndExecuteTransactionBlock({ signer: keypair, transactionBlock: txb });
      console.log(`Success! Check our your TX here:
      https://suiexplorer.com/txblock/${txid.digest}?network=devnet`);
  } catch(e) {
      console.error(`Oops, something went wrong: ${e}`)
  }
})();