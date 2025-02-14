<script>
import {
  GlAvatarLabeled,
  GlDropdown,
  GlDropdownItem,
  GlDropdownText,
  GlSearchBoxByType,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { s__ } from '~/locale';
import { getGroups, getDescendentGroups } from '~/rest_api';
import { SEARCH_DELAY, GROUP_FILTERS } from '../constants';

export default {
  name: 'GroupSelect',
  components: {
    GlAvatarLabeled,
    GlDropdown,
    GlDropdownItem,
    GlDropdownText,
    GlSearchBoxByType,
  },
  model: {
    prop: 'selectedGroup',
  },
  props: {
    accessLevels: {
      type: Object,
      required: true,
    },
    groupsFilter: {
      type: String,
      required: false,
      default: GROUP_FILTERS.ALL,
    },
    parentGroupId: {
      type: Number,
      required: false,
      default: null,
    },
    invalidGroups: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      isFetching: false,
      groups: [],
      selectedGroup: {},
      searchTerm: '',
    };
  },
  computed: {
    selectedGroupName() {
      return this.selectedGroup.name || this.$options.i18n.dropdownText;
    },
    isFetchResultEmpty() {
      return this.groups.length === 0;
    },
    defaultFetchOptions() {
      return {
        exclude_internal: true,
        active: true,
        min_access_level: this.accessLevels.Guest,
      };
    },
  },
  watch: {
    searchTerm() {
      this.retrieveGroups();
    },
  },
  mounted() {
    this.retrieveGroups();
  },
  methods: {
    retrieveGroups: debounce(function debouncedRetrieveGroups() {
      this.isFetching = true;
      return this.fetchGroups()
        .then((response) => {
          this.groups = this.processGroups(response);
          this.isFetching = false;
        })
        .catch(() => {
          this.isFetching = false;
        });
    }, SEARCH_DELAY),
    processGroups(response) {
      const rawGroups = response.map((group) => ({
        id: group.id,
        name: group.full_name,
        path: group.path,
        avatarUrl: group.avatar_url,
      }));

      return this.filterOutInvalidGroups(rawGroups);
    },
    filterOutInvalidGroups(groups) {
      return groups.filter((group) => this.invalidGroups.indexOf(group.id) === -1);
    },
    selectGroup(group) {
      this.selectedGroup = group;

      this.$emit('input', this.selectedGroup);
    },
    fetchGroups() {
      switch (this.groupsFilter) {
        case GROUP_FILTERS.DESCENDANT_GROUPS:
          return getDescendentGroups(this.parentGroupId, this.searchTerm, this.defaultFetchOptions);
        default:
          return getGroups(this.searchTerm, this.defaultFetchOptions);
      }
    },
  },
  i18n: {
    dropdownText: s__('GroupSelect|Select a group'),
    searchPlaceholder: s__('GroupSelect|Search groups'),
    emptySearchResult: s__('GroupSelect|No matching results'),
  },
};
</script>
<template>
  <div>
    <gl-dropdown
      data-testid="group-select-dropdown"
      :text="selectedGroupName"
      block
      toggle-class="gl-mb-2"
      menu-class="gl-w-full!"
    >
      <gl-search-box-by-type
        v-model="searchTerm"
        :is-loading="isFetching"
        :placeholder="$options.i18n.searchPlaceholder"
        data-qa-selector="group_select_dropdown_search_field"
      />
      <gl-dropdown-item
        v-for="group in groups"
        :key="group.id"
        :name="group.name"
        @click="selectGroup(group)"
      >
        <gl-avatar-labeled
          :label="group.name"
          :src="group.avatarUrl"
          :entity-id="group.id"
          :entity-name="group.name"
          :size="32"
        />
      </gl-dropdown-item>
      <gl-dropdown-text v-if="isFetchResultEmpty && !isFetching" data-testid="empty-result-message">
        <span class="gl-text-gray-500">{{ $options.i18n.emptySearchResult }}</span>
      </gl-dropdown-text>
    </gl-dropdown>
  </div>
</template>
