import { defineConfig } from "@wagmi/cli";
import { foundry, react } from "@wagmi/cli/plugins";
import * as chains from "wagmi/chains";

export default defineConfig({
  out: "src/generated.ts",
  plugins: [
    foundry({
      deployments: {
        TankGame: {
          [chains.mainnet.id]: "0x021dbff4a864aa25c51f0ad2cd73266fde66199d",
          [chains.foundry.id]: "0x5fbdb2315678afecb367f032d93f642f64180aa3",
          // [chains.goerli.id]: "0x1D738bb3c3D594E248Fdb5234b7Af7a2Ecb7B64D",
          [chains.goerli.id]: "0x0a8628a32f0AC3A208B8CEf032B38fF08bB140D7",
        },
      },
      project: "../contracts",
    }),
    react(),
  ],
});
