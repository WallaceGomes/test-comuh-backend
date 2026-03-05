class CreateCommunities < ActiveRecord::Migration[8.0]
  def change
    create_table :communities do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
    add_index :communities, :name, unique: true
  end
end
