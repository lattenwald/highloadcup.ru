defmodule Round1.Db.Avg do
  require Logger
  use Agent, restart: :transient

  alias Round1.Db

  @moduledoc """
  Storage has map from location_id to visits
  """

  ### interface
  def start_link() do
    Logger.debug "#{__MODULE__} starting"
    Agent.start_link(
      fn -> %{} end,
      name: __MODULE__
    )
  end

  def get_state(), do: Agent.get(__MODULE__, & &1)
  def add_visits(nil), do: :ok
  def add_visits(data), do: Enum.map(data, &add_visit(&1))

  def add_visit(visit) do
    Agent.update(
      __MODULE__,
      fn state ->
        Map.update(
          state, visit.location, [visit],
          & [visit | &1]
        )
      end
    )
  end

  def update(old, new) do
    if old.location != new.location do
      Agent.update(
        __MODULE__,
        fn state ->
          state
          |> Map.update!(old.location, &Enum.filter(&1, fn v -> v.id != old.id end))
          |> Map.update(new.location, [new], & [new | &1 ])
        end)
    end
  end

  def get(location_id, opts \\ []) do
    from_date = opts[:from_date]
    to_date   = opts[:to_date]

    {{y, m, d}, t} = :erlang.localtime
    born_before = case opts[:from_age] do
                    nil -> nil
                    age -> to_timestamp {{y - age, m, d}, t}
                  end
    born_after  = case opts[:to_age] do
                    nil -> nil
                    age -> to_timestamp {{y - age, m, d}, t}
                  end

    gender    = opts[:gender]

    cond do
      is_nil(Db.get(:locations, location_id)) -> nil

      true ->
        {total, cnt} = get_visits(location_id)
        |> Stream.filter(& is_nil(from_date) || &1.visited_at > from_date)
        |> Stream.filter(& is_nil(to_date) || &1.visited_at < to_date)
        |> Stream.map(fn visit ->
          user = Db.get(:users, visit.user)
          %{visit | user: user}
        end)
        |> Stream.filter(& is_nil(gender) || &1.user.gender == gender)
        |> Stream.filter(& is_nil(born_before) || &1.user.birth_date < born_before)
        |> Stream.filter(& is_nil(born_after)  || &1.user.birth_date > born_after)
        |> Enum.reduce({0, 0}, fn visit, {total, cnt} -> {total+visit.mark, cnt+1} end)

        # if cnt == 0, do: 0, else: total / cnt
        if cnt == 0, do: 0, else: round((total / cnt) * 100000) / 100000
    end
  end

  defp get_visits(location_id) do
    Agent.get(
      __MODULE__,
      & &1[location_id]
    ) || []
  end

  # https://stackoverflow.com/questions/12527908/how-to-convert-datetime-to-timestamp-in-erlang
  defp to_timestamp(datetime) do
    (:calendar.datetime_to_gregorian_seconds(datetime) - 62167219200)*1000000
  end

end
