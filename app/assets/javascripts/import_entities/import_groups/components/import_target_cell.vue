<script>
import {
  GlDropdownDivider,
  GlDropdownItem,
  GlDropdownSectionHeader,
  GlFormInput,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import ImportGroupDropdown from '../../components/group_dropdown.vue';
import { getInvalidNameValidationMessage } from '../utils';

export default {
  components: {
    ImportGroupDropdown,
    GlDropdownDivider,
    GlDropdownItem,
    GlDropdownSectionHeader,
    GlFormInput,
  },
  props: {
    group: {
      type: Object,
      required: true,
    },
    availableNamespaces: {
      type: Array,
      required: true,
    },
  },

  computed: {
    fullPath() {
      return this.group.importTarget.targetNamespace.fullPath || s__('BulkImport|No parent');
    },
    validationMessage() {
      return (
        this.group.progress?.message || getInvalidNameValidationMessage(this.group.importTarget)
      );
    },
    validNameState() {
      // bootstrap-vue requires null for "indifferent" state, if we return true
      // this will highlight field in green like "passed validation"
      return this.group.flags.isInvalid && this.group.flags.isAvailableForImport ? false : null;
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-display-flex gl-align-items-stretch">
      <import-group-dropdown
        #default="{ namespaces }"
        :text="fullPath"
        :disabled="!group.flags.isAvailableForImport"
        :namespaces="availableNamespaces"
        toggle-class="gl-rounded-top-right-none! gl-rounded-bottom-right-none!"
        class="gl-h-7 gl-flex-grow-1"
        data-qa-selector="target_namespace_selector_dropdown"
      >
        <gl-dropdown-item @click="$emit('update-target-namespace', { fullPath: '', id: null })">{{
          s__('BulkImport|No parent')
        }}</gl-dropdown-item>
        <template v-if="namespaces.length">
          <gl-dropdown-divider />
          <gl-dropdown-section-header>
            {{ s__('BulkImport|Existing groups') }}
          </gl-dropdown-section-header>
          <gl-dropdown-item
            v-for="ns in namespaces"
            :key="ns.fullPath"
            data-qa-selector="target_group_dropdown_item"
            :data-qa-group-name="ns.fullPath"
            @click="$emit('update-target-namespace', ns)"
          >
            {{ ns.fullPath }}
          </gl-dropdown-item>
        </template>
      </import-group-dropdown>
      <div
        class="gl-h-7 gl-px-3 gl-display-flex gl-align-items-center gl-border-solid gl-border-0 gl-border-t-1 gl-border-b-1 gl-bg-gray-10"
        :class="{
          'gl-text-gray-400 gl-border-gray-100': !group.flags.isAvailableForImport,
          'gl-border-gray-200': group.flags.isAvailableForImport,
        }"
      >
        /
      </div>
      <div class="gl-flex-grow-1">
        <gl-form-input
          class="gl-rounded-top-left-none gl-rounded-bottom-left-none"
          :class="{
            'gl-inset-border-1-gray-200!':
              group.flags.isAvailableForImport && !group.flags.isInvalid,
            'gl-inset-border-1-gray-100!':
              !group.flags.isAvailableForImport && !group.flags.isInvalid,
          }"
          debounce="500"
          :disabled="!group.flags.isAvailableForImport"
          :value="group.importTarget.newName"
          :aria-label="__('New name')"
          :state="validNameState"
          @input="$emit('update-new-name', $event)"
        />
      </div>
    </div>
    <div
      v-if="group.flags.isAvailableForImport && (group.flags.isInvalid || validationMessage)"
      class="gl-text-red-500 gl-m-0 gl-mt-2"
      role="alert"
    >
      {{ validationMessage }}
    </div>
  </div>
</template>
