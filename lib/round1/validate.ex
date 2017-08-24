defmodule Round1.Validate do
  require Logger

  def schema(:users) do
    [id: &is_integer/1, email: &is_binary/1, first_name: &is_binary/1,
     last_name: &is_binary/1, gender: fn s -> s in ["m", "f"] end,
     birth_date: &is_integer/1]
  end

  def schema(:visits) do
    [id: &is_integer/1, user: &is_integer/1, mark: &is_integer/1, location: &is_integer/1,
     visited_at: &is_integer/1]
  end

  def schema(:locations) do
    [id: &is_integer/1, distance: &is_integer/1, country: &is_binary/1, city: &is_binary/1,
     place: &is_binary/1]
  end

  defp validate_with_schema(schema, json) do
    try do
      json
      |> Enum.map(fn {k, v} ->
        k = String.to_existing_atom k
        if not schema[k].(v) do
          Logger.debug "failed validation for key #{k}"
          throw :error
        end
        {k, v}
      end)
      |> Enum.into(%{})
    rescue
      _ -> :error
    catch
      _ -> :error
    else
      new -> {:ok, new}
    end
  end

  def validate_update(type, json) do
    schema(type) |> validate_with_schema(json)
  end

  def validate_new(type, json) do
    keys = Map.keys(json) |> Enum.map(&String.to_existing_atom/1)
    schema = schema(type)
    schema_keys = Keyword.keys(schema) |> Enum.sort
    if Enum.sort(keys) != schema_keys do
      :error
    else
      validate_with_schema(schema, json)
    end
  end

end
