defmodule ReqResp do
  defstruct method: "GET", uri: nil, code: nil, resp: nil
end


defmodule StatusGetTest do
  use ExUnit.Case
  require ReqResp

  @ansfile Application.fetch_env!(:round1, :datafile) |> Path.dirname |> Path.join("answers/phase_1_get.answ")
  @port Application.get_env(:round1, :port, 80)

  def req_status_equals(method, uri, code) do
    {:ok, resp} = HTTPoison.request(method, "http://localhost:#{@port}#{uri}")
    resp.status_code == code
  end

  defmacro test_status(method, uri, code) do
    quote do
      test "#{unquote method} #{unquote uri} #{unquote code}" do
        method = unquote method
        uri = unquote uri
        code = unquote code
        assert req_status_equals(method, uri, code)
      end
    end
  end

  @ansfile
  |> File.read!
  |> String.split("\n")
  |> Stream.map(&String.split(&1, "\t"))
  |> Stream.map(fn [m, u, s | r] ->
    %ReqResp{method: m |> String.downcase |> String.to_atom,
             uri: u,
             code: String.to_integer(s),
             resp: List.first(r)
            }
    _ -> nil
  end)
  |> Stream.filter(&not is_nil(&1))
  |> Enum.zip(1 .. 50000)
  |> Enum.each(fn {%{method: method, uri: uri, code: code}, n} ->
    test "#{n}: #{method} #{uri} #{code}" do
      method = unquote method
      uri = unquote uri
      code = unquote code

      assert req_status_equals(method, uri, code)
    end
  end)

end
