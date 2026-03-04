defmodule EDA.Voice do
  @moduledoc """
  Public API for Discord voice support.

  Manages voice connections per guild, including joining/leaving voice channels,
  audio playback, and listening to incoming audio.

  ## Usage

      # Join a voice channel
      EDA.Voice.join(guild_id, channel_id)

      # Play audio from a URL
      EDA.Voice.play(guild_id, "https://example.com/audio.mp3")

      # Stop playback
      EDA.Voice.stop(guild_id)

      # Leave voice
      EDA.Voice.leave(guild_id)
  """

  use GenServer

  require Logger

  alias EDA.Voice.{Audio, Dave, Session, State}

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Joins a voice channel.

  Options:
  - `:mute` - Join self-muted (default: `false`)
  - `:deaf` - Join self-deafened (default: `false`)
  """
  @spec join(String.t(), String.t(), keyword()) :: :ok
  def join(guild_id, channel_id, opts \\ []) do
    GenServer.call(__MODULE__, {:join, guild_id, channel_id, opts})
  end

  @doc """
  Leaves the voice channel in the given guild.
  """
  @spec leave(String.t()) :: :ok
  def leave(guild_id) do
    GenServer.call(__MODULE__, {:leave, guild_id})
  end

  @doc """
  Plays audio from the given input.

  Types:
  - `:url` - URL or file path (passed to ffmpeg)
  - `:raw` - Raw opus frames
  """
  @spec play(String.t(), String.t() | Enumerable.t(), atom()) :: :ok | {:error, term()}
  def play(guild_id, input, type \\ :url) do
    GenServer.call(__MODULE__, {:play, guild_id, input, type})
  end

  @doc """
  Stops audio playback in the given guild.
  """
  @spec stop(String.t()) :: :ok
  def stop(guild_id) do
    GenServer.call(__MODULE__, {:stop, guild_id})
  end

  @doc """
  Pauses audio playback.
  """
  @spec pause(String.t()) :: :ok
  def pause(guild_id) do
    GenServer.call(__MODULE__, {:pause, guild_id})
  end

  @doc """
  Resumes audio playback.
  """
  @spec resume(String.t()) :: :ok
  def resume(guild_id) do
    GenServer.call(__MODULE__, {:resume, guild_id})
  end

  @doc """
  Enables continuous audio receiving for the given guild.

  Incoming voice packets will be dispatched as `VOICE_AUDIO` events
  via `EDA.Gateway.Events`, along with `VOICE_SPEAKING_START` and
  `VOICE_SPEAKING_STOP` events when users begin or stop speaking.
  """
  @spec start_listening(String.t()) :: :ok | {:error, term()}
  def start_listening(guild_id) do
    GenServer.call(__MODULE__, {:start_listening, guild_id})
  end

  @doc """
  Disables continuous audio receiving for the given guild.
  """
  @spec stop_listening(String.t()) :: :ok
  def stop_listening(guild_id) do
    GenServer.call(__MODULE__, {:stop_listening, guild_id})
  end

  @doc """
  Returns `true` if audio is currently playing in the given guild.
  """
  @spec playing?(String.t()) :: boolean()
  def playing?(guild_id) do
    GenServer.call(__MODULE__, {:playing?, guild_id})
  end

  @doc """
  Returns `true` if the voice connection is ready for the given guild.
  """
  @spec ready?(String.t()) :: boolean()
  def ready?(guild_id) do
    GenServer.call(__MODULE__, {:ready?, guild_id})
  end

  @doc """
  Returns the channel ID the bot is connected to in the given guild, or `nil`.
  """
  @spec channel_id(String.t()) :: String.t() | nil
  def channel_id(guild_id) do
    GenServer.call(__MODULE__, {:channel_id, guild_id})
  end

  @doc """
  Returns the voice state for the given guild if the connection is ready.
  """
  @spec get_voice_state(String.t()) :: {:ok, State.t()} | {:error, :not_ready | :not_connected}
  def get_voice_state(guild_id) do
    GenServer.call(__MODULE__, {:get_voice_state, guild_id})
  end

  @doc """
  Sets the audio pid for a guild, preventing conflicts with `play/3`.
  Use `nil` to clear it when done.
  """
  @spec set_audio_pid(String.t(), pid() | nil) :: :ok
  def set_audio_pid(guild_id, pid) do
    GenServer.cast(__MODULE__, {:set_audio_pid, guild_id, pid})
  end

  @doc """
  Receives `count` voice packets (blocking).

  Returns a list of `{ssrc, opus_data}` tuples.
  """
  @spec listen(String.t(), integer()) :: [{integer(), binary()}]
  def listen(guild_id, count) do
    GenServer.call(__MODULE__, {:listen, guild_id, count}, 30_000)
  end

  # Internal callbacks from Voice.Event and Voice.Audio

  @doc false
  def voice_state_update(guild_id, session_id),
    do: voice_state_update(guild_id, session_id, nil)

  @doc false
  def voice_state_update(guild_id, session_id, channel_id) do
    GenServer.cast(__MODULE__, {:voice_state_update, guild_id, session_id, channel_id})
  end

  @doc false
  def voice_server_update(guild_id, token, endpoint) do
    GenServer.cast(__MODULE__, {:voice_server_update, guild_id, token, endpoint})
  end

  @doc false
  def voice_ready(guild_id, session_state) do
    GenServer.cast(__MODULE__, {:voice_ready, guild_id, session_state})
  end

  @doc false
  def voice_disconnected(guild_id) do
    GenServer.cast(__MODULE__, {:voice_disconnected, guild_id})
  end

  @doc false
  def restart_session(guild_id) do
    GenServer.cast(__MODULE__, {:restart_session, guild_id})
  end

  @doc false
  def playback_finished(guild_id, seq, ts, nonce) do
    GenServer.cast(__MODULE__, {:playback_finished, guild_id, seq, ts, nonce})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)
    Audio.init_playback_progress_table()
    {:ok, %{guilds: %{}}}
  end

  @impl true
  def handle_call({:join, guild_id, channel_id, opts}, _from, state) do
    Logger.info(
      "Voice.join called: guild=#{guild_id} channel=#{channel_id} opts=#{inspect(opts)}"
    )

    voice_state =
      case Map.get(state.guilds, guild_id) do
        %State{} = existing ->
          existing
          |> reset_runtime_state()
          |> Map.merge(%{guild_id: guild_id, channel_id: channel_id})

        nil ->
          %State{
            guild_id: guild_id,
            channel_id: channel_id
          }
      end

    new_guilds = Map.put(state.guilds, guild_id, voice_state)

    # Send OP 4 to the main gateway
    Logger.debug("Sending OP 4 (Voice State Update) to gateway for guild #{guild_id}")
    EDA.Gateway.Connection.update_voice_state(guild_id, channel_id, opts)

    {:reply, :ok, %{state | guilds: new_guilds}}
  end

  def handle_call({:leave, guild_id}, _from, state) do
    case Map.get(state.guilds, guild_id) do
      nil ->
        {:reply, :ok, state}

      voice_state ->
        cleanup_voice(guild_id, voice_state)
        EDA.Gateway.Connection.update_voice_state(guild_id, nil, [])
        {:reply, :ok, %{state | guilds: Map.delete(state.guilds, guild_id)}}
    end
  end

  def handle_call({:play, guild_id, input, type}, _from, state) do
    case Map.get(state.guilds, guild_id) do
      %State{ready: true, audio_pid: nil} = voice_state ->
        voice_state = sync_playback_progress(voice_state, guild_id)

        cond do
          not session_alive?(guild_id) ->
            stale_vs = %{voice_state | ready: false}
            {:reply, {:error, :not_connected}, put_in(state, [:guilds, guild_id], stale_vs)}

          not voice_crypto_ready?(voice_state) ->
            {:reply, {:error, :not_ready}, state}

          true ->
            pid = Audio.play(guild_id, input, type, voice_state)
            new_vs = %{voice_state | audio_pid: pid}
            {:reply, :ok, put_in(state, [:guilds, guild_id], new_vs)}
        end

      %State{ready: true, audio_pid: _pid} ->
        {:reply, {:error, :already_playing}, state}

      %State{ready: false} ->
        {:reply, {:error, :not_ready}, state}

      nil ->
        {:reply, {:error, :not_connected}, state}
    end
  end

  def handle_call({:stop, guild_id}, _from, state) do
    case Map.get(state.guilds, guild_id) do
      %State{audio_pid: pid} = voice_state when is_pid(pid) ->
        Process.exit(pid, :kill)

        new_vs =
          voice_state
          |> Map.put(:audio_pid, nil)
          |> sync_playback_progress(guild_id)

        {:reply, :ok, put_in(state, [:guilds, guild_id], new_vs)}

      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:pause, guild_id}, _from, state) do
    case Map.get(state.guilds, guild_id) do
      %State{audio_pid: pid} when is_pid(pid) ->
        Process.exit(pid, :kill)

        new_vs =
          state.guilds[guild_id]
          |> Map.put(:audio_pid, nil)
          |> Map.put(:paused, true)
          |> sync_playback_progress(guild_id)

        {:reply, :ok, put_in(state, [:guilds, guild_id], new_vs)}

      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:resume, _guild_id}, _from, state) do
    # Resume is a no-op for now - would require tracking position
    {:reply, :ok, state}
  end

  def handle_call({:playing?, guild_id}, _from, state) do
    playing =
      case Map.get(state.guilds, guild_id) do
        %State{audio_pid: pid} when is_pid(pid) -> Process.alive?(pid)
        _ -> false
      end

    {:reply, playing, state}
  end

  def handle_call({:ready?, guild_id}, _from, state) do
    ready =
      case Map.get(state.guilds, guild_id) do
        %State{ready: true} = voice_state ->
          session_alive?(guild_id) and voice_crypto_ready?(voice_state)

        _ ->
          false
      end

    {:reply, ready, state}
  end

  def handle_call({:channel_id, guild_id}, _from, state) do
    channel =
      case Map.get(state.guilds, guild_id) do
        %State{channel_id: cid} -> cid
        nil -> nil
      end

    {:reply, channel, state}
  end

  def handle_call({:get_voice_state, guild_id}, _from, state) do
    case Map.get(state.guilds, guild_id) do
      %State{ready: true} = vs -> {:reply, {:ok, vs}, state}
      %State{} -> {:reply, {:error, :not_ready}, state}
      nil -> {:reply, {:error, :not_connected}, state}
    end
  end

  def handle_call({:start_listening, guild_id}, _from, state) do
    case Map.get(state.guilds, guild_id) do
      %State{ready: true} = voice_state ->
        Session.start_listening(guild_id)
        new_vs = %{voice_state | listening: true}
        {:reply, :ok, put_in(state, [:guilds, guild_id], new_vs)}

      %State{} ->
        {:reply, {:error, :not_ready}, state}

      nil ->
        {:reply, {:error, :not_connected}, state}
    end
  end

  def handle_call({:stop_listening, guild_id}, _from, state) do
    case Map.get(state.guilds, guild_id) do
      %State{listening: true} = voice_state ->
        Session.stop_listening(guild_id)
        new_vs = %{voice_state | listening: false}
        {:reply, :ok, put_in(state, [:guilds, guild_id], new_vs)}

      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:listen, guild_id, count}, _from, state) do
    case Map.get(state.guilds, guild_id) do
      %State{ready: true, udp_socket: socket, secret_key: key, encryption_mode: mode}
      when not is_nil(socket) ->
        result = Audio.listen(socket, key, mode, count)
        {:reply, result, state}

      _ ->
        {:reply, [], state}
    end
  end

  @impl true
  def handle_cast({:voice_state_update, guild_id, session_id, channel_id}, state) do
    Logger.debug(
      "voice_state_update received: guild=#{guild_id} session_id=#{session_id} channel_id=#{inspect(channel_id)}"
    )

    case Map.get(state.guilds, guild_id) do
      nil ->
        Logger.warning("voice_state_update: guild #{guild_id} not in voice state map, ignoring")
        {:noreply, state}

      %State{} = voice_state when is_nil(channel_id) ->
        maybe_restart_after_channel_drop(guild_id, voice_state)

        new_vs =
          voice_state
          |> reset_runtime_state()
          |> Map.put(:session_id, session_id)

        {:noreply, put_in(state, [:guilds, guild_id], new_vs)}

      voice_state ->
        new_vs =
          if voice_state.session_id == session_id and voice_state.channel_id == channel_id do
            %{voice_state | session_id: session_id, channel_id: channel_id}
          else
            voice_state
            |> reset_runtime_state()
            |> Map.merge(%{session_id: session_id, channel_id: channel_id})
          end

        new_state = put_in(state, [:guilds, guild_id], new_vs)
        maybe_start_session(guild_id, new_vs)
        {:noreply, new_state}
    end
  end

  def handle_cast({:voice_server_update, guild_id, token, endpoint}, state) do
    Logger.debug(
      "voice_server_update received: guild=#{guild_id} endpoint=#{endpoint} token=#{if token, do: String.slice(token, 0..7) <> "...", else: "nil"}"
    )

    case Map.get(state.guilds, guild_id) do
      nil ->
        Logger.warning("voice_server_update: guild #{guild_id} not in voice state map, ignoring")
        {:noreply, state}

      voice_state ->
        new_vs =
          if voice_state.token == token and voice_state.endpoint == endpoint do
            %{voice_state | token: token, endpoint: endpoint}
          else
            voice_state
            |> reset_runtime_state()
            |> Map.merge(%{token: token, endpoint: endpoint})
          end

        new_state = put_in(state, [:guilds, guild_id], new_vs)
        maybe_start_session(guild_id, new_vs)
        {:noreply, new_state}
    end
  end

  def handle_cast({:voice_ready, guild_id, session_state}, state) do
    case Map.get(state.guilds, guild_id) do
      nil ->
        {:noreply, state}

      voice_state ->
        new_vs = %{
          voice_state
          | ready: true,
            ssrc: session_state.ssrc,
            secret_key: session_state.secret_key,
            encryption_mode: session_state.encryption_mode,
            udp_socket: session_state.udp_socket,
            dave_manager: session_state.dave_manager,
            ip: session_state.ip,
            port: session_state.port,
            restart_count: 0
        }

        {:noreply, put_in(state, [:guilds, guild_id], new_vs)}
    end
  end

  def handle_cast({:voice_disconnected, guild_id}, state) do
    case Map.get(state.guilds, guild_id) do
      nil ->
        {:noreply, state}

      voice_state ->
        if voice_state.audio_pid, do: Process.exit(voice_state.audio_pid, :kill)

        # Clear ALL connection fields so maybe_start_session won't re-trigger.
        # Also clear channel_id to reflect actual disconnected state.
        new_vs = %{
          voice_state
          | ready: false,
            channel_id: nil,
            secret_key: nil,
            udp_socket: nil,
            session_id: nil,
            token: nil,
            endpoint: nil,
            ssrc: nil,
            audio_pid: nil,
            listening: false
        }

        Audio.clear_playback_progress(guild_id)
        {:noreply, put_in(state, [:guilds, guild_id], new_vs)}
    end
  end

  @max_restart_attempts 3

  def handle_cast({:restart_session, guild_id}, state) do
    case Map.get(state.guilds, guild_id) do
      nil ->
        {:noreply, state}

      %State{restart_count: count} when count >= @max_restart_attempts ->
        Logger.error("Voice session for guild #{guild_id} failed #{count} times, giving up")

        {:noreply, %{state | guilds: Map.delete(state.guilds, guild_id)}}

      voice_state ->
        attempt = voice_state.restart_count + 1

        Logger.info(
          "Restarting voice session for guild #{guild_id} (attempt #{attempt}/#{@max_restart_attempts})"
        )

        # Clear connection fields but keep channel_id and bump restart counter
        new_vs = %{
          voice_state
          | ready: false,
            secret_key: nil,
            udp_socket: nil,
            session_id: nil,
            token: nil,
            endpoint: nil,
            ssrc: nil,
            restart_count: attempt
        }

        # Leave voice (OP 4 with channel_id=nil)
        EDA.Gateway.Connection.update_voice_state(guild_id, nil, [])

        # Schedule rejoin after a short delay to let Discord process the leave
        Process.send_after(self(), {:rejoin_voice, guild_id, voice_state.channel_id}, 500)

        {:noreply, put_in(state, [:guilds, guild_id], new_vs)}
    end
  end

  def handle_cast({:playback_finished, guild_id, seq, ts, nonce}, state) do
    case Map.get(state.guilds, guild_id) do
      nil ->
        {:noreply, state}

      voice_state ->
        new_vs = %{voice_state | audio_pid: nil, sequence: seq, timestamp: ts, nonce: nonce}

        Audio.clear_playback_progress(guild_id)

        EDA.Gateway.Events.dispatch("VOICE_PLAYBACK_FINISHED", %{
          "guild_id" => guild_id
        })

        {:noreply, put_in(state, [:guilds, guild_id], new_vs)}
    end
  end

  def handle_cast({:set_audio_pid, guild_id, pid}, state) do
    case Map.get(state.guilds, guild_id) do
      %State{} = vs ->
        {:noreply, put_in(state, [:guilds, guild_id], %{vs | audio_pid: pid})}

      nil ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:EXIT, pid, _reason}, state) do
    # Clean up audio pid if it crashed
    new_guilds =
      Map.new(state.guilds, fn
        {gid, %State{audio_pid: ^pid} = vs} -> {gid, %{vs | audio_pid: nil}}
        entry -> entry
      end)

    {:noreply, %{state | guilds: new_guilds}}
  end

  def handle_info({:rejoin_voice, guild_id, channel_id}, state) do
    case Map.get(state.guilds, guild_id) do
      nil ->
        {:noreply, state}

      _voice_state ->
        Logger.info("Rejoining voice channel #{channel_id} in guild #{guild_id}")
        EDA.Gateway.Connection.update_voice_state(guild_id, channel_id, [])
        {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Private

  defp maybe_restart_after_channel_drop(_guild_id, %State{channel_id: nil}), do: :ok

  defp maybe_restart_after_channel_drop(guild_id, %State{restart_count: count}) when count > 0 do
    Logger.debug(
      "voice_state_update: guild #{guild_id} already restarting after channel drop, skipping duplicate trigger"
    )

    :ok
  end

  defp maybe_restart_after_channel_drop(guild_id, %State{channel_id: channel_id}) do
    Logger.warning(
      "voice_state_update: bot disconnected from channel #{channel_id} in guild #{guild_id}, scheduling voice restart"
    )

    GenServer.cast(__MODULE__, {:restart_session, guild_id})
  end

  defp maybe_start_session(guild_id, %State{
         session_id: sid,
         token: tok,
         endpoint: ep,
         channel_id: cid
       })
       when not is_nil(sid) and not is_nil(tok) and not is_nil(ep) and not is_nil(cid) do
    # Don't start a second session if one already exists
    case Registry.lookup(EDA.Voice.Registry, {:session, guild_id}) do
      [{_pid, _}] ->
        Logger.debug("Voice session already running for guild #{guild_id}, skipping")

      [] ->
        Logger.info("Starting voice session for guild #{guild_id}")
        Logger.debug("Voice IDENTIFY will use session_id=#{sid} endpoint=#{ep}")

        opts = [
          guild_id: guild_id,
          channel_id: cid,
          session_id: sid,
          token: tok,
          endpoint: ep
        ]

        case DynamicSupervisor.start_child(EDA.Voice.DynamicSupervisor, {Session, opts}) do
          {:ok, pid} ->
            Logger.info("Voice session started for guild #{guild_id}: #{inspect(pid)}")

          {:error, reason} ->
            Logger.error(
              "Failed to start voice session for guild #{guild_id}: #{inspect(reason)}"
            )
        end
    end
  end

  defp maybe_start_session(guild_id, %State{} = vs) do
    Logger.debug(
      "maybe_start_session: not ready for guild #{guild_id} — " <>
        "session_id=#{inspect(vs.session_id != nil)} " <>
        "token=#{inspect(vs.token != nil)} " <>
        "endpoint=#{inspect(vs.endpoint != nil)} " <>
        "channel_id=#{inspect(vs.channel_id != nil)}"
    )
  end

  defp maybe_start_session(_guild_id, _state), do: :ok

  defp reset_runtime_state(%State{} = voice_state) do
    terminate_voice_session(voice_state.guild_id)

    if voice_state.audio_pid, do: Process.exit(voice_state.audio_pid, :kill)
    if voice_state.udp_socket, do: :gen_udp.close(voice_state.udp_socket)

    %{
      voice_state
      | ready: false,
        secret_key: nil,
        udp_socket: nil,
        ssrc: nil,
        dave_manager: nil,
        encryption_mode: nil,
        ip: nil,
        port: nil,
        audio_pid: nil,
        listening: false
    }
  end

  defp session_alive?(guild_id) do
    Registry.lookup(EDA.Voice.Registry, {:session, guild_id}) != []
  end

  defp voice_crypto_ready?(%State{dave_manager: %Dave.Manager{} = manager}) do
    Dave.Manager.ready?(manager)
  end

  defp voice_crypto_ready?(%State{}), do: true

  defp cleanup_voice(guild_id, voice_state) do
    if voice_state.audio_pid, do: Process.exit(voice_state.audio_pid, :kill)

    if voice_state.udp_socket do
      :gen_udp.close(voice_state.udp_socket)
    end

    Audio.clear_playback_progress(guild_id)
    terminate_voice_session(guild_id)
  end

  defp terminate_voice_session(guild_id) do
    case Registry.lookup(EDA.Voice.Registry, {:session, guild_id}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(EDA.Voice.DynamicSupervisor, pid)
      [] -> :ok
    end
  end

  defp sync_playback_progress(%State{} = voice_state, guild_id) do
    case Audio.playback_progress(guild_id) do
      {:ok, {seq, ts, nonce}} ->
        %{voice_state | sequence: seq, timestamp: ts, nonce: nonce}

      :error ->
        voice_state
    end
  end
end
