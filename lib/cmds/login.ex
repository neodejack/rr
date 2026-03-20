defmodule RR.Login do
  @moduledoc """
  three finite state: [:no_auth_config, :invalid_auth_config, :valid_auth_config]
  login/1 function will pattern match on these three and proceed to respective actions

  """
  alias RR.Config.Auth
  alias RR.Config.Profiles
  alias RR.Shell

  def run(args) do
    with {:ok, profile_name} <- parse_args(args),
         {:ok, profile_name} <- select_profile_name(profile_name) do
      maybe_login(profile_name)
    end
  end

  defp parse_args(args) do
    {switches, rest, invalid_args} = OptionParser.parse(args, args_definition())

    cond do
      invalid_args != [] ->
        invalids = Enum.map(invalid_args, fn {arg, _value} -> arg end)
        render_help()
        {:error, "the arguments you provided are invalid\nyou provided: #{Enum.join(invalids, " ")}"}

      Keyword.has_key?(switches, :help) ->
        render_help()
        :ok

      rest != [] ->
        render_help()
        {:error, "rr login command doesn't take any subcommands\nyou provided: #{Enum.join(rest, " ")}"}

      true ->
        {:ok, Profiles.normalize_profile_name(Keyword.get(switches, :profile))}
    end
  end

  defp args_definition do
    [
      strict: [
        help: :boolean,
        profile: :string
      ],
      aliases: [h: :help, p: :profile]
    ]
  end

  defp render_help do
    Shell.info_stdout("""
    save or update rancher auth profiles

    USAGE:
      rr login
      rr login -p <profile>
    """)
  end

  defp select_profile_name(profile_name) when is_binary(profile_name), do: {:ok, profile_name}

  defp select_profile_name(nil) do
    case Profiles.names() do
      [] ->
        {:ok, prompt_new_profile_name([])}

      profile_names ->
        case Owl.IO.select([:update_existing, :create_new],
               label: "choose login flow",
               render_as: fn
                 :update_existing -> "update existing profile"
                 :create_new -> "create new profile"
               end
             ) do
          :update_existing ->
            {:ok, Owl.IO.select(profile_names, label: "select profile")}

          :create_new ->
            {:ok, prompt_new_profile_name(profile_names)}
        end
    end
  end

  defp prompt_new_profile_name(existing_profile_names) do
    profile_name =
      [label: "profile name"]
      |> Owl.IO.input()
      |> Profiles.normalize_profile_name()

    cond do
      is_nil(profile_name) ->
        Shell.error("profile name cannot be blank")
        prompt_new_profile_name(existing_profile_names)

      profile_name in existing_profile_names ->
        Shell.error("profile '#{profile_name}' already exists")
        prompt_new_profile_name(existing_profile_names)

      true ->
        profile_name
    end
  end

  defp login(profile_name) do
    auth = prompt(profile_name)

    case Auth.check_auth_validity_from_ets_or_rancher(auth) do
      {:ok, auth} ->
        Auth.put_auth(profile_name, auth)
        Shell.info_stdout("token successfully validated and saved")
        :ok

      {:error, :unauthorized, reason} ->
        {:error, "token validation failed with reason: \n#{reason}"}

      {:error, :unknown, reason} ->
        {:error, "token validation failed with reason: \n#{reason}"}

      {:error, reason} ->
        {:error, "token validation failed with reason: \n#{reason}"}
    end
  end

  defp prompt(profile_name) do
    hostname = Owl.IO.input(label: "rancher hostname")
    token = Owl.IO.input(label: "rancher token (in the form of token-xxxx:xxxxxx)", secret: true)

    %Auth{profile_name: profile_name, rancher_hostname: hostname, rancher_token: token}
  end

  defp maybe_login(profile_name) do
    with {:ok, auth} <- Auth.ensure_valid_auth(profile_name),
         {:ok, token_info} <- External.RancherHttpClient.get_token_info(auth),
         true <-
           Owl.IO.confirm(
             message: [
               "profile '#{profile_name}' already has a valid auth config with description '#{token_info.description}',",
               "are you sure you want to overwrite it?"
             ]
           ) do
      login(profile_name)
    else
      false -> :ok
      {:error, :unauthorized, _} -> login(profile_name)
      {:error, :unknown, message} -> {:error, message}
      {:error, _} -> login(profile_name)
    end
  end
end
