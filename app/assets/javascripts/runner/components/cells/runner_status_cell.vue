<script>
import { GlTooltipDirective } from '@gitlab/ui';

import RunnerStatusBadge from '../runner_status_badge.vue';
import RunnerPausedBadge from '../runner_paused_badge.vue';

export default {
  components: {
    RunnerStatusBadge,
    RunnerPausedBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    runner: {
      type: Object,
      required: true,
    },
  },
  computed: {
    paused() {
      return !this.runner.active;
    },
  },
};
</script>

<template>
  <div>
    <runner-status-badge
      :runner="runner"
      size="sm"
      class="gl-display-inline-block gl-max-w-full gl-text-truncate"
    />
    <runner-paused-badge
      v-if="paused"
      size="sm"
      class="gl-display-inline-block gl-max-w-full gl-text-truncate"
    />
  </div>
</template>
