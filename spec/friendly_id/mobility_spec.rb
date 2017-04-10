require 'spec_helper'

describe FriendlyId::Mobility do
  it 'has a version number' do
    expect(FriendlyId::Mobility::VERSION).not_to be nil
  end

  context "base column is untranslated" do
    describe "#friendly_id" do
      it "returns the current locale's slug" do
        journalist = Journalist.new(:name => "John Doe")
        journalist.slug_es = "juan-fulano"
        journalist.valid?
        I18n.with_locale(I18n.default_locale) do
          expect(journalist.friendly_id).to eq("john-doe")
        end
        I18n.with_locale(:es) do
          expect(journalist.friendly_id).to eq("juan-fulano")
        end
      end
    end

    describe "generating slugs in different locales" do
      it "creates record with slug for the current locale" do
        I18n.with_locale(I18n.default_locale) do
          journalist = Journalist.new(name: "John Doe")
          journalist.valid?
          expect(journalist.slug_en).to eq("john-doe")
          expect(journalist.slug_es).to be_nil
        end

        I18n.with_locale(:es) do
          journalist = Journalist.new(name: "John Doe")
          journalist.valid?
          expect(journalist.slug_es).to eq("john-doe")
          expect(journalist.slug_en).to be_nil
        end
      end
    end

    describe "#to_param" do
      it "returns numeric id when there is no slug for the current locale" do
        journalist = Journalist.new(name: "Juan Fulano")
        I18n.with_locale(:es) do
          journalist.save!
          journalist.to_param
          expect(journalist.to_param).to eq("juan-fulano")
        end
        expect(journalist.to_param).to eq(journalist.id.to_s)
      end
    end

    describe "#set_friendly_id" do
      it "sets friendly id for locale" do
        journalist = Journalist.create!(name: "John Smith")
        journalist.set_friendly_id("Juan Fulano", :es)
        journalist.save!
        expect(journalist.slug_es).to eq("juan-fulano")
        I18n.with_locale(:es) do
          expect(journalist.to_param).to eq("juan-fulano")
        end
      end

      it "should fall back to default locale when none is given" do
        journalist = I18n.with_locale(:es) do
          Journalist.create!(name: "Juan Fulano")
        end
        journalist.set_friendly_id("John Doe")
        journalist.save!
        expect(journalist.slug_en).to eq("john-doe")
      end

      it "sequences localized slugs" do
        journalist = Journalist.create!(name: "John Smith")
        I18n.with_locale(:es) do
          Journalist.create!(name: "Juan Fulano")
        end
        journalist.set_friendly_id("Juan Fulano", :es)
        journalist.save!

        aggregate_failures do
          expect(journalist.to_param).to eq("john-smith")
          I18n.with_locale(:es) do
            expect(journalist.to_param).to match(/juan-fulano-.+/)
          end
        end
      end
    end

    describe ".friendly" do
      it "finds record by slug in current locale" do
        john = Journalist.create!(name: "John Smith")
        juan = I18n.with_locale(:es) { Journalist.create!(name: "Juan Fulano") }

        aggregate_failures do 
          expect(Journalist.friendly.find("john-smith")).to eq(john)
          expect {
            Journalist.friendly.find("juan-fulano")
          }.to raise_error(ActiveRecord::RecordNotFound)

          I18n.with_locale(:es) do
            expect(Journalist.friendly.find("juan-fulano")).to eq(juan)
            expect { Journalist.friendly.find("john-smith") }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end

  context "base column is translated" do
    describe "#friendly_id" do
      it "sets friendly_id from base column in each locale" do
        article = Article.create!(:title => "War and Peace")
        I18n.with_locale(:'es-MX') { article.title = "Guerra y paz" }
        article.save!
        article = Article.first

        aggregate_failures do
          I18n.with_locale(:'es-MX') { expect(article.friendly_id).to eq("guerra-y-paz") }
          I18n.with_locale(:en) { expect(article.friendly_id).to eq("war-and-peace") }
        end
      end
    end
  end

  describe "history" do
    describe "base features" do
      it "inserts record in slugs table on create" do
        post = Post.create!(title: "foo title", content: "once upon a time...")
        expect(post.slugs.any?).to eq(true)
      end

      it "does not create new slug record if friendly_id is not changed" do
        post = Post.create(published: true)
        post.published = false
        post.save!
        expect(FriendlyId::Slug.count).to eq(1)
      end

      it "creates new slug record when friendly_id changes" do
        post = Post.create(title: "foo title")
        post.title = post.title + " 2"
        post.slug = nil
        post.save!
        expect(FriendlyId::Slug.count).to eq(2)
      end

      it "is findable by old slugs" do
        post = Post.create(title: "foo title")
        old_friendly_id = post.friendly_id
        post.title = post.title + " 2"
        post.slug = nil
        post.save!
        expect(Post.friendly.find(old_friendly_id)).to eq(post)
        expect(Post.friendly.exists?(old_friendly_id))
      end

      it "creates slug records on each change" do
        post = Post.create! title: "hello"
        expect(FriendlyId::Slug.count).to eq(1)
        post = Post.friendly.find("hello")
        post.title = "hello again"
        post.slug = nil
        post.save!
        expect(FriendlyId::Slug.count).to eq(2)
      end
    end

    describe "translations" do
      it "stores locale on slugs" do
        expect {
          Post.create(title: "Foo Title")
        }.to change(FriendlyId::Slug, :count).by(1)
        post = Post.first
        slug = post.slugs.first

        aggregate_failures do
          expect(slug.slug).to eq("foo-title")
          expect(slug.locale).to eq("en")
        end

        expect {
          Mobility.with_locale(:fr) do
            post.title = "Foo Titre"
            post.save!
          end
        }.to change(FriendlyId::Slug.unscoped, :count).by(1)

        slug = post.slugs.find { |slug| slug.locale == "fr" }
        expect(slug.slug).to eq("foo-titre")
      end

      it "finds slug in current locale" do
        Mobility.with_locale(:'pt-BR') do
          post = Post.create!(title: "Foo Title")
          post.title = "New Title"
          post.slug = nil
          post.save!
        end

        Mobility.with_locale(:de) do
          post = Post.create!(title: "Foo Title")
          post.title = "New Title"
          post.slug = nil
          post.save!
        end

        expect { Post.friendly.find("new-title") }.to raise_error(ActiveRecord::RecordNotFound)
        expect { Post.friendly.find("foo-title") }.to raise_error(ActiveRecord::RecordNotFound)

        Mobility.with_locale(:'pt-BR') do
          expect(Post.friendly.find("foo-title")).to eq(Post.first)
          expect(Post.friendly.find("new-title")).to eq(Post.first)
        end

        Mobility.with_locale(:de) do
          expect(Post.friendly.find("foo-title")).to eq(Post.last)
          expect(Post.friendly.find("new-title")).to eq(Post.last)
        end
      end
    end
  end
end
