defmodule Faulty.Scrubber do
  @moduledoc """
  Redacts sensitive values from an error context before it is sent.

  Faulty scrubs every context by default, before your `Faulty.Filter` runs. The
  value under a sensitive key is replaced by `"[FILTERED]"`, whatever its type,
  and maps and lists are scrubbed recursively.

  A key is sensitive when, compared case-insensitively and ignoring everything
  that is not a letter or a digit, it contains one of: `password`, `passwd`,
  `pwd`, `secret`, `token`, `apikey`, `authorization`, `bearer`, `cookie`,
  `creditcard`, `cardnumber`, `cardnum`, `cvv`, `cvc`, `ssn`, `socialsecurity`
  or `privatekey`. So `Authorization`, `x-api-key` and `apiKey` all match.

  Only keys are looked at: error reasons and other strings are left as they are.
  Structs are left untouched.

  It can be turned off with:

      config :faulty, scrub_pii: false

  Your own `Faulty.Filter` runs afterwards, whether or not this is enabled.
  """

  @redacted "[FILTERED]"

  @sensitive_keys ~w(
    password passwd pwd secret token apikey authorization bearer cookie
    creditcard cardnumber cardnum cvv cvc ssn socialsecurity privatekey
  )

  @doc """
  Scrubs a context, or any value found inside one.

  ## Examples

      iex> Faulty.Scrubber.scrub(%{"password" => "hunter2", "name" => "Herman"})
      %{"password" => "[FILTERED]", "name" => "Herman"}

  """
  @spec scrub(term()) :: term()
  def scrub(%_{} = struct), do: struct

  def scrub(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, scrub_value(key, value)} end)
  end

  def scrub(list) when is_list(list), do: Enum.map(list, &scrub/1)
  def scrub(other), do: other

  defp scrub_value(_key, nil), do: nil

  defp scrub_value(key, value) do
    if sensitive_key?(key), do: @redacted, else: scrub(value)
  end

  defp sensitive_key?(key) when is_atom(key) and not is_nil(key),
    do: key |> Atom.to_string() |> sensitive_key?()

  defp sensitive_key?(key) when is_binary(key) do
    normalized =
      for <<char <- String.downcase(key)>>, char in ?a..?z or char in ?0..?9,
        into: "",
        do: <<char>>

    Enum.any?(@sensitive_keys, &String.contains?(normalized, &1))
  end

  defp sensitive_key?(_key), do: false
end
