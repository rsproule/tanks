import { NextFunction, Request, Response, Router } from "express";
import { tankGameABI, tankGameAddress } from "../../frontend/src/generated";
import publicClient from "../api/client";
var logsRouter = Router();

logsRouter.post("/", logHandler);

function logHandler(req: Request, res: Response, next: NextFunction) {
  getLogs(req.body.fromBlock).then((logs) => {
    res.send(
      // kinda hacky to handle the fact that BigInts are not JSON serializable
      JSON.parse(
        JSON.stringify(logs, (key, value) =>
          typeof value === "bigint" ? value.toString() : value
        )
      )
    );
  });
}

async function getLogs(fromBlock: number) {
  const chainId = publicClient.chain?.id;
  const filter = await publicClient.createContractEventFilter({
    abi: tankGameABI,
    strict: true,
    fromBlock: BigInt(fromBlock),
    address: tankGameAddress[chainId as keyof typeof tankGameAddress],
  });
  return await publicClient.getFilterLogs({
    filter,
  });
}

export default logsRouter;
