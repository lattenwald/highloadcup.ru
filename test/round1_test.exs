defmodule Round1Test do
  use ExUnit.Case
  require ReqResp

  @port Application.get_env(:round1, :port, 80)

  @ansfile1 Application.fetch_env!(:round1, :datafile) |> Path.dirname |> Path.join("answers/phase_1_get.answ")
  @ammofile1 Application.fetch_env!(:round1, :datafile) |> Path.dirname |> Path.join("ammo/phase_1_get.ammo")

  @ansfile2 Application.fetch_env!(:round1, :datafile) |> Path.dirname |> Path.join("answers/phase_2_post.answ")
  @ammofile2 Application.fetch_env!(:round1, :datafile) |> Path.dirname |> Path.join("ammo/phase_2_post.ammo")

  @ansfile3 Application.fetch_env!(:round1, :datafile) |> Path.dirname |> Path.join("answers/phase_3_get.answ")
  @ammofile3 Application.fetch_env!(:round1, :datafile) |> Path.dirname |> Path.join("ammo/phase_3_get.ammo")

  def req_status_equals(method, uri, code, body \\ "") do
    {:ok, resp} = HTTPoison.request(method, "http://localhost:#{@port}#{uri}", body)
    assert resp.status_code == code
  end

  def req_resp_ok(rr) do
    {:ok, resp} = HTTPoison.request(rr.method, "http://localhost:#{@port}#{rr.uri}", rr.body)
    resp.status_code == rr.code
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

  @ammofile1
  |> File.read!
  |> String.split(~r/^\d+\s+[A-Z]+:[^"',\s]+$/m)
  |> Stream.map(&String.trim_leading/1)
  |> Stream.drop(1)
  |> Enum.zip(
    @ansfile1
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
  |> Enum.each(fn {%{method: method, uri: uri, code: code, body: body}, n} ->
    test "phase1 #{n}: #{method} #{uri} #{code}" do
      method = unquote method
      uri = unquote uri
      code = unquote code
      body = unquote body

      assert req_status_equals(method, uri, code, body)
    end
  end)


  @ammofile2
  |> File.read!
  |> String.split(~r/^\d+\s+[A-Z]+:[^"',\s]+$/m)
  |> Stream.map(&String.trim_leading/1)
  |> Stream.drop(1)
  |> Enum.zip(
    @ansfile2
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
  |> Enum.each(fn {%{method: method, uri: uri, code: code, body: body}, n} ->
    test "phase2 #{n}: #{method} #{uri} #{code}" do
      method = unquote method
      uri = unquote uri
      code = unquote code
      body = unquote body

      req_status_equals(method, uri, code, body)
    end
  end)

  @ammofile3
  |> File.read!
  |> String.split(~r/^\d+\s+[A-Z]+:[^"',\s]+$/m)
  |> Stream.map(&String.trim_leading/1)
  |> Stream.drop(1)
  |> Enum.zip(
    @ansfile3
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
  |> Enum.each(fn {%{method: method, uri: uri, code: code, body: body}, n} ->
    test "phase3 #{n}: #{method} #{uri} #{code}" do
      method = unquote method
      uri = unquote uri
      code = unquote code
      body = unquote body

      req_status_equals(method, uri, code, body)
    end
  end)

end
