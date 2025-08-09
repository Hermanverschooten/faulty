defmodule Faulty.Fingerprint do
  @moduledoc """
  Generates unique fingerprints for errors to enable proper grouping and deduplication.

  The fingerprint is based on the error kind, source location (when available),
  and a normalized version of the error reason. This approach ensures that:

  - Similar errors are grouped together
  - Different error types are properly separated
  - Volatile details in error messages don't prevent grouping
  - Errors without source information are still differentiated by type
  """

  @doc """
  Generates a SHA256 fingerprint for an error.

  ## Parameters

    * `kind` - The error kind (e.g., "Elixir.ArgumentError", "error")
    * `reason` - The error reason/message
    * `source_line` - Source location as "file:line" or "-" if unknown
    * `source_function` - Source function as "Module.function/arity" or "-" if unknown

  ## Examples

      iex> Faulty.Fingerprint.generate("error", "Erlang error: {:port_died, :normal}", "-", "-")
      "4F3263C8ABD35E3985DEB0E6422D111D12B357D665604BCF2DE101C3EAC86951"

      iex> Faulty.Fingerprint.generate("error", "Erlang error: {:tls_alert, {:bad_record_mac, \\\"TLS error\\\"}}", "-", "-")
      "D04D58179897BD41292783B5360F2E14AF691D59C168D8D8E4F316819E09C466"

  """
  @spec generate(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def generate(kind, reason, source_line, source_function) do
    components = [
      to_string(kind),
      source_line,
      source_function,
      normalize_reason_for_fingerprint(reason)
    ]

    fingerprint_data = components |> Enum.join("|")
    fingerprint = :crypto.hash(:sha256, fingerprint_data)
    Base.encode16(fingerprint)
  end

  @doc """
  Normalizes an error reason for fingerprinting purposes.

  Extracts the essential error type while removing volatile details like
  specific messages, timestamps, or runtime-specific information that
  would prevent proper error grouping.

  ## Examples

      iex> Faulty.Fingerprint.normalize_reason_for_fingerprint("Erlang error: {:port_died, :normal}")
      "erlang_error:port_died"

      iex> Faulty.Fingerprint.normalize_reason_for_fingerprint("ArgumentError: invalid input here")
      "elixir_exception:ArgumentError"

  """
  @spec normalize_reason_for_fingerprint(String.t()) :: String.t()
  def normalize_reason_for_fingerprint(reason) when is_binary(reason) do
    case reason do
      # Erlang port errors - keep the port error type
      "Erlang error: {:port_died, " <> _ ->
        "erlang_error:port_died"

      # TLS/SSL errors - extract the alert type
      "Erlang error: {:tls_alert, {:" <> rest ->
        case extract_first_atom(rest) do
          {:ok, alert_type} -> "erlang_error:tls_alert:#{alert_type}"
          :error -> "erlang_error:tls_alert:unknown"
        end

      # Common network/connection errors
      "Erlang error: {:nxdomain}" ->
        "erlang_error:nxdomain"

      "Erlang error: {:timeout}" ->
        "erlang_error:timeout"

      "Erlang error: {:econnrefused}" ->
        "erlang_error:econnrefused"

      "Erlang error: {:econnreset}" ->
        "erlang_error:econnreset"

      "Erlang error: {:closed}" ->
        "erlang_error:closed"

      # Generic Erlang errors - extract the main error atom
      "Erlang error: {:" <> rest ->
        case extract_first_atom(rest) do
          {:ok, error_atom} -> "erlang_error:#{error_atom}"
          :error -> "erlang_error:unknown"
        end

      # Elixir exceptions - use the exception type
      reason ->
        case String.split(reason, ": ", parts: 2) do
          [exception_type, _message] when exception_type != reason ->
            "elixir_exception:#{exception_type}"

          [single] ->
            # Handle cases where there's no ": " separator
            if String.contains?(single, "Error") or String.contains?(single, "Exception") do
              "elixir_exception:#{single}"
            else
              "unknown_error:#{String.slice(single, 0, 50)}"
            end
        end
    end
  end

  def normalize_reason_for_fingerprint(_reason) do
    "unknown_error:non_string"
  end

  # Private helper to extract the first atom from an Erlang tuple string
  defp extract_first_atom(string) do
    case String.split(string, ",", parts: 2) do
      [atom_part | _] ->
        # Remove trailing "}" if present
        cleaned = String.trim_trailing(atom_part, "}")

        if cleaned == "" do
          :error
        else
          {:ok, cleaned}
        end

      [] ->
        :error
    end
  end
end
