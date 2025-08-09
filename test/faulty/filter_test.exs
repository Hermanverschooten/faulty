defmodule Faulty.FilterTest do
  use ExUnit.Case

  describe "Filter behaviour" do
    defmodule TestFilter do
      @behaviour Faulty.Filter

      def sanitize(context) do
        context
        |> sanitize_passwords()
        |> sanitize_auth_headers()
        |> sanitize_nested_maps()
      end

      defp sanitize_passwords(context) do
        if Map.has_key?(context, "password") do
          Map.put(context, "password", "[REDACTED]")
        else
          context
        end
      end

      defp sanitize_auth_headers(context) do
        if Map.has_key?(context, "authorization") do
          Map.put(context, "authorization", "[REDACTED]")
        else
          context
        end
      end

      defp sanitize_nested_maps(%{} = context) do
        context
        |> Enum.map(fn
          {key, value} when is_map(value) ->
            sanitized_value =
              value
              |> sanitize_passwords()
              |> sanitize_auth_headers()
              |> sanitize_nested_maps()

            {key, sanitized_value}

          {key, value} ->
            {key, value}
        end)
        |> Map.new()
      end

      defp sanitize_nested_maps(value), do: value
    end

    test "defines sanitize/1 callback" do
      assert Faulty.Filter.behaviour_info(:callbacks) == [{:sanitize, 1}]
    end

    test "can implement custom filter logic" do
      context = %{
        "user_id" => 123,
        "password" => "secret123",
        "authorization" => "Bearer token123"
      }

      result = TestFilter.sanitize(context)

      assert result["user_id"] == 123
      assert result["password"] == "[REDACTED]"
      assert result["authorization"] == "[REDACTED]"
    end

    test "handles nested context sanitization" do
      context = %{
        "user" => %{
          "id" => 123,
          "password" => "secret123"
        },
        "request" => %{
          "headers" => %{
            "authorization" => "Bearer token123"
          }
        }
      }

      result = TestFilter.sanitize(context)

      assert result["user"]["id"] == 123
      assert result["user"]["password"] == "[REDACTED]"
      assert result["request"]["headers"]["authorization"] == "[REDACTED]"
    end

    test "preserves non-sensitive data" do
      context = %{
        "user_id" => 456,
        "session_id" => "session123",
        "timestamp" => 1_234_567_890,
        "metadata" => %{
          "ip_address" => "127.0.0.1",
          "user_agent" => "Test Browser"
        }
      }

      result = TestFilter.sanitize(context)

      assert result == context
    end

    test "handles empty context" do
      result = TestFilter.sanitize(%{})
      assert result == %{}
    end

    test "handles non-map values gracefully" do
      context = %{
        "valid_key" => "valid_value",
        "list_value" => ["item1", "item2"],
        "number_value" => 42,
        "boolean_value" => true,
        "nil_value" => nil
      }

      result = TestFilter.sanitize(context)
      assert result == context
    end
  end

  describe "Common filter patterns" do
    defmodule CreditCardFilter do
      @behaviour Faulty.Filter

      def sanitize(context) do
        sanitize_credit_cards(context)
      end

      defp sanitize_credit_cards(%{} = context) do
        context
        |> Enum.map(fn
          {key, value} when is_binary(value) ->
            {key, sanitize_cc_number(value)}

          {key, value} when is_map(value) ->
            {key, sanitize_credit_cards(value)}

          {key, value} ->
            {key, value}
        end)
        |> Map.new()
      end

      defp sanitize_credit_cards(value), do: value

      defp sanitize_cc_number(value) when is_binary(value) do
        # Simple pattern to detect potential credit card numbers
        if String.match?(value, ~r/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/) do
          "[CREDIT_CARD_REDACTED]"
        else
          value
        end
      end

      defp sanitize_cc_number(value), do: value
    end

    test "filters credit card numbers" do
      context = %{
        "payment_info" => "4111 1111 1111 1111",
        "other_data" => "safe information",
        "nested" => %{
          "cc" => "4111-1111-1111-1111"
        }
      }

      result = CreditCardFilter.sanitize(context)

      assert result["payment_info"] == "[CREDIT_CARD_REDACTED]"
      assert result["other_data"] == "safe information"
      assert result["nested"]["cc"] == "[CREDIT_CARD_REDACTED]"
    end

    defmodule EmailFilter do
      @behaviour Faulty.Filter

      def sanitize(context) do
        sanitize_emails(context)
      end

      defp sanitize_emails(%{} = context) do
        context
        |> Enum.map(fn
          {key, value} when is_binary(value) ->
            {key, sanitize_email_value(value)}

          {key, value} when is_map(value) ->
            {key, sanitize_emails(value)}

          {key, value} ->
            {key, value}
        end)
        |> Map.new()
      end

      defp sanitize_emails(value), do: value

      defp sanitize_email_value(value) when is_binary(value) do
        if String.match?(value, ~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/) do
          "[EMAIL_REDACTED]"
        else
          value
        end
      end

      defp sanitize_email_value(value), do: value
    end

    test "filters email addresses" do
      context = %{
        "email" => "user@example.com",
        "message" => "Contact john.doe@company.org for help",
        "safe_text" => "This is safe content"
      }

      result = EmailFilter.sanitize(context)

      assert result["email"] == "[EMAIL_REDACTED]"
      assert result["message"] == "[EMAIL_REDACTED]"
      assert result["safe_text"] == "This is safe content"
    end
  end
end
