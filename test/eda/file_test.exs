defmodule EDA.FileTest do
  use ExUnit.Case, async: true

  alias EDA.File, as: F

  describe "from_binary/2,3" do
    test "creates a file struct" do
      file = F.from_binary("hello", "test.txt")

      assert file.name == "test.txt"
      assert file.data == "hello"
      assert file.description == nil
      assert file.spoiler == false
    end

    test "with description and spoiler" do
      file = F.from_binary("data", "img.png", description: "Alt text", spoiler: true)

      assert file.description == "Alt text"
      assert file.spoiler == true
    end

    test "raises on empty name" do
      assert_raise ArgumentError, ~r/cannot be empty/, fn ->
        F.from_binary("data", "")
      end
    end

    test "raises on name exceeding 260 characters" do
      long_name = String.duplicate("a", 261)

      assert_raise ArgumentError, ~r/exceeds 260/, fn ->
        F.from_binary("data", long_name)
      end
    end

    test "raises on description exceeding 1024 characters" do
      long_desc = String.duplicate("a", 1025)

      assert_raise ArgumentError, ~r/exceeds 1024/, fn ->
        F.from_binary("data", "test.txt", description: long_desc)
      end
    end
  end

  describe "from_path/1,2" do
    test "reads file and extracts name from path" do
      path = Path.join(System.tmp_dir!(), "eda_test_#{:rand.uniform(100_000)}.txt")
      File.write!(path, "file content")

      on_exit(fn -> File.rm(path) end)

      file = F.from_path(path)

      assert file.data == "file content"
      assert file.name == Path.basename(path)
    end

    test "allows overriding name" do
      path = Path.join(System.tmp_dir!(), "eda_test_#{:rand.uniform(100_000)}.txt")
      File.write!(path, "data")

      on_exit(fn -> File.rm(path) end)

      file = F.from_path(path, name: "custom.txt")
      assert file.name == "custom.txt"
    end

    test "raises on non-existent file" do
      assert_raise ArgumentError, ~r/does not exist/, fn ->
        F.from_path("/nonexistent/file.txt")
      end
    end
  end

  describe "effective_name/1" do
    test "returns name when not spoiler" do
      file = F.from_binary("data", "image.png")
      assert F.effective_name(file) == "image.png"
    end

    test "a spoiler keeps its name — the blur is asked for with is_spoiler" do
      file = F.from_binary("data", "image.png", spoiler: true)
      assert F.effective_name(file) == "image.png"
    end

    test "a name the caller prefixed itself is passed through" do
      file = F.from_binary("data", "SPOILER_image.png")
      assert F.effective_name(file) == "SPOILER_image.png"
    end
  end
end
