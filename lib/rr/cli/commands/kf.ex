defmodule RR.CLI.Commands.Kf do
  @moduledoc false
  @behaviour RR.CLI.Command

  alias RR.CLI.ParseError
  alias RR.Config.Paths
  alias RR.Providers.Terminal
  alias RR.Services.Kubeconfigs

  @enforce_keys [:cluster]
  defstruct [:cluster, sh?: false, new?: false]

  @impl true
  def build_action(switches, rest) do
    cond do
      rest == [] ->
        {:error, %ParseError{module: __MODULE__, message: "you didn't provide <cluster_name_substring>"}}

      match?([_], rest) ->
        [cluster] = rest

        {:ok,
         %__MODULE__{
           cluster: cluster,
           sh?: Keyword.get(switches, :sh, false),
           new?: Keyword.get(switches, :new, false)
         }}

      true ->
        {:error,
         %ParseError{
           module: __MODULE__,
           message: ["you provided more than one clusters: ", Enum.intersperse(rest, ", ")]
         }}
    end
  end

  @impl true
  def execute(%__MODULE__{cluster: cluster, new?: overwrite?, sh?: sh?}) do
    with {:ok, kubconfig_path} <- Kubeconfigs.fetch(cluster, overwrite: overwrite?) do
      output_kubeconfig_path(kubconfig_path, sh?)
      :ok
    end
  end

  @impl true
  def summary, do: "playing with rancher generated kubeconfigs"

  @impl true
  def help do
    """
    obtain and manage kubeconfigs from rancher

    USAGE:
      rr kf <cluster_name_substring> [flags]

      rr trys to match <cluster_name_substring> as substring of the cluster names, and will only proceed if there's one exact match.
      no match or more than one match will lead to error.

    FlAGS:
      --new Overwrite existing valid kubeconfigs.
      --sh Generate `export KUBECONIFG=` shell command to use a kubeconfig in the current shell.
    """
  end

  @impl true
  def args_definition do
    [
      strict: [
        help: :boolean,
        sh: :boolean,
        new: :boolean
      ],
      alias: [h: :help]
    ]
  end

  defp output_kubeconfig_path(kubeconfig_path, generate_sh_template?)

  defp output_kubeconfig_path(kubconfig_path, true) do
    Paths.sh_template_path()
    |> EEx.eval_file(kf_path: kubconfig_path)
    |> Terminal.info_stdout()
  end

  defp output_kubeconfig_path(kubconfig_path, false) do
    Terminal.info_stdout(kubconfig_path)
  end
end
