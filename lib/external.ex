defmodule External do
  @moduledoc """
  Macro helpers for defining external behaviour modules that delegate to
  a swappable implementation resolved at runtime via `:external_bound`.

  `use External` injects:

    * `import External, only: [defcallback: 1]`
    * A private `impl/0` that resolves to `__MODULE__.<suffix>` where
      `<suffix>` comes from `Application.get_env(:rr, :external_bound, Impl)`.
      In production this resolves to the `Impl` submodule; in test it
      resolves to the `Mock` submodule defined by Mox.

  ## Example

      defmodule External.Config do
        use External

        defcallback read() :: map()
        defcallback write(map()) :: :ok
      end
  """

  defmacro __using__(_opts) do
    quote do
      import External, only: [defcallback: 1]

      defp impl, do: Module.concat([__MODULE__, Application.get_env(:rr, :external_bound, Impl)])
    end
  end

  @doc """
  Defines a `@callback` and a public function that delegates to `impl/0`.

  Takes a standard typespec and expands it into both the behaviour callback
  and a delegating function with the matching arity.

      defcallback write(map()) :: :ok

  expands to:

      @callback write(map()) :: :ok
      def write(arg1), do: impl().write(arg1)
  """
  defmacro defcallback({:"::", _meta, [{name, _meta2, args}, _return_type]} = spec) do
    args = args || []
    arity = length(args)
    generated_args = Macro.generate_arguments(arity, __MODULE__)

    quote do
      @callback unquote(spec)

      def unquote(name)(unquote_splicing(generated_args)) do
        impl().unquote(name)(unquote_splicing(generated_args))
      end
    end
  end
end
