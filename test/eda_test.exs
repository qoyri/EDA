defmodule EdaTest do
  use ExUnit.Case

  test "token/0 returns configured token" do
    Application.put_env(:eda, :token, "test_token")
    assert EDA.token() == "test_token"
    Application.put_env(:eda, :token, nil)
  end

  test "consumer/0 returns configured consumer" do
    Application.put_env(:eda, :consumer, MyFakeConsumer)
    assert EDA.consumer() == MyFakeConsumer
    Application.delete_env(:eda, :consumer)
  end

  test "consumer/0 returns nil when not configured" do
    Application.delete_env(:eda, :consumer)
    assert EDA.consumer() == nil
  end
end
