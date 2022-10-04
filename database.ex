defmodule Database do
  use GenServer

  @moduledoc """
   1. Create a User struct with the following parameters: [username, password, email, sex,
   is_logged_in] `is_logged_in` is telling us whether the User is logged in ot not.
  2. Write a GenServer called Database that holds Users which exposes the following functionality:
    a) Add new User (here we mean a struct User) to the GenServer (Database).
    If there is already a User with the same email/username, return an error.
    b) Be able to login as a User. The function should take a username and password as parameters.
    When a User logs in his state should show that he is logged in.
    c) You cannot log in with more than one user at a time.
    You should not be able to login as UserB if UserA is already logged in.
    d) Be able to delete a User by providing a username.
    e) Be able to change a password for a User by providing a username,
    current password and new password. Change password can only be called from a logged in User.
    You shouldn't be able to change a password to a User that is not logged in.
    f) Be able to logout.
    g) Be able to show all users in the database.

  3. The GenServer should expose the following client functions:
    - create/1 (takes a User struct)
    - login/2 (takes a username and password) -az
    - logout/1 (takes a username)
    - change_password/3 (takes a username, current_password, new_password) - az
    - delete/1 (takes a username)
    - show/0 (returns all Users in the database) - az
  """
  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # Client side

  def create(user) do
    GenServer.call(__MODULE__, {:create, %User{} = user})
  end

  def login(username, password) do
    GenServer.call(__MODULE__, {:login, username, password})
  end

  def logout(username) do
    GenServer.call(__MODULE__, {:logout, username})
  end

  def change_password(username, current_password, new_password) do
    GenServer.call(__MODULE__, {:change_password, username, current_password, new_password})
  end

  def delete(username) do
    GenServer.call(__MODULE__, {:delete, username})
  end

  def show() do
    GenServer.call(__MODULE__, :show)
  end

  # Server side

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:create, %User{} = user}, _from, state) do
    is_username_in_db = Map.has_key?(state, user.username)

    is_email_in_db =
      Map.values(state)
      |> Enum.map(fn n -> n.email end)
      |> Enum.member?(user.email)

    if is_username_in_db or is_email_in_db do
      {:reply, :error, state}
    else
      renewed_state = Map.put_new(state, user.username, user)
      {:reply, renewed_state, renewed_state}
    end
  end

  @impl true
  def handle_call({:login, username, password}, _from, state) do
    # връща list от структури, които представляват всички регистрирани потребители в нашата база данни
    all_users_in_db = Map.values(state)

    is_any_user_logged_in =
      Enum.map(all_users_in_db, fn n -> n.is_logged_in end)
      |> Enum.any?()

    if is_any_user_logged_in do
      logged_in_user_username =
        Enum.map(all_users_in_db, fn n ->
          if n.is_logged_in == true do
            n.username
          end
        end)

      {:reply,
       "User #{List.first(logged_in_user_username)} already logged in! Please logout first!",
       state}
    else
      # # върща list
      # all_usernames_in_db = Enum.map(all_users_in_db, fn n -> n.username end)
      # is_username_in_db = Enum.any?(all_usernames_in_db, fn x -> x === username end)

      is_username_in_db = Map.has_key?(state, username)

      # проверка дали има потребител с такива потребителско име и парола
      if is_username_in_db do
        # взима потребителя с конкретното потребителско име и го слага в списък

        # може да е само user_in_question_struct = state[username]
        user_in_question_struct =
          Enum.filter(all_users_in_db, fn n -> n.username === username end)
          |> List.first()

        this_usernames_password = user_in_question_struct.password

        # връща boolean с резултата дали подадената парола за това потребителско име съвпада с паролата за същото от базата данни
        is_password_correct = this_usernames_password === password

        if is_password_correct do
          # тук трябва да бръкна в базата данни, да порменя статуса за логнатост и да върна обновената база данни

          modified_state =
            Map.update!(state, username, fn existing_value ->
              %User{existing_value | is_logged_in: true}
            end)

          {:reply, "#{username} is now logged in!", modified_state}
        else
          {:reply, "#{username}, you've entered an incorrect password!", state}
        end
      else
        {:reply, "User with such username does not exist!", state}
      end
    end
  end

  @impl true
  def handle_call({:logout, username}, _from, state) when is_map_key(state, username) do
    # искаме да видим дали някой потребител е логнат, за да се сравни неговото потр. име с подаденото като параметър
    logged_in_user =
      Map.values(state)
      |> Enum.filter(fn n -> n.is_logged_in == true end)
      |> List.first()

    is_any_user_logged_in = logged_in_user != nil

    if is_any_user_logged_in do
      if logged_in_user.username === username do
        updated_state =
          Map.get_and_update(state, username, fn current_value ->
            {current_value, %User{current_value | is_logged_in: false}}
          end)
          |> elem(1)

        {:reply, "User #{username} has been logged out successfully!", updated_state}
      else
        {:reply,
         "Currently #{logged_in_user.username} is logged in! #{username}, please login first!",
         state}
      end
    else
      {:reply, "No user logged in! Please login to logout!", state}
    end
  end

  @impl true
  def handle_call({:logout, _username}, _from, state) do
    # проверка дали има потребител с такова потребителско име
    {:reply, "No such user in the database!", state}
  end

  @impl true
  def handle_call({:change_password, username, current_password, new_password}, _from, state)
      when is_map_key(state, username) do
    user_in_db = Map.get(state, username)

    is_user_logged_in = user_in_db.is_logged_in

    if is_user_logged_in do
      if user_in_db.password == current_password do
        updated_state =
          Map.get_and_update(state, username, fn current_value ->
            {current_value, %User{current_value | password: new_password}}
          end)
          |> elem(1)

        {:reply, "#{username}'s password changed successfully!", updated_state}
      else
        {:reply, "Invalid current password!", state}
      end
    else
      {:reply, "#{username} is logged out! Please login first!", state}
    end
  end

  @impl true
  def handle_call({:change_password, username, _current_password, _new_password}, _from, state) do
    # проверка дали има потребител с такова потребителско име
    {:reply, "Username #{username} does not exist! Please enter a valid username!", state}
  end

  @impl true
  def handle_call({:delete, username}, _from, state) when is_map_key(state, username) do
    updated_state = Map.delete(state, username)
    {:reply, "User '#{username}' has been deleted!", updated_state}
  end

  @impl true
  def handle_call({:delete, username}, _from, state) do
    {:reply, "User '#{username}' does not exist!", state}
  end

  @impl true
  def handle_call(:show, _from, state) do
    {:reply, state, state}
  end
end
