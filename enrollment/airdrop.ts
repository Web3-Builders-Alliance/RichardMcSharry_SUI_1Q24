import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";

// import requestSuiFromFaucetV0 and getFaucetHost to let us request a airdrop for the Sui devnet.
import { getFaucetHost, requestSuiFromFaucetV0 } from "@mysten/sui.js/faucet";

// import our wallet and recreate the Keypair object using its private key:
import wallet from "./dev-wallet.json"
const keypair = Ed25519Keypair.fromSecretKey(new Uint8Array(wallet));

// Now lets send off that airdrop reqest for Devnet Sui:
((async () => {
  try {
      let res = await requestSuiFromFaucetV0({
          host: getFaucetHost("devnet"),
          recipient: keypair.toSuiAddress(),
        });
        console.log(`Success! Check our your TX here:
        https://suiscan.xyz/devnet/object/${res.transferredGasObjects[0].id}`);
  } catch(e) {
      console.error(`Oops, something went wrong: ${e}`)
  }
})());
