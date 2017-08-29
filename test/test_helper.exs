defmodule ReqResp do
  defstruct method: "GET", uri: nil, body: "", code: nil, resp: nil
end

:timer.sleep 5000
ExUnit.start(seed: 0)
