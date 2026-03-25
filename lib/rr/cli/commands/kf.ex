defmodule RR.CLI.Commands.Kf do
  @moduledoc false
  alias RR.CLI.Output
  alias RR.Config.Paths
  alias RR.Services.Kubeconfigs

  def run(args) do
    with {:ok, {switches, cluster_name_substring}} <- parse_args(args) do
      with {:ok, kubconfig_path} <-
             Kubeconfigs.fetch(cluster_name_substring, overwrite: Keyword.get(switches, :new, false)) do
        output_kubeconfig_path(kubconfig_path, Keyword.get(switches, :sh, false))
        :ok
      end
    end
  end

  defp parse_args(args) do
    {switches, rest, invalid_args} = OptionParser.parse(args, args_definition())

    cond do
      invalid_args != [] ->
        invalids = Enum.map(invalid_args, fn {arg, _value} -> arg end)
        render_help()
        {:error, ["the arguments you provided are invalid: ", invalids]}

      Keyword.has_key?(switches, :help) ->
        render_help()
        :ok

      rest == [] ->
        render_help()
        {:error, "you didn't provide <cluster_name_substring>"}

      match?([_], rest) ->
        [cluster] = rest
        {:ok, {switches, cluster}}

      true ->
        render_help()
        {:error, ["you provided more than one clusters: ", Enum.intersperse(rest, ", ")]}
    end
  end

  defp args_definition do
    [
      strict: [
        help: :boolean,
        sh: :boolean,
        new: :boolean
      ],
      alias: [h: :help]
    ]
  end

  defp render_help do
    Output.info_stdout("""
    obtain and manage kubeconfigs from rancher

    USAGE:
      rr kf <cluster_name_substring> [flags]

      rr trys to match <cluster_name_substring> as substring of the cluster names, and will only proceed if there's one exact match.
      no match or more than one match will lead to error.
      
    FlAGS:
      --new Overwrite existing valid kubeconfigs.
      --sh Generate `export KUBECONIFG=` shell command to use a kubeconfig in the current shell.
    """)
  end

  defp output_kubeconfig_path(kubeconfig_path, generate_sh_template?)

  defp output_kubeconfig_path(kubconfig_path, true) do
    Paths.sh_template_path()
    |> EEx.eval_file(kf_path: kubconfig_path)
    |> Output.info_stdout()
  end

  defp output_kubeconfig_path(kubconfig_path, false) do
    Output.info_stdout(kubconfig_path)
  end
end
