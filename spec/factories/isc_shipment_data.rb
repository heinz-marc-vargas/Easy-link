# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :isc_shipment_datum, :class => 'IscShipmentData' do
    order_id 1
    ship_flag "MyString"
    ext_product_id "MyString"
    qty_shipped 1
    tracking_num "MyString"
    ship_date "2012-10-30 17:37:22"
    file_name "MyString"
  end
end
