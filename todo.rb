require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
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

    incomplete_lists.each { |list| yield list, lists.index(list)}
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo)}
    complete_todos.each { |todo| yield todo, todos.index(todo)}
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET   /lists        -> view all lists
# GET   /lists/new    -> new list form
# POST  /lists        -> create new list
# GET   /lists/1      -> view a single list

# View list of lists
get '/lists' do
  @lists = session[:lists].sort_by { |list| list_complete?(list) ? 1 : 0 }
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
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

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created'
    redirect '/lists'
  end
end


get '/lists/:number' do
  @list_number = params[:number].to_i
  @list = session[:lists][@list_number]
  erb :specific_todo, layout: :layout
end 

#Edit an exisiting to do list

get '/lists/:number/edit' do 
  number = params[:number].to_i
  @list = session[:lists][number]
  erb :edit_list, layout: :layout
end

post '/lists/:number' do
  list_name = params[:todo_name].strip
  error = error_for_list_name(list_name)
  @list_number = params[:number].to_i
  @list = session[:lists][number]
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated'
    redirect "/lists/#{@list_number}"
  end
end

post '/lists/:number/delete' do
  number = params[:number].to_i
  session[:lists].delete_at(number)
  session[:success] = 'The list has been deleted'
  redirect "/lists"
end

post '/lists/:number/todos' do
  @list_number = params[:number].to_i
  @list = session[:lists][@list_number]
  text = params[:todo].strip

  error  = error_for_todo(text)
  if error
    session[:error] = error
    erb :specific_todo, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "the todo was added."
    redirect "/lists/#{@list_number}"
  end
end

#delete a todo from a list 

post '/lists/:number/todos/:todo_index/delete' do
  @list_number = params[:number].to_i
  @list = session[:lists][@list_number]
  
  todo_number = params[:todo_index].to_i
  @list[:todos].delete_at(todo_number)
  session[:success] = "the todo was deleted"
  redirect "/lists/#{@list_number}"
end

#update the status of a todo

post "/lists/:number/todos/:todo_index" do
  @list_number = params[:number].to_i
  @list = session[:lists][@list_number]
  
  todo_number = params[:todo_index].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_number][:completed] = is_completed

  session[:success] = "the todo has been updated"
  redirect "/lists/#{@list_number}"
end

# Mark all todos as complete for a list

post "/lists/:number/complete_all" do
  @list_number = params[:number].to_i
  @list = session[:lists][@list_number]
  
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  
  session[:success] = "All todos have been completed"
  redirect "/lists/#{@list_number}"
end