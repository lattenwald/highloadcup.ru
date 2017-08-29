defmodule Round1.Handler do
  require Logger
  require Record

  @behaviour :elli_handler

  # Record.defrecord :req, Record.extract(:req, from_lib: "elli/include/elli.hrl")

  def handle(req, _args) do
    # Logger.debug "#{inspect req} #{inspect args}"
    handle(:elli_request.method(req), :elli_request.path(req), req)
  end

  def handle(:GET, [], _req), do: {200, [], ""}

  def handle(:GET, ["users", id], _req), do: fetch(:users, id)
  def handle(:GET, ["locations", id], _req), do: fetch(:locations, id)
  def handle(:GET, ["visits", id], _req), do: fetch(:visits, id)
  def handle(:GET, ["users", id, "visits"], req), do: fetch_visits(id, req)
  def handle(:GET, ["locations", id, "avg"], req), do: fetch_avg(id, req)

  def handle(:POST, ["users", "new"], req), do: insert(:users, :elli_request.body(req))
  def handle(:POST, ["locations", "new"], req), do: insert(:locations, :elli_request.body(req))
  def handle(:POST, ["visits", "new"], req), do: insert(:visits, :elli_request.body(req))

  def handle(:POST, ["users", id], req), do: update(:users, id, :elli_request.body(req))
  def handle(:POST, ["locations", id], req), do: update(:locations, id, :elli_request.body(req))
  def handle(:POST, ["visits", id], req), do: update(:visits, id, :elli_request.body(req))

  def handle(_, _, _), do: not_found()

  # post "/users/new",     do: conn |> insert(:users)
  # post "/locations/new", do: conn |> insert(:locations)
  # post "/visits/new",    do: conn |> insert(:visits)

  # post "/users/:id",     do: conn |> update(:users)
  # post "/locations/:id", do: conn |> update(:locations)
  # post "/visits/:id",    do: conn |> update(:visits)

  # match _, do: not_found(conn)

  ### see https://github.com/knutin/elli/blob/master/src/elli_example_callback.erl
  def handle_event(:elli_startup, [], _) do
    Logger.info ":elli starting up"
    :ok
  end

  def handle_event(
    :request_complete,
    [req, response_code, _response_headers, _response_body, {timings, _}],
    _) do
    Logger.debug fn ->
      req_time = (timings[:request_end] - timings[:request_start]) / 1000
      send_time = (timings[:send_end] - timings[:send_start]) / 1000
      hdr_time = (timings[:headers_end] - timings[:headers_start]) / 1000
      body_time = (timings[:body_end] - timings[:body_start]) / 1000
      user_time = (timings[:user_end] - timings[:user_start]) / 1000
      "#{:elli_request.method(req)} #{:elli_request.path(req) |> Enum.join("/")} : #{response_code} req:#{req_time} send:#{send_time} user:#{user_time} hdr:#{hdr_time} body:#{body_time}"
    end
    :ok
  end

  def handle_event(_event, _, _), do: :ok
  # def handle_event(:request_throw, [_request, _exception, _stacktrace], _), do: :ok
  # def handle_event(:request_error, [_request, _exception, _stacktrace], _), do: :ok
  # def handle_event(:request_exit,  [_request, _exception, _stacktrace], _), do: :ok
  # def handle_event(:invalid_return, [_request, _return_value], _), do: :ok
  # def handle_event(:chunk_complete,
  #   [_request, _response_code, _response_headers, _closing_end, _timings],
  #   _), do: :ok
  # def handle_event(:request_closed, [], _), do: :ok
  # def handle_event(:request_timeout, [], _), do: :ok
  # def handle_event(:request_parse_error, [_], _), do: :ok
  # def handle_event(:client_closed, [_where], _), do: :ok
  # def handle_event(:client_timeout, [_where], _), do: :ok
  # def handle_event(:bad_request, [_reason], _), do: :ok
  # def handle_event(:file_error, [_error_reason], _), do: :ok

  defp not_found(), do: {404, [{"Server", "round1 (ets, jiffy, elli)"}], ""}
  defp bad_request(), do: {400, [{"Server", "round1 (ets, jiffy, elli)"}], ""}
  defp ok("") do
    {200,
     [{"Server", "round1 (ets, jiffy, elli)"},
      {"Content-Type", "application/json"},
      {"Connection", "close"}],
     "{}"}
  end
  defp ok(data) do
    {200,
     [{"Server", "round1 (ets, jiffy, elli)"},
      {"Content-Type", "application/json"}],
     :jiffy.encode(data)}
  end

  defp fetch(type, id) do
    case Integer.parse(id) do
      {id, ""} ->
        case Round1.Db.get(type, id) do
          nil -> not_found()
          item -> ok(item)
        end

      _ -> not_found()
    end
  end

  defp try_decode(str) do
    try do
      :jiffy.decode(str, [:use_nil, :return_maps])
    rescue
      _ -> :error
    catch
      _, _ -> :error
    else
      res -> {:ok, res}
    end

  end

  defp update(type, id, body) do
    with {id, ""} <- Integer.parse(id),
         {:ok, json} <- try_decode(body),
         {:ok, entity} <- Round1.Validate.validate_update(type, json) do
      case Round1.Db.update(type, id, entity) do
        nil -> not_found()
        :error -> bad_request()
        :ok -> ok("")
      end
    else
      _ -> bad_request()
    end
  end

  defp insert(type, body) do
    with {:ok, json} <- try_decode(body),
         {:ok, entity} <- Round1.Validate.validate_new(type, json) do
      case Round1.Db.insert(type, entity.id, entity) do
        :ok -> ok("")
        _ -> bad_request()
      end
    else
      _ -> bad_request()
    end
  end

  defp fetch_visits(id, req) do
    with {id, ""} <- Integer.parse(id),
         {:ok, from_date} <- parse_int(:elli_request.get_arg_decoded("fromDate", req, nil)),
         {:ok, to_date} <- parse_int(:elli_request.get_arg_decoded("toDate", req, nil)),
         {:ok, to_distance} <- parse_int(:elli_request.get_arg_decoded("toDistance", req, nil)),
         {:ok, country} <- parse_str(:elli_request.get_arg_decoded("country", req, nil))
      do
      opts = []
      |> Keyword.put(:from_date, from_date)
      |> Keyword.put(:to_date, to_date)
      |> Keyword.put(:to_distance, to_distance)
      |> Keyword.put(:country, country)

      case Round1.Db.Visits.get(id, opts) do
        nil -> not_found()
        v -> ok(%{visits: v})
      end
    else
      _ -> bad_request()
    end
  end

  defp fetch_avg(id, req) do
    with {id, ""} <- Integer.parse(id),
         {:ok, from_date} <- parse_int(:elli_request.get_arg_decoded("fromDate", req, nil)),
         {:ok, to_date} <- parse_int(:elli_request.get_arg_decoded("toDate", req, nil)),
         {:ok, from_age} <- parse_int(:elli_request.get_arg_decoded("fromAge", req, nil)),
         {:ok, to_age} <- parse_int(:elli_request.get_arg_decoded("toAge", req, nil)),
         {:ok, gender} <- parse_gender(:elli_request.get_arg_decoded("gender", req, nil))
      do
      opts = []
      |> Keyword.put(:from_date, from_date)
      |> Keyword.put(:to_date, to_date)
      |> Keyword.put(:from_age, from_age)
      |> Keyword.put(:to_age, to_age)
      |> Keyword.put(:gender, gender)

      case Round1.Db.Avg.get(id, opts) do
        nil -> not_found()
        avg -> ok(%{avg: avg})
      end
    else
      _ -> bad_request()
    end
  end

  defp parse_int(nil), do: {:ok, nil}
  defp parse_int(str) do
    case Integer.parse(str) do
      {num, ""} -> {:ok, num}
      _other    -> :error
    end
  end

  defp parse_str(nil), do: {:ok, nil}
  defp parse_str(""), do: :error
  defp parse_str(str), do: {:ok, str}

  defp parse_gender(nil), do: {:ok, nil}
  defp parse_gender(str) when str in ["m", "f"], do: {:ok, str}
  defp parse_gender(_), do: :error

end
