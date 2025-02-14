# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRepository, :aggregate_failures do
  using RSpec::Parameterized::TableSyntax

  let(:group) { create(:group, name: 'group') }
  let(:project) { create(:project, path: 'test', group: group) }

  let(:repository) do
    create(:container_repository, name: 'my_image', project: project)
  end

  before do
    stub_container_registry_config(enabled: true,
                                   api_url: 'http://registry.gitlab',
                                   host_port: 'registry.gitlab')

    stub_request(:get, 'http://registry.gitlab/v2/group/test/my_image/tags/list')
      .with(headers: { 'Accept' => ContainerRegistry::Client::ACCEPTED_TYPES.join(', ') })
      .to_return(
        status: 200,
        body: Gitlab::Json.dump(tags: ['test_tag']),
        headers: { 'Content-Type' => 'application/json' })
  end

  it_behaves_like 'having unique enum values'

  describe 'associations' do
    it 'belongs to the project' do
      expect(repository).to belong_to(:project)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:migration_retries_count) }
    it { is_expected.to validate_numericality_of(:migration_retries_count).is_greater_than_or_equal_to(0) }

    it { is_expected.to validate_inclusion_of(:migration_aborted_in_state).in_array(ContainerRepository::ACTIVE_MIGRATION_STATES) }
    it { is_expected.to allow_value(nil).for(:migration_aborted_in_state) }

    context 'migration_state' do
      it { is_expected.to validate_presence_of(:migration_state) }
      it { is_expected.to validate_inclusion_of(:migration_state).in_array(ContainerRepository::MIGRATION_STATES) }

      describe 'pre_importing' do
        it 'validates expected attributes' do
          expect(build(:container_repository, migration_state: 'pre_importing')).to be_invalid
          expect(build(:container_repository, :pre_importing)).to be_valid
        end
      end

      describe 'pre_import_done' do
        it 'validates expected attributes' do
          expect(build(:container_repository, migration_state: 'pre_import_done')).to be_invalid
          expect(build(:container_repository, :pre_import_done)).to be_valid
        end
      end

      describe 'importing' do
        it 'validates expected attributes' do
          expect(build(:container_repository, migration_state: 'importing')).to be_invalid
          expect(build(:container_repository, :importing)).to be_valid
        end
      end

      describe 'import_skipped' do
        it 'validates expected attributes' do
          expect(build(:container_repository, migration_state: 'import_skipped')).to be_invalid
          expect(build(:container_repository, :import_skipped)).to be_valid
        end
      end

      describe 'import_aborted' do
        it 'validates expected attributes' do
          expect(build(:container_repository, migration_state: 'import_aborted')).to be_invalid
          expect(build(:container_repository, :import_aborted)).to be_valid
        end
      end
    end
  end

  context ':migration_state state_machine' do
    shared_examples 'no action when feature flag is disabled' do
      context 'feature flag disabled' do
        before do
          stub_feature_flags(container_registry_migration_phase2_enabled: false)
        end

        it { is_expected.to eq(false) }
      end
    end

    shared_examples 'transitioning to pre_importing', skip_pre_import_success: true do
      before do
        repository.update_column(:migration_pre_import_done_at, Time.zone.now)
      end

      it_behaves_like 'no action when feature flag is disabled'

      context 'successful pre_import request' do
        it 'sets migration_pre_import_started_at and resets migration_pre_import_done_at' do
          expect(repository).to receive(:migration_pre_import).and_return(:ok)

          expect { subject }.to change { repository.reload.migration_pre_import_started_at }
            .and change { repository.migration_pre_import_done_at }.to(nil)

          expect(repository).to be_pre_importing
        end
      end

      context 'failed pre_import request' do
        it 'sets migration_pre_import_started_at and resets migration_pre_import_done_at' do
          expect(repository).to receive(:migration_pre_import).and_return(:error)

          expect { subject }.to change { repository.reload.migration_pre_import_started_at }
            .and change { repository.migration_aborted_at }
            .and change { repository.migration_pre_import_done_at }.to(nil)

          expect(repository.migration_aborted_in_state).to eq('pre_importing')
          expect(repository).to be_import_aborted
        end
      end
    end

    shared_examples 'transitioning to importing', skip_import_success: true do
      before do
        repository.update_columns(migration_import_done_at: Time.zone.now)
      end

      context 'successful import request' do
        it 'sets migration_import_started_at and resets migration_import_done_at' do
          expect(repository).to receive(:migration_import).and_return(:ok)

          expect { subject }.to change { repository.reload.migration_import_started_at }
            .and change { repository.migration_import_done_at }.to(nil)

          expect(repository).to be_importing
        end
      end

      context 'failed import request' do
        it 'sets migration_import_started_at and resets migration_import_done_at' do
          expect(repository).to receive(:migration_import).and_return(:error)

          expect { subject }.to change { repository.reload.migration_import_started_at }
            .and change { repository.migration_aborted_at }

          expect(repository.migration_aborted_in_state).to eq('importing')
          expect(repository).to be_import_aborted
        end
      end
    end

    shared_examples 'transitioning out of import_aborted' do
      it 'resets migration_aborted_at and migration_aborted_in_state' do
        expect { subject }.to change { repository.reload.migration_aborted_in_state }.to(nil)
          .and change { repository.migration_aborted_at }.to(nil)
      end
    end

    shared_examples 'transitioning from allowed states' do |allowed_states|
      ContainerRepository::MIGRATION_STATES.each do |state|
        result = allowed_states.include?(state)

        context "when transitioning from #{state}" do
          let(:repository) { create(:container_repository, state.to_sym) }

          it "returns #{result}" do
            expect(subject).to eq(result)
          end
        end
      end
    end

    describe '#start_pre_import' do
      let_it_be_with_reload(:repository) { create(:container_repository) }

      subject { repository.start_pre_import }

      before do |example|
        unless example.metadata[:skip_pre_import_success]
          allow(repository).to receive(:migration_pre_import).and_return(:ok)
        end
      end

      it_behaves_like 'transitioning from allowed states', %w[default]
      it_behaves_like 'transitioning to pre_importing'
    end

    describe '#retry_pre_import' do
      let_it_be_with_reload(:repository) { create(:container_repository, :import_aborted) }

      subject { repository.retry_pre_import }

      before do |example|
        unless example.metadata[:skip_pre_import_success]
          allow(repository).to receive(:migration_pre_import).and_return(:ok)
        end
      end

      it_behaves_like 'transitioning from allowed states', %w[import_aborted]
      it_behaves_like 'transitioning to pre_importing'
      it_behaves_like 'transitioning out of import_aborted'
    end

    describe '#finish_pre_import' do
      let_it_be_with_reload(:repository) { create(:container_repository, :pre_importing) }

      subject { repository.finish_pre_import }

      it_behaves_like 'transitioning from allowed states', %w[pre_importing]

      it 'sets migration_pre_import_done_at' do
        expect { subject }.to change { repository.reload.migration_pre_import_done_at }

        expect(repository).to be_pre_import_done
      end
    end

    describe '#start_import' do
      let_it_be_with_reload(:repository) { create(:container_repository, :pre_import_done) }

      subject { repository.start_import }

      before do |example|
        unless example.metadata[:skip_import_success]
          allow(repository).to receive(:migration_import).and_return(:ok)
        end
      end

      it_behaves_like 'transitioning from allowed states', %w[pre_import_done]
      it_behaves_like 'transitioning to importing'
    end

    describe '#retry_import' do
      let_it_be_with_reload(:repository) { create(:container_repository, :import_aborted) }

      subject { repository.retry_import }

      before do |example|
        unless example.metadata[:skip_import_success]
          allow(repository).to receive(:migration_import).and_return(:ok)
        end
      end

      it_behaves_like 'transitioning from allowed states', %w[import_aborted]
      it_behaves_like 'transitioning to importing'
      it_behaves_like 'no action when feature flag is disabled'
    end

    describe '#finish_import' do
      let_it_be_with_reload(:repository) { create(:container_repository, :importing) }

      subject { repository.finish_import }

      it_behaves_like 'transitioning from allowed states', %w[importing]

      it 'sets migration_import_done_at' do
        expect { subject }.to change { repository.reload.migration_import_done_at }

        expect(repository).to be_import_done
      end
    end

    describe '#already_migrated' do
      let_it_be_with_reload(:repository) { create(:container_repository) }

      subject { repository.already_migrated }

      it_behaves_like 'transitioning from allowed states', %w[default]

      it 'sets migration_import_done_at' do
        subject

        expect(repository).to be_import_done
      end
    end

    describe '#abort_import' do
      let_it_be_with_reload(:repository) { create(:container_repository, :importing) }

      subject { repository.abort_import }

      it_behaves_like 'transitioning from allowed states', %w[pre_importing importing]

      it 'sets migration_aborted_at and migration_aborted_at and increments the retry count' do
        expect { subject }.to change { repository.migration_aborted_at }
          .and change { repository.reload.migration_retries_count }.by(1)

        expect(repository.migration_aborted_in_state).to eq('importing')
        expect(repository).to be_import_aborted
      end
    end

    describe '#skip_import' do
      let_it_be_with_reload(:repository) { create(:container_repository) }

      subject { repository.skip_import(reason: :too_many_retries) }

      it_behaves_like 'transitioning from allowed states', %w[default pre_importing importing]

      it 'sets migration_skipped_at and migration_skipped_reason' do
        expect { subject }.to change { repository.reload.migration_skipped_at }

        expect(repository.migration_skipped_reason).to eq('too_many_retries')
        expect(repository).to be_import_skipped
      end

      it 'raises and error if a reason is not given' do
        expect { repository.skip_import }.to raise_error(ArgumentError)
      end
    end

    describe '#finish_pre_import_and_start_import' do
      let_it_be_with_reload(:repository) { create(:container_repository, :pre_importing) }

      subject { repository.finish_pre_import_and_start_import }

      before do |example|
        unless example.metadata[:skip_import_success]
          allow(repository).to receive(:migration_import).and_return(:ok)
        end
      end

      it_behaves_like 'transitioning from allowed states', %w[pre_importing]
      it_behaves_like 'transitioning to importing'
    end
  end

  describe '#tag' do
    it 'has a test tag' do
      expect(repository.tag('test')).not_to be_nil
    end
  end

  describe '#path' do
    context 'when project path does not contain uppercase letters' do
      it 'returns a full path to the repository' do
        expect(repository.path).to eq('group/test/my_image')
      end
    end

    context 'when path contains uppercase letters' do
      let(:project) { create(:project, :repository, path: 'MY_PROJECT', group: group) }

      it 'returns a full path without capital letters' do
        expect(repository.path).to eq('group/my_project/my_image')
      end
    end
  end

  describe '#manifest' do
    it 'returns non-empty manifest' do
      expect(repository.manifest).not_to be_nil
    end
  end

  describe '#valid?' do
    it 'is a valid repository' do
      expect(repository).to be_valid
    end
  end

  describe '#tags' do
    it 'returns non-empty tags list' do
      expect(repository.tags).not_to be_empty
    end
  end

  describe '#tags_count' do
    it 'returns the count of tags' do
      expect(repository.tags_count).to eq(1)
    end
  end

  describe '#has_tags?' do
    it 'has tags' do
      expect(repository).to have_tags
    end
  end

  describe '#delete_tags!' do
    let(:repository) do
      create(:container_repository, name: 'my_image',
                                    tags: { latest: '123', rc1: '234' },
                                    project: project)
    end

    context 'when action succeeds' do
      it 'returns status that indicates success' do
        expect(repository.client)
          .to receive(:delete_repository_tag_by_digest)
          .twice
          .and_return(true)

        expect(repository.delete_tags!).to be_truthy
      end
    end

    context 'when action fails' do
      it 'returns status that indicates failure' do
        expect(repository.client)
          .to receive(:delete_repository_tag_by_digest)
          .twice
          .and_return(false)

        expect(repository.delete_tags!).to be_falsey
      end
    end
  end

  describe '#delete_tag_by_name' do
    let(:repository) do
      create(:container_repository, name: 'my_image',
                                    tags: { latest: '123', rc1: '234' },
                                    project: project)
    end

    context 'when action succeeds' do
      it 'returns status that indicates success' do
        expect(repository.client)
          .to receive(:delete_repository_tag_by_name)
          .with(repository.path, "latest")
          .and_return(true)

        expect(repository.delete_tag_by_name('latest')).to be_truthy
      end
    end

    context 'when action fails' do
      it 'returns status that indicates failure' do
        expect(repository.client)
          .to receive(:delete_repository_tag_by_name)
          .with(repository.path, "latest")
          .and_return(false)

        expect(repository.delete_tag_by_name('latest')).to be_falsey
      end
    end
  end

  describe '#location' do
    context 'when registry is running on a custom port' do
      before do
        stub_container_registry_config(enabled: true,
                                       api_url: 'http://registry.gitlab:5000',
                                       host_port: 'registry.gitlab:5000')
      end

      it 'returns a full location of the repository' do
        expect(repository.location)
          .to eq 'registry.gitlab:5000/group/test/my_image'
      end
    end
  end

  describe '#root_repository?' do
    context 'when repository is a root repository' do
      let(:repository) { create(:container_repository, :root) }

      it 'returns true' do
        expect(repository).to be_root_repository
      end
    end

    context 'when repository is not a root repository' do
      it 'returns false' do
        expect(repository).not_to be_root_repository
      end
    end
  end

  describe '#start_expiration_policy!' do
    subject { repository.start_expiration_policy! }

    it 'sets the expiration policy started at to now' do
      freeze_time do
        expect { subject }
          .to change { repository.expiration_policy_started_at }.from(nil).to(Time.zone.now)
      end
    end
  end

  describe '#reset_expiration_policy_started_at!' do
    subject { repository.reset_expiration_policy_started_at! }

    before do
      repository.start_expiration_policy!
    end

    it 'resets the expiration policy started at' do
      started_at = repository.expiration_policy_started_at

      expect(started_at).not_to be_nil
      expect { subject }
          .to change { repository.expiration_policy_started_at }.from(started_at).to(nil)
    end
  end

  context 'registry migration' do
    shared_examples 'handling the migration step' do |step|
      let(:client_response) { :foobar }

      before do
        allow(repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(true)
      end

      it 'returns the same response as the client' do
        expect(repository.gitlab_api_client)
          .to receive(step).with(repository.path).and_return(client_response)
        expect(subject).to eq(client_response)
      end

      context 'when the gitlab_api feature is not supported' do
        before do
          allow(repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
        end

        it 'returns :error' do
          expect(repository.gitlab_api_client).not_to receive(step)

          expect(subject).to eq(:error)
        end
      end
    end

    describe '#migration_pre_import' do
      subject { repository.migration_pre_import }

      it_behaves_like 'handling the migration step', :pre_import_repository
    end

    describe '#migration_import' do
      subject { repository.migration_import }

      it_behaves_like 'handling the migration step', :import_repository
    end
  end

  describe '.build_from_path' do
    let(:registry_path) do
      ContainerRegistry::Path.new(project.full_path + '/some/image')
    end

    let(:repository) do
      described_class.build_from_path(registry_path)
    end

    it 'fabricates repository assigned to a correct project' do
      expect(repository.project).to eq project
    end

    it 'fabricates repository with a correct name' do
      expect(repository.name).to eq 'some/image'
    end

    it 'is not persisted' do
      expect(repository).not_to be_persisted
    end
  end

  describe '.find_or_create_from_path' do
    let(:repository) do
      described_class.find_or_create_from_path(ContainerRegistry::Path.new(path))
    end

    let(:repository_path) { ContainerRegistry::Path.new(path) }

    context 'when received multi-level repository path' do
      let(:path) { project.full_path + '/some/image' }

      it 'fabricates repository assigned to a correct project' do
        expect(repository.project).to eq project
      end

      it 'fabricates repository with a correct name' do
        expect(repository.name).to eq 'some/image'
      end
    end

    context 'when path is too long' do
      let(:path) do
        project.full_path + '/a/b/c/d/e/f/g/h/i/j/k/l/n/o/p/s/t/u/x/y/z'
      end

      it 'does not create repository and raises error' do
        expect { repository }.to raise_error(
          ContainerRegistry::Path::InvalidRegistryPathError)
      end
    end

    context 'when received multi-level repository with nested groups' do
      let(:group) { create(:group, :nested, name: 'nested') }
      let(:path) { project.full_path + '/some/image' }

      it 'fabricates repository assigned to a correct project' do
        expect(repository.project).to eq project
      end

      it 'fabricates repository with a correct name' do
        expect(repository.name).to eq 'some/image'
      end

      it 'has path including a nested group' do
        expect(repository.path).to include 'nested/test/some/image'
      end
    end

    context 'when received root repository path' do
      let(:path) { project.full_path }

      it 'fabricates repository assigned to a correct project' do
        expect(repository.project).to eq project
      end

      it 'fabricates repository with an empty name' do
        expect(repository.name).to be_empty
      end
    end

    context 'when repository already exists' do
      let(:path) { project.full_path + '/some/image' }

      it 'returns the existing repository' do
        container_repository = create(:container_repository, project: project, name: 'some/image')

        expect(repository.id).to eq(container_repository.id)
      end
    end

    context 'when many of the same repository are created at the same time' do
      let(:path) { ContainerRegistry::Path.new(project.full_path + '/some/image') }

      it 'does not throw validation errors and only creates one repository' do
        expect { repository_creation_race(path) }.to change { ContainerRepository.count }.by(1)
      end

      it 'retrieves a persisted repository for all concurrent calls' do
        repositories = repository_creation_race(path).map(&:value)

        expect(repositories).to all(be_persisted)
      end
    end

    def repository_creation_race(path)
      # create a race condition - structure from https://blog.arkency.com/2015/09/testing-race-conditions/
      wait_for_it = true

      threads = Array.new(10) do |i|
        Thread.new do
          true while wait_for_it

          ::ContainerRepository.find_or_create_from_path(path)
        end
      end
      wait_for_it = false
      threads.each(&:join)
    end
  end

  describe '.find_by_path' do
    let_it_be(:container_repository) { create(:container_repository) }
    let_it_be(:repository_path) { container_repository.project.full_path }

    let(:path) { ContainerRegistry::Path.new(repository_path + '/' + container_repository.name) }

    subject { described_class.find_by_path(path) }

    context 'when repository exists' do
      it 'finds the repository' do
        expect(subject).to eq(container_repository)
      end
    end

    context 'when repository does not exist' do
      let(:path) { ContainerRegistry::Path.new(repository_path + '/some/image') }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '.find_by_path!' do
    let_it_be(:container_repository) { create(:container_repository) }
    let_it_be(:repository_path) { container_repository.project.full_path }

    let(:path) { ContainerRegistry::Path.new(repository_path + '/' + container_repository.name) }

    subject { described_class.find_by_path!(path) }

    context 'when repository exists' do
      it 'finds the repository' do
        expect(subject).to eq(container_repository)
      end
    end

    context 'when repository does not exist' do
      let(:path) { ContainerRegistry::Path.new(repository_path + '/some/image') }

      it 'raises an exception' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.build_root_repository' do
    let(:repository) do
      described_class.build_root_repository(project)
    end

    it 'fabricates a root repository object' do
      expect(repository).to be_root_repository
    end

    it 'assignes it to the correct project' do
      expect(repository.project).to eq project
    end

    it 'does not persist it' do
      expect(repository).not_to be_persisted
    end
  end

  describe '.for_group_and_its_subgroups' do
    subject { described_class.for_group_and_its_subgroups(test_group) }

    context 'in a group' do
      let(:test_group) { group }

      it { is_expected.to contain_exactly(repository) }
    end

    context 'with a subgroup' do
      let_it_be(:test_group) { create(:group) }
      let_it_be(:another_project) { create(:project, path: 'test', group: test_group) }
      let_it_be(:project3) { create(:project, :container_registry_disabled, path: 'test3', group: test_group) }

      let_it_be(:another_repository) do
        create(:container_repository, name: 'my_image', project: another_project)
      end

      let_it_be(:repository3) do
        create(:container_repository, name: 'my_image3', project: project3)
      end

      before do
        group.parent = test_group
        group.save!
      end

      it { is_expected.to contain_exactly(repository, another_repository) }
    end

    context 'group without container_repositories' do
      let(:test_group) { create(:group) }

      it { is_expected.to eq([]) }
    end
  end

  describe '.search_by_name' do
    let!(:another_repository) do
      create(:container_repository, name: 'my_foo_bar', project: project)
    end

    subject { described_class.search_by_name('my_image') }

    it { is_expected.to contain_exactly(repository) }
  end

  describe '.for_project_id' do
    subject { described_class.for_project_id(project.id) }

    it { is_expected.to contain_exactly(repository) }
  end

  describe '.expiration_policy_started_at_nil_or_before' do
    let_it_be(:repository1) { create(:container_repository, expiration_policy_started_at: nil) }
    let_it_be(:repository2) { create(:container_repository, expiration_policy_started_at: 1.day.ago) }
    let_it_be(:repository3) { create(:container_repository, expiration_policy_started_at: 2.hours.ago) }
    let_it_be(:repository4) { create(:container_repository, expiration_policy_started_at: 1.week.ago) }

    subject { described_class.expiration_policy_started_at_nil_or_before(3.hours.ago) }

    it { is_expected.to contain_exactly(repository1, repository2, repository4) }
  end

  describe '.with_stale_ongoing_cleanup' do
    let_it_be(:repository1) { create(:container_repository, :cleanup_ongoing, expiration_policy_started_at: 1.day.ago) }
    let_it_be(:repository2) { create(:container_repository, :cleanup_ongoing, expiration_policy_started_at: 25.minutes.ago) }
    let_it_be(:repository3) { create(:container_repository, :cleanup_ongoing, expiration_policy_started_at: 1.week.ago) }
    let_it_be(:repository4) { create(:container_repository, :cleanup_unscheduled, expiration_policy_started_at: 25.minutes.ago) }

    subject { described_class.with_stale_ongoing_cleanup(27.minutes.ago) }

    it { is_expected.to contain_exactly(repository1, repository3) }
  end

  describe '.waiting_for_cleanup' do
    let_it_be(:repository_cleanup_scheduled) { create(:container_repository, :cleanup_scheduled) }
    let_it_be(:repository_cleanup_unfinished) { create(:container_repository, :cleanup_unfinished) }
    let_it_be(:repository_cleanup_ongoing) { create(:container_repository, :cleanup_ongoing) }

    subject { described_class.waiting_for_cleanup }

    it { is_expected.to contain_exactly(repository_cleanup_scheduled, repository_cleanup_unfinished) }
  end

  describe '.exists_by_path?' do
    it 'returns true for known container repository paths' do
      path = ContainerRegistry::Path.new("#{project.full_path}/#{repository.name}")
      expect(described_class.exists_by_path?(path)).to be_truthy
    end

    it 'returns false for unknown container repository paths' do
      path = ContainerRegistry::Path.new('you/dont/know/me')
      expect(described_class.exists_by_path?(path)).to be_falsey
    end
  end

  describe '.with_enabled_policy' do
    let_it_be(:repository) { create(:container_repository) }
    let_it_be(:repository2) { create(:container_repository) }

    subject { described_class.with_enabled_policy }

    before do
      repository.project.container_expiration_policy.update!(enabled: true)
    end

    it { is_expected.to eq([repository]) }
  end

  describe '#migration_in_active_state?' do
    subject { container_repository.migration_in_active_state? }

    ContainerRepository::MIGRATION_STATES.each do |state|
      context "when in #{state} migration_state" do
        let(:container_repository) { create(:container_repository, state.to_sym)}

        it { is_expected.to eq(state == 'importing' || state == 'pre_importing') }
      end
    end
  end

  describe '#migration_importing?' do
    subject { container_repository.migration_importing? }

    ContainerRepository::MIGRATION_STATES.each do |state|
      context "when in #{state} migration_state" do
        let(:container_repository) { create(:container_repository, state.to_sym)}

        it { is_expected.to eq(state == 'importing') }
      end
    end
  end

  describe '#migration_pre_importing?' do
    subject { container_repository.migration_pre_importing? }

    ContainerRepository::MIGRATION_STATES.each do |state|
      context "when in #{state} migration_state" do
        let(:container_repository) { create(:container_repository, state.to_sym)}

        it { is_expected.to eq(state == 'pre_importing') }
      end
    end
  end

  context 'with repositories' do
    let_it_be_with_reload(:repository) { create(:container_repository, :cleanup_unscheduled) }
    let_it_be(:other_repository) { create(:container_repository, :cleanup_unscheduled) }

    let(:policy) { repository.project.container_expiration_policy }

    before do
      ContainerExpirationPolicy.update_all(enabled: true)
    end

    describe '.requiring_cleanup' do
      subject { described_class.requiring_cleanup }

      context 'with next_run_at in the future' do
        before do
          policy.update_column(:next_run_at, 10.minutes.from_now)
        end

        it { is_expected.to eq([]) }
      end

      context 'with next_run_at in the past' do
        before do
          policy.update_column(:next_run_at, 10.minutes.ago)
        end

        it { is_expected.to eq([repository]) }
      end

      context 'with repository cleanup started at after policy next run at' do
        before do
          repository.update!(expiration_policy_started_at: policy.next_run_at + 5.minutes)
        end

        it { is_expected.to eq([]) }
      end
    end

    describe '.with_unfinished_cleanup' do
      subject { described_class.with_unfinished_cleanup }

      it { is_expected.to eq([]) }

      context 'with an unfinished repository' do
        before do
          repository.cleanup_unfinished!
        end

        it { is_expected.to eq([repository]) }
      end
    end
  end
end
