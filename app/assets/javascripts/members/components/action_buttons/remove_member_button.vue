<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { mapActions, mapState } from 'vuex';

export default {
  name: 'RemoveMemberButton',
  components: { GlButton },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['namespace'],
  props: {
    memberId: {
      type: Number,
      required: true,
    },
    memberType: {
      type: String,
      required: false,
      default: null,
    },
    message: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    icon: {
      type: String,
      required: false,
      default: undefined,
    },
    buttonText: {
      type: String,
      required: false,
      default: '',
    },
    buttonCategory: {
      type: String,
      required: false,
      default: 'secondary',
    },
    isAccessRequest: {
      type: Boolean,
      required: false,
      default: false,
    },
    isInvite: {
      type: Boolean,
      required: false,
      default: false,
    },
    userDeletionObstacles: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    ...mapState({
      memberPath(state) {
        return state[this.namespace].memberPath;
      },
    }),
    modalData() {
      return {
        isAccessRequest: this.isAccessRequest,
        isInvite: this.isInvite,
        memberPath: this.memberPath.replace(':id', this.memberId),
        memberType: this.memberType,
        message: this.message,
        userDeletionObstacles: this.userDeletionObstacles,
      };
    },
  },
  methods: {
    ...mapActions({
      showRemoveMemberModal(dispatch, payload) {
        return dispatch(`${this.namespace}/showRemoveMemberModal`, payload);
      },
    }),
  },
};
</script>

<template>
  <gl-button
    v-gl-tooltip
    variant="danger"
    :category="buttonCategory"
    :title="title"
    :aria-label="title"
    :icon="icon"
    data-qa-selector="delete_member_button"
    @click="showRemoveMemberModal(modalData)"
    ><template v-if="buttonText">{{ buttonText }}</template></gl-button
  >
</template>
