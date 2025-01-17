require "pulpcore_client"

module Katello
  module Pulp3
    class Repository
      attr_accessor :repo, :input
      attr_accessor :smart_proxy
      delegate :root, to: :repo
      delegate :pulp3_api, to: :smart_proxy

      def initialize(repo, smart_proxy)
        @repo = repo
        @smart_proxy = smart_proxy
      end

      def create_remote
        repo.update_attributes!(:remote_href => create_content_remote)
      end

      def remote_options
        common_remote_options.delete(:url)
        common_remote_options
      end

      def update_remote
        if remote_options[:url].blank?
          if repo.remote_href
            href = repo.remote_href
            repo.update_attributes(remote_href: nil)
            delete_remote href
          end
        else
          if repo.remote_href?
            remote_partial_update
          else
            create_remote
          end
        end
      end

      def sync
        fail NotImplementedError
      end

      def create_publication
        fail NotImplementedError
      end

      def delete_publication
        fail NotImplementedError
      end

      def self.instance_for_type(repo, smart_proxy)
        Katello::RepositoryTypeManager.repository_types[repo.root.content_type].pulp3_service_class.new(repo, smart_proxy)
      end

      def should_purge_empty_contents?
        false
      end

      def backend_object_name
        "#{root.label}-#{repo.id}#{rand(9999)}"
      end

      def repository_reference
        RepositoryReference.find_by(:root_repository_id => repo.root_id, :content_view_id => repo.content_view.id)
      end

      def distribution_reference(path)
        DistributionReference.find_by(:path => path)
      end

      def create
        unless repository_reference
          response = pulp3_api.repositories_create(
            name: backend_object_name)
          RepositoryReference.create!(
           root_repository_id: repo.root_id,
           content_view_id: repo.content_view.id,
           repository_href: response._href)
          response
        end
      end

      def update
        pulp3_api.repositories_update(repository_reference.repository_href, name: backend_object_name)
      end

      def list(args)
        pulp3_api.repositories_list(args).results
      end

      def delete(href = repository_reference.try(:repository_href))
        repository_reference.try(:destroy)
        if href
          response = pulp3_api.repositories_delete(href)
          response
        end
      end

      def refresh_distributions
        path = repo.relative_path.sub(/^\//, '')
        dist_ref = distribution_reference(path)
        if dist_ref
          update_distribution(path)
        else
          create_distribution(path)
        end
      end

      def create_version
        pulp3_api.repositories_versions_create(repository_reference.repository_href, {})
      end

      def save_distribution_references(hrefs)
        hrefs.each do |href|
          path = get_distribution(href)&.base_path
          unless distribution_reference(path)
            DistributionReference.create!(path: path, href: href, root_repository_id: repo.root.id)
          end
        end
      end

      def delete_distributions
        path = repo.relative_path.sub(/^\//, '')
        dists = lookup_distributions(base_path: path)
        delete_distribution(dists.first._href) if dists.first
        dist_ref = distribution_reference(path)
        dist_ref.destroy! if dist_ref
      end

      def common_remote_options
        remote_options = {
          validate: true,
          ssl_validation: root.verify_ssl_on_sync,
          name: backend_object_name,
          url: root.url
        }
        if root.upstream_username && root.upstream_password
          remote_options.merge(username: root.upstream_username,
                               password: root.upstream_password)
        end
        remote_options.merge(ssl_remote_options)
      end

      def ssl_remote_options
        if root.redhat? && Katello::Resources::CDN::CdnResource.redhat_cdn?(root.url)
          {
            ssl_client_certificate: root.product.certificate,
            ssl_client_key: root.product.key,
            ssl_ca_certificate: Katello::Repository.feed_ca_cert(root.url)
          }
        elsif root.custom?
          {
            ssl_client_certificate: root.ssl_client_cert&.content,
            ssl_client_key: root.ssl_client_key&.content,
            ssl_ca_certificate: root.ssl_ca_cert&.content
          }
        else
          {}
        end
      end

      def lookup_version(href)
        pulp3_api.repositories_versions_read href
      rescue PulpcoreClient::ApiError => e
        Rails.logger.error "Exception when calling RepositoriesApi->repositories_versions_read: #{e}"
        nil
      end

      def remove_content(content_units)
        data = PulpcoreClient::RepositoryVersionCreate.new(
          remove_content_units: content_units.map(&:pulp_id))
        pulp3_api.repositories_versions_create(repository_reference.repository_href, data)
      end
    end
  end
end
