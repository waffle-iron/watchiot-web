##
# Faq model
#
class CreateFaqs < ActiveRecord::Migration
  def change
    create_table :faqs do |t|
      t.string :lang, default: 'en'
      t.string :question
      t.text :answer
    end
  end
end
