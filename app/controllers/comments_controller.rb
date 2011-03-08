# The CommentController can handle comments on polymorphic 'commentables'
# REVIEW: The code to handle comments with different levels of commentable SMELLS!
class CommentsController < ApplicationController
    
  respond_to :html, :xml, :js
  
  load_and_authorize_resource :except => [:edit,:update]
  before_filter :load_commentable
      
  def index
    @comments = Comment.desc if can? :read, Comment
  end
  
  def create
    if can? :create, Comment
      @comment, errors = Comment::build_and_validate_comment(@commentable,params[:comment])    
      if errors
        flash[:error] = t(:comment_could_not_be_saved, :errors => errors).html_safe
      else
        remember_comment
      end
      notice = nil
    else
      notice = t(:access_denied)
    end
    redirect_to view_context.commentable_show_path(@commentable), :alert => notice  
  end
  
  def edit
    @comment = Comment.find(params[:id])
    if can? :edit, @comment, session[:comments]
      respond_to do |format|
        format.js
        format.html
      end
    else
      redirect_to view_context.commentable_show_path(@comment.commentable), :alert => t(:not_authorized)
    end
  end
  
  def update
    @comment = Comment.find(params[:id])
    if can? :edit, @comment, session[:comments]
      
      unless params[:commit] == t(:cancel)
        @comment.comment = params[:comment][:comment]
        remember_comment
        @comment.save
      end
      @new_comment = (RedCloth.new(@comment.comment).to_html.html_safe)
      respond_to do |format|
        format.js
        format.html { redirect_to view_context.commentable_show_path(@commentable), :notice => t(:comment_successfully_updated).html_safe }
      end
    else
      redirect_to view_context.commentable_show_path(@comment.commentable), :alert => t(:not_authorized)
    end
  end
  
  def destroy
    @commentable ||= @comment.commentable
    @comment.destroy
    @commentable.save
    respond_to do |format|
      format.js
      format.html { redirect_to view_context.commentable_show_path(@commentable), :notice => t(:comment_successfully_destroyed).html_safe }
    end
  end
  
  
  private
  def load_commentable    
    return @commentable if @commentable
    params.each do |name, value|
      if name =~ /(.+)_id$/
        @commentable = $1.classify.constantize.find(value)
        break
      end
    end
    @commentable
  end
  
  
  # Save comment_ids with timestamps in session[:comments]
  # Will be used in Ability.rb to check if comment can be edited.
  def remember_comment
    session[:comments] = @comment.update_session_comments(session[:comments])
  end
  
end