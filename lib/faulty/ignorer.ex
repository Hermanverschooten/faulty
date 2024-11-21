defmodule Faulty.Ignorer do
  @moduledoc """
  Behaviour for ignoring errors.

  The Faulty tracks every error that happens in your application. In certain cases you may
  want to ignore some errors and don't track them. To do so you can implement this behaviour.

      defmodule MyApp.ErrorIgnorer do
        @behaviour Faulty.Ignorer

        @impl true
        def ignore?(error = %Faulty.Error{}, context) do
          # return true if the error should be ignored
        end
      end

  Once implemented, include it in the Faulty configuration:

      config :faulty, ignorer: MyApp.ErrorIgnorer

  With this configuration in place, the Faulty will call `MyApp.ErrorIgnorer.ignore?/2` before
  tracking errors. If the function returns `true` the error will be ignored and won't be tracked.

  > #### A note on performance {: .warning}
  >
  > Keep in mind that the `ignore?/2` will be called in the context of the Faulty itself.
  > Slow code will have a significant impact in the Faulty performance. Buggy code can bring
  > the Faulty process down.
  """

  @doc """
  Decide wether the given error should be ignored or not.

  This function receives both the current Error and context and should return a boolean indicating
  if it should be ignored or not. If the function returns true the error will be ignored, otherwise
  it will be tracked.
  """
  @callback ignore?(error :: Faulty.Error.t(), context :: map()) :: boolean
end
