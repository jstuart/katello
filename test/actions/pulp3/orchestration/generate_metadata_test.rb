require 'katello_test_helper'

module ::Actions::Pulp3
  class GenerateMetadataTest < ActiveSupport::TestCase
    include Katello::Pulp3Support

    def setup
      @master = FactoryBot.create(:smart_proxy, :default_smart_proxy, :with_pulp3)
      @repo = katello_repositories(:generic_file)
      @repo.root.update_attributes(:url => 'http://test/test/')
      ensure_creatable(@repo, @master)
      create_repo(@repo, @master)
    end

    def teardown
      ForemanTasks.sync_task(
          ::Actions::Pulp3::Orchestration::Repository::Delete, @repo, @master)
      @repo.reload
    end

    def test_generate_metadata
      refute @repo.version_href

      ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::GenerateMetadata, @repo, @master, repository_creation: true)
      @repo.reload

      assert @repo.version_href
      assert @repo.publication_href
    end

    def test_generate_with_source_repo
      ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::GenerateMetadata, @repo, @master, repository_creation: true)
      @repo.reload
      @clone = katello_repositories(:generic_file_dev)
      assert_equal 1, Katello::Pulp3::DistributionReference.where(root_repository_id: @clone.root.id).count
      ensure_creatable(@clone, @master)
      ForemanTasks.sync_task(::Actions::Pulp3::Orchestration::Repository::GenerateMetadata, @clone, @master, source_repository: @repo)
      assert_equal @repo.publication_href, @clone.publication_href
      assert_equal 2, Katello::Pulp3::DistributionReference.where(root_repository_id: @clone.root.id).count
    end
  end
end
