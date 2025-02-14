<script>
import {
  GlLoadingIcon,
  GlEmptyState,
  GlLink,
  GlIcon,
  GlAlert,
  GlTooltipDirective,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { n__, s__, __ } from '~/locale';
import { formatDate, getDayDifference, isToday } from '~/lib/utils/datetime_utility';
import { EVENTS_STORED_DAYS } from '../constants';
import getAgentActivityEventsQuery from '../graphql/queries/get_agent_activity_events.query.graphql';
import ActivityHistoryItem from './activity_history_item.vue';

export default {
  components: {
    GlLoadingIcon,
    GlEmptyState,
    GlAlert,
    GlLink,
    GlIcon,
    ActivityHistoryItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    emptyText: s__(
      'ClusterAgents|See Agent activity updates such as tokens created or revoked and clusters connected or not connected.',
    ),
    emptyTooltip: s__('ClusterAgents|What is GitLab Agent activity?'),
    error: s__(
      'ClusterAgents|An error occurred while retrieving GitLab Agent activity. Reload the page to try again.',
    ),
    today: __('Today'),
    yesterday: __('Yesterday'),
  },
  emptyHelpLink: helpPagePath('user/clusters/agent/install/index', {
    anchor: 'view-agent-activity',
  }),
  borderClasses: 'gl-border-b-1 gl-border-b-solid gl-border-b-gray-100',
  apollo: {
    agentEvents: {
      query: getAgentActivityEventsQuery,
      variables() {
        return {
          agentName: this.agentName,
          projectPath: this.projectPath,
        };
      },
      update: (data) => data?.project?.clusterAgent?.activityEvents?.nodes,
      error() {
        this.isError = true;
      },
    },
  },
  inject: ['agentName', 'projectPath', 'activityEmptyStateImage'],
  data() {
    return {
      isError: false,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.agentEvents?.loading;
    },
    emptyStateTitle() {
      return n__(
        "ClusterAgents|There's no activity from the past day",
        "ClusterAgents|There's no activity from the past %d days",
        EVENTS_STORED_DAYS,
      );
    },
    eventsList() {
      const list = this.agentEvents;
      const listByDates = {};

      if (!list?.length) {
        return listByDates;
      }

      list.forEach((event) => {
        const dateName = this.getFormattedDate(event.recordedAt);
        if (!listByDates[dateName]) {
          listByDates[dateName] = [];
        }
        listByDates[dateName].push(event);
      });

      return listByDates;
    },
    hasEvents() {
      return Object.keys(this.eventsList).length;
    },
  },
  methods: {
    isYesterday(date) {
      const today = new Date();
      return getDayDifference(today, date) === -1;
    },
    getFormattedDate(dateString) {
      const date = new Date(dateString);
      let dateName;
      if (isToday(date)) {
        dateName = this.$options.i18n.today;
      } else if (this.isYesterday(date)) {
        dateName = this.$options.i18n.yesterday;
      } else {
        dateName = formatDate(date, 'yyyy-mm-dd');
      }
      return dateName;
    },
    isLast(dateEvents, idx) {
      return idx === dateEvents.length - 1;
    },
    getBodyClasses(dateEvents, idx) {
      return !this.isLast(dateEvents, idx) ? this.$options.borderClasses : '';
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="md" />

    <div v-else-if="hasEvents">
      <div
        v-for="(dateEvents, key) in eventsList"
        :key="key"
        class="agent-activity-list issuable-discussion"
      >
        <h4
          class="gl-pb-4 gl-ml-5"
          :class="$options.borderClasses"
          data-testid="activity-section-title"
        >
          {{ key }}
        </h4>

        <ul class="notes main-notes-list timeline">
          <activity-history-item
            v-for="(event, idx) in dateEvents"
            :key="idx"
            :event="event"
            :body-class="getBodyClasses(dateEvents, idx)"
          />
        </ul>
      </div>
    </div>

    <gl-alert v-else-if="isError" variant="danger" :dismissible="false" class="gl-mt-3">
      {{ $options.i18n.error }}
    </gl-alert>

    <gl-empty-state
      v-else
      :title="emptyStateTitle"
      :svg-path="activityEmptyStateImage"
      :svg-height="150"
    >
      <template #description
        >{{ $options.i18n.emptyText }}
        <gl-link
          v-gl-tooltip
          :href="$options.emptyHelpLink"
          :title="$options.i18n.emptyTooltip"
          :aria-label="$options.i18n.emptyTooltip"
          ><gl-icon name="question" :size="14"
        /></gl-link>
      </template>
    </gl-empty-state>
  </div>
</template>
