defmodule EDA.Test.DaveGateway.Native do
  @moduledoc false

  # The MLS side of a voice gateway, from native/eda_dave_test_gateway: see that crate. Built for
  # the test environment only.
  use Rustler, otp_app: :eda, crate: "eda_dave_test_gateway"

  @spec new(non_neg_integer()) :: {:ok, reference()} | {:error, String.t()}
  def new(_channel_id), do: :erlang.nif_error(:nif_not_loaded)

  @spec external_sender(reference()) :: {:ok, binary()} | {:error, String.t()}
  def external_sender(_gateway), do: :erlang.nif_error(:nif_not_loaded)

  @spec proposals(reference(), non_neg_integer(), [binary()], [non_neg_integer()]) ::
          {:ok, binary()} | {:error, String.t()}
  def proposals(_gateway, _epoch, _key_packages, _removed_leaves),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec split_commit_welcome(binary()) :: {:ok, {binary(), binary() | nil}} | {:error, String.t()}
  def split_commit_welcome(_payload), do: :erlang.nif_error(:nif_not_loaded)
end
