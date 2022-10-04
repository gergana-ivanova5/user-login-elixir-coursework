defmodule User do
  @enforce_keys [:username, :password, :email]
  defstruct [:username, :password, :email, sex: "unknown", is_logged_in: false]
end
