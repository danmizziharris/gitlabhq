<script>
import { GlButton } from '@gitlab/ui';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import notesEventHub from '~/notes/event_hub';
import statusIcon from '../mr_widget_status_icon.vue';

export default {
  name: 'UnresolvedDiscussions',
  components: {
    statusIcon,
    GlButton,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  methods: {
    jumpToFirstUnresolvedDiscussion() {
      notesEventHub.$emit('jumpToFirstUnresolvedDiscussion');
    },
  },
};
</script>

<template>
  <div class="mr-widget-body media gl-flex-wrap">
    <status-icon show-disabled-button status="warning" />
    <div class="media-body">
      <span
        :class="{
          'gl-ml-0! gl-text-body!': glFeatures.restructuredMrWidget,
          'gl-display-block': !glFeatures.restructuredMrWidget,
        }"
        class="gl-ml-3 gl-font-weight-bold gl-w-100"
      >
        {{ s__('mrWidget|Merge blocked: all threads must be resolved.') }}
      </span>
      <gl-button
        data-testid="jump-to-first"
        class="gl-ml-3"
        size="small"
        :icon="glFeatures.restructuredMrWidget ? undefined : 'comment-next'"
        :variant="glFeatures.restructuredMrWidget ? 'confirm' : 'default'"
        :category="glFeatures.restructuredMrWidget ? 'secondary' : 'primary'"
        @click="jumpToFirstUnresolvedDiscussion"
      >
        {{ s__('mrWidget|Jump to first unresolved thread') }}
      </gl-button>
      <gl-button
        v-if="mr.createIssueToResolveDiscussionsPath"
        :href="mr.createIssueToResolveDiscussionsPath"
        class="js-create-issue gl-ml-3"
        size="small"
        :icon="glFeatures.restructuredMrWidget ? undefined : 'issue-new'"
      >
        {{ s__('mrWidget|Create issue to resolve all threads') }}
      </gl-button>
    </div>
  </div>
</template>
