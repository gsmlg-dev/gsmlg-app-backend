defmodule GsmlgAppAdminWeb.ExampleLiveView do
  use GsmlgAppAdminWeb, :live_view
  import Phoenix.HTML.Form
  alias GsmlgAppAdmin.Blog.Post

  def render(assigns) do
    ~H"""
    <div>
      <div class="breadcrumbs">
        <ul>
          <li><.link navigate={~p"/"}>Home</.link></li>
          <li>Posts</li>
        </ul>
      </div>
    </div>
    <div class="flex flex-col gap-8">
      <div class="flex flex-col gap-4">
        <h3>Posts</h3>
        <table class="table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Content</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={post <- @posts}>
              <td><%= post.title %></td>
              <td><%= if Map.get(post, :content), do: post.content, else: "" %></td>
              <td><button class="btn btn-error" phx-click="delete_post" phx-value-post-id={post.id}>delete</button></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="flex flex-col gap-4">
        <h3>Create Post</h3>
        <.form :let={f} for={@create_form} as={:form} phx-submit="create_post" class="flex flex-col gap-4">
          <.input class="input-primary w-full" type="text" field={f[:title]} placeholder="input title" />
          <.button class="btn btn-primary" type="submit">create</.button>
        </.form>
      </div>
      <div class="flex flex-col gap-4">
        <h3>Update Post</h3>
        <.form :let={f} for={@update_form} as={:form} phx-submit="update_post" class="flex flex-col gap-4">
          <.input field={f[:post_id]} type="select" options={@post_selector} />
          <.input class="textarea-secondary w-full" type="textarea" field={f[:content]} placeholder="input content" />
          <.button class="btn btn-primary" type="submit">update</.button>
        </.form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    posts = Post.read_all!()

    socket =
      assign(socket,
        posts: posts,
        post_selector: post_selector(posts),
        # the `to_form/1` calls below are for liveview 0.18.12+. For earlier versions, remove those calls
        create_form: AshPhoenix.Form.for_create(Post, :create) |> to_form(),
        update_form: AshPhoenix.Form.for_update(List.first(posts, %Post{}), :update) |> to_form()
      )

    {:ok, socket}
  end

  def handle_event("delete_post", %{"post-id" => post_id}, socket) do
    post_id |> Post.get_by_id!() |> Post.destroy!()
    posts = Post.read_all!()

    {:noreply, assign(socket, posts: posts, post_selector: post_selector(posts))}
  end

  def handle_event("create_post", %{"form" => %{"title" => title}}, socket) do
    IO.inspect({"create post", title})
    Post.create(%{title: title})
    IO.inspect({"create post success", title})
    posts = Post.read_all!()

    {:noreply, assign(socket, posts: posts, post_selector: post_selector(posts))}
  rescue
    e ->
      {:noreply, socket |> put_flash(:error, inspect(e))}
  end

  def handle_event("update_post", %{"form" => form_params}, socket) do
    %{"post_id" => post_id, "content" => content} = form_params

    post_id |> Post.get_by_id!() |> Post.update!(%{content: content})
    posts = Post.read_all!()

    {:noreply, assign(socket, posts: posts, post_selector: post_selector(posts))}
  end

  defp post_selector(posts) do
    for post <- posts do
      {post.title, post.id}
    end
  end
end
