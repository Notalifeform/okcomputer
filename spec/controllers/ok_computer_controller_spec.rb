require 'rails_helper'

describe OkComputer::OkComputerController do
  module PositionalTestCaseAPI
    def get(*args, **kwargs)
      if kwargs.include?(:params)
        super(*args, kwargs[:params])
      else
        super
      end
    end
  end

  # Confused? See https://github.com/rails/rails/issues/23643
  # TLDR: This override unwraps the 'params' kwarg in these Rails 5 style specs
  # to call the old TestCase API if that's what's available (which has positional arguments)
  prepend PositionalTestCaseAPI if Rails::VERSION::MAJOR < 5


  routes { OkComputer::Engine.routes }

  before do
    # not testing authentication here
    if Rails::VERSION::MAJOR < 5
      controller.class.skip_before_filter :authenticate
    else
      controller.class.skip_before_action :authenticate, raise: false
    end
  end

  describe "GET 'index'" do
    let(:checks) do
      double(:all_checks, {
        to_text: "text of the results",
        to_json: "json of the results",
        success?: nil,
      })
    end

    before do
      OkComputer::Registry.stub(:all) { checks }
      checks.should_receive(:run)
    end

    it "performs the basic up check when format: text" do
      get :index, format: :text
      response.body.should == checks.to_text
    end

    it "performs the basic up check when format: html" do
      get :index, format: :html
      response.body.should == checks.to_text
    end

    it "performs the basic up check with accept text/html" do
      request.accept = "text/html"
      get :index
      response.body.should == checks.to_text
    end

    it "performs the basic up check with accept text/plain" do
      request.accept = "text/plain"
      get :index
      response.body.should == checks.to_text
    end

    it "performs the basic up check as JSON" do
      get :index, format: :json
      response.body.should == checks.to_json
    end

    it "performs the basic up check as JSON with accept application/json" do
      request.accept = "application/json"
      get :index
      response.body.should == checks.to_json
    end

    it "returns a failure status code if any check fails" do
      checks.stub(:success?) { false }
      get :index, format: :text
      response.should_not be_success
    end

    it "returns a success status code if all checks pass" do
      checks.stub(:success?) { true }
      get :index, format: :text
      response.should be_success
    end
  end

  describe "GET 'show'" do
    let(:check_type) { "basic" }
    let(:check) do
      double(:single_check, {
        to_text: "text of check",
        to_json: "json of check",
        success?: nil,
      })
    end

    context "existing check-type" do
      before do
        OkComputer::Registry.should_receive(:fetch).with(check_type) { check }
        check.should_receive(:run)
      end

      it "performs the given check and returns text when format: text" do
        get :show, params: { check: check_type, format: :text }
        response.body.should == check.to_text
      end

      it "performs the given check and returns text when format: html" do
        get :show, params: { check: check_type, format: :html }
        response.body.should == check.to_text
      end

      it "performs the given check and returns text with accept text/html" do
        request.accept = "text/html"
        get :show, params: { check: check_type }
        response.body.should == check.to_text
      end

      it "performs the given check and returns text with accept text/plain" do
        request.accept = "text/plain"
        get :show, params: { check: check_type }
        response.body.should == check.to_text
      end

      it "performs the given check and returns JSON" do
        get :show, params: { check: check_type, format: :json }
        response.body.should == check.to_json
      end

      it "performs the given check and returns JSON with accept application/json" do
        request.accept = "application/json"
        get :show, params: { check: check_type }
        response.body.should == check.to_json
      end

      it "returns a success status code if the check passes" do
        check.stub(:success?) { true }
        get :show, params: { check: check_type, format: :text }
        response.should be_success
      end

      it "returns a failure status code if the check fails" do
        check.stub(:success?) { false }
        get :show, params: { check: check_type, format: :text }
        response.should_not be_success
      end
    end

    it "returns a 404 if the check does not exist" do
      get :show, params: { check: "non-existant", format: :text }
      response.body.should == "No matching check"
      response.code.should == "404"
    end

    it "returns a JSON 404 if the check does not exist" do
      get :show, params: { check: "non-existant", format: :json }
      response.body.should == { error: "No matching check" }.to_json
      response.code.should == "404"
    end

  end

  describe 'newrelic_ignore' do

    let(:load_class) do
      load OkComputer::Engine.root.join("app/controllers/ok_computer/ok_computer_controller.rb")
    end

    before do
      OkComputer.send(:remove_const, 'OkComputerController')
    end

    context "#newrelic_ignore" do

      context "when NewRelic is installed" do

        before do
          stub_const('NewRelic::Agent::Instrumentation::ControllerInstrumentation', Module.new)
        end

        context "when analytics_ignore is true" do

          before { OkComputer.stub(:analytics_ignore){ true } }

          it "should inject newrelic_ignore" do
            Module.any_instance.should_receive(:newrelic_ignore).with(no_args())
            load_class
          end
        end

        context "when analytics_ignore is false" do

          before { OkComputer.stub(:analytics_ignore){ false } }

          it "should inject newrelic_ignore" do
            Module.any_instance.should_not_receive(:newrelic_ignore)
            load_class
          end
        end
      end

      context "when NewRelic is not installed" do
        it "should not inject newrelic_ignore" do
          Module.any_instance.should_not_receive(:newrelic_ignore)
          load_class
        end
      end
    end
  end
end
