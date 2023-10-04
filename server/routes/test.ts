import { Request, Response, NextFunction, Router } from "express";
import { exec } from "child_process";

var testRouter = Router();

testRouter.post("/init", initHandler);
testRouter.get("/kill", killHandler);

function initHandler(req: Request, res: Response, next: NextFunction) {
  exec(
    "pkill -f 'anvil' || true && cd ../contracts && make chain",
    (error, stdout, stderr) => {
      if (error) {
        console.error(`Error: ${error.message}`);
        return res.status(500).send(`Error: ${error.message}`);
      }
      console.log(`stdout: ${stdout}`);
      console.log("anvil instance launched");
    }
  );
  console.log("admin address: " + req.body.adminAddress);
  // exec(`export ADMIN_ADDRESS=${req.body.adminAddress}`);
  // deploy the contracts for sim
  exec(
    `cd ../contracts && export ADMIN_ADDRESS=${req.body.adminAddress} && forge script script/TankGameDeployerSim.s.sol --broadcast --rpc-url http://0.0.0.0:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`,
    (error, stdout, stderr) => {
      console.log("deploying contracts");
      if (error) {
        console.error(`Error: ${error.message}`);
        return res.status(500).send(`Error: ${error.message}`);
      }
      const result = stdout
        .split("\n")
        .filter((x) => x.includes("at address:"))
        .map((line) => {
          const match =
            line.match(/(\w+)\s+at\s+address:\s+(0x[a-fA-F0-9]+)/) || [];
          return {
            name: match[1],
            address: match[2],
          };
        });

      return res.send(result);
    }
  );
}
function killHandler(req: Request, res: Response, next: NextFunction) {
  res.send("kill the simulation");
}
export default testRouter;
