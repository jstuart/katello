#
# Copyright 2014 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

module Katello
  class Api::V2::RepositoriesBulkActionsController < Api::V2::ApiController

    before_filter :find_repositories

    api :PUT, "/repositories/bulk/destroy", N_("Destroy one or more repositories")
    param :ids, Array, :desc => N_("List of repository ids"), :required => true
    def destroy_repositories
      deletable_repositories = @repositories.deletable

      deletable_repositories.each do |repository|
        trigger(::Actions::Katello::Repository::Destroy, repository)
      end

      messages = format_bulk_action_messages(
        :success    => _("Successfully removed %s repositories"),
        :error      => _("You were not allowed to delete %s"),
        :models     => @repositories,
        :authorized => deletable_repositories
      )

      respond_for_show :template => 'bulk_action', :resource_name => 'common',
                       :resource => { 'displayMessages' => messages }
    end

    api :POST, "/repositories/bulk/sync", N_("Synchronize repository")
    param :ids, Array, :desc => N_("List of repository ids"), :required => true
    def sync_repositories
      syncable_repositories = @repositories.syncable.has_feed
      syncable_repositories.each do |repo|
        async_task(::Actions::Katello::Repository::Sync, repo)
      end

      messages1 = format_bulk_action_messages(
        :success    => "",
        :error      => _("You do not have permissions to sync %s"),
        :models     => @repositories,
        :authorized => @repositories.syncable
      )

      messages2 = format_bulk_action_messages(
        :success    => _("Successfully started sync for %s repositories, you are free to leave this page."),
        :error      => _("Repository %s does not have a feed url."),
        :models     => @repositories,
        :authorized => @repositories.has_feed
      )

      messages2[:error] += messages1[:error]

      respond_for_show :template => 'bulk_action', :resource_name => 'common',
                       :resource => { 'displayMessages' => messages2 }
    end

    private

    def find_repositories
      params.require(:ids)
      @repositories = Repository.where(:id => params[:ids])
    end

  end
end
