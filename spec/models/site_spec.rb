require 'spec_helper'

describe Site do
  
  before(:each) do
    @valid_attr = FactoryGirl.attributes_for(:site_valid)
    @invalid_attr = FactoryGirl.attributes_for(:site_invalid)
  end
  
  it "should create a new site given a valid attribute" do
    Site.create!(@valid_attr)
  end
  
  it "should not allow empty attributes of site" do
    site = Site.create(@invalid_attr)
    site.should be_invalid
  end
  
  it "should be able to update existing site" do
    site = Site.create!(@valid_attr)
    site.name = "new name"
    site.code = "newcode"
    site.url = "http://www.newexample.com"
    site.hostname = "newexample.com"
    site.save!
    site.should be_valid
  end
  
end
