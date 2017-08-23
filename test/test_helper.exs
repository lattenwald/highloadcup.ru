defmodule ReqResp do
  defstruct method: "GET", uri: nil, body: "", code: nil, resp: nil
end

ExUnit.start(seed: 0)
