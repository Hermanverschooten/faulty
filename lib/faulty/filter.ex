defmodule Faulty.Filter do
  @moduledoc """
  Behaviour for sanitizing & modifying the error context before it's saved.

      defmodule MyApp.ErrorFilter do
        @behaviour Faulty.Filter

        @impl true
        def sanitize(context) do
          context # Modify the context object (add or remove fields as much as you need.)
        end
      end

  Once implemented, include it in the Faulty configuration:

    config :faulty, filter: MyApp.Filter

  With this configuration in place, the Faulty will call `MyApp.Filter.sanitize/1` to get a context before
  saving error occurrence.

  > #### A note on performance {: .warning}
  >
  > Keep in mind that the `sanitize/1` will be called in the context of the Faulty itself.
  > Slow code will have a significant impact in the Faulty performance. Buggy code can bring
  > the Faulty process down.
  """

  @doc """
  This function will be given an error context to inspect/modify before it's saved.
  """
  @callback sanitize(context :: map()) :: map()
end
