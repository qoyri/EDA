defmodule EDA.AutoDeleteTest do
  use ExUnit.Case

  alias EDA.AutoDelete

  describe "schedule/3" do
    test "nil delay is a no-op" do
      assert :ok = AutoDelete.schedule("ch1", "msg1", nil)
    end

    test "schedules deletion (GenServer accepts the cast)" do
      assert :ok = AutoDelete.schedule("ch1", "msg1", 60_000)
    end

    test "zero delay is accepted" do
      assert :ok = AutoDelete.schedule("ch1", "msg1", 0)
    end
  end
end
