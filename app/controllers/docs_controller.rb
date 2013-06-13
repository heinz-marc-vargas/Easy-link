class DocsController < ApplicationController
  before_filter :authenticate_user!
end
