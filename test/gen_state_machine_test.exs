defmodule GenStateMachineTest do
  use ExUnit.Case

  defmodule EventFunctionSwitch do
    use GenStateMachine

    def handle_event(:cast, :flip, :off, data) do
      {:next_state, :on, data + 1}
    end

    def handle_event(:cast, :flip, :on, data) do
      {:next_state, :off, data}
    end

    def handle_event({:call, from}, :get_count, state, data) do
      {:next_state, state, data, [{:reply, from, data}]}
    end
  end

  test "start_link/2, call/2 and cast/2" do
    {:ok, pid} = GenStateMachine.start_link(EventFunctionSwitch, {:off, 0})

    {:links, links} = Process.info(self(), :links)
    assert pid in links

    assert GenStateMachine.cast(pid, :flip) == :ok
    assert GenStateMachine.cast(pid, :flip) == :ok
    assert GenStateMachine.call(pid, :get_count) == 1
    assert GenStateMachine.stop(pid) == :ok

    assert GenStateMachine.cast({:global, :foo}, {:push, :world}) == :ok
    assert GenStateMachine.cast({:via, :foo, :bar}, {:push, :world}) == :ok
    assert GenStateMachine.cast(:foo, {:push, :world}) == :ok
  end

  defmodule StateFunctionsSwitch do
    use GenStateMachine, callback_mode: :state_functions

    def off(:cast, :flip, data) do
      {:next_state, :on, data + 1}
    end

    def off(event_type, event_content, data) do
      handle_event(event_type, event_content, data)
    end

    def on(:cast, :flip, data) do
      {:next_state, :off, data}
    end

    def on(event_type, event_content, data) do
      handle_event(event_type, event_content, data)
    end

    def handle_event({:call, from}, :get_count, data) do
      {:keep_state_and_data, [{:reply, from, data}]}
    end
  end

  test "start_link/2, call/2 and cast/2 for state_functions" do
    {:ok, pid} = GenStateMachine.start_link(StateFunctionsSwitch, {:off, 0})

    {:links, links} = Process.info(self(), :links)
    assert pid in links

    assert GenStateMachine.cast(pid, :flip) == :ok
    assert GenStateMachine.cast(pid, :flip) == :ok
    assert GenStateMachine.call(pid, :get_count) == 1
    assert GenStateMachine.stop(pid) == :ok

    assert GenStateMachine.cast({:global, :foo}, {:push, :world}) == :ok
    assert GenStateMachine.cast({:via, :foo, :bar}, {:push, :world}) == :ok
    assert GenStateMachine.cast(:foo, {:push, :world}) == :ok
  end

  test "start/2" do
    {:ok, pid} = GenStateMachine.start(EventFunctionSwitch, {:off, 0})
    {:links, links} = Process.info(self(), :links)
    refute pid in links
    GenStateMachine.stop(pid)
  end

  test "stop/3" do
    {:ok, pid} = GenStateMachine.start(EventFunctionSwitch, {:off, 0})
    assert GenStateMachine.stop(pid, :normal) == :ok

    {:ok, _} = GenStateMachine.start(EventFunctionSwitch, {:off, 0}, name: :stack)
    assert GenStateMachine.stop(:stack, :normal) == :ok
  end

  defmodule BadInit1 do
    use GenStateMachine

    def init(_args) do
      {:handle_event_function, nil, nil}
    end
  end

  defmodule BadInit2 do
    use GenStateMachine

    def init(_args) do
      {:state_functions, nil, nil}
    end
  end

  test "init/1 should not allow callback mode in return" do
    result = GenStateMachine.start(BadInit1, nil)

    assert result in [
             {:error, {:bad_return_value, {:handle_event_function, nil, nil}}},
             {:error, {:bad_return_from_init, {:handle_event_function, nil, nil}}}
           ]

    result = GenStateMachine.start(BadInit2, nil)

    assert result in [
             {:error, {:bad_return_value, {:state_functions, nil, nil}}},
             {:error, {:bad_return_from_init, {:state_functions, nil, nil}}}
           ]
  end

  defmodule CustomChildSpec do
    use GenStateMachine,
      id: :id,
      restart: :temporary,
      shutdown: :infinity,
      start: {:foo, :bar, []}
  end

  test "child_spec/1" do
    assert EventFunctionSwitch.child_spec([:hello]) == %{
             id: EventFunctionSwitch,
             start: {EventFunctionSwitch, :start_link, [[:hello]]}
           }

    assert CustomChildSpec.child_spec([:hello]) == %{
             id: :id,
             restart: :temporary,
             shutdown: :infinity,
             start: {:foo, :bar, []}
           }
  end
end
