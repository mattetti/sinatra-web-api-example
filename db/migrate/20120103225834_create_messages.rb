class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.string :from
      t.string :to
      t.string :text
      t.timestamps
    end
  end

  def self.down
  end
end
