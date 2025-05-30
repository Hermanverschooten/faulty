defmodule Faulty do
  @moduledoc """
  En Elixir-based  error tracking solution.

  The main objectives behind this project are:

  * Provide a basic free error tracking solution: because tracking errors in
  your application should be a requirement for almost any project, and helps to
  provide quality and maintenance to your project.

  ## Requirements

  Faulty requires Elixir 1.15+

  ## Integrations

  We currently include integrations for what we consider the basic stack of
  an application: Phoenix, Plug, Oban and Quantum.

  If you want to manually report an error, you can use the `Faulty.message/2` function.


  ## Context

  Aside from the information about each exception (kind, message, stack trace...)
  we also store contexts.

  Contexts are arbitrary maps that allow you to store extra information about an
  exception to be able to reproduce it later.

  Each integration includes a default context with useful information they
  can gather, but aside from that, you can also add your own information. You can
  do this in a per-process basis or in a per-call basis (or both).

  There are some requirements on the type of data that can be included in the
  context, so we recommend taking a look at `set_context/1` documentation.

  **Per process**

  This allows you to set a general context for the current process such as a Phoenix
  request or an Quantum or Oban job. For example, you could include the following code in your
  authentication Plug to automatically include the user ID in any error that is
  tracked during the Phoenix request handling.

  ```elixir
  Faulty.set_context(%{user_id: conn.assigns.current_user.id})
  ```

  **Per call**

  As we had seen before, you can use `Faulty.message/2` to manually report an
  error. The second parameter of this function is optional and allows you to include
  extra context that will be tracked along with the error.
  """

  @typedoc """
  A map containing the relevant context for a particular error.
  """
  @type context :: %{(String.t() | atom()) => any()}

  @typedoc """
  An `Exception` or a `{kind, payload}` tuple compatible with `Exception.normalize/3`.
  """
  @type exception :: Exception.t() | {:error, any()} | {Exception.non_error_kind(), any()}

  alias Faulty.Error

  @doc """
  Report an exception to be stored.

  Returns `:ok` stored or `:noop` if the Faulty is disabled by
  configuration the exception has not been stored.

  Aside from the exception, it is expected to receive the stack trace and,
  optionally, a context map which will be merged with the current process
  context.

  Keep in mind that errors that occur in Phoenix controllers, Phoenix LiveViews
  and Quantum and Oban jobs are automatically reported. You will need this function only if you
  want to report custom errors.

  ```elixir
  try do
    # your code
  catch
    e ->
      Faulty.report(e, __STACKTRACE__)
  end
  ```

  ## Exceptions

  Exceptions can be passed as:

  * An exception struct: the module of the exception is stored along with
  the exception message.

  * A `{kind, exception}` tuple in which case the information is converted to
  an Elixir exception (if possible) and stored.
  """

  @spec report(exception(), Exception.stacktrace(), context()) :: :ok | :noop
  def report(exception, stacktrace, given_context \\ %{}) do
    if !Process.get(:faulty_error_reported) do
      Process.put(:faulty_error_reported, true)
      {kind, reason} = normalize_exception(exception, stacktrace)
      {:ok, stacktrace} = Faulty.Stacktrace.new(stacktrace)
      {:ok, error} = Error.new(kind, reason, stacktrace)
      context = Map.merge(get_context(), given_context)

      context =
        if bread_crumbs = bread_crumbs(exception),
          do: Map.put(context, "bread_crumbs", bread_crumbs),
          else: context

      if enabled?() && !ignored?(error, context) do
        sanitized_context = sanitize_context(context)
        send_error!(error, stacktrace, sanitized_context, reason)
        :ok
      else
        :noop
      end
    else
      :noop
    end
  end

  @doc """
  Reports a message to be stored.

  Returns `:ok` stored or `:noop` if the Faulty is disabled by
  configuration the exception has not been stored.

  This allows you to store a message or exception manually,
  the stacktrace will be added automatically.

  ```elixir
  Faulty.message("Invalid user or password", %{login: login, password: password})

  Faulty.message({ArgumentError, "Invalid user or password"}, %{login: login, password: password})
  ```

  ## Exceptions

  Exceptions can be passed in three different forms:

  * A binary: This will be stored as an `ErlangError`.

  * An exception struct: the module of the exception is stored along with
  the exception message.

  * A `{kind, exception}` tuple in which case the information is converted to
  an Elixir exception (if possible) and stored.

  This function can also be used to test your setup.

  """

  @spec message(binary() | exception(), context()) :: :ok | :noop
  def message(message, given_context \\ %{})

  def message(message, given_context) when is_binary(message),
    do: message({:error, message}, given_context)

  def message(exception, given_context) when is_tuple(exception) or is_exception(exception) do
    {:current_stacktrace, [_process_info, _self | stacktrace]} =
      Process.info(self(), :current_stacktrace)

    report(exception, stacktrace, given_context)
  end

  def message(_, _), do: :noop

  @doc """
  Sets the current process context.

  The given context will be merged into the current process context. The given context
  may override existing keys from the current process context.

  ## Context depth

  You can store context on more than one level of depth, but take into account
  that the merge operation is performed on the first level.

  That means that any existing data on deep levels for he current context will
  be replaced if the first level key is received on the new contents.

  ## Content serialization

  The content stored on the context should be serializable using the JSON library
  used by the application (usually `Jason`), so it is rather recommended to use
  primitive types (strings, numbers, booleans...).

  If you still need to pass more complex data types to your context, please test
  that they can be encoded to JSON or storing the errors will fail. In the case
  of `Jason` that may require defining an Encoder for that data type if not
  included by default.
  """
  @spec set_context(context()) :: context()
  def set_context(params) when is_map(params) do
    current_context = Process.get(:faulty_context, %{})

    Process.put(:faulty_context, Map.merge(current_context, params))

    params
  end

  @doc """
  Obtain the context of the current process.
  """
  @spec get_context() :: context()
  def get_context do
    Process.get(:faulty_context, %{})
  end

  defp enabled? do
    !!Application.get_env(:faulty, :enabled, true)
  end

  defp ignored?(error, context) do
    ignorer = Application.get_env(:faulty, :ignorer)

    ignorer && ignorer.ignore?(error, context)
  end

  defp sanitize_context(context) do
    filter_mod = Application.get_env(:faulty, :filter)

    if filter_mod,
      do: filter_mod.sanitize(context),
      else: context
  end

  defp normalize_exception(%struct{} = ex, _stacktrace) when is_exception(ex) do
    {to_string(struct), Exception.message(ex)}
  end

  defp normalize_exception({kind, ex}, stacktrace) do
    case Exception.normalize(kind, ex, stacktrace) do
      %struct{} = ex ->
        {to_string(struct), Exception.message(ex)}

      other ->
        {to_string(kind), safe_to_string(other)}
    end
  end

  defp safe_to_string(term) do
    to_string(term)
  rescue
    Protocol.UndefinedError ->
      inspect(Term)
  end

  defp bread_crumbs(exception) do
    case exception do
      {_kind, exception} -> bread_crumbs(exception)
      %{bread_crumbs: bread_crumbs} -> bread_crumbs
      _other -> nil
    end
  end

  defp send_error!(error, stacktrace, sanitized_context, reason) do
    Faulty.Reporter.send(error, stacktrace, sanitized_context, reason)
  end
end
