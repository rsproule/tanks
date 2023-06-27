import {
  useTankGameEpochStart,
  useTankGameGetEpoch,
  useTankGameSettings,
} from "@/src/generated";
import { Card, CardContent, CardHeader, CardTitle } from "../ui/card";

export default function Timer() {
  const currentEpoch = useTankGameGetEpoch({ watch: true });
  const settings = useTankGameSettings();
  return (
    <div className="flex justify-center pb-3">
      <Card>
        <CardHeader>
          <CardTitle>Faucet Timer</CardTitle>
        </CardHeader>
        <CardContent>
          <>
            Time till next epoch:{" "}
            {currentEpoch.data &&
              secondsToHMS(
                Number(
                  getTimeTillNextEpoch(
                    currentEpoch.data!,
                    settings.data?.epochSeconds!
                  )
                )
              )}
          </>
        </CardContent>
      </Card>
    </div>
  );
}

const getTimeTillNextEpoch = (currentEpoch: bigint, epochDuration: bigint) => {
  let nowSeconds = Math.floor(Date.now() / 1000);
  let startBlock = currentEpoch * epochDuration;
  let endBlock = startBlock + epochDuration;
  let blocksTillNextEpoch = endBlock - BigInt(nowSeconds);
  return blocksTillNextEpoch;
};

function secondsToHMS(secs: number) {
  let hours = Math.floor(secs / 3600);
  let minutes = Math.floor((secs % 3600) / 60);
  let seconds = secs % 60;

  // Pad the minutes and seconds with leading zeros, if required
  let hoursString = hours < 10 ? "0" + hours : hours;
  let minutesString = minutes < 10 ? "0" + minutes : minutes;
  let secondsString = seconds < 10 ? "0" + seconds : seconds;

  // Compose the string for display
  let hms = hoursString + ":" + minutesString + ":" + secondsString;
  return hms;
}
