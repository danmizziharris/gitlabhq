<script>
import { GlButton, GlButtonGroup, GlModalDirective, GlTooltipDirective } from '@gitlab/ui';
import { createAlert } from '~/flash';
import { s__, sprintf } from '~/locale';
import runnerDeleteMutation from '~/runner/graphql/runner_delete.mutation.graphql';
import { captureException } from '~/runner/sentry_utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import RunnerEditButton from '../runner_edit_button.vue';
import RunnerPauseButton from '../runner_pause_button.vue';
import RunnerDeleteModal from '../runner_delete_modal.vue';

const I18N_DELETE = s__('Runners|Delete runner');
const I18N_DELETED_TOAST = s__('Runners|Runner %{name} was deleted');

export default {
  name: 'RunnerActionsCell',
  components: {
    GlButton,
    GlButtonGroup,
    RunnerEditButton,
    RunnerPauseButton,
    RunnerDeleteModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModal: GlModalDirective,
  },
  props: {
    runner: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      updating: false,
      deleting: false,
    };
  },
  computed: {
    deleteTitle() {
      if (this.deleting) {
        // Prevent a "sticky" tooltip: If this button is disabled,
        // mouseout listeners don't run leaving the tooltip stuck
        return '';
      }
      return I18N_DELETE;
    },
    runnerId() {
      return getIdFromGraphQLId(this.runner.id);
    },
    runnerName() {
      return `#${this.runnerId} (${this.runner.shortSha})`;
    },
    runnerDeleteModalId() {
      return `delete-runner-modal-${this.runnerId}`;
    },
    canUpdate() {
      return this.runner.userPermissions?.updateRunner;
    },
    canDelete() {
      return this.runner.userPermissions?.deleteRunner;
    },
  },
  methods: {
    async onDelete() {
      // Deleting stays "true" until this row is removed,
      // should only change back if the operation fails.
      this.deleting = true;
      try {
        const {
          data: {
            runnerDelete: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: runnerDeleteMutation,
          variables: {
            input: {
              id: this.runner.id,
            },
          },
          awaitRefetchQueries: true,
          refetchQueries: ['getRunners', 'getGroupRunners'],
        });
        if (errors && errors.length) {
          throw new Error(errors.join(' '));
        } else {
          // Use $root to have the toast message stay after this element is removed
          this.$root.$toast?.show(sprintf(I18N_DELETED_TOAST, { name: this.runnerName }));
        }
      } catch (e) {
        this.deleting = false;
        this.onError(e);
      }
    },

    onError(error) {
      const { message } = error;
      createAlert({ message });

      this.reportToSentry(error);
    },
    reportToSentry(error) {
      captureException({ error, component: this.$options.name });
    },
  },
  I18N_DELETE,
};
</script>

<template>
  <gl-button-group>
    <!--
      This button appears for administrators: those with
      access to the adminUrl. More advanced permissions policies
      will allow more granular permissions.

      See https://gitlab.com/gitlab-org/gitlab/-/issues/334802
    -->
    <runner-edit-button v-if="canUpdate && runner.editAdminUrl" :href="runner.editAdminUrl" />
    <runner-pause-button v-if="canUpdate" :runner="runner" :compact="true" />
    <gl-button
      v-if="canDelete"
      v-gl-tooltip.hover.viewport="deleteTitle"
      v-gl-modal="runnerDeleteModalId"
      :aria-label="deleteTitle"
      icon="close"
      :loading="deleting"
      variant="danger"
      data-testid="delete-runner"
    />

    <runner-delete-modal
      v-if="canDelete"
      :ref="runnerDeleteModalId"
      :modal-id="runnerDeleteModalId"
      :runner-name="runnerName"
      @primary="onDelete"
    />
  </gl-button-group>
</template>
