defmodule Round1.Handler do
  require Logger
  use Plug.Router

  alias Round1.Db

  @port Application.get_env(:round1, :port, 80)

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:json], json_decoder: Poison
  plug :match
  plug :dispatch

  def start_link() do
    Logger.debug "#{__MODULE__} starting"
    {:ok, _} = Plug.Adapters.Cowboy.http(
      __MODULE__,
      nil,
      port: @port
    )
  end

  def init(opts), do: opts

  get "/", do: Plug.Conn.send_resp(conn, 200, "")

  get "/users/:id", do: conn |> fetch(:users)
  get "/locations/:id", do: conn |> fetch(:locations)
  get "/visits/:id", do: conn |> fetch(:visits)

  get "/users/:id/visits", do: conn |> fetch_visits()
  get "/locations/:id/avg", do: conn |> fetch_avg()

  match _, do: not_found(conn)

  defp not_found(conn), do: Plug.Conn.send_resp(conn, 404, "not found")
  defp bad_request(conn), do: Plug.Conn.send_resp(conn, 400, "bad request")

  defp fetch(conn, type) do
    case Integer.parse(conn.params["id"]) do
      {id, ""} ->
        case Db.get(type, id) do
          nil -> not_found(conn)
          item ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Poison.encode!(item))
        end

      _ -> not_found(conn)
    end
  end

  defp fetch_visits(conn) do
    with {id, ""} <- Integer.parse(conn.params["id"]),
         {:ok, from_date} <- parse_int(conn.params["fromDate"]),
         {:ok, to_date} <- parse_int(conn.params["toDate"]),
         {:ok, to_distance} <- parse_int(conn.params["toDistance"]),
         {:ok, country} <- parse_str(conn.params["country"])
      do
      opts = []
      |> Keyword.put(:from_date, from_date)
      |> Keyword.put(:to_date, to_date)
      |> Keyword.put(:to_distance, to_distance)
      |> Keyword.put(:country, country)

      case Db.Visits.get(id, opts) do
        nil -> not_found(conn)
        visits ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Poison.encode!(%{visits: visits}))
      end

    else
      _ -> bad_request(conn)
    end
  end

  defp fetch_avg(conn) do
    with {id, ""} <- Integer.parse(conn.params["id"]),
         {:ok, from_date} <- parse_int(conn.params["fromDate"]),
         {:ok, to_date} <- parse_int(conn.params["toDate"]),
         {:ok, from_age} <- parse_int(conn.params["fromAge"]),
         {:ok, to_age} <- parse_int(conn.params["toAge"]),
         {:ok, gender} <- parse_str(conn.params["gender"])
      do
      opts = []
      |> Keyword.put(:from_date, from_date)
      |> Keyword.put(:to_date, to_date)
      |> Keyword.put(:from_age, from_age)
      |> Keyword.put(:to_age, to_age)
      |> Keyword.put(:gender, gender)

      case Db.Avg.get(id, opts) do
        nil -> not_found(conn)
        avg ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Poison.encode!(%{avg: avg}))
      end
    else
      _ -> bad_request(conn)
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

end
