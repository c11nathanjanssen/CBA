require 'test_helper'

class LegislatorsControllerTest < ActionController::TestCase

  setup do
    @legislator = Fabricate(:rep)
    Fabricate(:oh) # needed to get
    User.delete_all
    @user = Fabricate(:user)
    @request.env['devise.mapping'] = :user
    @user.confirm!
    sign_in @user
    SiteMenu.destroy_all
    SiteMenu.create(:name => Faker::Lorem.words(4), :target => Faker::Lorem.words(1), :info => Faker::Company.bs)
    SiteMenu.create(:name => Faker::Lorem.words(4), :target => Faker::Lorem.words(1), :info => Faker::Company.bs)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:legislators)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

#  test "should create legislator" do
#    assert_difference('Legislator.count') do
#      post :create, :legislator => @legislator.attributes
#    end
#
#    assert_redirected_to legislator_path(assigns(:legislator))
#  end

  test "should show legislator" do
    get :show, :id => @legislator.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @legislator.to_param
    assert_response :success
  end

  test "should update legislator" do
    put :update, :id => @legislator.to_param, :legislator => @legislator.attributes
    assert_redirected_to legislator_path(assigns(:legislator))
  end

  test "should destroy legislator" do
    assert_difference('Legislator.count', -1) do
      delete :destroy, :id => @legislator.to_param
    end

    assert_redirected_to legislators_path
  end
end
