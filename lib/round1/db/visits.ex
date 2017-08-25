defmodule Round1.Db.Visits do
  require Logger
  use Agent, restart: :transient

  alias Round1.Db

  @moduledoc """
  Storage has map from user id to visits.
  Visits is a list of {visit, location} and flag `sorted`.
  On `get` sort it if it isn't sorted yet and set the flag.
  On `put`, set `sorted=false`.
  """

  defstruct sorted: false, visits: []

  ### interface
  def start_link() do
    Logger.info "#{__MODULE__} starting"
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
          state, visit.user,
          %__MODULE__{sorted: true, visits: [visit]},
          & %{ &1 | sorted: false, visits: [ visit | &1.visits ]}
        )
      end
    )
  end

  def update(old, new) do
    if old.user != new.user do
      Agent.update(
        __MODULE__,
        fn state ->
          state
          |> Map.update!(old.user, & %{ &1 | visits: Enum.filter(&1.visits, fn v -> v.id != old.id end)})
          |> Map.update(
            new.user, %__MODULE__{sorted: false, visits: [new]},
          & %{ &1 | sorted: false, visits: [ new | &1.visits ]})
        end)
    end

    Agent.update(
      __MODULE__,
      fn state ->
        state
        |> Map.update!(new.user, & %{ &1 |
                                    sorted: &1.sorted && old.visited_at == new.visited_at,
                                    visits: Enum.map(&1.visits, fn v ->
                                      if v.id == new.id, do: new, else: v
                                    end)})
      end)

  end

  def get(user_id, opts \\ []) do
    from_date   = opts[:from_date]
    to_date     = opts[:to_date]
    country     = opts[:country]
    to_distance = opts[:to_distance]

    cond do
      is_nil(Db.get(:users, user_id)) -> nil

      true ->
        get_visits(user_id)
        |> Stream.map(fn visit ->
          loc = Db.get(:locations, visit.location)
          %{visit | location: loc}
        end)
        |> Stream.filter(& is_nil(country) || &1.location.country == country)
        |> Stream.filter(& is_nil(to_distance) || &1.location.distance < to_distance)
        |> Stream.map(& %{mark: &1.mark, visited_at: &1.visited_at, place: &1.location.place})
        |> Stream.filter(& is_nil(from_date) || &1.visited_at > from_date)
        |> Stream.filter(& is_nil(to_date) || &1.visited_at < to_date)
        |> Enum.into([])
    end
  end

  defp get_visits(user_id) do
    Agent.get_and_update(
      __MODULE__,
      fn state ->
        case state[user_id] do
          nil -> {[], state}
          %{sorted: true, visits: visits} -> {visits, state}
          %{visits: visits} ->
            new_visits = Enum.sort_by(visits, & &1.visited_at)
            new_state = Map.update!(
              state, user_id,
              & %{&1 | sorted: true, visits: new_visits}
            )
            {new_visits, new_state}
        end
      end
    )
  end

end
