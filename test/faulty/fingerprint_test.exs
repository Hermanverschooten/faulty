defmodule Faulty.FingerprintTest do
  use ExUnit.Case
  doctest Faulty.Fingerprint

  alias Faulty.Fingerprint

  describe "generate/4" do
    test "generates consistent fingerprints for identical inputs" do
      fingerprint1 =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input",
          "file.ex:123",
          "Module.func/1"
        )

      fingerprint2 =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input",
          "file.ex:123",
          "Module.func/1"
        )

      assert fingerprint1 == fingerprint2
    end

    test "generates different fingerprints for different kinds" do
      fingerprint1 =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input",
          "file.ex:123",
          "Module.func/1"
        )

      fingerprint2 =
        Fingerprint.generate(
          "exit",
          "ArgumentError: invalid input",
          "file.ex:123",
          "Module.func/1"
        )

      assert fingerprint1 != fingerprint2
    end

    test "generates different fingerprints for different source lines" do
      fingerprint1 =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input",
          "file.ex:123",
          "Module.func/1"
        )

      fingerprint2 =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input",
          "file.ex:456",
          "Module.func/1"
        )

      assert fingerprint1 != fingerprint2
    end

    test "generates different fingerprints for different source functions" do
      fingerprint1 =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input",
          "file.ex:123",
          "Module.func/1"
        )

      fingerprint2 =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input",
          "file.ex:123",
          "Module.other/2"
        )

      assert fingerprint1 != fingerprint2
    end

    test "generates same fingerprints for errors with same normalized reason" do
      fingerprint1 =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input here",
          "file.ex:123",
          "Module.func/1"
        )

      fingerprint2 =
        Fingerprint.generate(
          "error",
          "ArgumentError: different message",
          "file.ex:123",
          "Module.func/1"
        )

      assert fingerprint1 == fingerprint2
    end

    test "returns a valid SHA256 hex string" do
      fingerprint =
        Fingerprint.generate(
          "error",
          "ArgumentError: invalid input",
          "file.ex:123",
          "Module.func/1"
        )

      assert is_binary(fingerprint)
      assert String.length(fingerprint) == 64
      assert String.match?(fingerprint, ~r/^[0-9A-F]+$/)
    end
  end

  describe "normalize_reason_for_fingerprint/1" do
    test "normalizes Erlang port errors" do
      reason = "Erlang error: {:port_died, :normal}"
      assert Fingerprint.normalize_reason_for_fingerprint(reason) == "erlang_error:port_died"

      reason = "Erlang error: {:port_died, {:exit_status, 1}}"
      assert Fingerprint.normalize_reason_for_fingerprint(reason) == "erlang_error:port_died"
    end

    test "normalizes TLS alert errors" do
      reason =
        "Erlang error: {:tls_alert, {:bad_record_mac, \"TLS client: In state cipher received SERVER ALERT: Fatal - Bad Record MAC\"}}"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "erlang_error:tls_alert:bad_record_mac"

      reason = "Erlang error: {:tls_alert, {:handshake_failure}}"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "erlang_error:tls_alert:handshake_failure"
    end

    test "normalizes common network errors" do
      assert Fingerprint.normalize_reason_for_fingerprint("Erlang error: {:nxdomain}") ==
               "erlang_error:nxdomain"

      assert Fingerprint.normalize_reason_for_fingerprint("Erlang error: {:timeout}") ==
               "erlang_error:timeout"

      assert Fingerprint.normalize_reason_for_fingerprint("Erlang error: {:econnrefused}") ==
               "erlang_error:econnrefused"

      assert Fingerprint.normalize_reason_for_fingerprint("Erlang error: {:econnreset}") ==
               "erlang_error:econnreset"

      assert Fingerprint.normalize_reason_for_fingerprint("Erlang error: {:closed}") ==
               "erlang_error:closed"
    end

    test "normalizes generic Erlang errors" do
      reason = "Erlang error: {:badarg, :crypto}"
      assert Fingerprint.normalize_reason_for_fingerprint(reason) == "erlang_error:badarg"

      reason = "Erlang error: {:function_clause}"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "erlang_error:function_clause"
    end

    test "normalizes Elixir exceptions with messages" do
      reason = "ArgumentError: argument error message"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "elixir_exception:ArgumentError"

      reason = "RuntimeError: something went wrong"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "elixir_exception:RuntimeError"

      reason = "KeyError: key :foo not found in: %{}"
      assert Fingerprint.normalize_reason_for_fingerprint(reason) == "elixir_exception:KeyError"
    end

    test "handles Elixir exceptions without messages" do
      reason = "ArgumentError"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "elixir_exception:ArgumentError"

      reason = "RuntimeError"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "elixir_exception:RuntimeError"
    end

    test "handles unknown error formats" do
      reason = "some random error message"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "unknown_error:some random error message"

      reason = "a very long error message that exceeds fifty characters and should be truncated"
      expected = "unknown_error:a very long error message that exceeds fifty chara"
      assert Fingerprint.normalize_reason_for_fingerprint(reason) == expected
    end

    test "handles non-string inputs" do
      assert Fingerprint.normalize_reason_for_fingerprint(:atom) == "unknown_error:non_string"
      assert Fingerprint.normalize_reason_for_fingerprint(123) == "unknown_error:non_string"
      assert Fingerprint.normalize_reason_for_fingerprint(%{}) == "unknown_error:non_string"
    end

    test "handles malformed Erlang error strings" do
      reason = "Erlang error: {:invalid_format"
      assert Fingerprint.normalize_reason_for_fingerprint(reason) == "erlang_error:invalid_format"

      reason = "Erlang error: {:}"
      assert Fingerprint.normalize_reason_for_fingerprint(reason) == "erlang_error:unknown"
    end

    test "handles TLS errors with malformed alert structure" do
      reason = "Erlang error: {:tls_alert, {:}}"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "erlang_error:tls_alert:unknown"

      reason = "Erlang error: {:tls_alert, {:invalid"

      assert Fingerprint.normalize_reason_for_fingerprint(reason) ==
               "erlang_error:tls_alert:invalid"
    end
  end
end
