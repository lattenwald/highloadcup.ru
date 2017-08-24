defmodule Round1Test do
  use ExUnit.Case
  require ReqResp

  @moduletag timeout: 180

  @port Application.get_env(:round1, :port, 80)
  @basedir Application.fetch_env!(:round1, :datafile) |> Path.dirname

  def req_status_equals(method, uri, code, body \\ "", resp_body \\ "") do
    {:ok, resp} = HTTPoison.request(method, "http://localhost:#{@port}#{uri}", body)
    assert resp.status_code == code
    with {:ok, json} <- Poison.decode(resp_body || "") do
      assert Poison.decode!(resp.body) == json
    end
  end

  ["1_get", "2_post", "3_get"]
  |> Enum.map(& {&1, "#{@basedir}/answers/phase_#{&1}.answ", "#{@basedir}/ammo/phase_#{&1}.ammo"})
  |> Enum.each(fn {phase, ansfile, ammofile} ->
    ammofile
    |> File.read!
    |> String.split(~r/^\d+\s+[A-Z]+:[^"',\s]+$/m)
    |> Stream.map(&String.trim_leading/1)
    |> Stream.drop(1)
    |> Enum.zip(
      ansfile
      |> File.read!
      |> String.split("\n")
      |> Stream.map(&String.split(&1, "\t"))
      |> Stream.map(fn [m, u, s | r] ->
        %ReqResp{method: m |> String.downcase |> String.to_atom,
                 uri: u,
                 code: String.to_integer(s),
                 resp: case r do
                         [] -> nil
                         [x] -> x
                       end
                }
        _ -> nil
      end)
    ) |> Stream.map(fn {ammo, reqresp} ->
      body = Regex.run(~r/\r\n\r\n(.*)$/, ammo, capture: :all_but_first)
      %{reqresp | body: body}
    end)
    |> Enum.zip(1 .. 50000)
    |> Enum.each(fn {%{method: method, uri: uri, code: code, body: body, resp: resp}, n} ->
      test "phase_#{phase} [#{n}] #{method} #{uri} #{code}" do
        method = unquote method
        uri = unquote uri
        code = unquote code
        body = unquote body
        resp = unquote resp

        assert req_status_equals(method, uri, code, body, resp)
      end
    end)
  end)

end
