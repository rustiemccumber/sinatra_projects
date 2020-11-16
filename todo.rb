require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do 
  def list_complete?(list)
    list[:todos].size > 0 && list[:todos].all? { |todo| todo[:completed] } 
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def fraction_complete(list)
     "#{list[:todos].count {|todo| !todo[:completed] }} / #{list[:todos].size}"
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list)}

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

def load_list(id)
  list = session[:lists].find{ |list| list[:id] == id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# Return an error message if the name is invalid.  Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'list name must be between 1 and 100 characters'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

# Return an error message if the todo is invalid. Return nil if the name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters'
  end
end

def next_element_id(elements)
  max = elements.map { |element| element[:id] }.max || 0
  max + 1
end


before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created'
    redirect '/lists'
  end
end

#View a single todo list
get '/lists/:number' do 
  @list_number = params[:number].to_i
  @list = load_list(@list_number)
  erb :specific_todo, layout: :layout
end 

#Edit an exisiting todo list
get '/lists/:number/edit' do 
  @number = params[:number].to_i
  @list = load_list(@number)
  erb :edit_list, layout: :layout
end

#update an existing todo list
post '/lists/:number' do
  list_name = params[:todo_name].strip
  list_number = params[:number].to_i
  @list = load_list(list_number)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated'
    redirect "/lists/#{list_number}"
  end
end


# Delete a todo list
post '/lists/:number/delete' do
  list_number = params[:number].to_i

  session[:lists].reject! { |list| list[:id] == list_number }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "the todo has been deleted"
    redirect "/lists"
  end
end

# Add a new todo to a list
post "/lists/:number/todos" do
  @list_number = params[:number].to_i
  @list = load_list(@list_number)
  text = params[:todo].strip

  error  = error_for_todo(text)
  if error
    session[:error] = error
    erb :specific_todo, layout: :layout
  else
    
    id = next_element_id(@list[:todos]) # refine this later
    @list[:todos] << { id: id, name: text, completed: false}

    session[:success] = "the todo was added."
    redirect "/lists/#{@list_number}"
  end
end

#delete a todo from a list 
post '/lists/:number/todos/:todo_id/delete' do
  @list_number = params[:number].to_i
  @list = load_list(@list_number)
  
  todo_number = params[:todo_id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_number }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204 
  else
    session[:success] = "the todo has been updated"
    redirect "/lists/#{@list_number}"
  end
end

#update the status of a todo
post "/lists/:number/todos/:todo_id" do
  @list_number = params[:number].to_i
  @list = load_list(@list_number)
  
  todo_number = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_number }
  todo[:completed] = is_completed

  session[:success] = "the todo has been updated"
  redirect "/lists/#{@list_number}"
end

# Mark all todos as complete for a list
post "/lists/:number/complete_all" do
  @list_number = params[:number].to_i
  @list = load_list(@list_number)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  
  session[:success] = "All todos have been completed"
  redirect "/lists/#{@list_number}"
end