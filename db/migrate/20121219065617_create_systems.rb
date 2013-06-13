class CreateSystems < ActiveRecord::Migration
  def self.up
    create_table :systems do |t|
      t.text :command_ln
      t.text :output
      t.datetime :command_ran_at
      t.timestamps
    end
  end

  def self.down
    #drop_table :systems
  end
end
