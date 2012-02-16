require 'spec_helper'
include OrchestrationHelper

describe Changeset, :katello => true do

  describe "Changeset should" do
    before(:each) do
      disable_org_orchestration
      disable_product_orchestration
      disable_user_orchestration

      User.current = User.find_or_create_by_username(:username => 'admin', :password => 'admin12345')
      @organization = Organization.create!(:name => 'candyroom', :cp_key => 'test_organization')
      @environment = KTEnvironment.new({:name => 'julia', :prior=>@organization.library})
      @organization.environments << @environment
      @organization.save!
      @environment.save!
      @changeset = Changeset.new(:environment=>@environment, :name=>"foo-changeset")
      @changeset.save!
    end

    it "changeset should not be null" do
      @environment.should_not be_nil
      @environment.working_changesets.should_not be_nil
    end

    it "changeset first user should equal current user" do
      cu = ChangesetUser.new(:changeset => @changeset, :user => User.current)
      cu.save!
      @changeset.users.first.user_id.should == User.current.id
      @changeset.users.first.changeset_id.should == @changeset.id
    end

    it "changeset find or create should work" do
      cu = ChangesetUser.find_or_create_by_user_id_and_changeset_id(User.current.id, @changeset.id)
      cu.save!
      @changeset.users.first.user_id.should == User.current.id
      @changeset.users.first.changeset_id.should == @changeset.id
    end

    it "changeset find or create should work" do
      cu = ChangesetUser.find_or_create_by_user_id_and_changeset_id(User.current.id, @changeset.id)
      cu.save!
      ChangesetUser.destroy_all(:changeset_id => @changeset.id)
      @changeset.users.should be_empty
    end

    describe "fail adding content not contained in the prior environment" do

      it "should fail on add product" do
        lambda {@changeset.add_product("prod")}.should raise_error
      end

      it "should fail on add package" do
        lambda {@changeset.add_package("pack")}.should raise_error
      end

      it "should fail on add erratum" do
        lambda {@changeset.add_erratum("err")}.should raise_error
      end

      it "should fail on add repo" do
        lambda {@changeset.add_repo("repo")}.should raise_error
      end

      it "should fail on add repo" do
        lambda {@changeset.add_distribution("distro-id")}.should raise_error
      end

    end


    describe "adding content" do
      before(:each) do
        @provider = Provider.create!(:name => "provider", :provider_type => Provider::CUSTOM, :organization => @organization, :repository_url => "https://something.url/stuff")

        @prod = Product.new({:name => "prod"})

        @prod.provider = @provider
        @prod.environments << @organization.library
        @prod.stub(:arch).and_return('noarch')
        @prod.save!
        ep = EnvironmentProduct.find_or_create(@organization.library, @prod)
        @pack_name = "pack"
        @pack_version = "0.1"
        @pack_release = "1"
        @pack_arch = "noarch"
        @pack_nvre = @pack_name +"-"+ @pack_version +"-"+ @pack_release +"."+ @pack_arch
        @pack = {
          :id => 1,
          :name => @pack_name,
          :version => @pack_version,
          :release => @pack_release,
          :arch => @pack_arch
        }.with_indifferent_access
        @err  = mock('Err', {:id => 'err', :name => 'err'})

        @repo = Repository.create!(:environment_product => ep, :name=> "repo", :pulp_id=>"1")
        @distribution = mock('Distribution', {:id=> 'some-distro-id'})
        @repo.stub(:distributions).and_return([@distribution])
        @repo.stub_chain(:distributions, :index).and_return([@distribution])
        @repo.stub(:packages).and_return([@pack])
        @repo.stub(:errata).and_return([@err])
        @repo.stub(:has_package?).with(1).and_return(true)
        @repo.stub(:has_erratum?).with('err').and_return(true)
        @repo.stub(:has_distribution?).with('some-distro-id').and_return(true)
        @repo.stub(:clone_ids).and_return([])
        Product.stub(:find).and_return(@prod)

        @prod.stub(:repos).and_return([@repo])
        @prod.stub_chain(:repos, :where).and_return([@repo])
        @environment.prior.stub(:products).and_return([@prod])
        @environment.prior.products.stub(:find_by_name).and_return(@prod)
        @environment.prior.products.stub(:find_by_cp_id).and_return(@prod)
      end

      describe "fail adding content from not promoted product" do

        before(:each) do
          @repo.stub(:is_cloned_in?).and_return(true)
        end

        it "should fail on add package" do
          lambda {@changeset.add_package("pack")}.should raise_error
        end

        it "should fail on add erratum" do
          lambda {@changeset.add_erratum("err")}.should raise_error
        end

        it "should fail on add repo" do
          lambda {@changeset.add_repo("repo")}.should raise_error
        end

        it "should fail on add distribution" do
          lambda {@changeset.add_distribution("some_distro_id")}.should raise_error
        end
      end

      describe "fail adding content from not promoted repository" do

        before(:each) do
          @prod.environments << @environment
          @repo.stub(:is_cloned_in?).and_return(true)
        end

        it "should fail on add package" do
          lambda {@changeset.add_package("pack")}.should raise_error
        end

        it "should fail on add erratum" do
          lambda {@changeset.add_erratum("err")}.should raise_error
        end

        it "should fail on add distribution" do
          lambda {@changeset.add_distribution("some_distro_id")}.should raise_error
        end
      end

      describe "adding content from the prior environment" do

        before(:each) do
          @prod.environments << @environment
          @repo.stub(:is_cloned_in?).and_return(true)
          @repo.stub(:last_sync).and_return("2011-11-11 11:11")
        end

        it "should add product" do
          @changeset.add_product("prod")
          @changeset.products.should include @prod
        end

        it "should add package by nvre" do
          @prod.stub(:find_packages_by_nvre).with(@changeset.environment.prior, @pack_name, @pack_version, @pack_release, nil).and_return([@pack])
          @changeset.add_package(@pack_nvre, "prod")
          @changeset.packages.length.should == 1
        end

        it "should add package by name" do
          @prod.stub(:find_packages_by_name).with(@changeset.environment.prior, @pack_name).and_return([@pack])
          @changeset.add_package(@pack_name, "prod")
          @changeset.packages.length.should == 1
        end

        it "should add erratum" do
          @changeset.add_erratum("err", "prod")
          @changeset.errata.length.should == 1
        end

        it "should add repo" do
          @changeset.add_repo("repo", "prod")
          @changeset.repos.length.should == 1
        end

        it "should add distribution" do
          @changeset.add_distribution("some-distro-id", "prod")
          @changeset.distributions.length.should == 1
        end

      end
    end

    describe "removing content" do

      before(:each) do
        @provider = Provider.create!(:name => "provider", :provider_type => Provider::CUSTOM, :organization => @organization, :repository_url => "https://something.url/stuff")

        @prod = Product.new({:name => "prod", :cp_id => "prod"})
        @prod.provider = @provider
        @prod.environments << @organization.library
        @prod.environments << @environment
        @prod.stub(:arch).and_return('noarch')
        @prod.save!

        ep = EnvironmentProduct.find_or_create(@organization.library, @prod)
        @pack_name = "pack"
        @pack_version = "0.1"
        @pack_release = "1"
        @pack_arch = "noarch"
        @pack_nvre = @pack_name +"-"+ @pack_version +"-"+ @pack_release +"."+ @pack_arch
        @pack = {:id => 1, :name => @pack_name}.with_indifferent_access
        @err  = mock('Err', {:id => 'err', :name => 'err'})

        @repo = Repository.create!(:environment_product => ep, :name=> "repo", :pulp_id=>"1")

        @distribution = mock('Distribution', {:id=> 'some-distro-id'})
        @repo.stub(:distributions).and_return([@distribution])
        @repo.stub(:packages).and_return([@pack])
        @repo.stub(:errata).and_return([@err])
        @repo.stub(:clone_ids).and_return([])

        @prod.stub(:repos).and_return([@repo])
        @prod.stub_chain(:repos, :where).and_return([@repo])

        @changeset.products = [@prod]
        @changeset.products.stub(:find_by_cp_id).and_return(@prod)

        @environment.prior.stub(:products).and_return([@prod])
        @environment.prior.products.stub(:find_by_name).and_return(@prod)
        @environment.prior.products.stub(:find_by_cp_id).and_return(@prod)
      end

      it "should remove product" do
        @changeset.products.should_receive(:delete).with(@prod).and_return(true)
        @changeset.remove_product("prod")
      end

      it "should remove package" do
        @prod.stub(:find_packages_by_nvre).with(@changeset.environment.prior, @pack_name, @pack_version, @pack_release, nil).and_return([@pack])
        ChangesetPackage.should_receive(:destroy_all).with(:package_id => 1, :changeset_id => @changeset.id, :product_id => @prod.id).and_return(true)
        @changeset.remove_package(@pack_nvre, "prod")
      end

      it "should remove erratum" do
        ChangesetErratum.should_receive(:destroy_all).with(:errata_id => 'err', :changeset_id => @changeset.id, :product_id => @prod.id).and_return(true)
        @changeset.remove_erratum("err", "prod")
      end

      it "should remove repo" do
        @changeset.repos.should_receive(:delete).with(@repo).and_return(true)
        @changeset.remove_repo("repo", "prod")
      end

      it "should remove distribution" do
        ChangesetDistribution.should_receive(:destroy_all).with(:distribution_id => 'some-distro-id', :changeset_id => @changeset.id, :product_id => @prod.id).and_return(true)
        @changeset.remove_distribution('some-distro-id', "prod")
      end

    end


    describe "promotions" do
      before(:each) do
        @provider = Provider.create!(:name => "provider", :provider_type => Provider::CUSTOM, :organization => @organization, :repository_url => "https://something.url/stuff")

        @prod = Product.new({:name => "prod"})
        @prod.provider = @provider
        @prod.environments << @organization.library
        @prod.stub(:arch).and_return('noarch')
        @prod.stub(:promote).and_return([])
        @prod.save!
        Product.stub(:find).and_return(@prod)

        @pack = mock('Pack', {:id => 1, :name => 'pack'})
        @err  = mock('Err', {:id => 'err', :name => 'err'})
        @distribution = mock('Distribution', {:id=> 'some-distro-id'})
        ep = EnvironmentProduct.find_or_create(@organization.library, @prod)
        @repo = Repository.create!(:environment_product => ep, :name=>'repo', :pulp_id=>"1")
        @repo.stub_chain(:distributions, :index).and_return([@distribution])
        @repo.stub(:distributions).and_return([@distribution])
        @repo.stub(:packages).and_return([@pack])
        @repo.stub(:errata).and_return([@err])
        @repo.stub(:promote).and_return([])
        @repo.stub(:sync).and_return([])
        @repo.stub(:has_package?).and_return(true)
        @repo.stub(:has_erratum?).and_return(true)
        @repo.stub(:has_distribution?).with('some-distro-id').and_return(true)

        @repo.stub(:is_cloned_in?).and_return(true)
        @repo.stub(:clone_ids).and_return([])
        Repository.stub(:find_by_pulp_id).and_return(@repo)


        @clone = mock('Repo', {:id => 2, :name => 'repo_clone'})
        @clone.stub(:has_package?).and_return(false)
        @clone.stub(:has_erratum?).and_return(false)
        @clone.stub(:has_distribution?).and_return(false)
        @clone.stub(:generate_metadata)
        @repo.stub(:clone_ids).and_return([])
        @repo.stub(:get_clone).and_return(@clone)
        @repo.stub(:get_cloned_in).and_return(nil)
        @prod.stub(:repos).and_return([@repo])
        @prod.stub(:repos).and_return([@repo])
        @prod.stub_chain(:repos, :where).and_return([@repo])

        @clone.stub(:index_packages).and_return()
        @clone.stub(:index_errata).and_return()
        @repo.stub(:index_packages).and_return()
        @repo.stub(:index_errata).and_return()

        @environment.prior.stub(:products).and_return([@prod])
        @environment.prior.products.stub(:find_by_name).and_return(@prod)
        @changeset.stub(:wait_for_tasks).and_return(nil)
        @changeset.stub(:calc_dependencies).and_return([])

        Glue::Pulp::Package.stub(:index_packages).and_return(true)
        Glue::Pulp::Errata.stub(:index_errata).and_return(true)

      end

      it "should fail if the product is not in the review phase" do
        lambda {@changeset.promote}.should raise_error
      end

      it "should promote products" do
        @changeset.products << @prod
        @changeset.state = Changeset::REVIEW

        @prod.should_receive(:promote).once
        @changeset.should_receive(:index_repo_content).once

        @changeset.promote(false)
      end

      it "should promote repositories" do
        @prod.environments << @environment
        @changeset.state = Changeset::REVIEW

        @repo.stub(:is_cloned_in?).and_return(false)
        @repo.stub(:get_clone).and_return(nil)
        @changeset.stub(:repos).and_return([@repo])
        @repo.should_receive(:promote).once
        @changeset.should_receive(:index_repo_content).once

        @changeset.promote(false)
      end

      it "should promote packages" do
        @prod.environments << @environment
        @changeset.packages << ChangesetPackage.new(:package_id => @pack.id, :display_name => @pack.name, :product_id => @prod.id, :changeset => @changeset)
        @changeset.state = Changeset::REVIEW

        Pulp::Package.stub(:dep_solve).and_return({})

        @clone.should_receive(:add_packages).once.with([@pack.id])

        @changeset.promote(false)
      end

      it "should promote errata" do
        @prod.environments << @environment
        @changeset.errata << ChangesetErratum.new(:errata_id => @err.id, :display_name => @err.name, :product_id => @prod.id, :changeset => @changeset)
        @changeset.state = Changeset::REVIEW

        @clone.should_receive(:add_errata).once.with([@err.id])

        @changeset.promote(false)
      end

      it "should promote distributions" do
        @prod.environments << @environment
        @changeset.distributions << ChangesetDistribution.new(:distribution_id => @distribution.id, :display_name => @distribution.id, :product_id => @prod.id, :changeset => @changeset)
        @changeset.state = Changeset::REVIEW

        @clone.should_receive(:add_distribution).once.with(@distribution.id)

        @changeset.promote(false)
      end

      it "should regenerate metadata of changed repos" do
        @changeset.stub(:affected_repos).and_return([@repo])
        @clone.should_receive(:generate_metadata)
        @changeset.state = Changeset::REVIEW

        @changeset.promote(false)
      end

      it "should have correct state after successful promotion" do
        @changeset.state = Changeset::REVIEW
        @changeset.promote(false)
        @changeset.state.should == Changeset::PROMOTED
      end

      it "should have correct state after unsuccessful promotion" do
        @changeset.state = Changeset::REVIEW
        @changeset.stub(:calc_and_save_dependencies).and_raise(Exception)
        lambda {@changeset.promote(false)}.should raise_exception
        @changeset.state.should == Changeset::FAILED
      end

    end
  end
end
