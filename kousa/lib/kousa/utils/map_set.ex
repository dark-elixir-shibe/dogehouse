# implementation of JSON encoding for a MapSet

defimpl Jason.Encoder, for: MapSet do
  def encode(map_set, opts) do
    map_set
    |> Map.new(&{&1, true})
    |> Jason.Encoder.encode(opts)
  end
end
